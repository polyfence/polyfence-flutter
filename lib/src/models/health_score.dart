/// Health score emitted by polyfence-core every 5 minutes.
///
/// Score bands:
///   90-100  Excellent
///   70-89   Good
///   50-69   Fair — action recommended
///   0-49    Poor — significant issues
class HealthScore {
  /// Health score from 0 (worst) to 100 (best).
  final int score;

  /// Description of the most impactful issue, or null if score >= 90.
  final String? topIssue;

  /// Timestamp when this score was computed (milliseconds since epoch).
  final int timestamp;

  const HealthScore({
    required this.score,
    this.topIssue,
    required this.timestamp,
  });

  factory HealthScore.fromMap(Map<String, dynamic> map) {
    final topIssue = map['topIssue'] as String?;
    return HealthScore(
      score: (map['score'] as num?)?.toInt() ?? 0,
      topIssue: topIssue != null && topIssue.isNotEmpty ? topIssue : null,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'topIssue': topIssue,
        'timestamp': timestamp,
      };

  @override
  String toString() =>
      'HealthScore(score: $score, topIssue: $topIssue)';
}
