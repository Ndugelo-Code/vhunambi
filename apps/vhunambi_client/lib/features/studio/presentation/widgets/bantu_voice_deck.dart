import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/bantu_voice_profile.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';
import '../providers/vocal_identity_provider.dart';
import 'vocal_identity_picker_sheet.dart';
import 'voice_clone_recorder_sheet.dart';

/// Bantu Voice LoRA synthesis cockpit (REQ-VOX-01 / REQ-VOX-02 / Phase 26 REQ-VOC-01..15).
///
/// Lets creators pick one of 5 native African voice timbres, browse the 24-voice
/// Regional African Catalog, or record a 3-line Zero-Shot Phonetic Voice Clone,
/// and fine-tune the dialect inflection before generation.
class BantuVoiceDeck extends ConsumerWidget {
  const BantuVoiceDeck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioFormProvider);
    final vocalIdentity = ref.watch(vocalIdentityProvider);
    final selected = state.selectedVoiceProfile;
    final inflection = state.dialectInflection;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formNotifier = ref.read(studioFormProvider.notifier);

    return Container(
      key: const Key('bantu_voice_deck'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.coinGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bantu Voice LoRA Engine',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coinGold.withAlpha(40),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.coinGold.withAlpha(90)),
                ),
                child: Text(
                  '5 Native Dialects',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.coinGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Unified Vocal Ensemble, Gender & Energy Segmented Header Card (REQ-P56-VOICE-01)
          Container(
            key: const Key('voice_ensemble_header_card'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.55)
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
              ),
            ),
            child: Column(
              children: [
                _buildCompactSegmentRow<VocalVoices>(
                  label: 'Voices',
                  items: VocalVoices.values,
                  selected: state.vocalVoices,
                  labelBuilder: (v) => v.label,
                  keyPrefix: 'voice_config',
                  onSelect: formNotifier.setVocalVoices,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildCompactSegmentRow<VocalGender>(
                  label: 'Gender',
                  items: VocalGender.values,
                  selected: state.vocalGender,
                  labelBuilder: (g) => g.label,
                  keyPrefix: 'voice_gender',
                  onSelect: formNotifier.setVocalGender,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildCompactSegmentRow<VocalEnergy>(
                  label: 'Energy',
                  items: VocalEnergy.values,
                  selected: state.vocalEnergy,
                  labelBuilder: (e) => e.label,
                  keyPrefix: 'voice_energy',
                  onSelect: formNotifier.setVocalEnergy,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Phase 26: 24-Voice Regional Catalog & Zero-Shot Voice Cloning Actions (Compact 2-Column Row)
          Container(
            key: const Key('active_vocal_identity_badge'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vocal Identity: ${vocalIdentity.activeVoiceDisplayLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('open_vocal_identity_catalog_btn'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(
                            color: AppColors.coinGold.withAlpha(110),
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.buttonBorder,
                          ),
                        ),
                        onPressed: () => VocalIdentityPickerSheet.show(context),
                        icon: const Icon(
                          Icons.library_music_rounded,
                          size: 14,
                          color: AppColors.coinGold,
                        ),
                        label: Text(
                          '24 Regional Voices',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('open_voice_clone_recorder_btn'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(
                            color: AppColors.brandPrimary.withAlpha(110),
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.buttonBorder,
                          ),
                        ),
                        onPressed: () => VoiceCloneRecorderSheet.show(
                          context,
                          lyrics: state.customLyrics,
                          language: state.language,
                        ),
                        icon: const Icon(
                          Icons.mic_external_on_rounded,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                        label: Text(
                          'Clone My Voice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Timbre profile selector
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kBantuVoiceProfiles.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final profile = kBantuVoiceProfiles[i];
                return _TimbreCard(
                  profile: profile,
                  isActive: profile.id == selected.id,
                  onTap: () => ref
                      .read(studioFormProvider.notifier)
                      .setBantuVoiceProfile(profile),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2x2 Compact Dialect Inflection Sliders Grid (REQ-P56-VOICE-02)
          Container(
            key: const Key('voice_dialect_grid_card'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.45)
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 260;
                final cellWidth = isTwoCol
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _DialectSlider(
                        sliderKey: const Key('dialect_slider_syllable_stretch'),
                        label: 'Syllable Stretch',
                        subtitle: 'Penultimate vowel elongation',
                        value: inflection.vowelElongation,
                        onChanged: (v) => ref
                            .read(studioFormProvider.notifier)
                            .updateDialectInflection(
                              inflection.copyWith(vowelElongation: v),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _DialectSlider(
                        sliderKey: const Key('dialect_slider_vibrato'),
                        label: 'Ancestral Vibrato',
                        subtitle: 'Chest cavity resonance depth',
                        value: inflection.vibratoDepth,
                        onChanged: (v) => ref
                            .read(studioFormProvider.notifier)
                            .updateDialectInflection(
                              inflection.copyWith(vibratoDepth: v),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _DialectSlider(
                        sliderKey: const Key('dialect_slider_call_response'),
                        label: 'Call-and-Response',
                        subtitle: 'Choir backing intensity',
                        value: inflection.callAndResponseIntensity,
                        onChanged: (v) => ref
                            .read(studioFormProvider.notifier)
                            .updateDialectInflection(
                              inflection.copyWith(callAndResponseIntensity: v),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _DialectSlider(
                        sliderKey: const Key('dialect_slider_ad_libs'),
                        label: 'Cultural Ad-Libs',
                        subtitle: 'Spontaneous interjection frequency',
                        value: inflection.adLibFrequency,
                        onChanged: (v) => ref
                            .read(studioFormProvider.notifier)
                            .updateDialectInflection(
                              inflection.copyWith(adLibFrequency: v),
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSegmentRow<T extends Enum>({
    required String label,
    required List<T> items,
    required T selected,
    required String Function(T) labelBuilder,
    required String keyPrefix,
    required ValueChanged<T> onSelect,
    required bool isDark,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    key: Key('${keyPrefix}_${items[i].name}'),
                    onTap: () => onSelect(items[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: items[i] == selected
                            ? AppColors.brandPrimary
                            : (isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.surfaceElevated),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: items[i] == selected
                              ? AppColors.brandPrimary
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.borderSubtle),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          labelBuilder(items[i]),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: items[i] == selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: items[i] == selected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimbreCard extends StatelessWidget {
  final BantuVoiceProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  const _TimbreCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('timbre_${profile.id}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceSecondary : AppColors.surfaceModal,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color: isActive ? AppColors.coinGold : AppColors.borderSubtle,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.coinGold.withAlpha(70),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTimbreAvatar(profile),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LoRA ${profile.loraScale.toStringAsFixed(2)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coinGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              profile.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              profile.language,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              profile.region,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimbreAvatar(BantuVoiceProfile profile) {
    final asset = profile.assetPath ?? AppAssets.voiceTimbreForId(profile.id);
    if (asset != null) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.coinGold : AppColors.borderSubtle,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            asset,
            width: 26,
            height: 26,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                profile.iconEmoji,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }
    return Text(profile.iconEmoji, style: const TextStyle(fontSize: 20));
  }
}

class _DialectSlider extends StatelessWidget {
  final Key? sliderKey;
  final String label;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;
  const _DialectSlider({
    this.sliderKey,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.coinGold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: AppColors.surfaceSecondary,
              thumbColor: AppColors.coinGold,
              overlayColor: AppColors.coinGold.withAlpha(40),
              trackHeight: 4,
            ),
            child: Slider(
              key: sliderKey,
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
