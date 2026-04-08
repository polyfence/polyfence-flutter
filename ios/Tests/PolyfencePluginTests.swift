import XCTest
import Flutter
@testable import polyfence

class PolyfencePluginTests: XCTestCase {

    var plugin: PolyfencePlugin!
    var mockMethodChannel: MockFlutterMethodChannel!
    var capturedResults: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        plugin = PolyfencePlugin()
        mockMethodChannel = MockFlutterMethodChannel()
    }

    override func tearDown() {
        plugin = nil
        mockMethodChannel = nil
        capturedResults.removeAll()
        super.tearDown()
    }

    // MARK: - Method Routing Tests

    func testInitializeMethodRouted() {
        let arguments = [
            "licenseKey": nil as String?,
            "config": nil as [String: Any]?
        ] as [String: Any?]
        let call = FlutterMethodCall(methodName: "initialize", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for initialize")
    }

    func testStartTrackingMethodRouted() {
        let call = FlutterMethodCall(methodName: "startTracking", arguments: nil)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for startTracking")
    }

    func testStopTrackingMethodRouted() {
        let call = FlutterMethodCall(methodName: "stopTracking", arguments: nil)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for stopTracking")
    }

    func testAddZoneMethodRouted() {
        let zoneData: [String: Any] = [
            "id": "zone123",
            "name": "Test Zone",
            "type": "circle",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "radius": 100.0
        ]
        let call = FlutterMethodCall(methodName: "addZone", arguments: zoneData)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for addZone")
    }

    func testRemoveZoneMethodRouted() {
        let arguments = ["zoneId": "zone123"]
        let call = FlutterMethodCall(methodName: "removeZone", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for removeZone")
    }

    func testClearAllZonesMethodRouted() {
        let call = FlutterMethodCall(methodName: "clearAllZones", arguments: nil)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for clearAllZones")
    }

    func testRequestPermissionsMethodRouted() {
        let arguments = ["always": false]
        let call = FlutterMethodCall(methodName: "requestPermissions", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for requestPermissions")
    }

    // MARK: - Query Methods Tests

    func testIsLocationServiceEnabledReturnsBoolean() {
        let call = FlutterMethodCall(methodName: "isLocationServiceEnabled", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is Bool || receivedResult is NSNumber, "Result should be a boolean")
    }

    func testGetConfigurationReturnsMap() {
        let call = FlutterMethodCall(methodName: "getConfiguration", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is [String: Any], "Result should be a dictionary")
    }

    func testGetDebugInfoReturnsMap() {
        let call = FlutterMethodCall(methodName: "getDebugInfo", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is [String: Any], "Result should be a dictionary")
    }

    func testGetErrorHistoryReturnsListOfMaps() {
        let arguments: [String: Any] = [
            "timeRangeMs": 3600000 as NSNumber,
            "errorTypes": []
        ]
        let call = FlutterMethodCall(methodName: "getErrorHistory", arguments: arguments)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is [[String: Any]], "Result should be a list of dictionaries")
    }

    func testGetCurrentZoneStatesReturnsMap() {
        let call = FlutterMethodCall(methodName: "getCurrentZoneStates", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is [String: NSNumber] || receivedResult is [String: Bool], "Result should be a map of zone IDs to bools")
    }

    func testGetSessionTelemetryReturnsMap() {
        let call = FlutterMethodCall(methodName: "getSessionTelemetry", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Result should not be nil")
        XCTAssertTrue(receivedResult is [String: Any], "Result should be a dictionary")
    }

    // MARK: - Configuration Methods Tests

    func testUpdateConfigurationWithValidDataSucceeds() {
        let arguments: [String: Any] = [
            "accuracyProfile": "BALANCED",
            "updateIntervalMs": 5000
        ]
        let call = FlutterMethodCall(methodName: "updateConfiguration", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for updateConfiguration")
    }

    func testResetConfigurationMethodRouted() {
        let call = FlutterMethodCall(methodName: "resetConfiguration", arguments: nil)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for resetConfiguration")
    }

    func testSetAccuracyProfileWithValidProfileSucceeds() {
        let call = FlutterMethodCall(methodName: "setAccuracyProfile", arguments: "BALANCED")
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Result callback should be called for setAccuracyProfile")
    }

    // MARK: - Unknown Method Tests

    func testUnknownMethodReturnsNotImplemented() {
        let call = FlutterMethodCall(methodName: "unknownMethod", arguments: nil)
        var receivedError: FlutterError?
        let result: FlutterResult = { outcome in
            if let error = outcome as? FlutterError {
                receivedError = error
            }
        }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedError, "Unknown method should trigger error")
        XCTAssertEqual(receivedError?.code, "UNIMPLEMENTED", "Should return FlutterMethodNotImplemented")
    }

    func testMisspelledMethodNameReturnsNotImplemented() {
        let call = FlutterMethodCall(methodName: "startTrackingg", arguments: nil)
        var receivedError: FlutterError?
        let result: FlutterResult = { outcome in
            if let error = outcome as? FlutterError {
                receivedError = error
            }
        }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedError, "Misspelled method should trigger error")
    }

    // MARK: - Argument Type Coercion Tests

    func testAddZoneCoercesArgumentsFromDictionary() {
        let zoneData: [String: Any] = [
            "id": "zone456",
            "name": "Test Zone",
            "type": "circle",
            "radius": 100.0 as NSNumber,
            "latitude": 37.7749 as NSNumber,
            "longitude": -122.4194 as NSNumber
        ]
        let call = FlutterMethodCall(methodName: "addZone", arguments: zoneData)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Should handle zone data coercion")
    }

    func testRemoveZoneCoercesStringArgument() {
        let arguments = ["zoneId": "zone123"]
        let call = FlutterMethodCall(methodName: "removeZone", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Should handle string argument coercion")
    }

    func testRequestPermissionsCoercesBooleanArgument() {
        let arguments = ["always": true]
        let call = FlutterMethodCall(methodName: "requestPermissions", arguments: arguments)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Should handle boolean argument coercion")
    }

    func testUpdateConfigurationCoercesMapArgument() {
        let configMap: [String: Any] = [
            "accuracyProfile": "BALANCED",
            "updateIntervalMs": 5000 as NSNumber,
            "minDistanceMeters": 10.0 as NSNumber
        ]
        let call = FlutterMethodCall(methodName: "updateConfiguration", arguments: configMap)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Should handle map argument coercion")
    }

    func testGetErrorHistoryCoercesListArgument() {
        let arguments: [String: Any] = [
            "timeRangeMs": 3600000 as NSNumber,
            "errorTypes": ["PERMISSION", "GPS"] as [String]
        ]
        let call = FlutterMethodCall(methodName: "getErrorHistory", arguments: arguments)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNotNil(receivedResult, "Should handle list argument coercion")
    }

    // MARK: - Result Type Tests

    func testInitializeReturnsNil() {
        let arguments = [
            "licenseKey": nil as String?,
            "config": nil as [String: Any]?
        ] as [String: Any?]
        let call = FlutterMethodCall(methodName: "initialize", arguments: arguments)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "initialize should return nil")
    }

    func testStartTrackingReturnsNil() {
        let call = FlutterMethodCall(methodName: "startTracking", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "startTracking should return nil")
    }

    func testStopTrackingReturnsNil() {
        let call = FlutterMethodCall(methodName: "stopTracking", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "stopTracking should return nil")
    }

    func testAddZoneReturnsNil() {
        let zoneData: [String: Any] = [
            "id": "zone789",
            "name": "Test",
            "coordinates": []
        ]
        let call = FlutterMethodCall(methodName: "addZone", arguments: zoneData)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "addZone should return nil")
    }

    func testRemoveZoneReturnsNil() {
        let arguments = ["zoneId": "zone789"]
        let call = FlutterMethodCall(methodName: "removeZone", arguments: arguments)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "removeZone should return nil")
    }

    func testClearAllZonesReturnsNil() {
        let call = FlutterMethodCall(methodName: "clearAllZones", arguments: nil)
        var receivedResult: Any?
        let result: FlutterResult = { receivedResult = $0 }

        plugin.handle(call, result: result)
        XCTAssertNil(receivedResult, "clearAllZones should return nil")
    }

    // MARK: - Dispose Tests

    func testDisposeMethodHandledGracefully() {
        let call = FlutterMethodCall(methodName: "dispose", arguments: nil)
        var resultCalled = false
        let result: FlutterResult = { _ in resultCalled = true }

        plugin.handle(call, result: result)
        XCTAssertTrue(resultCalled, "Dispose should handle result gracefully")
    }
}

// MARK: - Mock Helper for Method Channel Testing

class MockFlutterMethodChannel {
    var lastMethodName: String?
    var lastArguments: Any?
}
