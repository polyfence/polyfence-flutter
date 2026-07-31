package io.polyfence.polyfence.flutter

import android.Manifest
import android.app.Application
import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Permission matrix for the bridge's `requestPermissions` gate.
 *
 * The property under test: this gate must never be stricter than
 * polyfence-core's own `hasCoreTrackingPerms`. A bridge-side copy that
 * additionally demanded `ACCESS_BACKGROUND_LOCATION` refused to start tracking
 * before core was ever consulted, so a relaxation landed in core alone was
 * inert. Counterpart matrix:
 * polyfence-core `LocationTrackerPermissionGateTest`.
 *
 * The gate is private, so the cases drive it by reflection. That is the exact
 * predicate the `requestPermissions` method-channel handler returns, and
 * `PolyfenceService.startTracking` throws `Location permissions not granted`
 * on a `false` — so asserting on it is asserting on whether tracking would
 * start.
 */
@RunWith(RobolectricTestRunner::class)
class PolyfencePluginPermissionGateTest {

    private lateinit var plugin: PolyfencePlugin
    private lateinit var context: Context

    @Before
    fun setUp() {
        plugin = PolyfencePlugin()
        context = ApplicationProvider.getApplicationContext()
    }

    private fun grant(vararg permissions: String) {
        shadowOf(ApplicationProvider.getApplicationContext<Application>())
            .grantPermissions(*permissions)
    }

    private fun deny(vararg permissions: String) {
        shadowOf(ApplicationProvider.getApplicationContext<Application>())
            .denyPermissions(*permissions)
    }

    /** True when the bridge would report permissions as satisfied. */
    private fun wouldStartTracking(): Boolean {
        val method = PolyfencePlugin::class.java
            .getDeclaredMethod("hasCoreTrackingPerms", Context::class.java)
        method.isAccessible = true
        return method.invoke(plugin, context) as Boolean
    }

    // ---------------------------------------------------------------
    // The case the bridge used to refuse
    // ---------------------------------------------------------------

    @Test
    @Config(sdk = [Build.VERSION_CODES.S])
    fun `starts without background location when wake fences are off`() {
        // A consumer running the in-process polling engine and never touching
        // OS wake fences must not be forced through Google Play's
        // background-location review to use this plugin at all. This is the
        // exact configuration an API 31 device reproduced as a hard refusal.
        grant(Manifest.permission.ACCESS_FINE_LOCATION)
        deny(Manifest.permission.ACCESS_BACKGROUND_LOCATION)

        assertTrue(wouldStartTracking())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.S])
    fun `starts on coarse location alone`() {
        grant(Manifest.permission.ACCESS_COARSE_LOCATION)
        deny(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION
        )

        assertTrue(wouldStartTracking())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.P])
    fun `pre-Q starts on foreground location alone`() {
        grant(Manifest.permission.ACCESS_FINE_LOCATION)

        assertTrue(wouldStartTracking())
    }

    // ---------------------------------------------------------------
    // What the gate still enforces
    // ---------------------------------------------------------------

    @Test
    @Config(sdk = [Build.VERSION_CODES.S])
    fun `refuses without any foreground location grant`() {
        deny(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        assertFalse(wouldStartTracking())
    }

    @Test
    @Config(sdk = [34])
    fun `API 34 refuses without FOREGROUND_SERVICE_LOCATION`() {
        grant(Manifest.permission.ACCESS_FINE_LOCATION)
        deny(Manifest.permission.FOREGROUND_SERVICE_LOCATION)

        assertFalse(wouldStartTracking())
    }

    @Test
    @Config(sdk = [34])
    fun `API 34 starts with FOREGROUND_SERVICE_LOCATION and no background grant`() {
        grant(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.FOREGROUND_SERVICE_LOCATION
        )
        deny(Manifest.permission.ACCESS_BACKGROUND_LOCATION)

        assertTrue(wouldStartTracking())
    }
}
