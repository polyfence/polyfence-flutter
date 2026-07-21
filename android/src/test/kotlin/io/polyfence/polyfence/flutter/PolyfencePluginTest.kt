package io.polyfence.polyfence.flutter

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceDebugCollector
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockedStatic
import org.mockito.Mockito
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

/**
 * Unit tests for PolyfencePlugin method channel routing.
 *
 * Tests cover: error paths (no mocking needed), unknown method routing,
 * and argument validation. Methods that call into polyfence-core statics
 * are tested via the error/validation paths only — the happy paths require
 * either mockk (for Kotlin companion objects) or a DI refactor.
 */
@RunWith(MockitoJUnitRunner::class)
class PolyfencePluginTest {

    private lateinit var plugin: PolyfencePlugin
    private lateinit var result: MethodChannel.Result

    @Before
    fun setUp() {
        plugin = PolyfencePlugin()
        result = mock(MethodChannel.Result::class.java)

        // BUG-001 added `setTrackingEnabled(context, false)` at the top of
        // the "initialize" method-channel handler, which requires the
        // plugin's lateinit `context` to be set. Inject a mock context
        // with a mock SharedPreferences chain via reflection so the
        // initialize tests can run without a real Flutter attachment.
        val mockContext = mock(Context::class.java)
        val mockPrefs = mock(SharedPreferences::class.java)
        val mockEditor = mock(SharedPreferences.Editor::class.java)
        `when`(mockContext.getSharedPreferences(anyString(), anyInt())).thenReturn(mockPrefs)
        `when`(mockPrefs.edit()).thenReturn(mockEditor)
        `when`(mockEditor.putBoolean(anyString(), anyBoolean())).thenReturn(mockEditor)

        val contextField = PolyfencePlugin::class.java.getDeclaredField("context")
        contextField.isAccessible = true
        contextField.set(plugin, mockContext)
    }

    // ==================== Unknown Method Routing ====================

    @Test
    fun testUnknownMethodReturnsNotImplemented() {
        val call = MethodCall("unknownMethod", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    @Test
    fun testMisspelledMethodReturnsNotImplemented() {
        val call = MethodCall("startTrackingg", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    @Test
    fun testEmptyMethodNameReturnsNotImplemented() {
        val call = MethodCall("", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    @Test
    fun testCaseSensitiveMethodNameReturnsNotImplemented() {
        val call = MethodCall("StartTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    // ==================== Argument Validation (Error Paths) ====================

    @Test
    fun testAddZoneNullDataReturnsError() {
        val call = MethodCall("addZone", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE"), any(), any())
    }

    @Test
    fun testRemoveZoneNullIdReturnsError() {
        val call = MethodCall("removeZone", mapOf("zoneId" to null))
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE_ID"), any(), any())
    }

    @Test
    fun testRemoveZoneMissingKeyReturnsError() {
        val call = MethodCall("removeZone", mapOf("wrongKey" to "z1"))
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE_ID"), any(), any())
    }

    @Test
    fun testRemoveZoneEmptyMapReturnsError() {
        val call = MethodCall("removeZone", emptyMap<String, Any>())
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE_ID"), any(), any())
    }

    @Test
    fun testUpdateConfigurationNullReturnsError() {
        val call = MethodCall("updateConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_CONFIG"), any(), any())
    }

    @Test
    fun testSetAccuracyProfileEmptyReturnsError() {
        val call = MethodCall("setAccuracyProfile", "")
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_PROFILE"), any(), any())
    }

    @Test
    fun testSetAccuracyProfileNullReturnsError() {
        val call = MethodCall("setAccuracyProfile", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_PROFILE"), any(), any())
    }

    @Test
    fun testSetAccuracyProfileBlankReturnsError() {
        val call = MethodCall("setAccuracyProfile", "   ")
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_PROFILE"), any(), any())
    }

    // ==================== Initialize (no context needed) ====================

    @Test
    fun testInitializeWithNullConfig() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testInitializeWithNullArgs() {
        val call = MethodCall("initialize", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testInitializeWithEmptyConfig() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to emptyMap<String, Any>()))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testInitializeWithDisableAlerts() {
        val config = mapOf<String, Any>("disableAlertNotifications" to true)
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to config))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testInitializeWithPluginVersion() {
        val config = mapOf<String, Any>("pluginVersion" to "0.14.0")
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to config))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    // ==================== Method Existence (all known methods route) ====================
    // These verify the method IS recognized (doesn't return notImplemented).
    // Methods that need context will throw, but they won't return notImplemented.

    @Test
    fun testStartTrackingIsRecognized() {
        val call = MethodCall("startTracking", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {
            // Expected — context not initialized. But method WAS recognized.
        }
        verify(result, never()).notImplemented()
    }

    @Test
    fun testStopTrackingIsRecognized() {
        val call = MethodCall("stopTracking", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testAddZoneIsRecognized() {
        val zone = mapOf("id" to "z1", "name" to "Test", "coordinates" to listOf<Map<String, Double>>())
        val call = MethodCall("addZone", zone)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testRemoveZoneIsRecognized() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "z1"))
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testClearAllZonesIsRecognized() {
        val call = MethodCall("clearAllZones", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testRequestPermissionsIsRecognized() {
        val call = MethodCall("requestPermissions", mapOf("always" to false))
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testIsLocationServiceEnabledIsRecognized() {
        val call = MethodCall("isLocationServiceEnabled", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testGetConfigurationIsRecognized() {
        val call = MethodCall("getConfiguration", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: Exception) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testGetDebugInfoIsRecognized() {
        val call = MethodCall("getDebugInfo", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: Exception) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testResetConfigurationIsRecognized() {
        val call = MethodCall("resetConfiguration", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: UninitializedPropertyAccessException) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testCheckBatteryOptimizationIsRecognized() {
        val call = MethodCall("checkBatteryOptimization", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: Exception) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testGetCurrentZoneStatesIsRecognized() {
        val call = MethodCall("getCurrentZoneStates", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: Exception) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testGetSessionTelemetryIsRecognized() {
        val call = MethodCall("getSessionTelemetry", null)
        try {
            plugin.onMethodCall(call, result)
        } catch (_: Exception) {}
        verify(result, never()).notImplemented()
    }

    @Test
    fun testDisposeReturnsNotImplemented() {
        // dispose is handled on the Dart side, not in the native plugin
        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    @Test
    fun testGetErrorHistoryIsRecognized() {
        // Pass 86_400_000 (24h) as a Kotlin Int, not Long. Flutter
        // marshals a Dart int that fits in int32 (< 2^31) as
        // java.lang.Integer on the Kotlin side; a Long-only extraction
        // would ClassCastException here. Asserting success (not just
        // "recognised") locks the numeric-type contract: any future
        // narrowing of the argument extraction lands on the plugin's
        // error branch instead, and this test fails.
        val call = MethodCall("getErrorHistory", mapOf("timeRangeMs" to 86400000, "errorTypes" to listOf<String>()))
        plugin.onMethodCall(call, result)
        verify(result).success(any())
        verify(result, never()).error(any(), any(), any())
        verify(result, never()).notImplemented()
    }
}
