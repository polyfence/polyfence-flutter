import 'package:flutter/material.dart';

/// 24×24 IconButton — used for in-card actions (close, refresh, clear)
/// where Material's default 40dp+ tap target would inflate the row.
///
/// Material's `IconButton` defaults to a 48dp tap target which is correct
/// for primary nav, but inside cards we want tight icons that hug the
/// header row. This widget centralises the override (zero padding, tight
/// 24×24 constraints, no minimum tap target) so every callsite renders
/// identically.
class CompactIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final String? tooltip;

  const CompactIconButton({
    super.key,
    required this.icon,
    this.iconSize = 16,
    this.color,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: iconSize, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      visualDensity: VisualDensity.compact,
    );
  }
}
