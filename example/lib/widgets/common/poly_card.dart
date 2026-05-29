import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Standard Polyfence dashboard card surface — white background, light
/// border, rounded corners. Used by every top-level dashboard widget
/// (StatusSection, GpsProfileCard, ZonesCard, EventsCard).
///
/// Centralises the Container + BoxDecoration that was duplicated 4× and
/// guarantees the card colour/border/radius stay in sync across surfaces.
/// Material `Card` is intentionally not used — its theme defaults (elevation,
/// surface tinting under MD3) don't match the flat Polyfence look.
class PolyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PolyCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: child,
    );
  }
}
