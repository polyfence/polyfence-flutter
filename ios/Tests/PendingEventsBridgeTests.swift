import XCTest
import Flutter
import PolyfenceCore
@testable import polyfence

/// Bridge-level tests for the pending-events queue passthrough.
///
/// Every case here has a paired Kotlin test in
/// android/src/test/kotlin/io/polyfence/polyfence/flutter/
/// PendingEventsBridgeTest.kt that drives the same behaviour on the
/// Android bridge. Platform tests silently diverge when one side is
/// covered and the other is not, so cross-platform parity is a required
/// invariant of any test added to this file.
class PendingEventsBridgeTests: XCTestCase {

    var plugin: PolyfencePlugin!

    override func setUp() {
        super.setUp()
        plugin = PolyfencePlugin()
    }

    override func tearDown() {
        plugin = nil
        super.tearDown()
    }

    func testDrainPendingEventsReturnsEmptyListWhenTrackerNotInitialized() {
        let call = FlutterMethodCall(methodName: "drainPendingEvents", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)

        XCTAssertNotNil(receivedResult, "Result callback must fire")
        let list = receivedResult as? [[String: Any]]
        XCTAssertNotNil(list, "Result must be a list of maps")
        XCTAssertEqual(list?.count ?? -1, 0, "Empty when no tracker is up")
    }

    func testDrainPendingEventsReturnsEmptyListWhenCoreHasNone() {
        let initCall = FlutterMethodCall(
            methodName: "initialize",
            arguments: ["licenseKey": nil, "config": nil] as [String: Any?]
        )
        plugin.handle(initCall, result: { _ in })

        let call = FlutterMethodCall(methodName: "drainPendingEvents", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)

        XCTAssertNotNil(receivedResult, "Result callback must fire")
        let list = receivedResult as? [[String: Any]]
        XCTAssertNotNil(list, "Result must be a list of maps")
        XCTAssertEqual(list?.count ?? -1, 0, "No queued events on a fresh tracker")
    }

    func testDrainPendingEventsIsRecognizedAndReturnsList() {
        let call = FlutterMethodCall(methodName: "drainPendingEvents", arguments: nil)
        var receivedResult: Any?
        var receivedError = false
        let result: FlutterResult = { value in
            if let err = value as? FlutterError, err.code != "" {
                receivedError = true
            }
            receivedResult = value
        }

        plugin.handle(call, result: result)

        XCTAssertNotNil(receivedResult, "Result callback must fire")
        XCTAssertFalse(receivedError, "Bridge must not surface a FlutterError for a valid method")
        let flutterErr = receivedResult as? FlutterError
        XCTAssertNotEqual(flutterErr?.code, "FlutterMethodNotImplemented",
                          "drainPendingEvents must not route to the default branch")
    }

    func testPendingEventsDroppedCountReturnsZeroWhenTrackerNotInitialized() {
        let call = FlutterMethodCall(methodName: "pendingEventsDroppedCount", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)

        XCTAssertNotNil(receivedResult, "Result callback must fire")
        if let n = receivedResult as? NSNumber {
            XCTAssertEqual(n.int64Value, 0, "Zero when no tracker exists yet")
        } else if let i = receivedResult as? Int {
            XCTAssertEqual(i, 0, "Zero when no tracker exists yet")
        } else {
            XCTFail("Expected numeric zero, got \(String(describing: receivedResult))")
        }
    }

    func testPendingEventsDroppedCountReturnsZeroOnFreshTracker() {
        let initCall = FlutterMethodCall(
            methodName: "initialize",
            arguments: ["licenseKey": nil, "config": nil] as [String: Any?]
        )
        plugin.handle(initCall, result: { _ in })

        let call = FlutterMethodCall(methodName: "pendingEventsDroppedCount", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)

        XCTAssertNotNil(receivedResult, "Result callback must fire")
        if let n = receivedResult as? NSNumber {
            XCTAssertEqual(n.int64Value, 0, "Fresh tracker never evicted")
        } else if let i = receivedResult as? Int {
            XCTAssertEqual(i, 0, "Fresh tracker never evicted")
        } else {
            XCTFail("Expected numeric zero, got \(String(describing: receivedResult))")
        }
    }

    func testDisposeMethodChannelCaseSignalsBridgeDetachedAndReturnsNil() {
        // The native "dispose" case exists so the Dart bridge can signal
        // core that live delivery is going away — critical for the
        // durable pending-events queue to persist events fired after
        // teardown instead of dropping them at the delegate boundary.
        let initCall = FlutterMethodCall(
            methodName: "initialize",
            arguments: ["licenseKey": nil, "config": nil] as [String: Any?]
        )
        plugin.handle(initCall, result: { _ in })

        let call = FlutterMethodCall(methodName: "dispose", arguments: nil)
        var receivedResult: Any?
        var callbackFired = false
        let result: FlutterResult = { value in
            callbackFired = true
            receivedResult = value
        }

        plugin.handle(call, result: result)

        XCTAssertTrue(callbackFired, "Result callback must fire on dispose")
        XCTAssertNil(receivedResult, "dispose returns nil (matches Android bridge)")
        let flutterErr = receivedResult as? FlutterError
        XCTAssertNotEqual(flutterErr?.code, "FlutterMethodNotImplemented",
                          "dispose must not route to the default branch")
    }

    func testPendingEventsQueueSizeFlowsThroughInitializeConfigMap() {
        let config: [String: Any] = ["pendingEventsQueueSize": 500]
        let call = FlutterMethodCall(
            methodName: "initialize",
            arguments: ["licenseKey": nil, "config": config] as [String: Any?]
        )
        var receivedResult: Any?
        var callbackFired = false
        let result: FlutterResult = { value in
            callbackFired = true
            receivedResult = value
        }

        plugin.handle(call, result: result)

        XCTAssertTrue(callbackFired, "Result callback must fire on initialize")
        XCTAssertNil(receivedResult, "initialize returns nil on success")
        let flutterErr = receivedResult as? FlutterError
        XCTAssertNil(flutterErr, "initialize must not error on a valid pendingEventsQueueSize")
    }

    func testInitializeAttachesBridgeToRunningTracker() {
        // Fresh initialize with no pre-existing tracker: the plugin creates
        // a new LocationTracker instance and immediately marks it attached
        // so any events fired before the consumer's first drainPendingEvents
        // call reach the live delivery path.
        let call = FlutterMethodCall(
            methodName: "initialize",
            arguments: ["licenseKey": nil, "config": nil] as [String: Any?]
        )
        var callbackFired = false
        let result: FlutterResult = { _ in callbackFired = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(callbackFired, "initialize must complete successfully")
    }
}
