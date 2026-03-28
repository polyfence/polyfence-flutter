import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/polyfence_service.dart';
import '../models/health_score.dart';
import '../debug/polyfence_debug_info.dart';

/// Debug overlay showing real-time Polyfence health and performance metrics.
///
/// Only renders in debug builds (`kDebugMode`). In release builds, renders
/// an empty SizedBox.
///
/// Place this anywhere in your widget tree — it uses an [Overlay] to float
/// above other content. Drag to reposition.
///
/// ```dart
/// // In your app's main screen:
/// Stack(
///   children: [
///     MyAppContent(),
///     PolyfenceDebugOverlay(),
///   ],
/// )
/// ```
class PolyfenceDebugOverlay extends StatefulWidget {
  /// Initial position offset from top-left.
  final Offset initialPosition;

  const PolyfenceDebugOverlay({
    super.key,
    this.initialPosition = const Offset(16, 80),
  });

  @override
  State<PolyfenceDebugOverlay> createState() => _PolyfenceDebugOverlayState();
}

class _PolyfenceDebugOverlayState extends State<PolyfenceDebugOverlay> {
  HealthScore? _healthScore;
  PolyfenceDebugInfo? _debugInfo;
  StreamSubscription<HealthScore>? _healthSub;
  Timer? _refreshTimer;
  late Offset _position;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    if (!kDebugMode) return;

    // Listen to health score stream
    _healthSub = PolyfenceService.instance.healthScoreStream.listen((score) {
      if (mounted) setState(() => _healthScore = score);
    });

    // Refresh debug info every 10 seconds
    _fetchDebugInfo();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchDebugInfo(),
    );
  }

  Future<void> _fetchDebugInfo() async {
    try {
      final info = await PolyfenceService.instance.debugInfo();
      if (mounted) setState(() => _debugInfo = info);
    } catch (_) {
      // Non-fatal
    }
  }

  @override
  void dispose() {
    _healthSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onDoubleTap: () {
          setState(() => _collapsed = !_collapsed);
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.85),
          child: _collapsed ? _buildCollapsed() : _buildExpanded(),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    final score = _healthScore?.score ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scoreCircle(score, size: 24),
          const SizedBox(width: 8),
          Text(
            'PF $score',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded() {
    final score = _healthScore?.score ?? 0;
    final info = _debugInfo;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _scoreCircle(score, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health: $score/100',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (_healthScore?.topIssue != null)
                      Text(
                        _healthScore!.topIssue!,
                        style: TextStyle(color: _scoreColor(score), fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (info != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            _metricRow('Tracking', info.performance.uptime > Duration.zero ? 'Active' : 'Stopped'),
            _metricRow('Zones', '${info.zones.activeZones}'),
            _metricRow('Events', '${info.performance.totalZoneDetections}'),
            _metricRow('GPS', '${info.systemStatus.lastKnownAccuracy.toStringAsFixed(0)}m'),
            _metricRow('Version', info.systemStatus.pluginVersion),
          ],
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Double-tap to minimize',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCircle(int score, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _scoreColor(score).withValues(alpha: 0.2),
        border: Border.all(color: _scoreColor(score), width: 2),
      ),
      child: Center(
        child: Text(
          '$score',
          style: TextStyle(
            color: _scoreColor(score),
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
