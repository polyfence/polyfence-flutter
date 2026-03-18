import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'analytics_service.dart';

/// Manages app lifecycle events for analytics session tracking.
///
/// Triggers telemetry upload when the app transitions to background/detached.
/// Session aggregation is handled entirely by native polyfence-core (D016).
/// Initialized internally by [PolyfenceService] during plugin initialization.
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
        // Session lifecycle managed by native polyfence-core
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Trigger telemetry upload on background transition
        PolyfenceAnalytics.instance.endSession();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Disposes the lifecycle manager and removes the message handler.
  void dispose() {
    if (!_isInitialized) return;

    SystemChannels.lifecycle.setMessageHandler(null);

    _isInitialized = false;
    _currentState = null;
  }
}
