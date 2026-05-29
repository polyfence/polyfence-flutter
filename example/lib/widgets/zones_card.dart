import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/count_badge.dart';
import 'common/poly_card.dart';

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
    return PolyCard(
      child: Column(
        children: [
          // Expandable Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                    LucideIcons.mapPin,
                    size: 20,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  const Text(
                    'Zones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
                      height: 1.1,
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    tooltip: 'Reload zones from the Polyfence API',
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
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
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                    ),
                    child: Column(
                      children: widget.zones.asMap().entries.map((entry) {
                        final index = entry.key;
                        final zone = entry.value;
                        final isLast = index == widget.zones.length - 1;
                        return _ZoneListItem(zone: zone, isLast: isLast);
                      }).toList(),
                    ),
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
        bgColor: AppTheme.primary,
        textColor: Colors.white,
      );
    }
    if (distance < 500) {
      return (
        label: 'Near',
        bgColor: AppTheme.secondary,
        textColor: AppTheme.secondaryForeground,
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
          vertical: AppTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.borderMuted)),
        ),
        child: Row(
          children: [
            // 32×32 rounded square with pastel zone-type fill.
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
                    : LucideIcons.octagon,
                size: 20,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        zone.type == ZoneType.circle ? 'Circle' : 'Polygon',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                      if (zone.distance != null) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.mutedForeground),
                        ),
                        Text(
                          '${_formatDistance(zone.distance)} away',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedForeground,
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
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: status.bgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXl3),
      child: Column(
        children: [
          Text(
            'No zones loaded',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Create zones in the Polyfence dashboard, then tap refresh',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
          ),
        ],
      ),
    );
  }
}
