import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/stem_mixer_state.dart';
import '../providers/stem_mixer_provider.dart';

/// Pocket 4-Channel Stem Mixer & Master Bus DSP console (REQ-MIX-01 … 05).
///
/// A tactile DAW-style mixing surface for balancing separated stems, applying
/// Bantu master-bus processing, and bouncing a master mix.
class StemMixerDeck extends ConsumerWidget {
  final String? title;
  const StemMixerDeck({super.key, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stemMixerProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    final strips = [
      for (final channel in state.channels) _ChannelStrip(channel: channel),
    ];

    return Container(
      color: AppColors.surfaceCanvas,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title ?? 'Pocket Stem Mixer',
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.bold)),
                      Text('4-Channel Console & Master DSP',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('mixer_reset_btn'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(stemMixerProvider.notifier).resetMix();
                  },
                  child: Text('Reset',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.brandPrimary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Channel strips
            SizedBox(
              height: 330,
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: strips,
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      children: strips,
                    ),
            ),
            const SizedBox(height: AppSpacing.md),

            const _MasterDspSection(),
          ],
        ),
      ),
    );
  }
}


class _ChannelStrip extends ConsumerWidget {
  final StemChannel channel;
  const _ChannelStrip({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stemMixerProvider.notifier);
    final type = channel.type;

    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(channel.emoji, style: const TextStyle(fontSize: 20)),
          Text(channel.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
            ),
            child: Text(channel.gainDecibels,
                style: AppTypography.caption.copyWith(color: AppColors.coinGold)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 92,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                key: Key('fader_${type.name}'),
                value: channel.gain.clamp(0.0, 1.5),
                min: 0.0,
                max: 1.5,
                activeColor: AppColors.brandPrimary,
                inactiveColor: AppColors.surfaceSecondary,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  notifier.setChannelGain(type, v);
                },
              ),
            ),
          ),
          Slider(
            key: Key('pan_${type.name}'),
            value: channel.pan.clamp(-1.0, 1.0),
            min: -1.0,
            max: 1.0,
            activeColor: AppColors.badgeCyan,
            inactiveColor: AppColors.surfaceSecondary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              notifier.setChannelPan(type, v);
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('L', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
              Text('C', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
              Text('R', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MsButton(
                key: Key('mute_${type.name}'),
                label: 'M',
                active: channel.isMuted,
                activeColor: AppColors.error,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  notifier.toggleMute(type);
                },
              ),
              const SizedBox(width: 6),
              _MsButton(
                key: Key('solo_${type.name}'),
                label: 'S',
                active: channel.isSolo,
                activeColor: AppColors.coinGold,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  notifier.toggleSolo(type);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MsButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _MsButton({
    super.key,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : AppColors.surfaceSecondary,
          borderRadius: AppRadius.thumbBorder,
          border: Border.all(
            color: active ? activeColor : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: active ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MasterDspSection extends ConsumerWidget {
  const _MasterDspSection();

  static const List<String> _presets = [
    'Amapiano Club Banger',
    'Deep Maskandi Acoustic',
    'Clean Vocal Duet',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stemMixerProvider);
    final notifier = ref.read(stemMixerProvider.notifier);
    final dsp = state.masterDsp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq_rounded,
                color: AppColors.coinGold, size: 18),
            const SizedBox(width: 8),
            Text('Master Bus DSP',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _DspSlider(
          label: 'Log Drum Saturation',
          value: dsp.logDrumSaturation,
          max: 1.0,
          onChanged: (v) => notifier.updateMasterDsp(dsp.copyWith(logDrumSaturation: v)),
        ),
        _DspSlider(
          label: 'Vocal Plate Reverb',
          value: dsp.vocalPlateReverb,
          max: 1.0,
          onChanged: (v) => notifier.updateMasterDsp(dsp.copyWith(vocalPlateReverb: v)),
        ),
        _DspSlider(
          label: 'Sidechain Compression',
          value: dsp.sidechainCompression,
          max: 1.0,
          onChanged: (v) => notifier.updateMasterDsp(dsp.copyWith(sidechainCompression: v)),
        ),
        _DspSlider(
          label: 'Stereo Width',
          value: dsp.stereoWidth,
          max: 1.5,
          onChanged: (v) => notifier.updateMasterDsp(dsp.copyWith(stereoWidth: v)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preset in _presets)
              ActionChip(
                key: Key('preset_$preset'),
                label: Text(preset,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textPrimary)),
                backgroundColor: AppColors.surfaceSecondary,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.applyPreset(preset);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          key: const Key('mixer_bounce_btn'),
          onPressed: state.isBouncing
              ? null
              : () async {
                  HapticFeedback.heavyImpact();
                  final path = await notifier.bounceMasterMix();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Master mix bounced to /vault/bounces! Ready for Content Studio.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  debugPrint('Bounced: $path');
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            minimumSize: const Size.fromHeight(50),
            shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.inputBorder),
          ),
          icon: const Icon(Icons.download_rounded,
              color: AppColors.brandContrast),
          label: Text(
            state.isBouncing ? 'Bouncing…' : 'Bounce Master Mix',
            style: AppTypography.bodyLarge.copyWith(
                color: AppColors.brandContrast, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _DspSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  const _DspSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, max),
            min: 0.0,
            max: max,
            activeColor: AppColors.coinGold,
            inactiveColor: AppColors.surfaceSecondary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
