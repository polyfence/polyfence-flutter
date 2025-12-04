/// Application configuration for Polyfence example app
class AppConfig {
  /// Enable demo mode to use hardcoded demo zones instead of API
  static const bool demoMode = true;

  /// API key for zone admin API (only used when demoMode = false)
  /// 
  /// ⚠️ **TEST/DEMO KEY ONLY** - This is a test API key for example app demonstration.
  /// Do NOT use this key in production applications.
  /// 
  /// For production use:
  /// 1. Get your own API key from https://polyfence.io/signup
  /// 2. Store it securely (environment variables, secure storage)
  /// 3. Never commit production keys to version control
  static const String apiKey = 'cu-5lmLLJE7lQLPBkd7JPR3SPgDI9D3PfR3j2StsdX8';
}

