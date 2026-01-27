import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/count_badge.dart';

class ZonesCard extends StatefulWidget {
  final List<Zone> zones;
  final bool isLoading;
  final VoidCallback onRefresh;

  const ZonesCard({
    super.key,
    required this.zones,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<ZonesCard> createState() => _ZonesCardState();
}

class _ZonesCardState extends State<ZonesCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ZonesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _rotationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
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
          // Expandable Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                    LucideIcons.mapPin,
                    size: 20,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  const Text(
                    'Zones',
                    style: TextStyle(
                      fontSize: 16, // text-base (match Tracking Active)
                      fontWeight: FontWeight.w500, // font-medium
                      color: AppTheme.foreground, // text-gray-900
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  CountBadge(count: widget.zones.length),
                  const Spacer(),
                  IconButton(
                    icon: RotationTransition(
                      turns: _rotationController,
                      child: const Icon(LucideIcons.refreshCcw, size: 16),
                    ),
                    onPressed: widget.onRefresh,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    tooltip: 'Reload zones from plugin API',
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

          // Content
          if (_isExpanded)
            widget.zones.isEmpty
                ? _EmptyZonesState()
                : Column(
                    children: widget.zones.asMap().entries.map((entry) {
                      final index = entry.key;
                      final zone = entry.value;
                      final isLast = index == widget.zones.length - 1;
                      return _ZoneListItem(zone: zone, isLast: isLast);
                    }).toList(),
                  ),
        ],
      ),
    );
  }
}

class _ZoneListItem extends StatelessWidget {
  final Zone zone;
  final bool isLast;

  const _ZoneListItem({required this.zone, this.isLast = false});

  String _formatDistance(double? distance) {
    if (distance == null) return '—';
    if (distance < 1000) return '${distance.round()}m';
    return '${(distance / 1000).toStringAsFixed(1)}km';
  }

  ({String label, Color bgColor, Color textColor})? _getZoneStatus(double? distance) {
    if (distance == null) return null;
    if (distance <= 50) {
      return (
        label: 'Inside',
        bgColor: AppTheme.primary, // #5B6FEE purple
        textColor: AppTheme.primaryForeground, // white
      );
    }
    if (distance < 500) {
      return (
        label: 'Near',
        bgColor: AppTheme.secondary, // #F0F0F3 light gray (original)
        textColor: AppTheme.secondaryForeground, // #030213 dark text (original)
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _getZoneStatus(zone.distance);

    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            // Type Icon (original: 32x32 with radiusLg)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: zone.type == ZoneType.circle
                    ? AppTheme.circleZoneBg
                    : AppTheme.polygonZoneBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(
                zone.type == ZoneType.circle
                    ? LucideIcons.circle
                    : LucideIcons.hexagon,
                size: 16,
                color: zone.type == ZoneType.circle
                    ? AppTheme.circleZoneIcon
                    : AppTheme.polygonZoneIcon,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),

            // Zone Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 14, // text-sm
                      fontWeight: FontWeight.w500, // font-medium
                      color: AppTheme.foreground, // text-gray-900
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        zone.type == ZoneType.circle ? 'Circle' : 'Polygon',
                        style: const TextStyle(
                          fontSize: 12, // text-xs
                          color: Color(0xFF6B7280), // text-gray-500
                        ),
                      ),
                      if (zone.distance != null) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(color: Color(0xFF6B7280)), // text-gray-500
                        ),
                        Text(
                          '${_formatDistance(zone.distance)} away',
                          style: const TextStyle(
                            fontSize: 12, // text-xs
                            color: Color(0xFF6B7280), // text-gray-500
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Right-aligned status pill
            if (status != null) ...[
              const SizedBox(width: AppTheme.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, // px-2
                  vertical: 2, // slight vertical padding for better pill shape
                ),
                decoration: BoxDecoration(
                  color: status.bgColor,
                  borderRadius: BorderRadius.circular(10), // rounded-full pill shape
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12, // text-xs
                    fontWeight: FontWeight.w500, // font-medium
                    color: status.textColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyZonesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'No zones loaded',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap refresh to load zones from plugin',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
          ),
        ],
      ),
    );
  }
}
