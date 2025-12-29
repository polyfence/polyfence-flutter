# Version Synchronization Scripts

## Overview

The plugin version is managed from a single source of truth: `pubspec.yaml`. All other files automatically sync with this version.

## Automatic Version Sync

### How It Works

1. **Single Source of Truth**: `pubspec.yaml` contains the plugin version
2. **Flutter/Dart**: Reads version from `PackageInfo.fromPlatform()` (reads from `pubspec.yaml`)
3. **Native Platforms**: Version is passed from Flutter to native during `initialize()`:
   - Android: Stored in `PolyfenceDebugCollector.setPluginVersion()`
   - iOS: Stored in `PolyfenceDebugCollector.shared.setPluginVersion()`
4. **Example App**: Synced via `scripts/sync_version.sh` script

### Files That Auto-Sync

- ✅ **Flutter/Dart**: Reads from `pubspec.yaml` automatically (no sync needed)
- ✅ **Android Debug Collector**: Receives version from Flutter during initialization
- ✅ **iOS Debug Collector**: Receives version from Flutter during initialization
- ✅ **iOS Podspec**: Synced via `sync_version.sh` script
- ✅ **Example App**: Synced via `sync_version.sh` script

## Manual Sync (if needed)

If you need to manually sync versions (e.g., after updating `pubspec.yaml`):

```bash
./scripts/sync_version.sh
```

This script will:
1. Extract version from `pubspec.yaml`
2. Update `ios/polyfence.podspec`
3. Update `example/pubspec.yaml` (adds `+1` build number)

## Version Flow

```
pubspec.yaml (0.2.4)
    ↓
Flutter reads via PackageInfo.fromPlatform()
    ↓
Passed to native during initialize() → Stored in debug collectors
    ↓
Used in debug info, analytics, etc.
```

## Notes

- **No hardcoding**: All versions come from `pubspec.yaml` or are passed from Flutter
- **Example app**: Version is synced but includes `+1` build number (e.g., `0.2.4+1`)
- **Native code**: Version is stored during initialization, so it's always current

