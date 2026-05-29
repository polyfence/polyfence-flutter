/// Polyfence API key resolution.
///
/// The key is supplied at build/run time via the `POLYFENCE_API_KEY`
/// dart-define and compiled into the binary:
///
///   flutter run --dart-define=POLYFENCE_API_KEY=pf_...
///
/// This example is dev-facing — developers run it from their IDE or
/// shell, so an env-only flow keeps the key out of the UI surface and
/// matches the usual API-credential ergonomics. There is no in-app
/// paste field by design.
class ApiKeyStore {
  static const String _value = String.fromEnvironment('POLYFENCE_API_KEY');

  /// The configured Polyfence API key, or null when the dart-define
  /// is missing or empty.
  static String? get() => _value.isEmpty ? null : _value;
}
