import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/count_badge.dart';

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

    // Format as "Jan 24"
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        children: [
          // Expandable Header (same pattern as ZonesCard)
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: 10, // py-2.5: 10+24+10 = 44px touch target
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
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  CountBadge(count: widget.events.length),
                  const Spacer(),
                  if (widget.events.isNotEmpty)
                    IconButton(
                      onPressed: widget.onClear,
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      tooltip: 'Clear all events',
                    ),
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

          // Content - Only visible when expanded
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
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Text(
        'No events recorded yet. Start tracking to see geofence entries and exits.',
        textAlign: TextAlign.center, // text-center
        style: TextStyle(
          fontSize: 14, // text-sm
          color: Color(0xFF6B7280), // text-gray-500
        ),
      ),
    );
  }

  Widget _buildGroupedEventList() {
    final grouped = _groupEventsByDate();
    final dateKeys = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dateKeys.asMap().entries.map((entry) {
          final dateKey = entry.value;
          final events = grouped[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 8,
                ),
                child: Text(
                  dateKey,
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w600, // font-semibold
                    color: Color(0xFF374151), // text-gray-700
                  ),
                ),
              ),
              // Events for this date
              ...events.map((event) => _buildEventItem(event)),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEventItem(GeofenceEvent event) {
    final isEnter = event.type == EventType.enter;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg, // 16px - consistent left edge with headers
        vertical: 10, // py-2.5
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circle with arrow icon (original style)
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
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF4B5563), // text-gray-600
                    fontFeatures: [FontFeature.tabularFigures()], // tabular-nums
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    color: Color(0xFF9CA3AF), // text-gray-400
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEnter ? 'ENTER' : 'EXIT',
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF374151), // text-gray-700
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    color: Color(0xFF9CA3AF), // text-gray-400
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.zoneName,
                    style: const TextStyle(
                      fontSize: 14, // text-sm
                      fontWeight: FontWeight.w500, // font-medium, matches zone list
                      color: AppTheme.foreground, // text-gray-900
                    ),
                    overflow: TextOverflow.ellipsis, // truncate
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
