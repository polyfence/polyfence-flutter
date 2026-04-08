package io.polyfence.polyfence.flutter

import android.content.Context
import android.content.Intent
import android.location.LocationManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceDebugCollector
import io.polyfence.core.SmartGpsConfig
import io.polyfence.core.SmartGpsConfigFactory
import io.polyfence.core.ZonePersistence
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockedConstruction
import org.mockito.MockedStatic
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

/**
 * Unit tests for PolyfencePlugin method channel routing.
 *
 * These tests verify that each MethodCall is routed correctly and returns
 * the expected result type. polyfence-core statics are mocked so tests
 * run without Android framework or a running LocationTracker service.
 */
@RunWith(MockitoJUnitRunner::class)
class PolyfencePluginTest {

    private lateinit var plugin: PolyfencePlugin
    private lateinit var result: MethodChannel.Result

    @Mock private lateinit var mockContext: Context
    @Mock private lateinit var mockMessenger: BinaryMessenger
    @Mock private lateinit var mockBinding: FlutterPlugin.FlutterPluginBinding

    private lateinit var mockedTracker: MockedStatic<LocationTracker>
    private lateinit var mockedDebug: MockedStatic<PolyfenceDebugCollector>
    private lateinit var mockedConfigFactory: MockedStatic<SmartGpsConfigFactory>
    private lateinit var mockedZonePersistence: MockedConstruction<ZonePersistence>

    @Before
    fun setUp() {
        // Wire up binding → context + messenger
        `when`(mockBinding.applicationContext).thenReturn(mockContext)
        `when`(mockBinding.binaryMessenger).thenReturn(mockMessenger)

        // Context stubs for Intent-based service calls
        `when`(mockContext.startService(any(Intent::class.java))).thenReturn(null)
        `when`(mockContext.startForegroundService(any(Intent::class.java))).thenReturn(null)
        `when`(mockContext.packageName).thenReturn("io.polyfence.example")

        // Mock polyfence-core statics
        mockedTracker = mockStatic(LocationTracker::class.java)
        mockedDebug = mockStatic(PolyfenceDebugCollector::class.java)
        mockedConfigFactory = mockStatic(SmartGpsConfigFactory::class.java)

        // Default return values for commonly called statics
        mockedTracker.`when`<SmartGpsConfig> { LocationTracker.getCurrentSmartConfiguration() }
            .thenReturn(SmartGpsConfig())
        mockedTracker.`when`<Map<String, Boolean>> { LocationTracker.getCurrentZoneStates() }
            .thenReturn(mapOf("zone1" to true))
        mockedTracker.`when`<Map<String, Any>> { LocationTracker.getSessionTelemetry() }
            .thenReturn(mapOf("session_duration_ms" to 60000L))
        mockedConfigFactory.`when`<Map<String, Any>> { SmartGpsConfigFactory.toMap(any()) }
            .thenReturn(mapOf("accuracyProfile" to "BALANCED"))
        mockedConfigFactory.`when`<SmartGpsConfig> { SmartGpsConfigFactory.fromMap(any()) }
            .thenReturn(SmartGpsConfig())
        mockedDebug.`when`<Map<String, Any>> { PolyfenceDebugCollector.collectDebugInfo(any()) }
            .thenReturn(mapOf("version" to "0.14.0"))
        mockedDebug.`when`<List<Map<String, Any>>> { PolyfenceDebugCollector.getErrorHistory(any(), any()) }
            .thenReturn(emptyList())

        // Mock ZonePersistence constructor (used in addZone when tracking is off)
        mockedZonePersistence = mockConstruction(ZonePersistence::class.java)

        // Create plugin and attach engine
        plugin = PolyfencePlugin()
        plugin.onAttachedToEngine(mockBinding)

        result = mock(MethodChannel.Result::class.java)
    }

    @After
    fun tearDown() {
        mockedTracker.close()
        mockedDebug.close()
        mockedConfigFactory.close()
        mockedZonePersistence.close()
    }

    // ==================== Method Routing ====================

