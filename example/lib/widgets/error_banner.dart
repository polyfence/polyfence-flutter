import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/compact_icon_button.dart';

/// Collapsible error banner.
///
/// Rendered by the host when its visibility flag is on. Shows a count
/// header with optional "Clear All" and close actions, then up to 2 red
/// error cards, then a "+N more" footer if there are additional errors.
class ErrorBanner extends StatelessWidget {
  final List<GeofenceEvent> errors;
  final Function(String) onDismiss;
  final VoidCallback? onClearAll;
  final VoidCallback? onClose;

  const ErrorBanner({
    super.key,
    required this.errors,
    required this.onDismiss,
    this.onClearAll,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final displayErrors = errors.take(2).toList();
    final hasMore = errors.length > 2;
    final extra = errors.length - 2;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Count header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${errors.length} Error${errors.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.destructiveHover,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onClearAll != null)
                    TextButton(
                      onPressed: onClearAll,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.destructiveHover,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (onClose != null)
                    CompactIconButton(
                      icon: LucideIcons.x,
                      iconSize: 16,
                      color: AppTheme.mutedForeground,
                      onPressed: onClose,
                      tooltip: 'Hide errors',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ...displayErrors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: _ErrorCard(
                  error: error,
                  onDismiss: onDismiss,
                ),
              )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: Text(
                  '+$extra more error${extra != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.destructiveHover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final GeofenceEvent error;
  final Function(String) onDismiss;

  const _ErrorCard({
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.destructive,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.alertTriangle,
              size: 16,
              color: AppTheme.destructiveForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.destructiveForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.message ?? error.zoneName,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.destructiveForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          CompactIconButton(
            icon: LucideIcons.x,
            iconSize: 14,
            color: AppTheme.destructiveForeground,
            onPressed: () => onDismiss(error.id),
            tooltip: 'Dismiss error',
          ),
        ],
      ),
    );
  }
}
