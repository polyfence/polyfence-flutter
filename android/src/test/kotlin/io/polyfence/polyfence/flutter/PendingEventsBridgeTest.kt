package io.polyfence.polyfence.flutter

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.polyfence.core.LocationTracker
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.MockedStatic
import org.mockito.Mockito
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

/**
 * Bridge-level tests for the pending-events queue passthrough.
 *
 * Mirrors the assertions in the iOS test/ios/PendingEventsBridgeTests.swift
 * — every case here has a paired Swift test that drives the same behaviour
 * on the iOS bridge. Cross-platform parity was the meta-lesson from the
 * prior release round: platform tests silently drift when one side is
 * covered and the other is not.
 */
@RunWith(MockitoJUnitRunner::class)
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
    }

    @After
    fun tearDown() {
        // reset any static mocks between tests
    }

    @Test
    fun drainPendingEventsReturnsEmptyListWhenCoreHasNone() {
        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<List<Map<String, Any>>> {
                LocationTracker.drainPendingEvents(any())
            }.thenReturn(emptyList())

            val call = MethodCall("drainPendingEvents", null)
            plugin.onMethodCall(call, result)

            verify(result).success(emptyList<Map<String, Any>>())
            verify(result, never()).error(any(), any(), any())
            verify(result, never()).notImplemented()
        }
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

        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<List<Map<String, Any>>> {
                LocationTracker.drainPendingEvents(any())
            }.thenReturn(rawEvents)

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
    }

    @Test
    fun drainPendingEventsPreservesOldestFirstOrder() {
        val rawEvents = listOf<Map<String, Any>>(
            mapOf("zoneId" to "z1", "eventType" to "ENTER", "timestamp" to 1_000L),
            mapOf("zoneId" to "z1", "eventType" to "EXIT", "timestamp" to 2_000L)
        )

        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<List<Map<String, Any>>> {
                LocationTracker.drainPendingEvents(any())
            }.thenReturn(rawEvents)

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
    }

    @Test
    fun drainPendingEventsSurfacesCoreExceptionAsPlatformError() {
        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<List<Map<String, Any>>> {
                LocationTracker.drainPendingEvents(any())
            }.thenThrow(RuntimeException("disk read error"))

            val call = MethodCall("drainPendingEvents", null)
            plugin.onMethodCall(call, result)

            verify(result).error(eq("DRAIN_PENDING_EVENTS_FAILED"), any(), any())
            verify(result, never()).success(any())
        }
    }

    @Test
    fun pendingEventsDroppedCountReturnsZeroInitially() {
        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<Long> {
                LocationTracker.pendingEventsDroppedCount(any())
            }.thenReturn(0L)

            val call = MethodCall("pendingEventsDroppedCount", null)
            plugin.onMethodCall(call, result)

            verify(result).success(0L)
        }
    }

    @Test
    fun pendingEventsDroppedCountReturnsCoreValueWhenNonZero() {
        Mockito.mockStatic(LocationTracker::class.java).use { staticMock ->
            staticMock.`when`<Long> {
                LocationTracker.pendingEventsDroppedCount(any())
            }.thenReturn(42L)

            val call = MethodCall("pendingEventsDroppedCount", null)
            plugin.onMethodCall(call, result)

            verify(result).success(42L)
        }
    }

    @Test
    fun disposeMethodChannelCaseSignalsBridgeDetachedAndReturnsSuccess() {
        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)
        verify(result).success(null)
        verify(result, never()).notImplemented()
    }

    @Test
    fun pendingEventsQueueSizeFlowsThroughInitializeConfigMap() {
        val config = mapOf<String, Any>("pendingEventsQueueSize" to 500)
        val call = MethodCall("initialize", mapOf("licenseKey" to null, "config" to config))
        plugin.onMethodCall(call, result)
        verify(result).success(null)
        verify(result, never()).notImplemented()
        verify(result, never()).error(any(), any(), any())
    }
}
