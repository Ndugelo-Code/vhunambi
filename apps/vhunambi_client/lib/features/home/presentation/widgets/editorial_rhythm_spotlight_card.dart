import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/home/domain/models/african_rhythm_matrix.dart';

/// Zone 5: Editorial Daily Rhythm Spotlight over scrimmed bundled African artwork
/// (`REQ-P68-SPOT-01`). Guarantees high contrast in both Light and Dark themes.
class EditorialRhythmSpotlightCard extends StatelessWidget {
  final AfricanRhythmSpotlight spotlight;
  final VoidCallback onTryRhythm;

  const EditorialRhythmSpotlightCard({
    super.key,
    required this.spotlight,
    required this.onTryRhythm,
  });

  @override
  Widget build(BuildContext context) {
    final bgAsset = AppAssets.resolveGenreCoverAsset(
      spotlight.genre,
      seedId: spotlight.dayName,
    );

    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.darkSurfaceElevated,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const <double>[0.0, 0.55, 1.0],
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.48),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.compass,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DAILY RHYTHM SPOTLIGHT • ${spotlight.dayName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badge.copyWith(
                          color: AppColors.brandPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '${spotlight.bpm} BPM',
                        style: AppTypography.badge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${spotlight.title} (${spotlight.bpm} BPM • ${spotlight.musicalKey})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spotlight.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton.icon(
                    key: const Key('home_try_rhythm_btn'),
                    onPressed: onTryRhythm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsFill.sparkle,
                      size: 15,
                      color: AppColors.brandContrast,
                    ),
                    label: Text(
                      'Try Rhythm',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
