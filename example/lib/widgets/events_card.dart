import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/compact_icon_button.dart';
import 'common/count_badge.dart';
import 'common/poly_card.dart';

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

  String _getDateGroup(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diffDays = today.difference(eventDay).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }

  Map<String, List<GeofenceEvent>> _groupEventsByDate() {
    final Map<String, List<GeofenceEvent>> grouped = {};
    for (final event in widget.events) {
      final dateKey = _getDateGroup(event.timestamp);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(event);
    }
    return grouped;
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
    return PolyCard(
      child: Column(
        children: [
          // Expandable Header
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                border: _isExpanded
                    ? const Border(bottom: BorderSide(color: AppTheme.border))
                    : null,
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.activity,
                    size: 20,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  const Text(
                    'Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  CountBadge(count: widget.events.length),
                  const Spacer(),
                  if (widget.events.isNotEmpty) ...[
                    CompactIconButton(
                      icon: LucideIcons.trash2,
                      iconSize: 16,
                      onPressed: widget.onClear,
                      tooltip: 'Clear all events',
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
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
            ),
          ),

          // Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: widget.events.isEmpty
                ? _buildEmptyState()
                : _buildGroupedEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXl3, horizontal: AppTheme.spacingLg),
      child: Text(
        'No events recorded yet. Start tracking to see geofence entries and exits.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildGroupedEventList() {
    final grouped = _groupEventsByDate();
    final dateKeys = grouped.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < dateKeys.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTheme.spacingLg),
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.spacingXs, right: AppTheme.spacingXs, bottom: AppTheme.spacingSm),
              child: Text(
                dateKeys[i],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            ...grouped[dateKeys[i]]!.map((event) => _buildEventItem(event)),
          ],
        ],
      ),
    );
  }

  ({IconData icon, Color iconColor, Color bgColor, Color? borderColor, String label})
      _eventStyle(EventType type) {
    switch (type) {
      case EventType.enter:
        return (
          icon: LucideIcons.arrowDown,
          iconColor: Colors.white,
          bgColor: AppTheme.success,
          borderColor: null,
          label: 'ENTER',
        );
      case EventType.dwell:
        return (
          icon: LucideIcons.clock,
          iconColor: Colors.white,
          bgColor: AppTheme.warning,
          borderColor: null,
          label: 'DWELL',
        );
      case EventType.exit:
        return (
          icon: LucideIcons.arrowUp,
          iconColor: AppTheme.error,
          bgColor: Colors.transparent,
          borderColor: AppTheme.error,
          label: 'EXIT',
        );
      case EventType.error:
        return (
          icon: LucideIcons.alertCircle,
          iconColor: Colors.white,
          bgColor: AppTheme.error,
          borderColor: null,
          label: 'ERROR',
        );
    }
  }

  Widget _buildEventItem(GeofenceEvent event) {
    final style = _eventStyle(event.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.bgColor,
              border: style.borderColor != null
                  ? Border.all(color: style.borderColor!, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              style.icon,
              size: 12,
              color: style.iconColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Row(
              children: [
                Text(
                  _formatTime(event.timestamp),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.mutedForeground,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  style.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    event.zoneName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
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
