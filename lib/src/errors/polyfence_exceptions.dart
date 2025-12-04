/// Base exception for all Polyfence exceptions
abstract class PolyfenceException implements Exception {
  final String message;
  final String? code;

  PolyfenceException(this.message, {this.code});

  @override
  String toString() =>
      'PolyfenceException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Thrown when Polyfence is used before initialization
class PolyfenceNotInitializedException extends PolyfenceException {
  PolyfenceNotInitializedException([String? message])
      : super(
          message ??
              'Polyfence not initialized. Call Polyfence.instance.initialize() first.',
          code: 'NOT_INITIALIZED',
        );
}

/// Thrown when platform operation fails
class PlatformOperationException extends PolyfenceException {
  final String operation;

  PlatformOperationException(this.operation, String message)
      : super(
          'Platform operation "$operation" failed: $message',
          code: 'PLATFORM_ERROR',
        );
}
