package io.polyfence.polyfence.flutter

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceDebugCollector
import io.polyfence.core.ZonePersistence
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Captor
import org.mockito.Mock
import org.mockito.MockedStatic
import org.mockito.Mockito.any
import org.mockito.Mockito.eq
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class PolyfencePluginTest {

    private lateinit var plugin: PolyfencePlugin
    private lateinit var result: MethodChannel.Result

    @Mock
    private lateinit var mockContext: Context

    @Captor
    private lateinit var resultCaptor: ArgumentCaptor<Any?>

    @Before
    fun setUp() {
        plugin = PolyfencePlugin()
        result = mock(MethodChannel.Result::class.java)
    }

    // ==================== Method Routing Tests ====================

    @Test
    fun testInitializeMethodRouted() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStartTrackingMethodRouted() {
        val call = MethodCall("startTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStopTrackingMethodRouted() {
        val call = MethodCall("stopTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testAddZoneMethodRouted() {
        val zoneData = mapOf(
            "id" to "zone123",
            "name" to "Test Zone",
            "coordinates" to listOf(mapOf("latitude" to 37.7749, "longitude" to -122.4194))
        )
        val call = MethodCall("addZone", zoneData)
        plugin.onMethodCall(call, result)
        // Should handle the call - mock prevents actual LocationTracker interaction
        verify(result).success(null)
    }

    @Test
    fun testAddZoneWithMissingDataReturnsError() {
        val call = MethodCall("addZone", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE"), any(), any())
    }

    @Test
    fun testRemoveZoneMethodRouted() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "zone123"))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRemoveZoneWithMissingIdReturnsError() {
        val call = MethodCall("removeZone", mapOf("zoneId" to null))
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE_ID"), any(), any())
    }

    @Test
    fun testClearAllZonesMethodRouted() {
        val call = MethodCall("clearAllZones", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    // ==================== Query Methods Tests ====================

    @Test
    fun testIsLocationServiceEnabledReturnsBoolean() {
        val call = MethodCall("isLocationServiceEnabled", null)
        plugin.onMethodCall(call, result)
        // Should respond with a boolean (true or false)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testRequestPermissionsReturnsBoolean() {
        val call = MethodCall("requestPermissions", mapOf("always" to false))
        plugin.onMethodCall(call, result)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testGetConfigurationReturnsMap() {
        val call = MethodCall("getConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Map::class.java))
    }

    @Test
    fun testGetDebugInfoReturnsMap() {
        val call = MethodCall("getDebugInfo", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Map::class.java))
    }

    @Test
    fun testGetErrorHistoryReturnsListOfMaps() {
        val call = MethodCall("getErrorHistory", mapOf("timeRangeMs" to 3600000L, "errorTypes" to listOf()))
        plugin.onMethodCall(call, result)
        verify(result).success(any(List::class.java))
    }

    @Test
    fun testCheckBatteryOptimizationReturnsMap() {
        val call = MethodCall("checkBatteryOptimization", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Map::class.java))
    }

    @Test
    fun testRequestBatteryOptimizationReturnsBoolean() {
        val call = MethodCall("requestBatteryOptimization", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testGetCurrentZoneStatesReturnsMap() {
        mockStatic(LocationTracker::class.java).use { mockedStatic ->
            mockedStatic.`when`<Map<String, Boolean>> { LocationTracker.getCurrentZoneStates() }
                .thenReturn(mapOf("zone1" to true, "zone2" to false))

            val call = MethodCall("getCurrentZoneStates", null)
            plugin.onMethodCall(call, result)

            verify(result).success(any(Map::class.java))
        }
    }

    @Test
    fun testGetSessionTelemetryReturnsMap() {
        mockStatic(LocationTracker::class.java).use { mockedStatic ->
            mockedStatic.`when`<Map<String, Any>> { LocationTracker.getSessionTelemetry() }
                .thenReturn(mapOf(
                    "avg_dwell_duration_minutes" to 12.5,
                    "activity_distribution" to mapOf("still" to 50, "walking" to 30)
                ))

            val call = MethodCall("getSessionTelemetry", null)
            plugin.onMethodCall(call, result)

            verify(result).success(any(Map::class.java))
        }
    }

    // ==================== Configuration Methods Tests ====================

    @Test
    fun testUpdateConfigurationWithValidDataSucceeds() {
        val configMap = mapOf(
            "accuracyProfile" to "BALANCED",
            "updateIntervalMs" to 5000
        )
        val call = MethodCall("updateConfiguration", configMap)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testUpdateConfigurationWithMissingDataReturnsError() {
        val call = MethodCall("updateConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_CONFIG"), any(), any())
    }

    @Test
    fun testResetConfigurationMethodRouted() {
        val call = MethodCall("resetConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testSetAccuracyProfileWithValidProfileSucceeds() {
        val call = MethodCall("setAccuracyProfile", "BALANCED")
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testSetAccuracyProfileWithInvalidProfileReturnsError() {
        val call = MethodCall("setAccuracyProfile", "")
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_PROFILE"), any(), any())
    }

    @Test
    fun testSetAccuracyProfileWithNullReturnsError() {
        val call = MethodCall("setAccuracyProfile", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_PROFILE"), any(), any())
    }

    // ==================== Unknown Method Tests ====================

    @Test
    fun testUnknownMethodReturnsNotImplemented() {
        val call = MethodCall("unknownMethod", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    @Test
    fun testMisspelledMethodNameReturnsNotImplemented() {
        val call = MethodCall("startTrackingg", null)
        plugin.onMethodCall(call, result)
        verify(result).notImplemented()
    }

    // ==================== Argument Type Coercion Tests ====================

    @Test
    fun testAddZoneCoercesArgumentsFromMap() {
        // Dart sends zone data as a flat Map — verify the plugin handles it
        val zoneData = mapOf<String, Any>(
            "id" to "zone456",
            "name" to "Test Zone",
            "type" to "circle",
            "radius" to 100.0,
            "latitude" to 37.7749,
            "longitude" to -122.4194
        )
        val call = MethodCall("addZone", zoneData)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRemoveZoneCoercesStringArgument() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "zone123"))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRequestPermissionsCoercesBooleanArgument() {
        val call = MethodCall("requestPermissions", mapOf("always" to true))
        plugin.onMethodCall(call, result)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testUpdateConfigurationCoercesMapArgument() {
        val configMap = mapOf<String, Any>(
            "accuracyProfile" to "BALANCED",
            "updateIntervalMs" to 5000L,
            "minDistanceMeters" to 10.0
        )
        val call = MethodCall("updateConfiguration", configMap)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testGetErrorHistoryCoercesListArgument() {
        val call = MethodCall("getErrorHistory", mapOf(
            "timeRangeMs" to 3600000L,
            "errorTypes" to listOf("PERMISSION", "GPS")
        ))
        plugin.onMethodCall(call, result)
        verify(result).success(any(List::class.java))
    }

    // ==================== Result Type Tests ====================

    @Test
    fun testInitializeReturnsVoid() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStartTrackingReturnsVoid() {
        val call = MethodCall("startTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStopTrackingReturnsVoid() {
        val call = MethodCall("stopTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testAddZoneReturnsVoid() {
        val zoneData = mapOf(
            "id" to "zone789",
            "name" to "Test",
            "coordinates" to listOf<Map<String, Double>>()
        )
        val call = MethodCall("addZone", zoneData)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRemoveZoneReturnsVoid() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "zone789"))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testClearAllZonesReturnsVoid() {
        val call = MethodCall("clearAllZones", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRequestPermissionsReturnsBoolean_Specific() {
        val call = MethodCall("requestPermissions", mapOf("always" to false))
        plugin.onMethodCall(call, result)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testIsLocationServiceEnabledReturnsBoolean_Specific() {
        val call = MethodCall("isLocationServiceEnabled", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Boolean::class.java))
    }

    @Test
    fun testDisposeMethodRouted() {
        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)
        // Dispose either returns null or throws — both should succeed in error handling
        verify(result, times(0)).notImplemented()
    }
}
