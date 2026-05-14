#!/bin/bash
# Install pre-commit hook for automatic version syncing
# Usage: ./scripts/install-pre-commit-hook.sh

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

HOOK_FILE=".git/hooks/pre-commit"
SCRIPT_DIR="scripts"

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
if [ -f "$SCRIPT_DIR/pre-commit-hook" ]; then
    cp "$SCRIPT_DIR/pre-commit-hook" "$HOOK_FILE"
    chmod +x "$HOOK_FILE"
    echo "[OK] Pre-commit hook installed successfully"
    echo "   Versions will now auto-sync when pubspec.yaml changes"
else
    # Create hook inline if template doesn't exist
    cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Pre-commit hook to automatically sync plugin version across all files
# Runs sync_version.sh if pubspec.yaml version changed

set -e

# Get the directory of the git repository
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Check if pubspec.yaml is being committed or modified
if git diff --cached --name-only | grep -q "pubspec.yaml"; then
    echo "pubspec.yaml changed - syncing versions..."
    
    # Run sync script
    if [ -f "scripts/sync_version.sh" ]; then
        bash scripts/sync_version.sh
        
        # Stage the synced files
        git add example/pubspec.yaml ios/polyfence.podspec 2>/dev/null || true
        
        echo "[OK] Versions synced and staged"
    else
        echo "Warning: sync_version.sh not found, skipping version sync"
    fi
fi

exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "[OK] Pre-commit hook created and installed successfully"
    echo "   Versions will now auto-sync when pubspec.yaml changes"
fi

