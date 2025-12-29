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

# Update example app version to next patch version (e.g., 0.2.5 -> 0.2.6)
# Extract major.minor.patch and increment patch
IFS='.' read -r MAJOR MINOR PATCH <<< "$PLUGIN_VERSION"
NEXT_PATCH=$((PATCH + 1))
EXAMPLE_VERSION="${MAJOR}.${MINOR}.${NEXT_PATCH}"
sed -i '' "s/^version:.*/version: $EXAMPLE_VERSION/" example/pubspec.yaml

echo "✅ Version synced successfully!"
echo "  Plugin version: $PLUGIN_VERSION"
echo "  Example app version: $EXAMPLE_VERSION"
echo "  iOS podspec: $PLUGIN_VERSION"

