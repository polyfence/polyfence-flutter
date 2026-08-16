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
 * Bridge-level wiring for the listener-live signal that triggers automatic
 * delivery of the durable queue.
 *
 * Every case here has a paired Swift test in
 * ios/Tests/PendingEventsAutoDrainBridgeTests.swift that drives the same
 * behaviour on the iOS bridge. Platform tests silently diverge when one side
 * is covered and the other is not, so cross-platform parity is a required
 * invariant of any test added to this file.
 */
@RunWith(MockitoJUnitRunner.Silent::class)
class PendingEventsAutoDrainBridgeTest {

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
        every { LocationTracker.setBridgeAttached(any()) } returns Unit
        every { LocationTracker.setEventListenerActive(any()) } returns Unit
    }

    @After
    fun tearDown() {
        unmockkObject(LocationTracker.Companion)
    }

    @Test
    fun onAttachedToEngineDeclaresOwnershipOfTheListenerSignal() {
        // Core treats delegate registration as a direct-Kotlin consumer
        // subscribing. Declaring here — before any method-channel call can
        // reach initialize() — is what stops that shortcut from replaying the
        // queue into a Dart stream the app has not subscribed to yet.
        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))

        plugin.onAttachedToEngine(binding)

        mockkVerify { LocationTracker.setEventListenerActive(false) }
    }

    @Test
    fun initializeNeverReportsAnActiveListener() {
        // The load-bearing property. initialize() registers the delegate and
        // attaches the sink, but the Dart-side subscription happens after it
        // returns — reporting an active listener here would replay the durable
        // queue into a broadcast stream with no subscribers, which discards it.
        every { LocationTracker.setBridgePlatform(any()) } returns Unit
        every { LocationTracker.setPendingCoreDelegate(any()) } returns Unit
        every { LocationTracker.setAlertNotificationsEnabled(any()) } returns Unit

        val call = MethodCall(
            "initialize",
            mapOf("licenseKey" to null, "config" to emptyMap<String, Any>())
        )
        plugin.onMethodCall(call, result)

        mockkVerify(exactly = 0) { LocationTracker.setEventListenerActive(true) }
        verify(result).success(null)
    }

    @Test
    fun setEventListenerActiveForwardsTrueToCore() {
        val call = MethodCall("setEventListenerActive", mapOf("active" to true))
        plugin.onMethodCall(call, result)

        mockkVerify { LocationTracker.setEventListenerActive(true) }
        verify(result).success(null)
        verify(result, never()).notImplemented()
        verify(result, never()).error(any(), any(), any())
    }

    @Test
    fun setEventListenerActiveForwardsFalseToCore() {
        val call = MethodCall("setEventListenerActive", mapOf("active" to false))
        plugin.onMethodCall(call, result)

        mockkVerify { LocationTracker.setEventListenerActive(false) }
        verify(result).success(null)
    }

    @Test
    fun setEventListenerActiveWithMissingArgumentDefaultsToInactive() {
        // A malformed call must not be read as "somebody is listening" — the
        // safe reading leaves the queue on disk.
        val call = MethodCall("setEventListenerActive", null)
        plugin.onMethodCall(call, result)

        mockkVerify { LocationTracker.setEventListenerActive(false) }
        verify(result).success(null)
    }

    @Test
    fun disposeReportsTheListenerAsGone() {
        val call = MethodCall("dispose", null)
        plugin.onMethodCall(call, result)

        mockkVerify { LocationTracker.setEventListenerActive(false) }
        verify(result).success(null)
    }

    @Test
    fun onDetachedFromEngineReportsTheListenerAsGone() {
        val binding = mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding::class.java)
        val binaryMessenger = mock(io.flutter.plugin.common.BinaryMessenger::class.java)
        `when`(binding.binaryMessenger).thenReturn(binaryMessenger)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))
        plugin.onAttachedToEngine(binding)

        plugin.onDetachedFromEngine(binding)

        mockkVerify(atLeast = 2) { LocationTracker.setEventListenerActive(false) }
    }
}
