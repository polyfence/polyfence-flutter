import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'analytics_service.dart';

/// Manages app lifecycle events for analytics session tracking.
///
/// Automatically starts and ends analytics sessions when the app transitions
/// between foreground and background states. Initialized internally by
/// [PolyfenceService] during plugin initialization.
class AppLifecycleManager {
  static AppLifecycleManager? _instance;

  /// Gets the singleton instance.
  static AppLifecycleManager get instance =>
      _instance ??= AppLifecycleManager._();
  AppLifecycleManager._();

  bool _isInitialized = false;
  AppLifecycleState? _currentState;

  /// Starts listening to app lifecycle changes.
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _currentState = AppLifecycleState.resumed;

    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == null) return null;

      final state = _parseLifecycleState(message);
      if (state != null && state != _currentState) {
        _handleLifecycleChange(state);
        _currentState = state;
      }

      return null;
    });
  }

  AppLifecycleState? _parseLifecycleState(String message) {
    switch (message) {
      case 'AppLifecycleState.paused':
        return AppLifecycleState.paused;
      case 'AppLifecycleState.resumed':
        return AppLifecycleState.resumed;
      case 'AppLifecycleState.inactive':
        return AppLifecycleState.inactive;
      case 'AppLifecycleState.detached':
        return AppLifecycleState.detached;
      case 'AppLifecycleState.hidden':
        return AppLifecycleState.hidden;
      default:
        return null;
    }
  }

  void _handleLifecycleChange(AppLifecycleState newState) {
    switch (newState) {
      case AppLifecycleState.resumed:
        PolyfenceAnalytics.instance.startSession();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        PolyfenceAnalytics.instance.endSession();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Manually starts an analytics session.
  void startSession() {
    PolyfenceAnalytics.instance.startSession();
  }

  /// Manually ends the current analytics session.
  void endSession() {
    PolyfenceAnalytics.instance.endSession();
  }

  /// Disposes the lifecycle manager and removes the message handler.
  void dispose() {
    if (!_isInitialized) return;

    SystemChannels.lifecycle.setMessageHandler(null);

    _isInitialized = false;
    _currentState = null;
  }
}
