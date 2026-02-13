/// Utility functions for converting between Dart enums and platform channel formats
class EnumUtils {
  /// Convert Dart enum name to platform channel format (SCREAMING_SNAKE_CASE)
  ///
  /// Example: `maxAccuracy` → `MAX_ACCURACY`
  static String toChannelFormat(String dartEnumName) {
    final withSeparators = dartEnumName.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    return withSeparators.toUpperCase();
  }

  /// Convert platform channel format to Dart enum
  ///
  /// Example: `MAX_ACCURACY` → finds `maxAccuracy` in values
  ///
  /// Returns [fallback] if [channelValue] is null or doesn't match any value.
  static T fromChannelFormat<T extends Enum>(
    String? channelValue,
    List<T> values,
    T fallback,
  ) {
    if (channelValue == null) return fallback;

    final normalized =
        channelValue.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    for (final candidate in values) {
      final candidateNormalized =
          toChannelFormat(candidate.name).replaceAll('_', '');

      if (candidateNormalized == normalized) {
        return candidate;
      }
    }

    return fallback;
  }
}
