import XCTest
import Flutter
import CoreLocation
import PolyfenceCore
@testable import polyfence

/// Coverage of automatic delivery of the durable queue across the Flutter iOS
/// bridge: a real LocationTracker with events on disk, the plugin's own
/// geofence sink, and the `setEventListenerActive` method call the Dart side
/// makes on first subscription.
///
/// Cross-platform companion of
/// `android/src/test/kotlin/io/polyfence/polyfence/flutter/PendingEventsAutoDrainBehaviourTest.kt`
/// and `...PendingEventsAutoDrainBridgeTest.kt`.
///
/// NOT CI-gated yet — the plugin's iOS test suite has no xcodebuild job in
/// `.github/workflows/ci.yml` and `example/ios/Runner.xcodeproj` does not
/// reference `ios/Tests/`. Runs manually via `xcodebuild test` when the
/// Runner project's test target is extended; wiring that is out of scope
/// for this file. The behaviour these cases describe is executed today by
/// polyfence-core's `PendingEventsAutoDrainTests`.
class PendingEventsAutoDrainBridgeTests: XCTestCase {

    var plugin: PolyfencePlugin!
    var receivedEvents: [[String: Any]] = []

    override func setUp() {
        super.setUp()
        LocationTracker.setEventListenerActive(false)
        plugin = PolyfencePlugin()
        receivedEvents = []
    }

    override func tearDown() {
        if let tracker = accessLocationTracker() {
            _ = tracker.drainPendingEvents()
        }
        plugin = nil
        LocationTracker.setEventListenerActive(false)
        super.tearDown()
    }

    /// The load-bearing property. `initialize` registers the delegate and
    /// attaches the sink, but the Dart-side subscription happens after it
    /// returns — replaying there emits into a broadcast stream with no
    /// subscribers, which discards it.
    func testQueuedEventsArriveOnlyOnceTheDartSideReportsAListener() {
        initializePluginWithQueueSize(10)
        guard let tracker = accessLocationTracker() else {
            XCTFail("plugin did not construct a LocationTracker")
            return
        }
        _ = tracker.drainPendingEvents()

        // A crossing captured while nothing was receiving.
        tracker.setBridgeAttached(false)
        clearGeofenceSink()
        tracker._testInvokeHandleGeofenceEvent(
            zoneId: "zone-queued",
            eventType: "ENTER",
            location: CLLocation(latitude: 51.5, longitude: -0.1)
        )
        tracker._testRestoreZonesFromStorage()

        // initialize()'s end state: sink attached, delegate registered, no
        // consumer subscribed on the Dart side.
        installGeofenceSink { [weak self] event in
            self?.receivedEvents.append(event)
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertTrue(receivedEvents.isEmpty,
                      "Attaching the sink is what initialize() does — replaying "
                      + "there emits into a Dart stream with no subscriber")

        // First Dart-side subscription.
        invokeSetEventListenerActive(true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?["zoneId"] as? String, "zone-queued")
        XCTAssertEqual(receivedEvents.first?["eventType"] as? String, "ENTER")
        XCTAssertEqual(receivedEvents.first?["deliveredLate"] as? Bool, true)
        XCTAssertTrue(tracker.drainPendingEvents().isEmpty,
                      "Replay must clear the queue")
    }

    func testASecondSubscriptionDoesNotRedeliverTheBatch() {
        initializePluginWithQueueSize(10)
        guard let tracker = accessLocationTracker() else {
            XCTFail("plugin did not construct a LocationTracker")
            return
        }
        _ = tracker.drainPendingEvents()

        tracker.setBridgeAttached(false)
        clearGeofenceSink()
        tracker._testInvokeHandleGeofenceEvent(
            zoneId: "zone-queued",
            eventType: "ENTER",
            location: CLLocation(latitude: 51.5, longitude: -0.1)
        )
        tracker._testRestoreZonesFromStorage()

        installGeofenceSink { [weak self] event in
            self?.receivedEvents.append(event)
        }
        invokeSetEventListenerActive(true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(receivedEvents.count, 1)

        invokeSetEventListenerActive(true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(receivedEvents.count, 1,
                       "A second subscriber must not re-receive the first one's batch")
    }

    func testOptOutLeavesTheQueueForAManualDrain() {
        initializePluginWithQueueSize(10, autoDrainEnabled: false)
        guard let tracker = accessLocationTracker() else {
            XCTFail("plugin did not construct a LocationTracker")
            return
        }
        _ = tracker.drainPendingEvents()

        tracker.setBridgeAttached(false)
        clearGeofenceSink()
        tracker._testInvokeHandleGeofenceEvent(
            zoneId: "zone-queued",
            eventType: "ENTER",
            location: CLLocation(latitude: 51.5, longitude: -0.1)
        )
        tracker._testRestoreZonesFromStorage()

        installGeofenceSink { [weak self] event in
            self?.receivedEvents.append(event)
        }
        invokeSetEventListenerActive(true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertTrue(receivedEvents.isEmpty, "Opt-out must suppress automatic delivery")
        let drained = tracker.drainPendingEvents()
        XCTAssertEqual(drained.count, 1, "The queue must survive intact for the manual drain")
        XCTAssertEqual(drained.first?["zoneId"] as? String, "zone-queued")
    }

    // ----- helpers -----

    private func initializePluginWithQueueSize(_ size: Int, autoDrainEnabled: Bool = true) {
        let call = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "licenseKey": nil,
                "config": [
                    "pendingEventsQueueSize": size,
                    "pendingEventsAutoDrainEnabled": autoDrainEnabled
                ]
            ] as [String: Any?]
        )
        let done = expectation(description: "initialize returns")
        plugin.handle(call) { _ in done.fulfill() }
        wait(for: [done], timeout: 1.0)
    }

    private func invokeSetEventListenerActive(_ active: Bool) {
        let call = FlutterMethodCall(
            methodName: "setEventListenerActive",
            arguments: ["active": active]
        )
        let done = expectation(description: "setEventListenerActive returns")
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
        // Call the plugin's own onListen so setBridgeAttached(true) fires via
        // the production path. Note this is the sink lifecycle, not the
        // listener lifecycle — the distinction the tests above turn on.
        _ = plugin.onListen(withArguments: "geofence", eventSink: sink)
    }

    private func clearGeofenceSink() {
        _ = plugin.onCancel(withArguments: "geofence")
    }
}
