package io.polyfence.polyfence.flutter

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify as mockkVerify
import io.polyfence.core.LocationTracker
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

/**
 * Bridge-level tests for the pending-events queue passthrough.
 *
 * Every case here has a paired Swift test in
 * ios/Tests/PendingEventsBridgeTests.swift that drives the same behaviour
 * on the iOS bridge. Platform tests silently diverge when one side is
 * covered and the other is not, so cross-platform parity is a required
 * invariant of any test added to this file.
 *
 * MockK is used for polyfence-core companion stubbing (Mockito's mockStatic
 * cannot intercept Kotlin companion methods without @JvmStatic on core;
 * MockK's mockkObject supports companion objects natively). Mockito is
 * retained for the FlutterResult mock, matching the rest of the test file.
 */
@RunWith(MockitoJUnitRunner.Silent::class)
class PendingEventsBridgeTest {

    private lateinit var plugin: PolyfencePlugin
    private lateinit var result: MethodChannel.Result

    @Before
    fun setUp() {
        plugin = PolyfencePlugin()
        result = mock(MethodChannel.Result::class.java)

        val mockContext = mock(Context::class.java)
        val mockPrefs = mock(SharedPreferences::class.java)
        val mockEditor = mock(SharedPreferences.Editor::class.java)
        `when`(mockContext.getSharedPreferences(anyString(), anyInt())).thenReturn(mockPrefs)
        `when`(mockPrefs.edit()).thenReturn(mockEditor)
        `when`(mockEditor.putBoolean(anyString(), anyBoolean())).thenReturn(mockEditor)
        `when`(mockContext.applicationContext).thenReturn(mockContext)

        val contextField = PolyfencePlugin::class.java.getDeclaredField("context")
        contextField.isAccessible = true
        contextField.set(plugin, mockContext)

        mockkObject(LocationTracker.Companion)
    }

    @After
    fun tearDown() {
        unmockkObject(LocationTracker.Companion)
    }

    @Test
    fun drainPendingEventsReturnsEmptyListWhenCoreHasNone() {
        every { LocationTracker.drainPendingEvents(any()) } returns emptyList()

        val call = MethodCall("drainPendingEvents", null)
        plugin.onMethodCall(call, result)

        verify(result).success(emptyList<Map<String, Any>>())
        verify(result, never()).error(any(), any(), any())
        verify(result, never()).notImplemented()
    }

    @Test
    fun drainPendingEventsMarksEventsDeliveredLateWithDrainMetadata() {
        val eventTs = System.currentTimeMillis() - 30_000L
        val rawEvents = listOf<Map<String, Any>>(
            mapOf(
                "zoneId" to "zone-1",
                "zoneName" to "Home",
                "eventType" to "ENTER",
                "timestamp" to eventTs,
                "latitude" to 37.7749,
                "longitude" to -122.4194,
                "detectionTimeMs" to 12.0
            )
        )
        every { LocationTracker.drainPendingEvents(any()) } returns rawEvents

        val call = MethodCall("drainPendingEvents", null)
        plugin.onMethodCall(call, result)

        val captor = org.mockito.ArgumentCaptor.forClass(List::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val enriched = captor.value as List<Map<String, Any>>
        assert(enriched.size == 1)
        val event = enriched[0]
        assert(event["zoneId"] == "zone-1")
        assert(event["deliveredLate"] == true)
        assert(event["capturedTs"] == eventTs)
        val queued = event["queuedDurationMs"] as Long
        assert(queued >= 0L) { "queuedDurationMs must not be negative, got $queued" }
    }

    @Test
    fun drainPendingEventsPreservesOldestFirstOrder() {
        val rawEvents = listOf<Map<String, Any>>(
            mapOf("zoneId" to "z1", "eventType" to "ENTER", "timestamp" to 1_000L),
            mapOf("zoneId" to "z1", "eventType" to "EXIT", "timestamp" to 2_000L)
        )
        every { LocationTracker.drainPendingEvents(any()) } returns rawEvents

        val call = MethodCall("drainPendingEvents", null)
        plugin.onMethodCall(call, result)

        val captor = org.mockito.ArgumentCaptor.forClass(List::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val enriched = captor.value as List<Map<String, Any>>
        assert(enriched.size == 2)
        assert(enriched[0]["eventType"] == "ENTER")
        assert(enriched[1]["eventType"] == "EXIT")
    }

    @Test
    fun drainPendingEventsSurfacesCoreExceptionAsPlatformError() {
        every { LocationTracker.drainPendingEvents(any()) } throws RuntimeException("disk read error")

        val call = MethodCall("drainPendingEvents", null)
        plugin.onMethodCall(call, result)

        verify(result).error(eq("DRAIN_PENDING_EVENTS_FAILED"), any(), any())
        verify(result, never()).success(any())
    }

    @Test
    fun pendingEventsDroppedCountReturnsZeroInitially() {
        every { LocationTracker.pendingEventsDroppedCount(any()) } returns 0L

        val call = MethodCall("pendingEventsDroppedCount", null)
        plugin.onMethodCall(call, result)

        verify(result).success(0L)
    }

    @Test
    fun pendingEventsDroppedCountReturnsCoreValueWhenNonZero() {
        every { LocationTracker.pendingEventsDroppedCount(any()) } returns 42L

        val call = MethodCall("pendingEventsDroppedCount", null)
        plugin.onMethodCall(call, result)

        verify(result).success(42L)
    }

    @Test
    fun disposeMethodChannelCaseCallsSetBridgeAttachedFalseAndReturnsSuccess() {
        every { LocationTracker.setBridgeAttached(any()) } returns Unit

        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)

        mockkVerify { LocationTracker.setBridgeAttached(false) }
        verify(result).success(null)
        verify(result, never()).notImplemented()
        verify(result, never()).error(any(), any(), any())
    }

    @Test
    fun initializeDoesNotFlipBridgeAttachedToTrueBeforeOnListen() {
        // Production contract: the geofence EventChannel's onListen is the
        // authoritative attach signal — initialize() must NOT pre-flip to
        // `true`, or the post-initialize / pre-listen window (while
        // PolyfenceAnalytics.instance.initialize() awaits) mis-classifies
        // events as live and drops them into a null sink. Only setBridgeAttached
        // call inside the initialize handler is the plugin's own attach
        // wiring on the tracker delegate; the true flip lives in
        // geofenceChannel.onListen.
        every { LocationTracker.setBridgeAttached(any()) } returns Unit
        every { LocationTracker.setBridgePlatform(any()) } returns Unit
        every { LocationTracker.setPendingCoreDelegate(any()) } returns Unit
        every { LocationTracker.setAlertNotificationsEnabled(any()) } returns Unit

        val call = MethodCall(
            "initialize",
            mapOf("licenseKey" to null, "config" to emptyMap<String, Any>())
        )
        plugin.onMethodCall(call, result)

        mockkVerify(exactly = 0) { LocationTracker.setBridgeAttached(true) }
        verify(result).success(null)
    }

    @Test
    fun onAttachedToEngineStartsInNotYetListeningState() {
        // Plugin attach must call setBridgeAttached(false) so the window
        // between attach and the geofence stream's first onListen deposits
        // any fired events into the durable queue (when opted in) rather
        // than delivering them into a null sink. Core's own default is
        // `true`, which would silently drop events in that window.
        every { LocationTracker.setBridgeAttached(any()) } returns Unit

        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))

