package io.polyfence.polyfence.flutter

import android.content.Context
import android.location.Location
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.EventChannel
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceCoreDelegate
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * Behavioural coverage of the XOR contract polyfence-core enforces inside
 * `LocationTracker.handleGeofenceEvent`:
 *
 *   attached → live-deliver via delegate, `drainPendingEvents()` returns empty
 *   detached → do NOT live-deliver, event lands in the durable queue
 *
 * Cross-platform companion of `ios/Tests/PendingEventsXorBehaviourTests.swift`.
 * The two files together lock in the invariant that would otherwise silently
 * regress into double-emit (bridge routes deliveries through a path outside
 * the XOR gate) or silent-drop bugs.
 *
 * The test hooks the plugin's `coreDelegate` — the same object the running
 * plugin registers with core — to a real Robolectric-backed LocationTracker.
 * A regression that stopped the plugin from routing geofence deliveries
 * through the delegate (e.g. reintroducing setGeofenceCallback on iOS, or
 * detaching the Android coreDelegate) surfaces here as either a
 * double-emit (drained.size != 0 in the attached case) or a silent-drop
 * (received.size != 1 in the attached case, drained.size != 1 in the
 * detached case). The paired unit tests in `PendingEventsBridgeTest`
 * (`initializeCallsSetBridgeAttachedTrue`, `disposeMethodChannelCase*`,
 * `onDetachedFromEngineCallsSetBridgeAttachedFalseBeforeNullingSinks`,
 * plus the two below) cover the plugin's `setBridgeAttached` wiring
 * from the other angle.
 */
@RunWith(RobolectricTestRunner::class)
class PendingEventsXorBehaviourTest {

    private lateinit var context: Context
    private lateinit var tracker: LocationTracker
    private lateinit var plugin: PolyfencePlugin
    private lateinit var coreDelegate: PolyfenceCoreDelegate
    private lateinit var storeDir: File
    private val receivedEvents = mutableListOf<Map<String, Any>>()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        storeDir = File(context.noBackupFilesDir, "pending_events")
        storeDir.deleteRecursively()

        tracker = Robolectric.buildService(LocationTracker::class.java).create().get()
        invokeUpdateConfigurationFromMap(mapOf("pendingEventsQueueSize" to 10))

        plugin = PolyfencePlugin()
        val contextField = PolyfencePlugin::class.java.getDeclaredField("context")
        contextField.isAccessible = true
        contextField.set(plugin, context)

        // Same `coreDelegate` object the plugin passes to core in production —
        // reach past `private` to prove the routing all the way through core's
        // handleGeofenceEvent lands where the plugin sends geofence events
        // when live-delivery wins the XOR check.
        val coreDelegateField = PolyfencePlugin::class.java.getDeclaredField("coreDelegate")
        coreDelegateField.isAccessible = true
        coreDelegate = coreDelegateField.get(plugin) as PolyfenceCoreDelegate
        tracker.setCoreDelegate(coreDelegate)
    }

    @After
    fun tearDown() {
        LocationTracker.drainPendingEvents(context)
        storeDir.deleteRecursively()
        setStaticGeofenceSink(null)
    }

    @Test
    fun xorInvariant_attachedDeliversLiveAndLeavesQueueEmpty() {
        installGeofenceSink { event -> receivedEvents.add(event) }
        LocationTracker.setBridgeAttached(true)

        invokeHandleGeofenceEvent("zone-live", "ENTER")
        drainMainLooper()

        assertEquals(
            "live event must reach the sink exactly once — a double-emit " +
                "regression (bridge routes deliveries outside core's XOR gate) " +
                "would show > 1 here",
            1, receivedEvents.size
        )
        assertEquals("zone-live", receivedEvents[0]["zoneId"])
        assertEquals("ENTER", receivedEvents[0]["eventType"])

        val drained = LocationTracker.drainPendingEvents(context)
        assertTrue(
            "attached delivery must NOT also persist to the durable queue " +
                "(double-emit BLOCKER regression check)",
            drained.isEmpty()
        )
    }

    @Test
    fun xorInvariant_detachedPersistsAndSuppressesLiveDelivery() {
        installGeofenceSink { event -> receivedEvents.add(event) }
        // Detach: mirrors what the geofence EventChannel's onCancel does —
        // flip the attach flag and null the sink so any racing delegate
        // callback finds nothing to deliver into.
        LocationTracker.setBridgeAttached(false)
        setStaticGeofenceSink(null)

        invokeHandleGeofenceEvent("zone-detached", "ENTER")
        drainMainLooper()

        assertTrue(
            "detached bridge must not receive live events (silent-drop " +
                "regression would show empty drain AND empty received)",
            receivedEvents.isEmpty()
        )

        val drained = LocationTracker.drainPendingEvents(context)
        assertEquals(
            "detached event must land in the durable queue",
            1, drained.size
        )
        assertEquals("zone-detached", drained[0]["zoneId"])
        assertEquals("ENTER", drained[0]["eventType"])
    }

    // ----- helpers -----

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
