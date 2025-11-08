// App Lifecycle Manager for Analytics
// File: lib/src/services/app_lifecycle_manager.dart

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'analytics_service.dart';

class AppLifecycleManager {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance =>
      _instance ??= AppLifecycleManager._();
  AppLifecycleManager._();

  bool _isInitialized = false;
  AppLifecycleState? _currentState;

  // Initialize lifecycle management
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _currentState = AppLifecycleState.resumed;

    // Listen to app lifecycle changes
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

  // Parse lifecycle state from platform message
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

  // Handle lifecycle state changes
  void _handleLifecycleChange(AppLifecycleState newState) {
    switch (newState) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Don't end session for these states as they're temporary
        break;
    }
  }

  // App resumed - start new analytics session
  void _onAppResumed() {
    PolyfenceAnalytics.instance.startSession();
  }

  // App paused - end current analytics session
  void _onAppPaused() {
    PolyfenceAnalytics.instance.endSession();
  }

  // App detached - end current analytics session
  void _onAppDetached() {
    PolyfenceAnalytics.instance.endSession();
  }

  // Manual session management (for testing or special cases)
  void startSession() {
    PolyfenceAnalytics.instance.startSession();
  }

  void endSession() {
    PolyfenceAnalytics.instance.endSession();
  }
}
