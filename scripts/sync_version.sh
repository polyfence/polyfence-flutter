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

# Update Android plugin gradle version (used in AAR metadata)
sed -i '' "s/^version '[^']*'/version '$PLUGIN_VERSION'/" android/build.gradle

# Update example app version to match plugin version exactly
EXAMPLE_VERSION="${PLUGIN_VERSION}"
sed -i '' "s/^version:.*/version: $EXAMPLE_VERSION/" example/pubspec.yaml

# Update Dart version constant
sed -i '' "s/const String polyfencePluginVersion = '.*';/const String polyfencePluginVersion = '$PLUGIN_VERSION';/" lib/src/version.dart

# Update README.md version sentinels (BCT-FLT-005)
sed -i '' "s|<!-- pf:version -->^[0-9][0-9.]*<!-- /pf:version -->|<!-- pf:version -->^$PLUGIN_VERSION<!-- /pf:version -->|" README.md
sed -i '' "s|<!-- pf:version-plain -->[0-9][0-9.]*<!-- /pf:version-plain -->|<!-- pf:version-plain -->$PLUGIN_VERSION<!-- /pf:version-plain -->|" README.md

# Update doc/TELEMETRY.md header and payload examples (BCT-FLT-005)
sed -i '' "s/^\*\*Plugin version:\*\* [0-9][0-9.]*/**Plugin version:** $PLUGIN_VERSION/" doc/TELEMETRY.md
sed -i '' "s/\"plugin_version\": \"[0-9][0-9.]*\"/\"plugin_version\": \"$PLUGIN_VERSION\"/g" doc/TELEMETRY.md
sed -i '' "s/\`\"[0-9][0-9.]*\"\` | Plugin version/\`\"$PLUGIN_VERSION\"\` | Plugin version/" doc/TELEMETRY.md

echo "Version synced successfully."
echo "  Plugin version: $PLUGIN_VERSION"
echo "  Example app version: $EXAMPLE_VERSION"
echo "  iOS podspec: $PLUGIN_VERSION"
echo "  Android plugin gradle: $PLUGIN_VERSION"
echo "  Dart version constant: $PLUGIN_VERSION"
echo "  README.md sentinels: $PLUGIN_VERSION"
echo "  doc/TELEMETRY.md: $PLUGIN_VERSION"

