import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common/poly_card.dart';

class GpsProfileCard extends StatelessWidget {
  final GpsProfile currentProfile;
  final ValueChanged<GpsProfile> onProfileChange;

  const GpsProfileCard({
    super.key,
    required this.currentProfile,
    required this.onProfileChange,
  });

  @override
  Widget build(BuildContext context) {
    final description = currentProfile.description;
    return PolyCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.settings,
                        size: 20, color: AppTheme.mutedForeground),
                    SizedBox(width: AppTheme.spacingSm),
                    Text(
                      'GPS Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),

                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Profile Grid — 4 equal-width tiles.
                Row(
                  children: [
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.max,
                            isActive: currentProfile == GpsProfile.max,
                            onTap: () => onProfileChange(GpsProfile.max))),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.balanced,
                            isActive: currentProfile == GpsProfile.balanced,
                            onTap: () => onProfileChange(GpsProfile.balanced))),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.battery,
                            isActive: currentProfile == GpsProfile.battery,
                            onTap: () => onProfileChange(GpsProfile.battery))),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.smart,
                            isActive: currentProfile == GpsProfile.smart,
                            onTap: () => onProfileChange(GpsProfile.smart))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final GpsProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeFg = Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        // Tightened horizontal padding (8dp instead of 12dp) so "Balanced"
        // (8 chars) fits on narrow devices (Samsung ~360dp). Vertical
        // stays 12 so tile height is identical across breakpoints.
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : AppTheme.secondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: isActive ? AppTheme.cardShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              profile.icon,
              size: 20,
              color: isActive ? activeFg : AppTheme.foreground,
            ),
            const SizedBox(height: 6),
            Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? activeFg : AppTheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
