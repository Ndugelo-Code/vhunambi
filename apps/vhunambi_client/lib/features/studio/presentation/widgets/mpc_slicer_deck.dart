import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../providers/heritage_crate_provider.dart';

/// 8-Pad AI MPC tactile slicer with chromatic pitch, reverse, time-stretch,
/// and DAW bounce bridges (REQ-MPC-01 … REQ-MPC-05).
class MpcSlicerDeck extends ConsumerWidget {
  const MpcSlicerDeck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mpcSlicerProvider);
    final notifier = ref.read(mpcSlicerProvider.notifier);
    final selected = state.selectedPad;

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
                const Icon(Icons.grid_view_rounded, color: AppColors.coinGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.sourceTitle,
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.bold)),
                      Text('${state.bpm} BPM · 8 AI Transient Slices',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Time-stretch slider
            Row(
              children: [
                Text(
                  'Stretch: ${state.timeStretchRatio.toStringAsFixed(1)}x',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Slider(
                    value: state.timeStretchRatio,
                    min: 0.5,
                    max: 2.0,
                    activeColor: AppColors.brandPrimary,
                    inactiveColor: AppColors.surfaceSecondary,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      notifier.setTimeStretch(v);
                    },
                  ),
                ),
              ],
            ),

            // 8-pad grid (4x2)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.pads.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, i) {
                final pad = state.pads[i];
                return _MpcPad(
                  pad: pad,
                  isSelected: i == state.selectedPadIndex,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    notifier.triggerPad(i);
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Selected pad modulation deck
            _ModulationDeck(pad: selected),
            const SizedBox(height: AppSpacing.md),

            // Actions
            ElevatedButton.icon(
              key: const Key('mpc_send_to_mixer'),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                await notifier.bounceChops();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chop kit bounced & sent to Stem Mixer! 🎹'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.inputBorder),
              ),
              icon: const Icon(Icons.tune_rounded, color: AppColors.brandContrast),
              label: Text('🎹 Send to Stem Mixer',
                  style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('mpc_send_to_studio'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chop kit routed into Studio prompt context 🎙️'),
                    backgroundColor: AppColors.surfaceModal,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderSubtle),
                minimumSize: const Size.fromHeight(48),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.inputBorder),
              ),
              icon: const Icon(Icons.mic_none_rounded, color: AppColors.textPrimary),
              label: Text('🎙️ Record into Studio',
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MpcPad extends StatelessWidget {
  final MpcPadEntity pad;
  final bool isSelected;
  final VoidCallback onTap;
  const _MpcPad(
      {required this.pad, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = pad.isTriggered || isSelected;
    return GestureDetector(
      key: Key('mpc_pad_${pad.index}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceSecondary : AppColors.surfaceElevated,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color: pad.isTriggered
                ? AppColors.brandPrimary
                : (isSelected ? AppColors.coinGold : AppColors.borderSubtle),
            width: active ? 2 : 1,
          ),
          boxShadow: pad.isTriggered
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withAlpha(90),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pad.label,
                style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${pad.startSec.toStringAsFixed(1)}s',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary, fontSize: 9)),
            if (pad.pitchShiftSemitones != 0) ...[
              const SizedBox(height: 2),
              _padPill(
                  '${pad.pitchShiftSemitones > 0 ? '+' : ''}${pad.pitchShiftSemitones} st',
                  AppColors.badgeCyan),
            ],
            if (pad.isReversed) ...[
              const SizedBox(height: 2),
              _padPill('◀ REV', AppColors.coinGold),
            ],
          ],
        ),
      ),
    );
  }

  Widget _padPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(text,
          style: AppTypography.caption.copyWith(
              color: color, fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }
}

class _ModulationDeck extends ConsumerWidget {
  final MpcPadEntity pad;
  const _ModulationDeck({required this.pad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mpcSlicerProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Modulate ${pad.label}',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          Row(
            children: [
              const SizedBox(
                  width: 60,
                  child: Text('Pitch',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 11))),
              Expanded(
                child: Slider(
                  key: const Key('mpc_pitch_slider'),
                  value: pad.pitchShiftSemitones.toDouble().clamp(-12, 12),
                  min: -12,
                  max: 12,
                  divisions: 24,
                  label: '${pad.pitchShiftSemitones} st',
                  activeColor: AppColors.badgeCyan,
                  inactiveColor: AppColors.surfaceSecondary,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    notifier.setPitchShift(pad.index, v.round());
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                  width: 60,
                  child: Text('Volume',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 11))),
              Expanded(
                child: Slider(
                  key: const Key('mpc_vol_slider'),
                  value: pad.volume.clamp(0.0, 1.5),
                  min: 0.0,
                  max: 1.5,
                  activeColor: AppColors.brandPrimary,
                  inactiveColor: AppColors.surfaceSecondary,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    notifier.setPadVolume(pad.index, v);
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Reverse',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              Switch(
                key: const Key('mpc_reverse_toggle'),
                value: pad.isReversed,
                activeThumbColor: AppColors.coinGold,
                onChanged: (_) {
                  HapticFeedback.lightImpact();
                  notifier.toggleReverse(pad.index);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
