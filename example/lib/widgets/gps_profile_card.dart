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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        children: [
          // All content in one padded container (no header border)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                const Row(
                  children: [
                    Icon(LucideIcons.settings,
                        size: 20, color: AppTheme.mutedForeground),
                    SizedBox(width: 8),
                    Text(
                      'GPS Profile',
                      style: TextStyle(
                        fontSize: 16, // text-base (match Tracking Active)
                        fontWeight: FontWeight.w500, // font-medium
                        color: AppTheme.foreground, // text-gray-900
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description Text
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    color: Color(0xFF4B5563), // text-gray-600
                  ),
                ),
                const SizedBox(height: 12),

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
                fontSize: 12, // text-xs
                fontWeight: FontWeight.w500, // font-medium
                color: isActive
                    ? AppTheme.primaryForeground // text-white
                    : const Color(0xFF374151), // text-gray-700
              ),
            ),
          ],
        ),
      ),
    );
  }
}
