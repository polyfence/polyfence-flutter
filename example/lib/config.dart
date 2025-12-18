/// Application configuration for Polyfence example app
class AppConfig {
  /// Enable demo mode to use hardcoded demo zones instead of API
  ///
  /// - true: Uses 3 hardcoded demo zones (works offline, no API key needed)
  /// - false: Fetches real zones from polyfence.io API (requires API key below)
  static const bool demoMode = true;

  /// API key for zone admin API (only used when demoMode = false)
  ///
  /// To use the API:
  /// 1. Sign up at https://polyfence.io/auth/login (free tier available)
  /// 2. Generate your API key from the dashboard
  /// 3. Replace null below with your key: apiKey = 'your-api-key-here'
  ///
  /// ⚠️ SECURITY: Never commit real API keys to public repositories!
  /// For production apps:
  /// - Use environment variables or secure storage
  /// - Use Flutter's --dart-define or flutter_dotenv package
  /// - See: https://docs.flutter.dev/deployment/obfuscate
  static const String? apiKey = null;
}

