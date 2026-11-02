import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../studio/domain/models/vocal_identity_models.dart';
import '../../../studio/presentation/providers/vocal_identity_provider.dart';
import '../../../studio/presentation/views/studio_view.dart';

/// Card showcasing an artist's sovereign Bantu vocal archetype (Phase 30 REQ-PROF-VOICE-01..04).
/// Features real audio auditioning and direct 1-tap handoff to the Create Studio.
class ArtistVoiceShowcaseCard extends ConsumerWidget {
  final String artistName;
  final String? vocalArchetypeTitle;
  final String? vocalArchetypeLanguage;
  final String? vocalSampleUrl;

  const ArtistVoiceShowcaseCard({
    super.key,
    required this.artistName,
    this.vocalArchetypeTitle,
    this.vocalArchetypeLanguage,
    this.vocalSampleUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocalState = ref.watch(vocalIdentityProvider);

    // Resolve matching archetype from catalog or default
    final queryName = (vocalArchetypeTitle ?? artistName).toLowerCase();
    final archetype = vocalState.catalog.firstWhere(
      (arch) =>
          arch.name.toLowerCase().contains(queryName) ||
          queryName.contains(arch.name.toLowerCase()) ||
          arch.nativeLanguage.toLowerCase() == (vocalArchetypeLanguage ?? '').toLowerCase(),
      orElse: () => vocalState.activeArchetype,
    );

    final isPreviewing = vocalState.previewingArchetypeId == archetype.id;

    return Container(
      key: const Key('artist_voice_showcase_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isPreviewing ? AppColors.brandPrimary : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎙️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Sovereign Vocal Identity',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Text(
                  'Zero-Shot AI Clone',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Vocal Archetype Details Row
          Row(
            children: [
              // Avatar Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppGradients.forGenre('Amapiano'),
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: Center(
                  child: Text(
                    archetype.gender == VocalGender.female ? '👸' : '🤴',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archetype.name,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${archetype.nativeLanguage} • ${archetype.deliveryStyle.label}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      archetype.accentDescription,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Interactive Action Buttons
          Row(
            children: [
              // Audition Preview Button (44dp touch area)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: OutlinedButton.icon(
                  key: const Key('voice_audition_btn'),
                  onPressed: () {
                    ref
                        .read(vocalIdentityProvider.notifier)
                        .togglePreviewArchetype(archetype.id);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isPreviewing ? AppColors.brandPrimary : AppColors.borderSubtle,
                    ),
                    foregroundColor:
                        isPreviewing ? AppColors.brandPrimary : AppColors.textPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: Icon(
                    isPreviewing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isPreviewing ? 'Stop' : 'Audition',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Primary Studio Remix CTA Button
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: ElevatedButton.icon(
                    key: const Key('voice_remix_studio_btn'),
                    onPressed: () {
                      ref
                          .read(vocalIdentityProvider.notifier)
                          .selectArchetype(archetype);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StudioView()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Selected ${archetype.name} for Studio synthesis! 🎤',
                          ),
                          backgroundColor: AppColors.brandPrimary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(
                      Icons.mic_rounded,
                      size: 18,
                      color: AppColors.brandContrast,
                    ),
                    label: const Text(
                      'Remix in Studio',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.brandContrast,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

