import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10), // radius-lg
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, // lg padding
              vertical: 12, // md padding
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.border),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.settings,
                    size: 20, color: AppTheme.mutedForeground),
                const SizedBox(width: 8), // sm gap
                Text(
                  'GPS Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 16, // text-base
                      ),
                ),
              ],
            ),
          ),

          // Body Container
          Padding(
            padding: const EdgeInsets.all(16), // lg padding
            child: Column(
              children: [
                // Description Text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14, // text-sm
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: 12), // md spacing

                // Profile Grid - 4 columns
                Row(
                  children: [
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.max,
                            isActive: currentProfile == GpsProfile.max,
                            onTap: () => onProfileChange(GpsProfile.max))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.balanced,
                            isActive: currentProfile == GpsProfile.balanced,
                            onTap: () => onProfileChange(GpsProfile.balanced))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _ProfileButton(
                            profile: GpsProfile.battery,
                            isActive: currentProfile == GpsProfile.battery,
                            onTap: () => onProfileChange(GpsProfile.battery))),
                    const SizedBox(width: 6),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10), // rounded-lg
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : AppTheme.secondary,
          borderRadius: BorderRadius.circular(10), // rounded-lg
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon (top)
            Icon(
              profile.icon,
              size: 20, // w-5 h-5
              color: isActive
                  ? AppTheme.primaryForeground
                  : AppTheme.secondaryForeground,
            ),
            const SizedBox(height: 6), // mb-1.5

            // Label (bottom)
            Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppTheme.primaryForeground
                    : AppTheme.secondaryForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
