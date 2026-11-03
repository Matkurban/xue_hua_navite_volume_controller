#include "include/xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "xue_hua_navite_volume_controller_plugin_private.h"

#define XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST(                       \
      (obj), xue_hua_navite_volume_controller_plugin_get_type(), \
      XueHuaNaviteVolumeControllerPlugin))

struct _XueHuaNaviteVolumeControllerPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  gchar* default_stream;
  gdouble pre_mute_volume;
  gdouble last_volume;
  gboolean last_muted;
  guint poll_timer_id;
};

G_DEFINE_TYPE(XueHuaNaviteVolumeControllerPlugin,
              xue_hua_navite_volume_controller_plugin,
              g_object_get_type())

namespace {

enum class LinuxAudioBackend {
  kWpctl,
  kPactl,
  kAmixer,
  kFallbackMemory,
};

double g_fallback_volume = 0.5;
bool g_fallback_muted = false;

std::string RunCommandCapture(const std::string& cmd) {
  std::string output;
  FILE* pipe = popen(cmd.c_str(), "r");
  if (!pipe) return output;
  char buffer[256];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    output += buffer;
  }
  pclose(pipe);
  return output;
}

bool CommandExists(const char* binary) {
  std::string cmd = std::string("command -v ") + binary + " >/dev/null 2>&1";
  return system(cmd.c_str()) == 0;
}

LinuxAudioBackend DetectLinuxBackend() {
  static bool initialized = false;
  static LinuxAudioBackend cached = LinuxAudioBackend::kFallbackMemory;
  if (initialized) return cached;
  initialized = true;

  if (CommandExists("pactl")) {
    std::string out = RunCommandCapture("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null");
    if (!out.empty()) {
      cached = LinuxAudioBackend::kPactl;
      return cached;
    }
  }
  if (CommandExists("wpctl")) {
    std::string out = RunCommandCapture("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null");
    if (!out.empty()) {
      cached = LinuxAudioBackend::kWpctl;
      return cached;
    }
  }
  if (CommandExists("amixer")) {
    std::string out = RunCommandCapture("amixer get Master 2>/dev/null");
    if (!out.empty()) {
      cached = LinuxAudioBackend::kAmixer;
      return cached;
    }
  }
  cached = LinuxAudioBackend::kFallbackMemory;
  return cached;
}

const char* BackendDisplayName(LinuxAudioBackend backend) {
  switch (backend) {
    case LinuxAudioBackend::kPactl:
      return "Linux PulseAudio / PipeWire (pactl)";
    case LinuxAudioBackend::kWpctl:
      return "Linux PipeWire WirePlumber (wpctl)";
    case LinuxAudioBackend::kAmixer:
      return "Linux ALSA Mixer (amixer)";
    case LinuxAudioBackend::kFallbackMemory:
      return "Linux Software Mixer Fallback";
  }
  return "Linux Audio";
}

