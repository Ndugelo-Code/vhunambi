import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/multi_stem_audio_provider.dart';
import '../../domain/models/stem_mastering_recipe.dart';
import '../providers/mastering_session_provider.dart';

/// Pocket Studio Mastering & Vocal Cleanse Modal Sheet (REQ-MST-UI-01, REQ-MST-UI-03).
///
/// Designed for mobile ergonomics: A/B bypass preview, regional preset selector,
/// Adobe-style vocal cleanse flavors, log-drum knock modes, and Tier B cloud bake.
class MobileQuickMasterSheet extends ConsumerWidget {
  final String? trackId;
  final String? trackTitle;
  final String? genre;

  const MobileQuickMasterSheet({
    super.key,
    this.trackId,
    this.trackTitle,
    this.genre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masteringSessionProvider);
    final notifier = ref.read(masteringSessionProvider.notifier);
    final hasRealStems =
        ref.watch(multiStemAudioEngineProvider).hasRealStems;

    return Container(
      key: const Key('mobile_quick_master_sheet'),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),

              // 2. Header Row
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.brandPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Studio Master Polisher',
                          style: AppTypography.titleLarge
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${state.trackTitle} • ${state.genre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // 3. Honest Master-Only Mode Notice (REQ-MST-AUD-04)
              if (!hasRealStems) ...[
                Container(
                  key: const Key('mastering_master_only_notice'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accentGold,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Full stem isolation engages upon Cloud Studio Bake. Auditioning macro log-drum knock & stereo bus.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // 4. A/B Bypass Audition Toggle (REQ-MST-AUD-03)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isMasteredPreviewActive
                              ? 'Mastered (Active)'
                              : 'Raw AI (Bypassed)',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: state.isMasteredPreviewActive
                                ? AppColors.brandPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Instant zero-latency preview comparison',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    Switch(
                      key: const Key('mastering_ab_toggle'),
                      value: state.isMasteredPreviewActive,
                      activeThumbColor: AppColors.brandPrimary,
                      onChanged: (_) {
                        HapticFeedback.selectionClick();
                        notifier.togglePreviewBypass();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 5. Genre Master Presets Rail (REQ-MST-DOM-02)
              Text(
                'Regional Studio Presets',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kGenreMasterPresets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final preset = kGenreMasterPresets[index];
                    final isSelected = state.recipe.presetId == preset.id;

                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: InkWell(
                        key: Key('mastering_preset_${preset.id}'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.applyPreset(preset.id);
                        },
                        borderRadius: AppRadius.pillBorder,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withValues(alpha: 0.16)
                                : AppColors.surfaceElevated,
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Text(
                            preset.name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 6. Character Flavors (4 Pillars) (REQ-MST-DOM-03)
              _buildFlavorSection(
                title: '🎙️ Vocal Cleanse (Adobe-Style)',
                options: VocalCleanseFlavor.values
                    .map((f) => _FlavorOption(
                          key: Key('vocal_flavor_${f.name}'),
                          label: f.label,
                          description: f.description,
                          isSelected: state.recipe.vocals.flavor == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setVocalFlavor(f);
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: AppSpacing.sm),

              _buildFlavorSection(
                title: '🪵 Log Drum & Sub Knock',
                options: BassCharacterFlavor.values
                    .map((f) => _FlavorOption(
                          key: Key('bass_flavor_${f.name}'),
                          label: f.label,
                          description: f.description,
                          isSelected: state.recipe.bass.flavor == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setBassFlavor(f);
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: AppSpacing.sm),

              _buildFlavorSection(
                title: '🥁 Drum Bus Snap & Punch',
                options: DrumCharacterFlavor.values
                    .map((f) => _FlavorOption(
                          key: Key('drum_flavor_${f.name}'),
                          label: f.label,
                          description: f.description,
                          isSelected: state.recipe.drums.flavor == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setDrumFlavor(f);
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: AppSpacing.sm),

              _buildFlavorSection(
                title: '🎹 Melodic Width & Vocal Pocket',
                options: MelodicCharacterFlavor.values
                    .map((f) => _FlavorOption(
                          key: Key('melodic_flavor_${f.name}'),
                          label: f.label,
                          description: f.description,
                          isSelected: state.recipe.melodic.flavor == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setMelodicFlavor(f);
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: AppSpacing.md),

              // 7. Loudness Target Selector (REQ-MST-DOM-01)
              Text(
                'Commercial Loudness Target',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: InkWell(
                        key: const Key('mastering_lufs_club'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setTargetLufs(-9.5);
                        },
                        borderRadius: AppRadius.cardBorder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: state.recipe.targetLufs == -9.5
                                ? AppColors.brandPrimary.withValues(alpha: 0.16)
                                : AppColors.surfaceElevated,
                            borderRadius: AppRadius.cardBorder,
                            border: Border.all(
                              color: state.recipe.targetLufs == -9.5
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '-9.5 LUFS Club Knock',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: state.recipe.targetLufs == -9.5
                                      ? AppColors.brandPrimary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Amapiano sound systems, TikTok & DJ sets',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: InkWell(
                        key: const Key('mastering_lufs_stream'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setTargetLufs(-14.0);
                        },
                        borderRadius: AppRadius.cardBorder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: state.recipe.targetLufs == -14.0
                                ? AppColors.brandPrimary.withValues(alpha: 0.16)
                                : AppColors.surfaceElevated,
                            borderRadius: AppRadius.cardBorder,
                            border: Border.all(
                              color: state.recipe.targetLufs == -14.0
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '-14.0 LUFS Streaming',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: state.recipe.targetLufs == -14.0
                                      ? AppColors.brandPrimary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Spotify, Apple Music & DSP standards',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 8. Primary Bake CTA (REQ-MST-API-01, REQ-MST-UI-03)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ElevatedButton.icon(
                  key: const Key('mastering_bake_btn'),
                  onPressed: state.isBaking
                      ? null
                      : () async {
                          HapticFeedback.heavyImpact();
                          final success = await notifier.bakeMaster();
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✨ Studio master baked successfully! WAV & MP3 ready.',
                                ),
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.inputBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: state.isBaking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandContrast,
                          ),
                        )
                      : const Icon(Icons.flash_on_rounded),
                  label: Text(
                    state.isBaking
                        ? 'Baking Studio Master on Cloud GPU…'
                        : state.hasBakedMaster
                            ? 'Re-Bake Studio Master (${state.recipe.targetLufs} LUFS)'
                            : 'Bake Studio Master (${state.recipe.targetLufs} LUFS)',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Baked Master Success Links
              if (state.hasBakedMaster) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Cloud Studio Master Ready (Lossless 24-bit WAV & 320k MP3)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlavorSection({
    required String title,
    required List<_FlavorOption> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options.map((opt) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: InkWell(
                key: opt.key,
                onTap: opt.onTap,
                borderRadius: AppRadius.cardBorder,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: opt.isSelected
                        ? AppColors.brandPrimary.withValues(alpha: 0.16)
                        : AppColors.surfaceElevated,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(
                      color: opt.isSelected
                          ? AppColors.brandPrimary
                          : AppColors.borderSubtle,
                      width: opt.isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        opt.label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: opt.isSelected
                              ? AppColors.brandPrimary
                              : AppColors.textPrimary,
                          fontWeight: opt.isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        opt.description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FlavorOption {
  final Key key;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _FlavorOption({
    required this.key,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });
}

