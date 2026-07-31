package io.polyfence.polyfence.flutter

import android.content.Context
import android.location.Location
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceCoreDelegate
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * End-to-end coverage of automatic delivery across the Flutter bridge: a real
 * Robolectric-backed LocationTracker with events on disk, the plugin's own
 * `coreDelegate` and geofence sink, and the `setEventListenerActive` method
 * call the Dart side makes on first subscription.
 *
 * Cross-platform companion of
 * `ios/Tests/PendingEventsAutoDrainBridgeTests.swift`.
 */
@RunWith(RobolectricTestRunner::class)
class PendingEventsAutoDrainBehaviourTest {

    private lateinit var context: Context
    private lateinit var tracker: LocationTracker
    private lateinit var plugin: PolyfencePlugin
    private lateinit var coreDelegate: PolyfenceCoreDelegate
    private lateinit var storeDir: File
    private lateinit var result: MethodChannel.Result
    private val receivedEvents = mutableListOf<Map<String, Any>>()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        storeDir = File(context.noBackupFilesDir, "pending_events")
        storeDir.deleteRecursively()
        clearStagedListenerSignal()
        result = mock(MethodChannel.Result::class.java)

        tracker = Robolectric.buildService(LocationTracker::class.java).create().get()
        invokeUpdateConfigurationFromMap(mapOf("pendingEventsQueueSize" to 10))

        plugin = PolyfencePlugin()
        val contextField = PolyfencePlugin::class.java.getDeclaredField("context")
        contextField.isAccessible = true
        contextField.set(plugin, context)

