import XCTest
import Flutter
import CoreLocation
import PolyfenceCore
@testable import polyfence

/// Behavioural coverage of the XOR contract polyfence-core enforces inside
/// `LocationTracker.handleGeofenceEvent`:
///
///   attached → live-deliver via delegate, `drainPendingEvents()` returns empty
///   detached → do NOT live-deliver, event lands in the durable queue
///
/// Cross-platform companion of
/// `android/src/test/kotlin/io/polyfence/polyfence/flutter/PendingEventsXorBehaviourTest.kt`.
/// The two files together lock in the invariant that would otherwise silently
/// regress into double-emit (`geofenceCallback` fires unconditionally while
/// `deliveredLive` stays false → persist happens too) or silent-drop bugs.
///
/// Uses core's `_testInvokeHandleGeofenceEvent` seam to drive the event path
/// without a real CLLocationManager fix.
class PendingEventsXorBehaviourTests: XCTestCase {

    var plugin: PolyfencePlugin!
    var receivedEvents: [[String: Any]] = []

    override func setUp() {
        super.setUp()
        plugin = PolyfencePlugin()
        receivedEvents = []
    }

    override func tearDown() {
        // Force a clean queue between tests so a stale event from one case
        // doesn't leak into the next assertion.
        if let tracker = accessLocationTracker() {
            _ = tracker.drainPendingEvents()
        }
        plugin = nil
        super.tearDown()
    }

    func testXorInvariant_attachedDeliversLiveAndLeavesQueueEmpty() {
        initializePluginWithQueueSize(10)
        // Simulate onListen — the geofence stream just got a subscriber.
        installGeofenceSink { [weak self] event in
            self?.receivedEvents.append(event)
        }
        accessLocationTracker()?.setBridgeAttached(true)

        // Drain any pre-existing entries so the assertion is unambiguous.
        _ = accessLocationTracker()?.drainPendingEvents()

        accessLocationTracker()?._testInvokeHandleGeofenceEvent(
            zoneId: "zone-live",
            eventType: "ENTER",
            location: CLLocation(latitude: 51.5, longitude: -0.1)
        )

        // core dispatches delegate callbacks on the main queue; spin the
        // runloop so the sink observes the event before we assert.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(receivedEvents.count, 1,
                       "live event must reach the sink exactly once")
        XCTAssertEqual(receivedEvents.first?["zoneId"] as? String, "zone-live")
        XCTAssertEqual(receivedEvents.first?["eventType"] as? String, "ENTER")

        let drained = accessLocationTracker()?.drainPendingEvents() ?? []
        XCTAssertTrue(drained.isEmpty,
                      "attached delivery must NOT persist to the durable queue " +
                      "(double-emit BLOCKER regression check)")
    }

    func testXorInvariant_detachedPersistsAndSuppressesLiveDelivery() {
        initializePluginWithQueueSize(10)
        installGeofenceSink { [weak self] event in
            self?.receivedEvents.append(event)
        }
        // Drain any pre-existing entries so the assertion is unambiguous.
        _ = accessLocationTracker()?.drainPendingEvents()

        // Simulate onCancel — the geofence stream has no listener.
        accessLocationTracker()?.setBridgeAttached(false)
        clearGeofenceSink()

        accessLocationTracker()?._testInvokeHandleGeofenceEvent(
            zoneId: "zone-detached",
            eventType: "ENTER",
            location: CLLocation(latitude: 51.5, longitude: -0.1)
        )

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertTrue(receivedEvents.isEmpty,
                      "detached bridge must not receive live events")

        let drained = accessLocationTracker()?.drainPendingEvents() ?? []
        XCTAssertEqual(drained.count, 1,
                       "detached event must land in the durable queue")
        XCTAssertEqual(drained.first?["zoneId"] as? String, "zone-detached")
        XCTAssertEqual(drained.first?["eventType"] as? String, "ENTER")
    }

    // ----- helpers -----

    private func initializePluginWithQueueSize(_ size: Int) {
        let call = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "licenseKey": nil,
                "config": ["pendingEventsQueueSize": size]
            ] as [String: Any?]
        )
        let done = expectation(description: "initialize returns")
        plugin.handle(call) { _ in done.fulfill() }
        wait(for: [done], timeout: 1.0)
    }

    private func accessLocationTracker() -> LocationTracker? {
        let mirror = Mirror(reflecting: plugin!)
        for child in mirror.children where child.label == "locationTracker" {
            return child.value as? LocationTracker
        }
        return nil
    }

    private func installGeofenceSink(_ sink: @escaping FlutterEventSink) {
        // Call the plugin's own onListen so setBridgeAttached(true) fires
        // via the production path we're covering.
        _ = plugin.onListen(withArguments: "geofence", eventSink: sink)
    }

    private func clearGeofenceSink() {
        _ = plugin.onCancel(withArguments: "geofence")
    }
}
