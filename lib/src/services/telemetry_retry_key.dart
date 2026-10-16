/// Prefix of every telemetry retry entry in SharedPreferences.
const String telemetryRetryKeyPrefix = 'polyfence_analytics_retry_';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// 32-bit FNV-1a hash as 8 hex characters. Not cryptographic. Same
/// algorithm as the React Native bridge.
String _fnv1aHex(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash = (hash ^ unit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// The Idempotency-Key a queued telemetry entry must be retried with.
///
/// Entries are named `<prefix><ms>_<key>`, carrying the key their first
/// send used, so every retry dedupes against that send on the server.
/// Entries queued by older versions are named `<prefix><ms>`; their key was
/// not stored, so they get a key derived from the stored payload, and the
/// same entry always maps to the same key without rewriting storage. The
/// name is left out because it holds the time the session was queued, which
/// a hash of it would not hide. Two entries with identical payloads get the
/// same key, so if both arrive on the same UTC day the server keeps one. That
/// can undercount identical old sessions, such as empty ones sent while
/// tracking was off, which is accepted for a one-off drain of old entries.
String retryIdempotencyKey(String entryName, String payload) {
  final suffix = entryName.substring(telemetryRetryKeyPrefix.length);
  final sep = suffix.indexOf('_');
  if (sep != -1) {
    final key = suffix.substring(sep + 1);
    if (_uuidPattern.hasMatch(key)) return key;
  }
  return 'legacy-${_fnv1aHex(payload)}${_fnv1aHex('legacy:$payload')}';
}
