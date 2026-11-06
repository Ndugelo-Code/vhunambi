import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/heritage_crate_provider.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'crate_browser_deck.dart';
import 'direct_daw_vocal_upload_sheet.dart';
import 'melody_sketchpad_modal.dart';

enum InlineWorkbenchMode { crate, mpc, sketchpad, dawUpload }

final inlineWorkbenchModeProvider = StateProvider<InlineWorkbenchMode>(
  (ref) => InlineWorkbenchMode.crate,
);

/// Inline 4-Mode Groove, Crate, 8-Pad MPC & DAW Stem Workbench on Tab 2 (REQ-P56-CRATE-02).
class InlineCrateMpcWorkbench extends ConsumerWidget {
  const InlineCrateMpcWorkbench({
    super.key = const Key('cockpit_inline_crate_mpc_workbench'),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(inlineWorkbenchModeProvider);
    final mpcState = ref.watch(mpcSlicerProvider);
    final crateState = ref.watch(heritageCrateProvider);
    final sketchState = ref.watch(melodySketchpadProvider);
    final formState = ref.watch(studioFormProvider);
    final beatLocked =
        formState.branchStemLockModes['node_beat_tempo'] ==
            StemLockMode.lockedPure44k ||
        formState.branchStemLockModes['node_branch_beat'] ==
            StemLockMode.lockedPure44k;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Beat Stem Lock Toggle and Full-Screen Crate Slicer Button
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.faders,
                color: AppColors.coinGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Groove, Crate & DAW Workbench',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Heritage samples, 8-pad MPC, 5-Ch groove & DAW stem intake',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                key: const Key('workbench_lock_beat_btn'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(studioFormProvider.notifier)
                      .cycleClusterStemLockMode(
                        MyceliumClusterDomain.rhythmNetwork,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: beatLocked
                        ? const Color(0xFF00B4D8).withValues(alpha: 0.18)
                        : AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: beatLocked
                          ? const Color(0xFF00B4D8)
                          : AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        beatLocked
                            ? PhosphorIconsBold.lockKey
                            : PhosphorIconsBold.lockKeyOpen,
                        size: 12,
                        color: beatLocked
                            ? const Color(0xFF00B4D8)
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        beatLocked ? 'Beat Locked' : 'Beat Guided',
                        style: AppTypography.caption.copyWith(
                          color: beatLocked
                              ? const Color(0xFF00B4D8)
                              : AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('studio_open_crate_btn'),
                tooltip: 'Full-Screen Heritage Crate & MPC Slicer',
                visualDensity: VisualDensity.compact,
                icon: const PhosphorIcon(
                  PhosphorIconsBold.arrowsOutSimple,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surfaceModalOf(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.modalBorder,
                      side: BorderSide(color: AppColors.borderSubtleOf(context)),
                    ),
                    builder: (_) => const CrateBrowserDeck(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Unified 4-Pill Mode Switcher (Zero Truncation on 360dp Mobile)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildModeTab(
                  context: context,
                  ref: ref,
                  mode: InlineWorkbenchMode.crate,
                  activeMode: activeMode,
                  keyName: 'workbench_mode_crate',
                  label: 'Crate',
                  icon: PhosphorIconsBold.disc,
                ),
                const SizedBox(width: 4),
                _buildModeTab(
                  context: context,
                  ref: ref,
                  mode: InlineWorkbenchMode.mpc,
                  activeMode: activeMode,
                  keyName: 'workbench_mode_mpc',
                  label: '8-Pad MPC',
                  icon: PhosphorIconsBold.squaresFour,
                ),
                const SizedBox(width: 4),
                _buildModeTab(
                  context: context,
                  ref: ref,
                  mode: InlineWorkbenchMode.sketchpad,
                  activeMode: activeMode,
                  keyName: 'workbench_mode_sketchpad',
                  label: '5-Ch Groove',
                  icon: PhosphorIconsBold.pianoKeys,
                ),
                const SizedBox(width: 4),
                _buildModeTab(
                  context: context,
                  ref: ref,
                  mode: InlineWorkbenchMode.dawUpload,
                  activeMode: activeMode,
                  keyName: 'workbench_mode_daw_upload',
                  label: 'DAW Upload',
                  icon: PhosphorIconsBold.uploadSimple,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Active Mode Surface
          if (activeMode == InlineWorkbenchMode.crate)
            _buildInlineCrateSurface(context, ref, crateState)
          else if (activeMode == InlineWorkbenchMode.mpc)
            _buildInlineMpcSurface(context, ref, mpcState)
          else if (activeMode == InlineWorkbenchMode.sketchpad)
            _buildInlineSketchpadSurface(context, sketchState)
          else
            _buildInlineDawUploadSurface(context),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required BuildContext context,
    required WidgetRef ref,
    required InlineWorkbenchMode mode,
    required InlineWorkbenchMode activeMode,
    required String keyName,
    required String label,
    required PhosphorIconData icon,
  }) {
    final isSelected = activeMode == mode;
    return Expanded(
      child: GestureDetector(
        key: Key(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(inlineWorkbenchModeProvider.notifier).state = mode;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPrimary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? AppColors.brandPrimary
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 13,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondaryOf(context),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineCrateSurface(
    BuildContext context,
    WidgetRef ref,
    HeritageCrateState crateState,
  ) {
    final samples = crateState.filteredSamples.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sample in samples)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtleOf(context)),
            ),
            child: Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsBold.musicNotes,
                  size: 15,
                  color: AppColors.coinGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.name,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${sample.cultureRegion} • ${sample.bpm} BPM',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: Key('workbench_chop_sample_${sample.id}'),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(mpcSlicerProvider.notifier).sliceSample(sample);
                    ref.read(inlineWorkbenchModeProvider.notifier).state =
                        InlineWorkbenchMode.mpc;
                  },
                  child: Text(
                    'Chop to MPC',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInlineMpcSurface(
    BuildContext context,
    WidgetRef ref,
    MpcSlicerState mpcState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${mpcState.sourceTitle} • ${mpcState.bpm} BPM',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Stretch: ${mpcState.timeStretchRatio.toStringAsFixed(1)}x',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(mpcState.pads.length, (i) {
            final pad = mpcState.pads[i];
            final isSelected = mpcState.selectedPadIndex == i;
            return GestureDetector(
              key: Key('workbench_mpc_pad_$i'),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(mpcSlicerProvider.notifier).selectPad(i);
                ref.read(mpcSlicerProvider.notifier).triggerPad(i);
              },
              child: Container(
                width: 72,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary.withValues(alpha: 0.22)
                      : AppColors.surfaceSecondaryOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtleOf(context),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pad.label,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      '${pad.startSec.toStringAsFixed(1)}s',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInlineSketchpadSurface(
    BuildContext context,
    MelodySketchpadState sketchState,
  ) {
    final pat = sketchState.activePattern;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.pianoKeys,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pat.instrument.label} • ${pat.musicalKey} ${pat.scaleMode.label}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '5 Channels (Lead, Chords, Bass, Drums, Hats) • ${pat.bpm} BPM',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          key: const Key('workbench_open_sketchpad_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => MelodySketchpadModal.show(context),
          icon: const PhosphorIcon(
            PhosphorIconsBold.waveSine,
            size: 16,
            color: Colors.black,
          ),
          label: Text(
            'Open 5-Channel Master Sketchpad',
            style: AppTypography.caption.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineDawUploadSurface(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.fileAudio,
                color: AppColors.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct DAW Stem Pack & Vocal Track Uploader',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload WAV/FLAC/MP3 stems or acapellas with 5-stem AI separation and cryptographic provenance.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('studio_daw_uploader_btn'),
              onPressed: () => DirectDawVocalUploadSheet.show(context),
              icon: const PhosphorIcon(PhosphorIconsBold.uploadSimple, size: 15),
              label: const Text('Launch Direct DAW & Vocal Uploader'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
