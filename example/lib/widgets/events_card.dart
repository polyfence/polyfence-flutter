import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class EventsCard extends StatefulWidget {
  final List<GeofenceEvent> events;
  final VoidCallback? onClear;
  final TrackingStatus? trackingStatus;

  const EventsCard({
    super.key,
    required this.events,
    this.onClear,
    this.trackingStatus,
  });

  @override
  State<EventsCard> createState() => _EventsCardState();
}

class _EventsCardState extends State<EventsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _expandController.forward();
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10), // radius-lg
      ),
      child: Column(
        children: [
          // Header - Tappable to expand/collapse
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, // lg padding
                vertical: 10, // tighter header
              ),
              constraints:
                  const BoxConstraints(minHeight: 44), // WCAG touch target
              decoration: BoxDecoration(
                border: _isExpanded
                    ? const Border(
                        bottom: BorderSide(color: AppTheme.border),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Left side: Icon + Title + Badge
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.zap,
                          size: 20,
                          color: AppTheme.mutedForeground,
                        ),
                        const SizedBox(width: 8), // sm gap
                        Text(
                          'Events',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(width: 8), // sm gap
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, // sm padding
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(6), // radius-sm
                          ),
                          child: Text(
                            '${widget.events.length}',
                            style: const TextStyle(
                              fontSize: 12, // text-xs
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side: Clear button + Expand/Collapse icon
                  Row(
                    children: [
                      if (widget.events.isNotEmpty) ...[
                        IconButton(
                          onPressed: widget.onClear,
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(width: 8), // sm gap
                      ],
                      Icon(
                        _isExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 20,
                        color: AppTheme.mutedForeground,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content - Only visible when expanded
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                // Event List
                widget.events.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          ...widget.events.asMap().entries.map((entry) {
                            final index = entry.key;
                            final event = entry.value;
                            final isLast = index == widget.events.length - 1;
                            return Column(
                              children: [
                                _buildEventItem(event),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    color: AppTheme.border,
                                  ),
                              ],
                            );
                          }),
                          // Add consistent bottom padding
                          const SizedBox(height: 16),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16), // lg padding
      child: Column(
        children: [
          const Text(
            'No events yet',
            style: TextStyle(
              fontSize: 14, // text-sm
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8), // sm gap
          Text(
            widget.trackingStatus == TrackingStatus.active
                ? 'Enter or exit a geofence to generate events'
                : 'Start tracking to monitor zone activity',
            style: const TextStyle(
              fontSize: 12, // text-xs
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(GeofenceEvent event) {
    final isEnter = event.type == EventType.enter;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, // lg padding
        vertical: 10, // py-2.5 equivalent
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnter ? AppTheme.success : Colors.transparent,
              border:
                  isEnter ? null : Border.all(color: AppTheme.error, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(
              isEnter ? LucideIcons.arrowDown : LucideIcons.arrowUp,
              size: 12,
              color: isEnter ? Colors.white : AppTheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  _formatTime(event.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: AppTheme.mutedForeground,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppTheme.mutedForeground)),
                const SizedBox(width: 8),
                Text(
                  isEnter ? 'ENTER' : 'EXIT',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppTheme.mutedForeground)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.zoneName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
