import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/bantu_voice_profile.dart';
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

    return Container(
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
              const Icon(Icons.graphic_eq_rounded,
                  color: AppColors.coinGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bantu Voice LoRA Engine',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.coinGold.withAlpha(40),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.coinGold.withAlpha(90)),
                ),
                child: Text('5 Native Dialects',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Phase 26: 24-Voice Regional Catalog & Zero-Shot Voice Cloning Actions
          Container(
            key: const Key('active_vocal_identity_badge'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                Text(
                  'Vocal Identity: ${vocalIdentity.activeVoiceDisplayLabel}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    TextButton.icon(
                      key: const Key('open_vocal_identity_catalog_btn'),
                      onPressed: () => VocalIdentityPickerSheet.show(context),
                      icon: const Icon(
                        Icons.library_music_rounded,
                        size: 15,
                        color: AppColors.coinGold,
                      ),
                      label: Text(
                        '24 Regional Voices',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.coinGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('open_voice_clone_recorder_btn'),
                      onPressed: () => VoiceCloneRecorderSheet.show(
                        context,
                        lyrics: state.customLyrics,
                        language: state.language,
                      ),
                      icon: const Icon(
                        Icons.mic_external_on_rounded,
                        size: 15,
                        color: AppColors.brandPrimary,
                      ),
                      label: Text(
                        'Clone My Voice',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
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

          // Dialect inflection sliders
          _DialectSlider(
            label: 'Syllable Stretch',
            subtitle: 'Penultimate vowel elongation',
            value: inflection.vowelElongation,
            onChanged: (v) => ref
                .read(studioFormProvider.notifier)
                .updateDialectInflection(
                    inflection.copyWith(vowelElongation: v)),
          ),
          _DialectSlider(
            label: 'Ancestral Vibrato',
            subtitle: 'Chest cavity resonance depth',
            value: inflection.vibratoDepth,
            onChanged: (v) => ref
                .read(studioFormProvider.notifier)
                .updateDialectInflection(inflection.copyWith(vibratoDepth: v)),
          ),
          _DialectSlider(
            label: 'Call-and-Response',
            subtitle: 'Choir backing intensity',
            value: inflection.callAndResponseIntensity,
            onChanged: (v) => ref
                .read(studioFormProvider.notifier)
                .updateDialectInflection(
                    inflection.copyWith(callAndResponseIntensity: v)),
          ),
          _DialectSlider(
            label: 'Cultural Ad-Libs',
            subtitle: 'Spontaneous interjection frequency',
            value: inflection.adLibFrequency,
            onChanged: (v) => ref
                .read(studioFormProvider.notifier)
                .updateDialectInflection(
                    inflection.copyWith(adLibFrequency: v)),
          ),
        ],
      ),
    );
  }
}

class _TimbreCard extends StatelessWidget {
  final BantuVoiceProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  const _TimbreCard(
      {required this.profile, required this.isActive, required this.onTap});

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
                        color: AppColors.coinGold, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(profile.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(profile.language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
            Text(profile.region,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
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
              child: Text(profile.iconEmoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ),
      );
    }
    return Text(profile.iconEmoji, style: const TextStyle(fontSize: 20));
  }
}

class _DialectSlider extends StatelessWidget {
  final String label;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;
  const _DialectSlider({
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
                child: Text(label,
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              Text('${(value * 100).round()}%',
                  style: AppTypography.caption.copyWith(color: AppColors.coinGold)),
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
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(subtitle,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}
