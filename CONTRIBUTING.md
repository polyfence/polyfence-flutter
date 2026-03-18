# Contributing to Polyfence

Thank you for considering contributing to Polyfence! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, constructive, and collaborative. We're building this together.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**When filing a bug report, include:**
- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected vs actual behavior**
- **Platform** (iOS/Android version)
- **Flutter/Dart version** (`flutter --version`)
- **Code snippet** (minimal reproduction)
- **Logs** (if applicable)

**Label your issue:** `bug`

### Suggesting Features

We love feature ideas! Before suggesting:
1. Check if it's already requested in issues
2. Ensure it aligns with Polyfence's privacy-first philosophy
3. Consider if it belongs in the plugin or the SaaS (polyfence.io)

**When suggesting a feature:**
- Describe the problem you're trying to solve
- Explain your proposed solution
- Provide use cases or examples

**Label your issue:** `enhancement`

### Asking Questions

Have a question? Open an issue with the `question` label.

For commercial support, see [polyfence.io](https://polyfence.io).

## Development Process

### Setup

```bash
# Clone the repository
git clone https://github.com/blackabass/polyfence-flutter.git
cd polyfence-flutter

# Install dependencies
flutter pub get

# Run the example app
cd example
flutter run
```

### Running Tests

```bash
# Run Dart tests
flutter test

# Run platform-specific tests
cd android && ./gradlew test
cd ios && xcodebuild test
```

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Run `flutter analyze` before submitting
- Use `dart format .` to format code
- Add comments for complex logic (especially geofencing algorithms)

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add proximity-based GPS optimization
fix: Resolve iOS background tracking issue
docs: Update README with battery optimization guide
refactor: Simplify zone persistence logic
test: Add ray-casting algorithm tests
```

**Prefixes:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Tests
- `chore:` Maintenance

### Pull Request Process

1. **Fork the repository** and create your branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write tests for new features
   - Ensure all tests pass
   - Update documentation (README, code comments)
   - Run `flutter analyze` and fix any warnings

3. **Test on both platforms**
   - iOS (physical device recommended for location testing)
   - Android (physical device recommended)

4. **Submit a pull request**
   - Reference related issues (e.g., "Fixes #123")
   - Describe your changes clearly
   - Include screenshots/videos for UI changes
   - Explain testing you performed

5. **Code review**
   - Address feedback constructively
   - Make requested changes
   - Be patient—reviews may take a few days

### What We Look For in PRs

✅ **Good PRs:**
- Solve a specific problem
- Include tests
- Have clear commit messages
- Update relevant documentation
- Are focused (one feature/fix per PR)

❌ **PRs we'll likely reject:**
- Large, unfocused changes
- No tests for new features
- Breaking changes without discussion
- Code style violations
- Features that compromise privacy

## Areas We Need Help

### High Priority
- [ ] Windows/macOS/Linux support
- [ ] Improved battery optimization algorithms
- [ ] More GPS accuracy profiles
- [ ] Better error messages
- [ ] Performance benchmarks

### Medium Priority
- [ ] Example apps for specific use cases (delivery, logistics, etc.)
- [ ] Integration guides for popular backends (Firebase, Supabase)
- [ ] Video tutorials
- [ ] Translations (documentation in other languages)

### Low Priority (But Appreciated)
- [ ] Code cleanup and refactoring
- [ ] Additional tests
- [ ] Typo fixes
- [ ] Better code comments

## Architecture Guidelines

### Core Principles

1. **Privacy First**
   - No external API calls by default
   - Anonymous telemetry is opt-in (disabled by default)
   - Location data stays on device

2. **Platform Parity**
   - iOS and Android should behave identically
   - Same API, same performance characteristics
   - Document any platform-specific limitations

3. **Developer Experience**
   - Simple, obvious API
   - Helpful error messages
   - Comprehensive documentation

4. **Performance**
   - Battery-efficient by default
   - Efficient algorithms (O(n) for zone checks)
   - Minimal memory usage

### Dependency: polyfence-core

The native geofencing engines (Kotlin + Swift) live in a separate repo: [polyfence-core](https://github.com/blackabass/polyfence-core). This Flutter plugin depends on polyfence-core for all native geofencing logic.

```
polyfence-core           ← Shared native engine (Kotlin + Swift)
  ├── GeofenceEngine     ← Ray-casting, haversine, dwell detection
  ├── LocationTracker    ← SmartGPS, activity-based intervals
  └── TelemetryAggregator

polyfence (this repo)    ← Flutter bridge
  ├── Dart API           ← PolyfenceService, models, config
  └── MethodChannel      ← Dart ↔ Native communication
```

If your contribution involves native geofencing logic (zone detection algorithms, GPS scheduling, activity recognition), changes likely need to go into polyfence-core first.

### File Structure

```
lib/
├── polyfence.dart              # Main export file
├── src/
│   ├── models/                 # Data models (Zone, Location, etc.)
│   ├── services/               # Core services (Polyfence, Analytics)
│   ├── platform/               # Platform channel interface
│   ├── configuration/          # GPS configuration classes
│   ├── errors/                 # Custom exceptions
│   └── debug/                  # Debug utilities
android/src/main/kotlin/        # Android implementation (bridges to polyfence-core)
ios/Classes/                    # iOS implementation (bridges to polyfence-core)
```

### Key Files

- **`lib/src/services/polyfence_service.dart`** - Main API
- **`android/.../GeofenceEngine.kt`** - Android geofencing logic
- **`ios/Classes/Core/GeofenceEngine.swift`** - iOS geofencing logic
- **Platform channels** - Communication bridge between Dart and native

## Testing Guidelines

### What to Test

- **Unit tests**: Geofencing algorithms (Haversine, ray-casting)
- **Widget tests**: Example app UI
- **Integration tests**: Full flow (add zone → track → events)
- **Platform tests**: Native code (Kotlin/Swift)

### Running Tests

```bash
# Dart tests
flutter test

# Android tests
cd android && ./gradlew test

# iOS tests
cd ios && xcodebuild test -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 14'
```

## Documentation

When adding features, update:
- [ ] README.md (if public API changed)
- [ ] CHANGELOG.md (user-facing changes)
- [ ] Code comments (complex logic)
- [ ] Example app (if demonstrating new feature)
- [ ] Dartdoc comments (public APIs)

## License

By contributing, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers the project.

## Questions?

- **General questions**: Open an issue with `question` label
- **Security issues**: See [SECURITY.md](SECURITY.md)
- **Commercial support**: [polyfence.io](https://polyfence.io)

## Thank You! 🎉

Every contribution makes Polyfence better for the entire Flutter community. We appreciate your time and effort!
