# Polyfence Plugin Release Automation
#
# Usage: make release VERSION=0.10.2
#
# IMPORTANT: Update CHANGELOG.md manually before running this command.
# The script will sync the version across pubspec.yaml, lib/src/version.dart,
# example/pubspec.yaml, and ios/polyfence.podspec automatically.

VERSION ?= $(error VERSION is required. Usage: make release VERSION=0.10.2)

.PHONY: check release clean

# Run static analysis and tests
check:
	@echo "Running static analysis..."
	@flutter analyze
	@echo "Running tests..."
	@flutter test
	@echo "✅ All checks passed"

# Release a new version (checks + version sync + commit + tag + push)
release: check
	@echo ""
	@echo "🔍 Checking working directory..."
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Working directory is not clean."; \
		echo "Please commit or stash changes first."; \
		git status --short; \
		exit 1; \
	fi
	@echo "✅ Working directory is clean"
	@echo ""
	@echo "📝 Releasing v$(VERSION)..."
	@echo ""
	@echo "1️⃣  Updating version in pubspec.yaml..."
	@sed -i.bak 's/^version: .*/version: $(VERSION)/' pubspec.yaml && rm pubspec.yaml.bak
	@echo "2️⃣  Syncing version across all files..."
	@./scripts/sync_version.sh
	@echo "3️⃣  Staging changes..."
	@git add -A
	@echo "4️⃣  Committing release..."
	@git commit -m "release: v$(VERSION)"
	@echo "5️⃣  Creating git tag..."
	@git tag v$(VERSION)
	@echo "6️⃣  Pushing to remote..."
	@git push origin main
	@git push origin v$(VERSION)
	@echo ""
	@echo "✅ Released v$(VERSION)"
	@echo ""

# Clean build artifacts
clean:
	@flutter clean
	@cd example && flutter clean
