import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  final List<GeofenceEvent> errors;
  final Function(String) onDismiss;

  const ErrorBanner({
    super.key,
    required this.errors,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final displayErrors = errors.take(2).toList();
    final hasMore = errors.length > 2;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingLg,
        right: AppTheme.spacingLg,
        bottom: AppTheme.spacingSm,
      ),
      child: Column(
        children: [
          ...displayErrors.map((error) => Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: _ErrorCard(
                  error: error,
                  onDismiss: onDismiss,
                ),
              )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSm),
              child: Text(
                '+${errors.length - 2} more errors',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.mutedForeground,
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
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.destructive,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 20,
            color: AppTheme.destructiveForeground,
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.destructiveForeground,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.message ?? error.zoneName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.destructiveForeground,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Container(
            constraints: const BoxConstraints.tightFor(
              width: 44,
              height: 44,
            ),
            child: IconButton(
              icon: const Icon(
                LucideIcons.x,
                size: 16,
                color: AppTheme.destructiveForeground,
              ),
              onPressed: () => onDismiss(error.id),
              tooltip: 'Dismiss error',
            ),
          ),
        ],
      ),
    );
  }
}
