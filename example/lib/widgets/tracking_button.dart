import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrackingButton extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onPressed;

  const TrackingButton({
    super.key,
    required this.isTracking,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isTracking ? AppTheme.destructive : AppTheme.primary,
                foregroundColor: AppTheme.primaryForeground,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24), // rounded-full (pill)
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TrackingDot(isTracking: isTracking),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    isTracking ? 'Stop Tracking' : 'Start Tracking',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingDot extends StatefulWidget {
  final bool isTracking;

  const _TrackingDot({required this.isTracking});

  @override
  State<_TrackingDot> createState() => _TrackingDotState();
}

class _TrackingDotState extends State<_TrackingDot>
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

    if (widget.isTracking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TrackingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking && !oldWidget.isTracking) {
      _controller.repeat(reverse: true);
    } else if (!widget.isTracking && oldWidget.isTracking) {
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
    return widget.isTracking
        ? FadeTransition(
            opacity: _animation,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          )
        : Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );
  }
}
