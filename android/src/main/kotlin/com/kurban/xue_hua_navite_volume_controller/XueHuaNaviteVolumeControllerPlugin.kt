package com.kurban.xue_hua_navite_volume_controller

import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import android.view.Window
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Native Android implementation of `xue_hua_navite_volume_controller`.
 *
 * Capabilities:
 * - Multi-stream volume control (`media`, `ring`, `alarm`, `notification`,
 *   `voiceCall`, `system`, `accessibility`, `dtmf`) via [AudioManager].
 * - Real-time volume and ringer mode observation via `android.media.VOLUME_CHANGED_ACTION`,
 *   [AudioManager.RINGER_MODE_CHANGED_ACTION], and [Settings.System.CONTENT_URI] fallback.
 * - System volume HUD visibility control (`AudioManager.FLAG_SHOW_UI` vs `0`).
 * - Physical hardware volume button interception (`KEYCODE_VOLUME_UP`,
 *   `KEYCODE_VOLUME_DOWN`, `KEYCODE_VOLUME_MUTE`) via a non-intrusive [Window.Callback] proxy.
 * - Ringer mode querying and modification (`normal`, `vibrate`, `silent`) with
 *   Do Not Disturb (`NotificationPolicy`) permission detection and settings navigation.
 * - Audio output device enumeration (`AudioManager.getDevices(GET_DEVICES_OUTPUTS)`)
 *   and communication device routing on Android 12+ (API 31+).
 */
class XueHuaNaviteVolumeControllerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var audioManager: AudioManager? = null
    private var notificationManager: NotificationManager? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var showSystemUI: Boolean = false
    private var interceptHardwareButtons: Boolean = false
    private var defaultStreamName: String = "media"
    private var isListening: Boolean = false

    private val lastObservedVolumes = mutableMapOf<String, Double>()
    private val preMuteVolumes = mutableMapOf<String, Double>()

    private var volumeBroadcastReceiver: BroadcastReceiver? = null
    private var settingsContentObserver: ContentObserver? = null
    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var originalWindowCallback: Window.Callback? = null
    private var interceptedWindow: Window? = null

    companion object {
        private const val ACTION_VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION"
        private const val EXTRA_VOLUME_STREAM_TYPE = "android.media.EXTRA_VOLUME_STREAM_TYPE"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        audioManager = applicationContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        notificationManager =
            applicationContext?.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "xue_hua_navite_volume_controller"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopVolumeObservation()
        restoreWindowCallback()
        channel.setMethodCallHandler(null)
        applicationContext = null
        audioManager = null
        notificationManager = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (interceptHardwareButtons) {
            installWindowCallbackIfNeeded()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        restoreWindowCallback()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (interceptHardwareButtons) {
            installWindowCallbackIfNeeded()
        }
    }

    override fun onDetachedFromActivity() {
        restoreWindowCallback()
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    defaultStreamName = call.argument<String>("defaultStream") ?: "media"
                    showSystemUI = call.argument<Boolean>("showSystemUI") ?: false
                    interceptHardwareButtons =
                        call.argument<Boolean>("interceptHardwareButtons") ?: false
                    val listenToVolumeChanges =
                        call.argument<Boolean>("listenToVolumeChanges") ?: true

                    if (listenToVolumeChanges) {
                        startVolumeObservation()
                    }
                    if (interceptHardwareButtons) {
                        installWindowCallbackIfNeeded()
                    } else {
                        restoreWindowCallback()
                    }
                    result.success(buildVolumeStateMap(defaultStreamName))
                }

                "getCapabilities" -> {
                    result.success(buildCapabilitiesMap())
                }

                "getVolumeState" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    result.success(buildVolumeStateMap(streamName))
                }

                "getVolume" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    result.success(readNormalizedVolume(mapStreamType(streamName)))
                }

                "setVolume" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    val targetVolume = (call.argument<Number>("volume")?.toDouble() ?: 0.5)
                        .coerceIn(0.0, 1.0)
                    val showUi = call.argument<Boolean>("showSystemUI") ?: showSystemUI
                    val state = setNormalizedVolume(streamName, targetVolume, showUi)
                    result.success(state)
                }

                "adjustVolume" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    val delta = (call.argument<Number>("delta")?.toDouble() ?: 0.0)
                        .coerceIn(-1.0, 1.0)
                    val showUi = call.argument<Boolean>("showSystemUI") ?: showSystemUI
                    val current = readNormalizedVolume(mapStreamType(streamName))
                    val target = (current + delta).coerceIn(0.0, 1.0)
                    val state = setNormalizedVolume(streamName, target, showUi)
                    result.success(state)
                }

                "stepVolume" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    val direction = call.argument<String>("direction") ?: "up"
                    val showUi = call.argument<Boolean>("showSystemUI") ?: showSystemUI
                    val state = stepStreamVolume(streamName, direction, showUi)
                    result.success(state)
                }

                "getAllStreamVolumes" -> {
                    val volumes = mutableMapOf<String, Double>()
                    val streams = listOf(
                        "media",
                        "ring",
                        "alarm",
                        "notification",
                        "voiceCall",
                        "system",
                        "accessibility",
                        "dtmf"
                    )
                    for (stream in streams) {
                        volumes[stream] = readNormalizedVolume(mapStreamType(stream))
                    }
                    result.success(volumes)
                }

                "isMuted" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    result.success(readStreamMuted(mapStreamType(streamName)))
                }

                "setMute" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    val muted = call.argument<Boolean>("muted") ?: false
                    val showUi = call.argument<Boolean>("showSystemUI") ?: showSystemUI
                    result.success(setStreamMuteState(streamName, muted, showUi))
                }

                "toggleMute" -> {
                    val streamName = call.argument<String>("streamType") ?: defaultStreamName
                    val showUi = call.argument<Boolean>("showSystemUI") ?: showSystemUI
                    val currentlyMuted = readStreamMuted(mapStreamType(streamName))
                    result.success(setStreamMuteState(streamName, !currentlyMuted, showUi))
                }

                "getRingerMode" -> {
                    result.success(readRingerModeWireName())
                }

                "setRingerMode" -> {
                    val modeName = call.argument<String>("ringerMode") ?: "normal"
                    val updatedMode = applyRingerMode(modeName)
                    result.success(updatedMode)
                }

                "hasDoNotDisturbAccess" -> {
                    result.success(checkDoNotDisturbAccess())
                }

                "requestDoNotDisturbAccess" -> {
                    result.success(openDoNotDisturbSettings())
                }

                "setShowSystemUI" -> {
                    showSystemUI = call.argument<Boolean>("showSystemUI") ?: false
                    result.success(null)
                }

                "setInterceptHardwareButtons" -> {
                    interceptHardwareButtons = call.argument<Boolean>("intercept") ?: false
                    if (interceptHardwareButtons) {
                        installWindowCallbackIfNeeded()
                    } else {
                        restoreWindowCallback()
                    }
                    result.success(null)
                }

                "getOutputDevices" -> {
                    result.success(listOutputDevices())
                }

                "getCurrentOutputDevice" -> {
                    result.success(findActiveOutputDevice())
                }

                "setOutputDevice" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    result.success(selectOutputDevice(deviceId))
                }

                "getAppVolume" -> {
                    result.success(readNormalizedVolume(AudioManager.STREAM_MUSIC))
                }

                "setAppVolume" -> {
                    val target = (call.argument<Number>("volume")?.toDouble() ?: 1.0)
                        .coerceIn(0.0, 1.0)
                    setNormalizedVolume("media", target, false)
                    result.success(readNormalizedVolume(AudioManager.STREAM_MUSIC))
                }

                "dispose" -> {
                    stopVolumeObservation()
                    restoreWindowCallback()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (se: SecurityException) {
            result.error(
                "DND_PERMISSION_REQUIRED",
                "Modifying Do Not Disturb / Silent mode requires Notification Policy access: ${se.message}",
                null
            )
        } catch (t: Throwable) {
            result.error(
                "ANDROID_VOLUME_ERROR",
                t.message ?: "Unexpected Android audio volume error.",
                null
            )
        }
    }

    private fun mapStreamType(streamName: String): Int {
        return when (streamName) {
            "media" -> AudioManager.STREAM_MUSIC
            "ring" -> AudioManager.STREAM_RING
            "alarm" -> AudioManager.STREAM_ALARM
            "notification" -> AudioManager.STREAM_NOTIFICATION
            "voiceCall" -> AudioManager.STREAM_VOICE_CALL
            "system" -> AudioManager.STREAM_SYSTEM
            "accessibility" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                AudioManager.STREAM_ACCESSIBILITY
            } else {
                AudioManager.STREAM_MUSIC
            }
            "dtmf" -> AudioManager.STREAM_DTMF
            else -> AudioManager.STREAM_MUSIC
        }
    }

    private fun reverseMapStreamType(streamInt: Int): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            streamInt == AudioManager.STREAM_ACCESSIBILITY
        ) {
            return "accessibility"
        }
        return when (streamInt) {
            AudioManager.STREAM_MUSIC -> "media"
            AudioManager.STREAM_RING -> "ring"
            AudioManager.STREAM_ALARM -> "alarm"
            AudioManager.STREAM_NOTIFICATION -> "notification"
            AudioManager.STREAM_VOICE_CALL -> "voiceCall"
            AudioManager.STREAM_SYSTEM -> "system"
            AudioManager.STREAM_DTMF -> "dtmf"
            else -> "media"
        }
    }

    private fun getMinStep(am: AudioManager, streamType: Int): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                am.getStreamMinVolume(streamType)
            } catch (_: Throwable) {
                0
            }
        } else {
            0
        }
    }

    private fun getMaxStep(am: AudioManager, streamType: Int): Int {
        return try {
            am.getStreamMaxVolume(streamType).coerceAtLeast(1)
        } catch (_: Throwable) {
            15
        }
    }

    private fun readNormalizedVolume(streamType: Int): Double {
        val am = audioManager ?: return 0.5
        val currentStep = try {
            am.getStreamVolume(streamType)
        } catch (_: Throwable) {
            0
        }
        val minStep = getMinStep(am, streamType)
        val maxStep = getMaxStep(am, streamType)
        val span = (maxStep - minStep).coerceAtLeast(1)
        return ((currentStep - minStep).toDouble() / span.toDouble()).coerceIn(0.0, 1.0)
    }

    private fun readStreamMuted(streamType: Int): Boolean {
        val am = audioManager ?: return false
        return try {
            am.isStreamMute(streamType) || am.getStreamVolume(streamType) <= 0
        } catch (_: Throwable) {
            false
        }
    }

    private fun readRingerModeWireName(): String {
        val am = audioManager ?: return "unknown"
        return when (am.ringerMode) {
            AudioManager.RINGER_MODE_NORMAL -> "normal"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            AudioManager.RINGER_MODE_SILENT -> "silent"
            else -> "unknown"
        }
    }

    private fun buildVolumeStateMap(streamName: String): Map<String, Any?> {
        val am = audioManager
        val streamType = mapStreamType(streamName)
        if (am == null) {
            return mapOf(
                "volume" to 0.5,
                "isMuted" to false,
                "streamType" to streamName,
                "stepIndex" to 7,
                "maxSteps" to 15,
                "minSteps" to 0,
                "ringerMode" to "normal",
                "outputDeviceName" to "Android Speaker",
                "outputRoute" to "speaker",
                "outputDeviceId" to "default"
            )
        }

        val stepIndex = try {
            am.getStreamVolume(streamType)
        } catch (_: Throwable) {
            0
        }
        val minSteps = getMinStep(am, streamType)
        val maxSteps = getMaxStep(am, streamType)
        val normalized = readNormalizedVolume(streamType)
        val muted = readStreamMuted(streamType)
        val activeDevice = findActiveOutputDevice()

        lastObservedVolumes[streamName] = normalized
        if (!muted && normalized > 0.001) {
            preMuteVolumes[streamName] = normalized
        }

        return mapOf(
            "volume" to normalized,
            "isMuted" to muted,
            "streamType" to streamName,
            "stepIndex" to stepIndex,
            "maxSteps" to maxSteps,
            "minSteps" to minSteps,
            "ringerMode" to readRingerModeWireName(),
            "outputDeviceName" to (activeDevice?.get("name") ?: "Built-in Speaker"),
            "outputRoute" to (activeDevice?.get("route") ?: "speaker"),
            "outputDeviceId" to (activeDevice?.get("id") ?: "default")
        )
    }

    private fun setNormalizedVolume(
        streamName: String,
        targetVolume: Double,
        showUi: Boolean
    ): Map<String, Any?> {
        val am = audioManager ?: return buildVolumeStateMap(streamName)
        val streamType = mapStreamType(streamName)
        val oldVolume = readNormalizedVolume(streamType)
        val minStep = getMinStep(am, streamType)
        val maxStep = getMaxStep(am, streamType)
        val span = (maxStep - minStep).coerceAtLeast(1)
        val targetStep = (minStep + (targetVolume.coerceIn(0.0, 1.0) * span).roundToInt())
            .coerceIn(minStep, maxStep)

        val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0

        if (targetStep > 0 && readStreamMuted(streamType)) {
            try {
                am.adjustStreamVolume(streamType, AudioManager.ADJUST_UNMUTE, 0)
            } catch (_: Throwable) {
            }
        }

        am.setStreamVolume(streamType, targetStep, flags)
        val updatedState = buildVolumeStateMap(streamName)
        emitVolumeChange(updatedState, oldVolume, "programmatic")
        return updatedState
    }

    private fun stepStreamVolume(
        streamName: String,
        direction: String,
        showUi: Boolean
    ): Map<String, Any?> {
        val am = audioManager ?: return buildVolumeStateMap(streamName)
        val streamType = mapStreamType(streamName)
        val oldVolume = readNormalizedVolume(streamType)
        val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0

        val adjustDirection = when (direction) {
            "up" -> AudioManager.ADJUST_RAISE
            "down" -> AudioManager.ADJUST_LOWER
            "mute" -> AudioManager.ADJUST_TOGGLE_MUTE
            else -> AudioManager.ADJUST_SAME
        }
        am.adjustStreamVolume(streamType, adjustDirection, flags)
        val updatedState = buildVolumeStateMap(streamName)
        emitVolumeChange(updatedState, oldVolume, "stepVolume")
        return updatedState
    }

    private fun setStreamMuteState(
        streamName: String,
        muted: Boolean,
        showUi: Boolean
    ): Map<String, Any?> {
        val am = audioManager ?: return buildVolumeStateMap(streamName)
        val streamType = mapStreamType(streamName)
        val oldVolume = readNormalizedVolume(streamType)
        val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0

        if (muted && oldVolume > 0.001) {
            preMuteVolumes[streamName] = oldVolume
        }

        val direction = if (muted) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
        am.adjustStreamVolume(streamType, direction, flags)

        if (!muted && readNormalizedVolume(streamType) <= 0.001) {
            val restoreVol = preMuteVolumes[streamName] ?: 0.5
            return setNormalizedVolume(streamName, restoreVol, showUi)
        }

        val updatedState = buildVolumeStateMap(streamName)
        emitVolumeChange(updatedState, oldVolume, "muteChange")
        return updatedState
    }

    private fun checkDoNotDisturbAccess(): Boolean {
        val nm = notificationManager ?: return true
        return nm.isNotificationPolicyAccessGranted
    }

    private fun openDoNotDisturbSettings(): Boolean {
        val ctx = activity ?: applicationContext ?: return false
        return try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            ctx.startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun applyRingerMode(modeName: String): String {
        val am = audioManager ?: return "unknown"
        val targetMode = when (modeName) {
            "normal" -> AudioManager.RINGER_MODE_NORMAL
            "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
            "silent" -> AudioManager.RINGER_MODE_SILENT
            else -> AudioManager.RINGER_MODE_NORMAL
        }
        if ((targetMode == AudioManager.RINGER_MODE_SILENT ||
                am.ringerMode == AudioManager.RINGER_MODE_SILENT) &&
            !checkDoNotDisturbAccess()
        ) {
            throw SecurityException("Do Not Disturb access not granted.")
        }
        am.ringerMode = targetMode
        val state = buildVolumeStateMap(defaultStreamName)
        emitVolumeChange(state, null, "ringerModeChange")
        return readRingerModeWireName()
    }

    private fun classifyDeviceRoute(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> "speaker"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_AUX_LINE -> "wiredHeadset"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_ACCESSORY,
            AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_HDMI_EARC -> "hdmi"
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        type == AudioDeviceInfo.TYPE_BLE_SPEAKER ||
                        type == AudioDeviceInfo.TYPE_BLE_BROADCAST)
                ) {
                    "bluetooth"
                } else {
                    "speaker"
                }
            }
        }
    }

    private fun friendlyDeviceName(device: AudioDeviceInfo, route: String): String {
        val productName = device.productName?.toString()?.trim().orEmpty()
        if (productName.isNotEmpty() && !productName.equals(Build.MODEL, ignoreCase = true)) {
            return productName
        }
        return when (route) {
            "bluetooth" -> "Bluetooth Audio (${productName.ifEmpty { "Device" }})"
            "wiredHeadset" -> "Wired Headphones"
            "usb" -> "USB Audio Device"
            "hdmi" -> "HDMI Audio Output"
            "earpiece" -> "Built-in Earpiece"
            else -> "Built-in Speaker"
        }
    }

    private fun routePriority(route: String): Int {
        return when (route) {
            "usb" -> 50
            "wiredHeadset" -> 45
            "bluetooth" -> 40
            "hdmi" -> 35
            "speaker" -> 20
            "earpiece" -> 10
            else -> 0
        }
    }

    private fun listOutputDevices(): List<Map<String, Any?>> {
        val am = audioManager ?: return emptyList()
        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val currentVol = readNormalizedVolume(AudioManager.STREAM_MUSIC)
        val currentMuted = readStreamMuted(AudioManager.STREAM_MUSIC)

        var highestPriorityId: Int? = null
        var highestPriority = -1
        for (dev in devices) {
            val route = classifyDeviceRoute(dev.type)
            val priority = routePriority(route)
            if (priority > highestPriority) {
                highestPriority = priority
                highestPriorityId = dev.id
            }
        }

        val result = mutableListOf<Map<String, Any?>>()
        val seenRoutes = mutableSetOf<String>()
        for (dev in devices) {
            val route = classifyDeviceRoute(dev.type)
            val name = friendlyDeviceName(dev, route)
            val key = "${dev.id}_$route"
            if (seenRoutes.add(key)) {
                result.add(
                    mapOf(
                        "id" to dev.id.toString(),
                        "name" to name,
                        "route" to route,
                        "isDefault" to (dev.id == highestPriorityId),
                        "isOutput" to dev.isSink,
                        "isInput" to dev.isSource,
                        "volume" to currentVol,
                        "isMuted" to currentMuted
                    )
                )
            }
        }
        return result
    }

    private fun findActiveOutputDevice(): Map<String, Any?>? {
        val devices = listOutputDevices()
        return devices.firstOrNull { it["isDefault"] == true } ?: devices.firstOrNull()
    }

    private fun selectOutputDevice(deviceId: String): Boolean {
        val am = audioManager ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val targetId = deviceId.toIntOrNull() ?: return false
            val target = am.availableCommunicationDevices.firstOrNull { it.id == targetId }
                ?: am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.id == targetId }
            if (target != null) {
                return try {
                    am.setCommunicationDevice(target)
                } catch (_: Throwable) {
                    false
                }
            }
        }
        return false
    }

    private fun buildCapabilitiesMap(): Map<String, Any?> {
        return mapOf(
            "platform" to "android",
            "supportsSystemVolumeControl" to true,
            "supportsMuteControl" to true,
            "supportsVolumeChangeListening" to true,
            "supportsHardwareButtonInterception" to true,
            "supportsSystemUIControl" to true,
            "supportsMultipleStreamTypes" to true,
            "supportsRingerMode" to true,
            "supportsAudioDeviceListing" to true,
            "supportsDeviceSelection" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
            "supportsAppVolumeControl" to false,
            "supportedStreams" to listOf(
                "media",
                "ring",
                "alarm",
                "notification",
                "voiceCall",
                "system",
                "accessibility",
                "dtmf"
            ),
            "audioBackend" to "Android AudioManager",
            "platformNotes" to listOf(
                "Supports 8 independent audio streams via AudioManager.STREAM_*.",
                "Switching into or out of Silent ringer mode requires Notification Policy (Do Not Disturb) access.",
                "Supports native system volume HUD control via AudioManager.FLAG_SHOW_UI and physical volume button interception."
            )
        )
    }

    private fun startVolumeObservation() {
        if (isListening) return
        val ctx = applicationContext ?: return
        isListening = true

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (action == ACTION_VOLUME_CHANGED) {
                    val streamInt = intent.getIntExtra(
                        EXTRA_VOLUME_STREAM_TYPE,
                        AudioManager.STREAM_MUSIC
                    )
                    val streamName = reverseMapStreamType(streamInt)
                    val prevVol = lastObservedVolumes[streamName]
                    val currentState = buildVolumeStateMap(streamName)
                    val currentVol = currentState["volume"] as? Double ?: 0.0
                    if (prevVol == null || abs(currentVol - prevVol) > 0.0001) {
                        emitVolumeChange(currentState, prevVol, "system")
                    }
                } else if (action == AudioManager.RINGER_MODE_CHANGED_ACTION) {
                    val currentState = buildVolumeStateMap(defaultStreamName)
                    emitVolumeChange(currentState, lastObservedVolumes[defaultStreamName], "ringerModeChange")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_VOLUME_CHANGED)
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(receiver, filter)
        }
        volumeBroadcastReceiver = receiver

        val observer = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                val prevVol = lastObservedVolumes[defaultStreamName]
                val currentState = buildVolumeStateMap(defaultStreamName)
                val currentVol = currentState["volume"] as? Double ?: 0.0
                if (prevVol == null || abs(currentVol - prevVol) > 0.001) {
                    emitVolumeChange(currentState, prevVol, "systemSettings")
                }
            }
        }
        ctx.contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            observer
        )
        settingsContentObserver = observer

        val am = audioManager
        if (am != null) {
            val devCallback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                    val state = buildVolumeStateMap(defaultStreamName)
                    emitVolumeChange(state, lastObservedVolumes[defaultStreamName], "routeChange")
                }

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    val state = buildVolumeStateMap(defaultStreamName)
                    emitVolumeChange(state, lastObservedVolumes[defaultStreamName], "routeChange")
                }
            }
            am.registerAudioDeviceCallback(devCallback, mainHandler)
            audioDeviceCallback = devCallback
        }
    }

    private fun stopVolumeObservation() {
        val ctx = applicationContext
        volumeBroadcastReceiver?.let {
            try {
                ctx?.unregisterReceiver(it)
            } catch (_: Throwable) {
            }
        }
        volumeBroadcastReceiver = null

        settingsContentObserver?.let {
            try {
                ctx?.contentResolver?.unregisterContentObserver(it)
            } catch (_: Throwable) {
            }
        }
        settingsContentObserver = null

        audioDeviceCallback?.let {
            try {
                audioManager?.unregisterAudioDeviceCallback(it)
            } catch (_: Throwable) {
            }
        }
        audioDeviceCallback = null
        isListening = false
    }

    private fun installWindowCallbackIfNeeded() {
        val act = activity ?: return
        val win = act.window ?: return
        if (interceptedWindow === win && originalWindowCallback != null) return

        restoreWindowCallback()
        val currentCallback = win.callback ?: return
        originalWindowCallback = currentCallback
        interceptedWindow = win

        win.callback = object : Window.Callback by currentCallback {
            override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
                if (interceptHardwareButtons && event != null) {
                    val direction = when (event.keyCode) {
                        KeyEvent.KEYCODE_VOLUME_UP -> "up"
                        KeyEvent.KEYCODE_VOLUME_DOWN -> "down"
                        KeyEvent.KEYCODE_VOLUME_MUTE -> "mute"
                        else -> null
                    }
                    if (direction != null) {
                        val actionName = when (event.action) {
                            KeyEvent.ACTION_DOWN -> "down"
                            KeyEvent.ACTION_UP -> "up"
                            else -> "press"
                        }
                        emitHardwareButton(direction, actionName, true)
                        return true
                    }
                }
                return currentCallback.dispatchKeyEvent(event)
            }
        }
    }

    private fun restoreWindowCallback() {
        val win = interceptedWindow
        val orig = originalWindowCallback
        if (win != null && orig != null) {
            try {
                win.callback = orig
            } catch (_: Throwable) {
            }
        }
        interceptedWindow = null
        originalWindowCallback = null
    }

    private fun emitVolumeChange(
        stateMap: Map<String, Any?>,
        oldVolume: Double?,
        reason: String
    ) {
        mainHandler.post {
            try {
                channel.invokeMethod(
                    "onVolumeChanged",
                    mapOf(
                        "state" to stateMap,
                        "oldVolume" to oldVolume,
                        "reason" to reason,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            } catch (_: Throwable) {
            }
        }
    }

    private fun emitHardwareButton(
        direction: String,
        action: String,
        intercepted: Boolean
    ) {
        mainHandler.post {
            try {
                channel.invokeMethod(
                    "onHardwareButton",
                    mapOf(
                        "direction" to direction,
                        "action" to action,
                        "intercepted" to intercepted,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            } catch (_: Throwable) {
            }
        }
    }
}
