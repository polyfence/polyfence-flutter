package io.polyfence.polyfence.flutter

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.polyfence.core.ZonePersistence
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The getZone happy path, against real core storage.
 *
 * The plugin hands core's loaded map to the channel without replacing
 * `JSONObject.NULL`, relying on `StandardMessageCodec.writeValue` encoding any
 * value that `.equals(null)` as a null. A stored circle always carries
 * `polygon: null`, so if that codec check changed, every circle would stop
 * reading back. These tests encode the plugin's real result through the real
 * codec so that change shows up here rather than on a phone.
 */
@RunWith(RobolectricTestRunner::class)
class PolyfencePluginGetZoneTest {

    private lateinit var context: Context
    private lateinit var plugin: PolyfencePlugin

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        ZonePersistence(context).clearAllZones()

        plugin = PolyfencePlugin()
        val contextField = PolyfencePlugin::class.java.getDeclaredField("context")
        contextField.isAccessible = true
        contextField.set(plugin, context)
    }

    @After
    fun tearDown() {
        ZonePersistence(context).clearAllZones()
    }

    private fun callGetZone(zoneId: String): CapturingResult {
        val result = CapturingResult()
        plugin.onMethodCall(MethodCall("getZone", mapOf("zoneId" to zoneId)), result)
        return result
    }

    /** What the Dart side receives: the plugin's value after a codec round trip. */
    private fun throughCodec(value: Any?): Any? {
        val encoded = StandardMessageCodec.INSTANCE.encodeMessage(value)
        encoded?.rewind()
        return StandardMessageCodec.INSTANCE.decodeMessage(encoded)
    }

    @Test
    fun storedNullReachesDartAsNull() {
        @Suppress("UNCHECKED_CAST")
        val zoneData = mapOf(
            "id" to "circle-1",
            "name" to "Depot",
            "type" to "circle",
            "center" to mapOf("latitude" to 51.5, "longitude" to -0.1),
            "radius" to 100.0,
            "polygon" to null,
            "metadata" to mapOf("bay" to 4, "note" to null),
        ) as Map<String, Any>
        ZonePersistence(context).saveZone("circle-1", "Depot", zoneData)

        val result = callGetZone("circle-1")
        assertTrue("getZone should succeed, got error ${result.errorCode}", result.succeeded)

        // Precondition: core really does hand back the sentinel, so the codec
        // assertion below is testing the case it claims to.
        @Suppress("UNCHECKED_CAST")
        val raw = result.value as Map<String, Any?>
        assertSame(JSONObject.NULL, raw["polygon"])

        @Suppress("UNCHECKED_CAST")
        val decoded = throughCodec(raw) as Map<String, Any?>
        assertTrue(decoded.containsKey("polygon"))
        assertNull(decoded["polygon"])
        assertEquals("Depot", decoded["name"])
        @Suppress("UNCHECKED_CAST")
        val metadata = decoded["metadata"] as Map<String, Any?>
        assertEquals(4, metadata["bay"])
        assertTrue(metadata.containsKey("note"))
        assertNull(metadata["note"])
    }

    @Test
    fun missingZoneSucceedsWithNull() {
        val result = callGetZone("never-added")
        assertTrue("getZone should succeed, got error ${result.errorCode}", result.succeeded)
        assertNull(result.value)
    }

    private class CapturingResult : MethodChannel.Result {
        var succeeded = false
        var value: Any? = null
        var errorCode: String? = null

        override fun success(result: Any?) {
            succeeded = true
            value = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
        }

        override fun notImplemented() {
            errorCode = "notImplemented"
        }
    }
}