void QueryLinuxVolumeAndMute(double* out_volume, bool* out_muted) {
  LinuxAudioBackend backend = DetectLinuxBackend();
  if (backend == LinuxAudioBackend::kPactl) {
    std::string vol_out =
        RunCommandCapture("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null");
    size_t pct_pos = vol_out.find('%');
    if (pct_pos != std::string::npos) {
      size_t start = pct_pos;
      while (start > 0 && std::isdigit(static_cast<unsigned char>(vol_out[start - 1]))) {
        --start;
      }
      if (start < pct_pos) {
        int pct = std::atoi(vol_out.substr(start, pct_pos - start).c_str());
        *out_volume = std::clamp(pct / 100.0, 0.0, 1.0);
      }
    }
    std::string mute_out =
        RunCommandCapture("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null");
    *out_muted = (mute_out.find("yes") != std::string::npos) || (*out_volume <= 0.0001);
    return;
  }

  if (backend == LinuxAudioBackend::kWpctl) {
    std::string out =
        RunCommandCapture("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null");
    // Format: "Volume: 0.45" or "Volume: 0.45 [MUTED]"
    size_t colon = out.find(':');
    if (colon != std::string::npos) {
      double val = std::atof(out.substr(colon + 1).c_str());
      *out_volume = std::clamp(val, 0.0, 1.0);
    }
    *out_muted = (out.find("MUTED") != std::string::npos) || (*out_volume <= 0.0001);
    return;
  }

  if (backend == LinuxAudioBackend::kAmixer) {
    std::string out = RunCommandCapture("amixer get Master 2>/dev/null");
    size_t pct_pos = out.find('%');
    if (pct_pos != std::string::npos) {
      size_t start = pct_pos;
      while (start > 0 && std::isdigit(static_cast<unsigned char>(out[start - 1]))) {
        --start;
      }
      if (start < pct_pos) {
        int pct = std::atoi(out.substr(start, pct_pos - start).c_str());
        *out_volume = std::clamp(pct / 100.0, 0.0, 1.0);
      }
    }
    *out_muted = (out.find("[off]") != std::string::npos) || (*out_volume <= 0.0001);
    return;
  }

  *out_volume = g_fallback_volume;
  *out_muted = g_fallback_muted;
}

void ApplyLinuxVolume(double target_volume) {
  double clamped = std::clamp(target_volume, 0.0, 1.0);
  int pct = static_cast<int>(std::round(clamped * 100.0));
  g_fallback_volume = clamped;
  if (clamped > 0.0001) {
    g_fallback_muted = false;
  }

  LinuxAudioBackend backend = DetectLinuxBackend();
  char cmd[256];
  if (backend == LinuxAudioBackend::kPactl) {
    if (clamped > 0.0001) {
      std::snprintf(cmd, sizeof(cmd),
                    "pactl set-sink-mute @DEFAULT_SINK@ 0 >/dev/null 2>&1 && "
                    "pactl set-sink-volume @DEFAULT_SINK@ %d%% >/dev/null 2>&1",
                    pct);
    } else {
      std::snprintf(cmd, sizeof(cmd),
                    "pactl set-sink-volume @DEFAULT_SINK@ 0%% >/dev/null 2>&1");
    }
    (void)system(cmd);
  } else if (backend == LinuxAudioBackend::kWpctl) {
    if (clamped > 0.0001) {
      std::snprintf(cmd, sizeof(cmd),
                    "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 && "
                    "wpctl set-volume @DEFAULT_AUDIO_SINK@ %.2f >/dev/null 2>&1",
                    clamped);
    } else {
      std::snprintf(cmd, sizeof(cmd),
                    "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.0 >/dev/null 2>&1");
    }
    (void)system(cmd);
  } else if (backend == LinuxAudioBackend::kAmixer) {
    std::snprintf(cmd, sizeof(cmd),
                  "amixer set Master %d%% unmute >/dev/null 2>&1", pct);
    (void)system(cmd);
  }
}

void ApplyLinuxMute(bool muted) {
  g_fallback_muted = muted;
  LinuxAudioBackend backend = DetectLinuxBackend();
  if (backend == LinuxAudioBackend::kPactl) {
    std::string cmd = std::string("pactl set-sink-mute @DEFAULT_SINK@ ") +
                      (muted ? "1" : "0") + " >/dev/null 2>&1";
    (void)system(cmd.c_str());
  } else if (backend == LinuxAudioBackend::kWpctl) {
    std::string cmd = std::string("wpctl set-mute @DEFAULT_AUDIO_SINK@ ") +
                      (muted ? "1" : "0") + " >/dev/null 2>&1";
    (void)system(cmd.c_str());
  } else if (backend == LinuxAudioBackend::kAmixer) {
    std::string cmd = std::string("amixer set Master ") +
                      (muted ? "mute" : "unmute") + " >/dev/null 2>&1";
    (void)system(cmd.c_str());
  }
}

