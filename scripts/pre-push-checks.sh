#!/bin/bash
# Pre-push quality checks — runs locally before push to save CI minutes
# Install: cp scripts/pre-push-checks.sh .git/hooks/pre-push && chmod +x .git/hooks/pre-push
set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "Running pre-push checks..."

# Code quality checks (moved from CI)
echo "  Checking for emojis in production code..."
if grep -rPn '[\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2702}-\x{27B0}\x{FE00}-\x{FE0F}\x{1F900}-\x{1F9FF}]' lib/ android/src/ ios/Classes/ 2>/dev/null; then
  echo "ERROR: Emojis found in production code"
  exit 1
fi

echo "  Checking for internal files in git..."
for file in CLAUDE.md .cursorrules; do
  if [ -f "$file" ] && git ls-files --error-unmatch "$file" 2>/dev/null; then
    echo "ERROR: Internal file $file is tracked in git"
    exit 1
  fi
done
for dir in tasks/ prompts/ .claude/; do
  if git ls-files | grep -q "^$dir"; then
    echo "ERROR: Internal directory $dir is tracked in git"
    exit 1
  fi
done

echo "  Checking for secrets..."
if grep -rPn '(sk_live|sk_test|pk_live|pk_test|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|xoxb-|xoxp-)' --include="*.dart" --include="*.kt" --include="*.swift" --include="*.yaml" --include="*.yml" --include="*.json" --include="*.properties" . 2>/dev/null | grep -v node_modules | grep -v ".gradle"; then
  echo "ERROR: Potential secrets found in code"
  exit 1
fi


echo "  Checking for local paths in docs..."
if git grep -nE '/Users/|C:\\\\Users\\\\|BEGIN PRIVATE KEY|BEGIN RSA PRIVATE KEY|AKIA[0-9A-Z]{16}' -- '**/*.md' 2>/dev/null; then
  echo "ERROR: Local paths or secrets found in markdown files"
  exit 1
fi

# Flutter analyze + test
echo "  Running flutter analyze..."
flutter analyze --no-fatal-infos

echo "  Running flutter test..."
flutter test

echo "All pre-push checks passed."
