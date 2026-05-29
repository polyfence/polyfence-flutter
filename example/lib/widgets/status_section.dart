import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/poly_card.dart';

class StatusSection extends StatefulWidget {
  final bool isTracking;
  final LatLng? location;
  final double? accuracy;
  final double speed;
  final String activity;
  final GpsProfile gpsProfile;
  final String? locationStatus;

  const StatusSection({
    super.key,
    required this.isTracking,
    this.location,
    required this.accuracy,
    required this.speed,
    this.activity = 'unknown',
    required this.gpsProfile,
    this.locationStatus,
  });

  @override
  State<StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<StatusSection> {
  // Activity label — emoji-prefixed per the ratified UX spec. The repo's
  // "no emojis" CI guard scopes to the plugin's lib/, android/src/, and
  // ios/Classes/ — example/lib/ is intentionally not covered, and these
  // activity glyphs are part of the example's surface design.
  String _formatActivity(String activity) {
    switch (activity.toLowerCase()) {
      case 'still':
        return '🧍 Still';
      case 'walking':
        return '🚶 Walking';
      case 'running':
        return '🏃 Running';
      case 'cycling':
        return '🚴 Cycling';
      case 'driving':
        return '🚗 Driving';
      default:
        return '❓ Unknown';
    }
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
    return PolyCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking Status Indicator
          Row(
            children: [
              _PulsingDot(
                isActive: widget.isTracking,
                color: widget.isTracking ? AppTheme.success : AppTheme.textTertiary,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                widget.isTracking ? 'Tracking Active' : 'Tracking Stopped',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Coordinates block
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Position',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.mutedForeground,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: widget.location != null
                        ? Text(
                            widget.location!.toFormattedString(),
                            // Space Grotesk + tabular figures gives stable
                            // digit widths so coords don't jitter as values
                            // update — without forcing a font switch.
                            style: AppTheme.brandTextStyle(
                              fontSize: 14,
                              color: AppTheme.foreground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            widget.locationStatus ?? 'Waiting for GPS...',
                            style: AppTheme.brandTextStyle(
                              fontSize: 14,
                              color: AppTheme.foreground,
                            ),
                          ),
                  ),
                  if (widget.location != null) ...[
                    const SizedBox(width: AppTheme.spacingSm),
                    InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                      child: const Padding(
                        padding: EdgeInsets.all(AppTheme.spacingXs),
                        child: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Metrics Grid - 2x2 layout
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Accuracy',
                  value: widget.isTracking && widget.accuracy != null
                      ? '±${widget.accuracy!.round()}m'
                      : '—',
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Speed',
                  value: widget.isTracking
                      ? '${widget.speed.toStringAsFixed(1)} km/h'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Activity',
                  value: widget.isTracking
                      ? _formatActivity(widget.activity)
                      : '—',
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Updates',
                  value: widget.isTracking
                      ? widget.gpsProfile.intervalText
                      : '—',
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

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

