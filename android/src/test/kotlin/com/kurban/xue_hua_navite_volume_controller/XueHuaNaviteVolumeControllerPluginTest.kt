package com.kurban.xue_hua_navite_volume_controller

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.ArgumentCaptor
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class XueHuaNaviteVolumeControllerPluginTest {
    @Test
    fun onMethodCall_getCapabilities_returnsExpectedAndroidCapabilities() {
        val plugin = XueHuaNaviteVolumeControllerPlugin()

        val call = MethodCall("getCapabilities", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        val captor = ArgumentCaptor.forClass( Any::class.java)
        Mockito.verify(mockResult).success(captor.capture())
        val map = captor.value as? Map<*, *>
        assertTrue(map != null)
        assertEquals("android", map["platform"])
        assertEquals(true, map["supportsMultipleStreamTypes"])
        assertEquals(true, map["supportsHardwareButtonInterception"])
    }
}