    @Test
    fun testInitializeRoutes() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStartTrackingRoutes() {
        val call = MethodCall("startTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testStopTrackingRoutes() {
        val call = MethodCall("stopTracking", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testAddZoneRoutes() {
        val zone = mapOf("id" to "z1", "name" to "Test", "coordinates" to listOf<Map<String, Double>>())
        val call = MethodCall("addZone", zone)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testAddZoneNullDataReturnsError() {
        val call = MethodCall("addZone", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE"), any(), any())
    }

    @Test
    fun testRemoveZoneRoutes() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "z1"))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRemoveZoneNullIdReturnsError() {
        val call = MethodCall("removeZone", mapOf("zoneId" to null))
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_ZONE_ID"), any(), any())
    }

    @Test
    fun testClearAllZonesRoutes() {
        val call = MethodCall("clearAllZones", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testDisposeRoutes() {
        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)
        verify(result, never()).notImplemented()
    }

    // ==================== Query Methods ====================

    @Test
    fun testIsLocationServiceEnabled() {
        val mockLocMgr = mock(LocationManager::class.java)
        `when`(mockContext.getSystemService(Context.LOCATION_SERVICE)).thenReturn(mockLocMgr)
        `when`(mockLocMgr.isProviderEnabled(LocationManager.GPS_PROVIDER)).thenReturn(true)

        val call = MethodCall("isLocationServiceEnabled", null)
        plugin.onMethodCall(call, result)
        verify(result).success(true)
    }

    @Test
    fun testIsLocationServiceDisabled() {
        val mockLocMgr = mock(LocationManager::class.java)
        `when`(mockContext.getSystemService(Context.LOCATION_SERVICE)).thenReturn(mockLocMgr)
        `when`(mockLocMgr.isProviderEnabled(LocationManager.GPS_PROVIDER)).thenReturn(false)
        `when`(mockLocMgr.isProviderEnabled(LocationManager.NETWORK_PROVIDER)).thenReturn(false)

        val call = MethodCall("isLocationServiceEnabled", null)
        plugin.onMethodCall(call, result)
        verify(result).success(false)
    }

    @Test
    fun testRequestPermissions() {
        val call = MethodCall("requestPermissions", mapOf("always" to false))
        plugin.onMethodCall(call, result)
        // Returns boolean — exact value depends on mock context permissions
        verify(result).success(any())
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
    fun testGetErrorHistoryReturnsList() {
        val call = MethodCall("getErrorHistory", mapOf("timeRangeMs" to 3600000L, "errorTypes" to listOf<String>()))
        plugin.onMethodCall(call, result)
        verify(result).success(any(List::class.java))
    }

    @Test
    fun testCheckBatteryOptimization() {
        val call = MethodCall("checkBatteryOptimization", null)
        plugin.onMethodCall(call, result)
        // Returns map or error — verifying no crash
        verify(result, never()).notImplemented()
    }

    @Test
    fun testGetCurrentZoneStatesReturnsMap() {
        val call = MethodCall("getCurrentZoneStates", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Map::class.java))
    }

    @Test
    fun testGetSessionTelemetryReturnsMap() {
        val call = MethodCall("getSessionTelemetry", null)
        plugin.onMethodCall(call, result)
        verify(result).success(any(Map::class.java))
    }

    // ==================== Configuration ====================

    @Test
    fun testUpdateConfigurationSuccess() {
        val config = mapOf<String, Any>("accuracyProfile" to "BALANCED", "updateIntervalMs" to 5000)
        val call = MethodCall("updateConfiguration", config)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testUpdateConfigurationNullReturnsError() {
        val call = MethodCall("updateConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).error(eq("INVALID_CONFIG"), any(), any())
    }

    @Test
    fun testResetConfigurationRoutes() {
        val call = MethodCall("resetConfiguration", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testSetAccuracyProfileValid() {
        val call = MethodCall("setAccuracyProfile", "BALANCED")
        plugin.onMethodCall(call, result)
        verify(result).success(null)
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

    // ==================== Unknown Methods ====================

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

    // ==================== Argument Coercion ====================

    @Test
    fun testAddZoneCoercesMapArguments() {
        val zone = mapOf<String, Any>(
            "id" to "z2", "name" to "Circle", "type" to "circle",
            "radius" to 100.0, "latitude" to 37.7749, "longitude" to -122.4194
        )
        val call = MethodCall("addZone", zone)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRemoveZoneCoercesStringArg() {
        val call = MethodCall("removeZone", mapOf("zoneId" to "z2"))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testRequestPermissionsCoercesBoolArg() {
        val call = MethodCall("requestPermissions", mapOf("always" to true))
        plugin.onMethodCall(call, result)
        verify(result).success(any())
    }

    @Test
    fun testUpdateConfigurationCoercesMapArg() {
        val config = mapOf<String, Any>(
            "accuracyProfile" to "BALANCED", "updateIntervalMs" to 5000L, "minDistanceMeters" to 10.0
        )
        val call = MethodCall("updateConfiguration", config)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
    }

    @Test
    fun testGetErrorHistoryCoercesListArg() {
        val call = MethodCall("getErrorHistory", mapOf(
            "timeRangeMs" to 3600000L, "errorTypes" to listOf("PERMISSION", "GPS")
        ))
        plugin.onMethodCall(call, result)
        verify(result).success(any(List::class.java))
    }

    // ==================== Initialize Variations ====================

    @Test
    fun testInitializeWithConfig() {
        val config = mapOf<String, Any>(
            "pluginVersion" to "0.14.0",
            "disableAlertNotifications" to true
        )
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to config))
        plugin.onMethodCall(call, result)
        verify(result).success(null)

        // Verify core interactions
        mockedTracker.verify { LocationTracker.setAlertNotificationsEnabled(false) }
        mockedTracker.verify { LocationTracker.setBridgePlatform("flutter") }
        mockedDebug.verify { PolyfenceDebugCollector.setPluginVersion("0.14.0") }
    }

    @Test
    fun testInitializeDefaultAlertNotifications() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        verify(result).success(null)

        // Default: alerts enabled (disable = false → enabled = true)
        mockedTracker.verify { LocationTracker.setAlertNotificationsEnabled(true) }
    }

    // ==================== Delegate Wiring ====================

    @Test
    fun testInitializeWiresCoreDelegate() {
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to null))
        plugin.onMethodCall(call, result)
        mockedTracker.verify { LocationTracker.setPendingCoreDelegate(any()) }
    }

    // ==================== Service Intent Verification ====================

    @Test
    fun testStartTrackingCallsForegroundService() {
        val call = MethodCall("startTracking", null)
        plugin.onMethodCall(call, result)
        verify(mockContext).startForegroundService(any(Intent::class.java))
    }

    @Test
    fun testStopTrackingCallsService() {
        val call = MethodCall("stopTracking", null)
        plugin.onMethodCall(call, result)
        verify(mockContext).startService(any(Intent::class.java))
    }
}