std::string ReadDefaultSinkName() {
  if (DetectLinuxBackend() == LinuxAudioBackend::kPactl) {
    std::string out = RunCommandCapture("pactl get-default-sink 2>/dev/null");
    while (!out.empty() && (out.back() == '\n' || out.back() == '\r')) {
      out.pop_back();
    }
    if (!out.empty()) return out;
  }
  return "Linux Default Audio Sink";
}

FlValue* BuildVolumeStateFlValue(XueHuaNaviteVolumeControllerPlugin* self,
                                 const gchar* stream_name) {
  double vol = 0.5;
  bool muted = false;
  QueryLinuxVolumeAndMute(&vol, &muted);

  self->last_volume = vol;
  self->last_muted = muted;
  if (!muted && vol > 0.0001) {
    self->pre_mute_volume = vol;
  }

  std::string sink_name = ReadDefaultSinkName();

  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "volume", fl_value_new_float(vol));
  fl_value_set_string_take(map, "isMuted", fl_value_new_bool(muted));
  fl_value_set_string_take(map, "streamType",
                           fl_value_new_string(stream_name ? stream_name : "media"));
  fl_value_set_string_take(map, "stepIndex",
                           fl_value_new_int(static_cast<int64_t>(std::round(vol * 100.0))));
  fl_value_set_string_take(map, "maxSteps", fl_value_new_int(100));
  fl_value_set_string_take(map, "minSteps", fl_value_new_int(0));
  fl_value_set_string_take(map, "ringerMode",
                           fl_value_new_string(muted ? "silent" : "normal"));
  fl_value_set_string_take(map, "outputDeviceName",
                           fl_value_new_string(sink_name.c_str()));
  fl_value_set_string_take(map, "outputRoute", fl_value_new_string("speaker"));
  fl_value_set_string_take(map, "outputDeviceId",
                           fl_value_new_string(sink_name.c_str()));
  return map;
}

void EmitLinuxVolumeChange(XueHuaNaviteVolumeControllerPlugin* self,
                           FlValue* state_value,
                           double old_volume,
                           const char* reason) {
  if (!self->channel) return;
  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string(event, "state", state_value);
  fl_value_set_string_take(event, "oldVolume", fl_value_new_float(old_volume));
  fl_value_set_string_take(event, "reason", fl_value_new_string(reason));
  gint64 now_ms = g_get_real_time() / 1000;
  fl_value_set_string_take(event, "timestamp", fl_value_new_int(now_ms));

  fl_method_channel_invoke_method(self->channel, "onVolumeChanged", event,
                                  nullptr, nullptr, nullptr);
}

gboolean OnLinuxVolumePollTick(gpointer user_data) {
  XueHuaNaviteVolumeControllerPlugin* self =
      XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN(user_data);
  double current_vol = 0.5;
  bool current_muted = false;
  QueryLinuxVolumeAndMute(&current_vol, &current_muted);

  if (std::abs(current_vol - self->last_volume) > 0.005 ||
      current_muted != static_cast<bool>(self->last_muted)) {
    double prev_vol = self->last_volume;
    g_autoptr(FlValue) state =
        BuildVolumeStateFlValue(self, self->default_stream);
    EmitLinuxVolumeChange(self, state, prev_vol, "system");
  }
  return G_SOURCE_CONTINUE;
}

}  // namespace

