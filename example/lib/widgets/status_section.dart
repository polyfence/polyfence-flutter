import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class StatusSection extends StatefulWidget {
  final bool isTracking;
  final LatLng? location;
  final double? accuracy;
  final double speed;
  final GpsProfile gpsProfile;
  final String? locationStatus;

  const StatusSection({
    super.key,
    required this.isTracking,
    this.location,
    required this.accuracy,
    required this.speed,
    required this.gpsProfile,
    this.locationStatus,
  });

  @override
  State<StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<StatusSection> {
  Color _getAccuracyColor() {
    if (widget.accuracy == null) return AppTheme.muted;
    if (widget.accuracy! < 20) return AppTheme.success;
    if (widget.accuracy! < 50) return AppTheme.warning;
    return AppTheme.error;
  }

  Future<void> _copyToClipboard() async {
    if (widget.location == null) return;

    await Clipboard.setData(
      ClipboardData(text: widget.location!.toFormattedString()),
    );
    
    // Show visual feedback on iOS only (Android has system feedback)
    if (mounted && Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Coordinates copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4FF), // Light purple tint inspired by brand
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking Status Indicator
          Row(
            children: [
              _PulsingDot(
                isActive: widget.isTracking,
                color: widget.isTracking ? AppTheme.success : AppTheme.muted,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                widget.isTracking ? 'Tracking Active' : 'Tracking Stopped',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Coordinates - Copyable
          InkWell(
            onTap: widget.location != null ? _copyToClipboard : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Position',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.mutedForeground,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: widget.location != null
                            ? Text(
                                widget.location!.toFormattedString(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              )
                            : Text(
                                widget.locationStatus ?? 'Waiting for GPS...',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  color: AppTheme.mutedForeground,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                      ),
                      if (widget.location != null)
                        const Icon(
                          LucideIcons.copy,
                          size: 16,
                          color: AppTheme.mutedForeground,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Metrics Grid
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Accuracy',
                  value: widget.accuracy != null
                      ? '±${widget.accuracy!.round()}m'
                      : '—',
                  dotColor: _getAccuracyColor(),
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'km/h',
                  value: widget.speed.toStringAsFixed(1),
                  dotColor: widget.speed > 0 ? AppTheme.info : AppTheme.muted,
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Updates',
                  value: widget.gpsProfile.intervalText,
                  dotColor: widget.isTracking
                      ? AppTheme.mutedForeground
                      : AppTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool isActive;
  final Color color;

  const _PulsingDot({
    required this.isActive,
    required this.color,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.mutedForeground,
              ),
        ),
      ],
    );
  }
}
