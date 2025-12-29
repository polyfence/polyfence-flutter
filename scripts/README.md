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

## Automatic Pre-commit Hook

**✅ Pre-commit hook is installed and active!**

The pre-commit hook automatically runs `sync_version.sh` when `pubspec.yaml` is modified, ensuring versions stay in sync before every commit.

**How it works:**
- When you commit changes to `pubspec.yaml`, the hook automatically:
  1. Detects the version change
  2. Runs `sync_version.sh` to sync all files
  3. Stages the synced files (`example/pubspec.yaml`, `ios/polyfence.podspec`)
  4. Allows the commit to proceed

**Installation:**
The hook is already installed in `.git/hooks/pre-commit`. If you need to reinstall it:
```bash
./scripts/install-pre-commit-hook.sh
```

## Manual Sync (if needed)

If you need to manually sync versions (e.g., after updating `pubspec.yaml`):

```bash
./scripts/sync_version.sh
```

This script will:
1. Extract version from `pubspec.yaml`
2. Update `ios/polyfence.podspec`
3. Update `example/pubspec.yaml` (increments patch version, e.g., 0.2.5 -> 0.2.6)

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