FlMethodResponse* get_linux_capabilities() {
  g_autoptr(FlValue) cap = fl_value_new_map();
  fl_value_set_string_take(cap, "platform", fl_value_new_string("linux"));
  fl_value_set_string_take(cap, "supportsSystemVolumeControl",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(cap, "supportsMuteControl",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(cap, "supportsVolumeChangeListening",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(cap, "supportsHardwareButtonInterception",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(cap, "supportsSystemUIControl",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(cap, "supportsMultipleStreamTypes",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(cap, "supportsRingerMode",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(cap, "supportsAudioDeviceListing",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(
      cap, "supportsDeviceSelection",
      fl_value_new_bool(DetectLinuxBackend() == LinuxAudioBackend::kPactl));
  fl_value_set_string_take(cap, "supportsAppVolumeControl",
                           fl_value_new_bool(FALSE));

  g_autoptr(FlValue) streams = fl_value_new_list();
  fl_value_append_take(streams, fl_value_new_string("media"));
  fl_value_set_string(cap, "supportedStreams", streams);
  fl_value_set_string_take(
      cap, "audioBackend",
      fl_value_new_string(BackendDisplayName(DetectLinuxBackend())));

  g_autoptr(FlValue) notes = fl_value_new_list();
  fl_value_append_take(
      notes, fl_value_new_string(
                 "Automatically detects PipeWire (wpctl), PulseAudio (pactl), or ALSA (amixer) at runtime without requiring extra compile-time libraries."));
  fl_value_set_string(cap, "platformNotes", notes);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(cap));
}

static void xue_hua_navite_volume_controller_plugin_handle_method_call(
    XueHuaNaviteVolumeControllerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  auto get_str_arg = [&](const char* key, const char* fallback) -> const char* {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, key);
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
        return fl_value_get_string(v);
      }
    }
    return fallback;
  };

  auto get_double_arg = [&](const char* key, double fallback) -> double {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, key);
      if (v) {
        if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) {
          return fl_value_get_float(v);
        }
        if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
          return static_cast<double>(fl_value_get_int(v));
        }
      }
    }
    return fallback;
  };

  auto get_bool_arg = [&](const char* key, bool fallback) -> bool {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, key);
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        return fl_value_get_bool(v);
      }
    }
    return fallback;
  };

  if (strcmp(method, "initialize") == 0) {
    const char* stream = get_str_arg("defaultStream", "media");
    g_free(self->default_stream);
    self->default_stream = g_strdup(stream);
    bool listen = get_bool_arg("listenToVolumeChanges", true);
    if (listen && self->poll_timer_id == 0) {
      self->poll_timer_id =
          g_timeout_add(350, OnLinuxVolumePollTick, self);
    }
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, self->default_stream);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "getCapabilities") == 0) {
    g_autoptr(FlValue) cap = fl_value_new_map();
    fl_value_set_string_take(cap, "platform", fl_value_new_string("linux"));
    fl_value_set_string_take(cap, "supportsSystemVolumeControl",
                             fl_value_new_bool(TRUE));
    fl_value_set_string_take(cap, "supportsMuteControl",
                             fl_value_new_bool(TRUE));
    fl_value_set_string_take(cap, "supportsVolumeChangeListening",
                             fl_value_new_bool(TRUE));
    fl_value_set_string_take(cap, "supportsHardwareButtonInterception",
                             fl_value_new_bool(FALSE));
    fl_value_set_string_take(cap, "supportsSystemUIControl",
                             fl_value_new_bool(FALSE));
    fl_value_set_string_take(cap, "supportsMultipleStreamTypes",
                             fl_value_new_bool(FALSE));
    fl_value_set_string_take(cap, "supportsRingerMode",
                             fl_value_new_bool(FALSE));
    fl_value_set_string_take(cap, "supportsAudioDeviceListing",
                             fl_value_new_bool(TRUE));
    fl_value_set_string_take(
        cap, "supportsDeviceSelection",
        fl_value_new_bool(DetectLinuxBackend() == LinuxAudioBackend::kPactl));
    fl_value_set_string_take(cap, "supportsAppVolumeControl",
                             fl_value_new_bool(FALSE));

    g_autoptr(FlValue) streams = fl_value_new_list();
    fl_value_append_take(streams, fl_value_new_string("media"));
    fl_value_set_string(cap, "supportedStreams", streams);
    fl_value_set_string_take(
        cap, "audioBackend",
        fl_value_new_string(BackendDisplayName(DetectLinuxBackend())));

    g_autoptr(FlValue) notes = fl_value_new_list();
    fl_value_append_take(
        notes, fl_value_new_string(
                   "Automatically detects PipeWire (wpctl), PulseAudio (pactl), or ALSA (amixer) at runtime without requiring extra compile-time libraries."));
    fl_value_set_string(cap, "platformNotes", notes);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(cap));
  } else if (strcmp(method, "getVolumeState") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "getVolume") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    g_autoptr(FlValue) res = fl_value_new_float(vol);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setVolume") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    double target = std::clamp(get_double_arg("volume", 0.5), 0.0, 1.0);
    double old_vol = self->last_volume;
    ApplyLinuxVolume(target);
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    EmitLinuxVolumeChange(self, state, old_vol, "programmatic");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "adjustVolume") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    double delta = std::clamp(get_double_arg("delta", 0.0), -1.0, 1.0);
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    double target = std::clamp(vol + delta, 0.0, 1.0);
    ApplyLinuxVolume(target);
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    EmitLinuxVolumeChange(self, state, vol, "adjustVolume");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "stepVolume") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    const char* direction = get_str_arg("direction", "up");
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    if (strcmp(direction, "mute") == 0) {
      ApplyLinuxMute(!muted);
    } else {
      double step = (strcmp(direction, "up") == 0) ? 0.05 : -0.05;
      ApplyLinuxVolume(std::clamp(vol + step, 0.0, 1.0));
    }
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    EmitLinuxVolumeChange(self, state, vol, "stepVolume");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "getAllStreamVolumes") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "media", fl_value_new_float(vol));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
  } else if (strcmp(method, "isMuted") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    g_autoptr(FlValue) res = fl_value_new_bool(muted);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setMute") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    bool muted = get_bool_arg("muted", false);
    double old_vol = self->last_volume;
    ApplyLinuxMute(muted);
    if (!muted && old_vol <= 0.0001) {
      ApplyLinuxVolume(self->pre_mute_volume > 0.0001 ? self->pre_mute_volume : 0.5);
    }
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    EmitLinuxVolumeChange(self, state, old_vol, "muteChange");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "toggleMute") == 0) {
    const char* stream = get_str_arg("streamType", self->default_stream);
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    ApplyLinuxMute(!muted);
    g_autoptr(FlValue) state = BuildVolumeStateFlValue(self, stream);
    EmitLinuxVolumeChange(self, state, vol, "muteChange");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (strcmp(method, "getRingerMode") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    g_autoptr(FlValue) res = fl_value_new_string(muted ? "silent" : "normal");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setRingerMode") == 0) {
    const char* mode = get_str_arg("ringerMode", "normal");
    bool should_mute = (strcmp(mode, "silent") == 0 || strcmp(mode, "vibrate") == 0);
    ApplyLinuxMute(should_mute);
    g_autoptr(FlValue) res = fl_value_new_string(should_mute ? "silent" : "normal");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "hasDoNotDisturbAccess") == 0 ||
             strcmp(method, "requestDoNotDisturbAccess") == 0) {
    g_autoptr(FlValue) res = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setShowSystemUI") == 0 ||
             strcmp(method, "setInterceptHardwareButtons") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "getOutputDevices") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    std::string sink_name = ReadDefaultSinkName();
    g_autoptr(FlValue) list = fl_value_new_list();
    FlValue* dev = fl_value_new_map();
    fl_value_set_string_take(dev, "id", fl_value_new_string(sink_name.c_str()));
    fl_value_set_string_take(dev, "name", fl_value_new_string(sink_name.c_str()));
    fl_value_set_string_take(dev, "route", fl_value_new_string("speaker"));
    fl_value_set_string_take(dev, "isDefault", fl_value_new_bool(TRUE));
    fl_value_set_string_take(dev, "isOutput", fl_value_new_bool(TRUE));
    fl_value_set_string_take(dev, "isInput", fl_value_new_bool(FALSE));
    fl_value_set_string_take(dev, "volume", fl_value_new_float(vol));
    fl_value_set_string_take(dev, "isMuted", fl_value_new_bool(muted));
    fl_value_append_take(list, dev);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (strcmp(method, "getCurrentOutputDevice") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    std::string sink_name = ReadDefaultSinkName();
    g_autoptr(FlValue) dev = fl_value_new_map();
    fl_value_set_string_take(dev, "id", fl_value_new_string(sink_name.c_str()));
    fl_value_set_string_take(dev, "name", fl_value_new_string(sink_name.c_str()));
    fl_value_set_string_take(dev, "route", fl_value_new_string("speaker"));
    fl_value_set_string_take(dev, "isDefault", fl_value_new_bool(TRUE));
    fl_value_set_string_take(dev, "isOutput", fl_value_new_bool(TRUE));
    fl_value_set_string_take(dev, "isInput", fl_value_new_bool(FALSE));
    fl_value_set_string_take(dev, "volume", fl_value_new_float(vol));
    fl_value_set_string_take(dev, "isMuted", fl_value_new_bool(muted));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(dev));
  } else if (strcmp(method, "setOutputDevice") == 0) {
    const char* device_id = get_str_arg("deviceId", "");
    bool ok = false;
    if (device_id && strlen(device_id) > 0 &&
        DetectLinuxBackend() == LinuxAudioBackend::kPactl) {
      std::string cmd = std::string("pactl set-default-sink '") + device_id +
                        "' >/dev/null 2>&1";
      ok = (system(cmd.c_str()) == 0);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(ok);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "getAppVolume") == 0) {
    double vol = 0.5;
    bool muted = false;
    QueryLinuxVolumeAndMute(&vol, &muted);
    g_autoptr(FlValue) res = fl_value_new_float(vol);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setAppVolume") == 0) {
    double target = std::clamp(get_double_arg("volume", 1.0), 0.0, 1.0);
    ApplyLinuxVolume(target);
    g_autoptr(FlValue) res = fl_value_new_float(target);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "dispose") == 0) {
    if (self->poll_timer_id != 0) {
      g_source_remove(self->poll_timer_id);
      self->poll_timer_id = 0;
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_navite_volume_controller_plugin_dispose(GObject* object) {
  XueHuaNaviteVolumeControllerPlugin* self =
      XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN(object);
  if (self->poll_timer_id != 0) {
    g_source_remove(self->poll_timer_id);
    self->poll_timer_id = 0;
  }
  g_clear_object(&self->channel);
  g_free(self->default_stream);
  self->default_stream = nullptr;
  G_OBJECT_CLASS(xue_hua_navite_volume_controller_plugin_parent_class)
      ->dispose(object);
}

static void xue_hua_navite_volume_controller_plugin_class_init(
    XueHuaNaviteVolumeControllerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose =
      xue_hua_navite_volume_controller_plugin_dispose;
}

static void xue_hua_navite_volume_controller_plugin_init(
    XueHuaNaviteVolumeControllerPlugin* self) {
  self->channel = nullptr;
  self->default_stream = g_strdup("media");
  self->pre_mute_volume = 0.5;
  self->last_volume = 0.5;
  self->last_muted = FALSE;
  self->poll_timer_id = 0;
}

static void method_call_cb(FlMethodChannel* /*channel*/,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaNaviteVolumeControllerPlugin* plugin =
      XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN(user_data);
  xue_hua_navite_volume_controller_plugin_handle_method_call(plugin,
                                                             method_call);
}

void xue_hua_navite_volume_controller_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaNaviteVolumeControllerPlugin* plugin =
      XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN(g_object_new(
          xue_hua_navite_volume_controller_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "xue_hua_navite_volume_controller",
                            FL_METHOD_CODEC(codec));
  plugin->channel = FL_METHOD_CHANNEL(g_object_ref(channel));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(channel);
  g_object_unref(plugin);
}
