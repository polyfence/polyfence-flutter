# Integration Tests

This directory contains integration tests for the Polyfence Flutter plugin.

## Running Integration Tests

### On a Physical Device or Emulator

```bash
# Run on the default device
flutter test integration_test/polyfence_test.dart

# Run with verbose output
flutter test -v integration_test/polyfence_test.dart

# Run a specific test group
flutter test -v integration_test/polyfence_test.dart -k "Zone Management"
```

### On Android Emulator

```bash
# Recommended: emulator with location services support (Play Services)
flutter test integration_test/polyfence_test.dart
```

### On iOS Simulator

```bash
# iOS simulator must have location services enabled
flutter test integration_test/polyfence_test.dart
```

## Test Coverage

The integration tests cover:

1. **Initialization** — Verify plugin initializes correctly and idempotently
2. **Zone Management** — Add/remove circle and polygon zones, validation
3. **Tracking Lifecycle** — Start/stop tracking cycles
4. **Permission Handling** — Request permissions, check location services
5. **Error Handling** — Verify error streams don't crash
6. **Zone State Management** — Retrieve zone inside/outside states

## Important Notes

- **Location Services**: Tests skip or adapt based on device location services state
- **Permissions**: Tests handle both granted and denied permission scenarios
- **Emulator Behavior**: Some emulators may not have GPS or location services enabled, which is expected
- **Background Tracking**: Background location tracking requires platform-level testing on real devices

## Test Behavior

- Each test is independent with setUp/tearDown cleanup
- Tests use try/catch for platform operations that may fail due to device state
- Error cases are validated, not treated as test failures when expected