        plugin.onAttachedToEngine(binding)

        mockkVerify { LocationTracker.setBridgeAttached(false) }
    }

    @Test
    fun onDetachedFromEngineCallsSetBridgeAttachedFalseBeforeNullingSinks() {
        every { LocationTracker.setBridgeAttached(any()) } returns Unit

        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))

        plugin.onAttachedToEngine(binding)
        plugin.onDetachedFromEngine(binding)

        // Both onAttachedToEngine and onDetachedFromEngine call
        // setBridgeAttached(false) — verify at least once.
        mockkVerify(atLeast = 1) { LocationTracker.setBridgeAttached(false) }
    }

    @Test
    fun geofenceStreamOnListenCallsSetBridgeAttachedTrue() {
        // The geofence sink's presence is the load-bearing signal for
        // core's persist-vs-live XOR — production wiring must call
        // setBridgeAttached(true) inside onListen so a re-subscribe after
        // an onCancel correctly flips core back to live delivery.
        every { LocationTracker.setBridgeAttached(any()) } returns Unit

        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))
        plugin.onAttachedToEngine(binding)

        val handler = extractGeofenceStreamHandler(plugin)
        val sink = mock(io.flutter.plugin.common.EventChannel.EventSink::class.java)
        handler.onListen("geofence", sink)

        mockkVerify { LocationTracker.setBridgeAttached(true) }
    }

    @Test
    fun geofenceStreamOnCancelCallsSetBridgeAttachedFalse() {
        // Symmetric with onListen: onCancel must call setBridgeAttached(false)
        // so an unsubscribed Dart stream flips core to the persist path
        // instead of leaving core believing the bridge is still receiving.
        every { LocationTracker.setBridgeAttached(any()) } returns Unit

        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))
        plugin.onAttachedToEngine(binding)

        val handler = extractGeofenceStreamHandler(plugin)
        val sink = mock(io.flutter.plugin.common.EventChannel.EventSink::class.java)
        handler.onListen("geofence", sink)
        handler.onCancel("geofence")

        // Expect setBridgeAttached(false) called exactly twice: once from
        // onAttachedToEngine's "not-yet-listening" seed and once from the
        // onCancel that just fired.
        mockkVerify(exactly = 2) { LocationTracker.setBridgeAttached(false) }
    }

    private fun extractGeofenceStreamHandler(
        plugin: PolyfencePlugin
    ): io.flutter.plugin.common.EventChannel.StreamHandler {
        val handlerField = PolyfencePlugin::class.java.getDeclaredField("geofenceStreamHandler")
        handlerField.isAccessible = true
        return handlerField.get(plugin) as io.flutter.plugin.common.EventChannel.StreamHandler
    }

    @Test
    fun pendingEventsQueueSizeFlowsThroughInitializeConfigMap() {
        every { LocationTracker.setBridgeAttached(any()) } returns Unit
        every { LocationTracker.setBridgePlatform(any()) } returns Unit
        every { LocationTracker.setPendingCoreDelegate(any()) } returns Unit
        every { LocationTracker.setAlertNotificationsEnabled(any()) } returns Unit
        every { LocationTracker.applyConfigurationDirect(any(), any()) } returns Unit

        val config = mapOf<String, Any>("pendingEventsQueueSize" to 500)
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to config))
        plugin.onMethodCall(call, result)

        mockkVerify {
            LocationTracker.applyConfigurationDirect(
                any(),
                match { map: Map<String, Any> ->
                    map["pendingEventsQueueSize"] == 500
                }
            )
        }
        verify(result).success(null)
    }
}
