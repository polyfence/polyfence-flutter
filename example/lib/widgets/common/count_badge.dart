import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final int? totalCount;

  const CountBadge({
    super.key,
    required this.count,
    this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = totalCount != null ? '$count / $totalCount' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 12, // text-xs
          color: Color(0xFF4B5563), // text-gray-600
        ),
      ),
    );
  }
}