        val coreDelegateField = PolyfencePlugin::class.java.getDeclaredField("coreDelegate")
        coreDelegateField.isAccessible = true
        coreDelegate = coreDelegateField.get(plugin) as PolyfenceCoreDelegate
    }

    @After
    fun tearDown() {
        LocationTracker.drainPendingEvents(context)
        storeDir.deleteRecursively()
        setStaticGeofenceSink(null)
        clearStagedListenerSignal()
    }

    @Test
    fun queuedEventsArriveAtTheSinkOnlyOnceTheDartSideReportsAListener() {
        // Plugin attach: the bridge declares that it owns the listener signal,
        // exactly as onAttachedToEngine does in production.
        LocationTracker.setEventListenerActive(false)

        // A crossing captured while nothing was receiving.
        tracker.setCoreDelegate(null)
        LocationTracker.setBridgeAttached(false)
        invokeHandleGeofenceEvent("zone-queued", "ENTER")
        invokeRestoreZonesFromStorage()

        // initialize(): delegate registered, sink attached. No consumer has
        // subscribed on the Dart side yet.
        installGeofenceSink { event -> receivedEvents.add(event) }
        tracker.setCoreDelegate(coreDelegate)
        LocationTracker.setBridgeAttached(true)
        drainMainLooper()

        assertTrue(
            "Registering the delegate and attaching the sink is what initialize() " +
                "does — replaying there emits into a Dart stream with no subscriber",
            receivedEvents.isEmpty()
        )

        // First Dart-side subscription.
        plugin.onMethodCall(
            MethodCall("setEventListenerActive", mapOf("active" to true)),
            result
        )
        drainMainLooper()

        assertEquals(1, receivedEvents.size)
        assertEquals("zone-queued", receivedEvents[0]["zoneId"])
        assertEquals("ENTER", receivedEvents[0]["eventType"])
        assertEquals(true, receivedEvents[0]["deliveredLate"])
        assertTrue(
            "Replay must clear the queue",
            LocationTracker.drainPendingEvents(context).isEmpty()
        )
    }

    @Test
    fun aSecondSubscriptionDoesNotRedeliverTheBatch() {
        LocationTracker.setEventListenerActive(false)
        tracker.setCoreDelegate(null)
        LocationTracker.setBridgeAttached(false)
        invokeHandleGeofenceEvent("zone-queued", "ENTER")
        invokeRestoreZonesFromStorage()

        installGeofenceSink { event -> receivedEvents.add(event) }
        tracker.setCoreDelegate(coreDelegate)
        LocationTracker.setBridgeAttached(true)

        plugin.onMethodCall(
            MethodCall("setEventListenerActive", mapOf("active" to true)),
            result
        )
        drainMainLooper()
        assertEquals(1, receivedEvents.size)

        plugin.onMethodCall(
            MethodCall("setEventListenerActive", mapOf("active" to true)),
            result
        )
        drainMainLooper()
        assertEquals(1, receivedEvents.size)
    }

    @Test
    fun theOptOutLeavesTheQueueForAManualDrain() {
        LocationTracker.setEventListenerActive(false)
        invokeUpdateConfigurationFromMap(
            mapOf(
                "pendingEventsQueueSize" to 10,
                "pendingEventsAutoDrainEnabled" to false
            )
        )
        tracker.setCoreDelegate(null)
        LocationTracker.setBridgeAttached(false)
        invokeHandleGeofenceEvent("zone-queued", "ENTER")
        invokeRestoreZonesFromStorage()

        installGeofenceSink { event -> receivedEvents.add(event) }
        tracker.setCoreDelegate(coreDelegate)
        LocationTracker.setBridgeAttached(true)

        plugin.onMethodCall(
            MethodCall("setEventListenerActive", mapOf("active" to true)),
            result
        )
        drainMainLooper()

        assertTrue(receivedEvents.isEmpty())
        val drained = LocationTracker.drainPendingEvents(context)
        assertEquals(1, drained.size)
        assertEquals("zone-queued", drained[0]["zoneId"])
    }

    // ----- helpers -----

    private fun clearStagedListenerSignal() {
        val field = LocationTracker::class.java.getDeclaredField("pendingEventListenerActive")
        field.isAccessible = true
        field.set(null, null)
    }

    private fun installGeofenceSink(sink: (Map<String, Any>) -> Unit) {
        val adapter = object : EventChannel.EventSink {
            override fun success(event: Any?) {
                @Suppress("UNCHECKED_CAST")
                sink(event as Map<String, Any>)
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun endOfStream() {}
        }
        setStaticGeofenceSink(adapter)
    }

    private fun setStaticGeofenceSink(sink: EventChannel.EventSink?) {
        // Companion `private var geofenceSink` is compiled to a static field
        // on the outer class in current kotlinc — check both locations for
        // resilience against a Kotlin compiler layout change.
        val field = try {
            PolyfencePlugin::class.java.getDeclaredField("geofenceSink")
        } catch (_: NoSuchFieldException) {
            PolyfencePlugin.Companion::class.java.getDeclaredField("geofenceSink")
        }
        field.isAccessible = true
        if (java.lang.reflect.Modifier.isStatic(field.modifiers)) {
            field.set(null, sink)
        } else {
            field.set(PolyfencePlugin.Companion, sink)
        }
    }

    private fun invokeUpdateConfigurationFromMap(configMap: Map<String, Any>) {
        val method = LocationTracker::class.java.getDeclaredMethod(
            "updateConfigurationFromMap",
            Map::class.java
        )
        method.isAccessible = true
        method.invoke(tracker, configMap)
    }

    private fun invokeRestoreZonesFromStorage() {
        val method = LocationTracker::class.java.getDeclaredMethod("restoreZonesFromStorage")
        method.isAccessible = true
        method.invoke(tracker)
    }

    private fun invokeHandleGeofenceEvent(zoneId: String, eventType: String) {
        val location = Location("test").apply {
            latitude = 51.5
            longitude = -0.1
        }
        val method = LocationTracker::class.java.getDeclaredMethod(
            "handleGeofenceEvent",
            String::class.java,
            String::class.java,
            Location::class.java,
            Double::class.javaPrimitiveType
        )
        method.isAccessible = true
        method.invoke(tracker, zoneId, eventType, location, 5.0)
    }

    private fun drainMainLooper() {
        // coreDelegate.onGeofenceEvent posts to mainHandler; flush the
        // Robolectric main looper so those posts run before we assert.
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
    }
}
