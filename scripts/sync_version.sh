#!/bin/bash
# Sync plugin version across all files
# Usage: ./scripts/sync_version.sh

set -e

# Get version from pubspec.yaml (single source of truth)
PLUGIN_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

if [ -z "$PLUGIN_VERSION" ]; then
    echo "Error: Could not extract version from pubspec.yaml"
    exit 1
fi

echo "Syncing version $PLUGIN_VERSION across all files..."

# Update iOS podspec
sed -i '' "s/s.version.*=.*/s.version          = '$PLUGIN_VERSION'/" ios/polyfence.podspec

# Update example app version to match plugin version exactly
EXAMPLE_VERSION="${PLUGIN_VERSION}"
sed -i '' "s/^version:.*/version: $EXAMPLE_VERSION/" example/pubspec.yaml

# Update Dart version constant
sed -i '' "s/const String polyfencePluginVersion = '.*';/const String polyfencePluginVersion = '$PLUGIN_VERSION';/" lib/src/version.dart

echo "✅ Version synced successfully!"
echo "  Plugin version: $PLUGIN_VERSION"
echo "  Example app version: $EXAMPLE_VERSION"
echo "  iOS podspec: $PLUGIN_VERSION"
echo "  Dart version constant: $PLUGIN_VERSION"

