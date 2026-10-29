import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/multi_stem_audio_provider.dart';
import '../../domain/models/stem_mastering_recipe.dart';
import '../providers/mastering_session_provider.dart';

/// Full-Fledged DAW Mastering Console & Channel Rack (REQ-MST-UI-02, REQ-MST-UI-03).
///
/// Designed for desktop screen real estate (>=1024dp):
/// 4-stem channel strips, 4-band parametric EQ curves, Adobe-style neural vocal denoise,
/// log-drum sub-harmonic/tube drive sliders, M/S vocal pocketing, and LUFS/dBTP metering.
class DesktopMasteringStudioView extends ConsumerStatefulWidget {
  final String? trackId;
  final String? trackTitle;
  final String? genre;

  const DesktopMasteringStudioView({
    super.key,
    this.trackId,
    this.trackTitle,
    this.genre,
  });

  @override
  ConsumerState<DesktopMasteringStudioView> createState() =>
      _DesktopMasteringStudioViewState();
}

class _DesktopMasteringStudioViewState
    extends ConsumerState<DesktopMasteringStudioView> {
  @override
  void initState() {
    super.initState();
    if (widget.trackId != null &&
        widget.trackTitle != null &&
        widget.genre != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(masteringSessionProvider.notifier).initializeForTrack(
              trackId: widget.trackId!,
              trackTitle: widget.trackTitle!,
              genre: widget.genre!,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masteringSessionProvider);
    final notifier = ref.read(masteringSessionProvider.notifier);
    final hasRealStems =
        ref.watch(multiStemAudioEngineProvider).hasRealStems;

    return Scaffold(
      key: const Key('desktop_mastering_studio_view'),
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Studio Header Toolbar
            _buildTopToolbar(context, state, notifier),

            // 2. Master-Only Notice Banner (if fallback)
            if (!hasRealStems)
              Container(
                key: const Key('mastering_master_only_notice'),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
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
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Master-Only Mode: Stems are offline or compiling on RunPod GPU. Real-time Tier A auditioning applies macro Log-Drum knock and M/S stereo wideners to the master bus.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 3. Main Console Surface: 4 Channel Strips + Master Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vocals Strip
                    Expanded(
                      child: _VocalsChannelStrip(
                        vocals: state.recipe.vocals,
                        onConfigChanged: notifier.updateVocalConfig,
                        onFlavorChanged: notifier.setVocalFlavor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Bass / Log Drum Strip
                    Expanded(
                      child: _BassChannelStrip(
                        bass: state.recipe.bass,
                        onConfigChanged: notifier.updateBassConfig,
                        onFlavorChanged: notifier.setBassFlavor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Drums Strip
                    Expanded(
                      child: _DrumsChannelStrip(
                        drums: state.recipe.drums,
                        onConfigChanged: notifier.updateDrumConfig,
                        onFlavorChanged: notifier.setDrumFlavor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Melodic Strip
                    Expanded(
                      child: _MelodicChannelStrip(
                        melodic: state.recipe.melodic,
                        onConfigChanged: notifier.updateMelodicConfig,
                        onFlavorChanged: notifier.setMelodicFlavor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Master Bus & Metering Rack
                    SizedBox(
                      width: 260,
                      child: _MasterOutputRack(
                        state: state,
                        onBake: () => notifier.bakeMaster(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(
    BuildContext context,
    MasteringSessionState state,
    MasteringSessionNotifier notifier,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Return to Player',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.brandPrimary, size: 24),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vhunambi Mastering Studio',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.trackTitle} • ${state.genre} Regional Master Suite',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Preset Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kGenreMasterPresets
                        .any((p) => p.id == state.recipe.presetId)
                    ? state.recipe.presetId
                    : null,
                hint: Text('Custom Recipe',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.coinGold)),
                dropdownColor: AppColors.surfaceElevated,
                items: kGenreMasterPresets.map((preset) {
                  return DropdownMenuItem<String>(
                    key: Key('mastering_preset_${preset.id}'),
                    value: preset.id,
                    child: Text(
                      preset.name,
                      style: AppTypography.bodyLarge.copyWith(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    HapticFeedback.selectionClick();
                    notifier.applyPreset(id);
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // A/B Audition Toggle (REQ-MST-AUD-03)
          Row(
            children: [
              Text(
                state.isMasteredPreviewActive ? 'Mastered' : 'Raw AI',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: state.isMasteredPreviewActive
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                key: const Key('desktop_mastering_ab_toggle'),
                value: state.isMasteredPreviewActive,
                activeThumbColor: AppColors.brandPrimary,
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  notifier.togglePreviewBypass();
                },
              ),
            ],
          ),

          const SizedBox(width: AppSpacing.md),

          // LUFS Target Toggle (REQ-MST-DOM-01)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                InkWell(
                  key: const Key('desktop_lufs_toggle'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final next =
                        state.recipe.targetLufs == -9.5 ? -14.0 : -9.5;
                    notifier.setTargetLufs(next);
                  },
                  borderRadius: AppRadius.pillBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '${state.recipe.targetLufs} LUFS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Cloud Studio Bake CTA
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: ElevatedButton.icon(
              key: const Key('desktop_mastering_bake_btn'),
              onPressed: state.isBaking
                  ? null
                  : () async {
                      HapticFeedback.heavyImpact();
                      final success = await notifier.bakeMaster();
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✨ Studio master baked successfully on RunPod GPU!',
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
              ),
              icon: state.isBaking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandContrast,
                      ),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(
                state.isBaking ? 'Baking Master…' : 'Bake Master',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vocals Sonar Channel Strip
class _VocalsChannelStrip extends StatelessWidget {
  final VocalsMasteringConfig vocals;
  final ValueChanged<VocalsMasteringConfig> onConfigChanged;
  final ValueChanged<VocalCleanseFlavor> onFlavorChanged;

  const _VocalsChannelStrip({
    required this.vocals,
    required this.onConfigChanged,
    required this.onFlavorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ChannelStripFrame(
      title: '🎙️ Vocals Cleanse',
      badge: vocals.flavor.label,
      eqGraphKey: const Key('eq_curve_vocals'),
      eq: vocals.eq,
      children: [
        // Cleanse Flavor Selector
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: VocalCleanseFlavor.values.map((f) {
            final isSel = vocals.flavor == f;
            return ChoiceChip(
              label: Text(f.label, style: const TextStyle(fontSize: 11)),
              selected: isSel,
              selectedColor: AppColors.brandPrimary.withValues(alpha: 0.2),
              backgroundColor: AppColors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSel ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
              onSelected: (_) => onFlavorChanged(f),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Neural Cleanse Sliders
        _ConsoleSlider(
          sliderKey: const Key('slider_vocal_denoise'),
          label: 'Neural De-Noise',
          value: vocals.neuralDenoiseStrength,
          displayValue: '${(vocals.neuralDenoiseStrength * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(vocals.copyWith(neuralDenoiseStrength: v)),
        ),
        _ConsoleSlider(
          label: 'Neural De-Reverb',
          value: vocals.neuralDereverbStrength,
          displayValue: '${(vocals.neuralDereverbStrength * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(vocals.copyWith(neuralDereverbStrength: v)),
        ),
        _ConsoleSlider(
          label: 'Vocal Compression',
          value: vocals.compressionAmount,
          displayValue: '${(vocals.compressionAmount * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(vocals.copyWith(compressionAmount: v)),
        ),
      ],
    );
  }
}

/// Bass / Log Drum Sonar Channel Strip
class _BassChannelStrip extends StatelessWidget {
  final BassMasteringConfig bass;
  final ValueChanged<BassMasteringConfig> onConfigChanged;
  final ValueChanged<BassCharacterFlavor> onFlavorChanged;

  const _BassChannelStrip({
    required this.bass,
    required this.onConfigChanged,
    required this.onFlavorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ChannelStripFrame(
      title: '🪵 Log Drum & Sub',
      badge: bass.flavor.label,
      eqGraphKey: const Key('eq_curve_bass'),
      eq: bass.eq,
      children: [
        // Bass Flavor Selector
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: BassCharacterFlavor.values.map((f) {
            final isSel = bass.flavor == f;
            return ChoiceChip(
              label: Text(f.label, style: const TextStyle(fontSize: 11)),
              selected: isSel,
              selectedColor: AppColors.brandPrimary.withValues(alpha: 0.2),
              backgroundColor: AppColors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSel ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
              onSelected: (_) => onFlavorChanged(f),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Sub & Knock Sliders
        _ConsoleSlider(
          sliderKey: const Key('slider_bass_sub_harmonic'),
          label: 'Sub-Harmonic (45Hz)',
          value: bass.subHarmonicMix,
          displayValue: '${(bass.subHarmonicMix * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(bass.copyWith(subHarmonicMix: v)),
        ),
        _ConsoleSlider(
          sliderKey: const Key('slider_bass_knock_drive'),
          label: 'Tube Knock (165Hz)',
          value: bass.knockDriveDb,
          min: 0.0,
          max: 9.0,
          displayValue: '+${bass.knockDriveDb.toStringAsFixed(1)} dB',
          onChanged: (v) =>
              onConfigChanged(bass.copyWith(knockDriveDb: v)),
        ),
        _ConsoleSlider(
          sliderKey: const Key('slider_bass_sidechain_duck'),
          label: 'Kick Sidechain Duck',
          value: bass.sidechainDuckDb,
          min: -6.0,
          max: 0.0,
          displayValue: '${bass.sidechainDuckDb.toStringAsFixed(1)} dB',
          onChanged: (v) =>
              onConfigChanged(bass.copyWith(sidechainDuckDb: v)),
        ),
      ],
    );
  }
}

/// Drums Sonar Channel Strip
class _DrumsChannelStrip extends StatelessWidget {
  final DrumsMasteringConfig drums;
  final ValueChanged<DrumsMasteringConfig> onConfigChanged;
  final ValueChanged<DrumCharacterFlavor> onFlavorChanged;

  const _DrumsChannelStrip({
    required this.drums,
    required this.onConfigChanged,
    required this.onFlavorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ChannelStripFrame(
      title: '🥁 Drum Bus Snap',
      badge: drums.flavor.label,
      eqGraphKey: const Key('eq_curve_drums'),
      eq: drums.eq,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: DrumCharacterFlavor.values.map((f) {
            final isSel = drums.flavor == f;
            return ChoiceChip(
              label: Text(f.label, style: const TextStyle(fontSize: 11)),
              selected: isSel,
              selectedColor: AppColors.brandPrimary.withValues(alpha: 0.2),
              backgroundColor: AppColors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSel ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
              onSelected: (_) => onFlavorChanged(f),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        _ConsoleSlider(
          label: 'Attack Snap',
          value: drums.transientAttackSnap,
          min: -1.0,
          max: 1.0,
          displayValue:
              '${(drums.transientAttackSnap * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(drums.copyWith(transientAttackSnap: v)),
        ),
        _ConsoleSlider(
          label: 'Parallel NY Crush',
          value: drums.parallelCrushMix,
          displayValue: '${(drums.parallelCrushMix * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(drums.copyWith(parallelCrushMix: v)),
        ),
      ],
    );
  }
}

/// Melodic Sonar Channel Strip
class _MelodicChannelStrip extends StatelessWidget {
  final MelodicMasteringConfig melodic;
  final ValueChanged<MelodicMasteringConfig> onConfigChanged;
  final ValueChanged<MelodicCharacterFlavor> onFlavorChanged;

  const _MelodicChannelStrip({
    required this.melodic,
    required this.onConfigChanged,
    required this.onFlavorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ChannelStripFrame(
      title: '🎹 Melodic & Keys',
      badge: melodic.flavor.label,
      eqGraphKey: const Key('eq_curve_melodic'),
      eq: melodic.eq,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: MelodicCharacterFlavor.values.map((f) {
            final isSel = melodic.flavor == f;
            return ChoiceChip(
              label: Text(f.label, style: const TextStyle(fontSize: 11)),
              selected: isSel,
              selectedColor: AppColors.brandPrimary.withValues(alpha: 0.2),
              backgroundColor: AppColors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSel ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
              onSelected: (_) => onFlavorChanged(f),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        _ConsoleSlider(
          label: 'Mid Vocal Pocket Cut',
          value: melodic.midVocalPocketCutDb,
          min: -6.0,
          max: 0.0,
          displayValue:
              '${melodic.midVocalPocketCutDb.toStringAsFixed(1)} dB',
          onChanged: (v) =>
              onConfigChanged(melodic.copyWith(midVocalPocketCutDb: v)),
        ),
        _ConsoleSlider(
          label: 'Sides Stereo Expansion',
          value: melodic.stereoWidthBoost,
          displayValue: '+${(melodic.stereoWidthBoost * 100).toInt()}%',
          onChanged: (v) =>
              onConfigChanged(melodic.copyWith(stereoWidthBoost: v)),
        ),
      ],
    );
  }
}

/// Reusable Channel Strip Shell with Embedded 4-Band Parametric EQ Graph
class _ChannelStripFrame extends StatelessWidget {
  final String title;
  final String badge;
  final Key eqGraphKey;
  final StemEqBands eq;
  final List<Widget> children;

  const _ChannelStripFrame({
    required this.title,
    required this.badge,
    required this.eqGraphKey,
    required this.eq,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  badge,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 4-Band Parametric EQ Curve
          SizedBox(
            height: 72,
            child: ClipRRect(
              borderRadius: AppRadius.inputBorder,
              child: CustomPaint(
                key: eqGraphKey,
                painter: _EqCurvePainter(eq: eq),
                size: Size.infinite,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Master Output Section with Commercial LUFS Metering
class _MasterOutputRack extends StatelessWidget {
  final MasteringSessionState state;
  final VoidCallback onBake;

  const _MasterOutputRack({
    required this.state,
    required this.onBake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.equalizer_rounded,
                  color: AppColors.coinGold, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Master Output',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Loudness Meters
          _buildMeterBar(
            label: 'Integrated LUFS',
            valueText: '${state.recipe.targetLufs} LUFS',
            percentage: (state.recipe.targetLufs.abs() / 24.0).clamp(0.0, 1.0),
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMeterBar(
            label: 'True Peak Ceiling',
            valueText: '-1.0 dBTP',
            percentage: 0.88,
            color: AppColors.success,
          ),

          const Spacer(),

          // Status & Baked Artifacts
          if (state.hasBakedMaster) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.success),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Master Baked (WAV 24b)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ready for export and release distribution.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: ElevatedButton.icon(
              onPressed: state.isBaking ? null : onBake,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
              icon: state.isBaking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandContrast,
                      ),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 16),
              label: Text(
                state.isBaking ? 'Baking Master…' : 'Bake Master',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBar({
    required String label,
    required String valueText,
    required double percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              valueText,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: AppRadius.pillBorder,
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.surfaceSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

/// Slider control with label, value read-out, and haptic feedback
class _ConsoleSlider extends StatelessWidget {
  final Key? sliderKey;
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _ConsoleSlider({
    this.sliderKey,
    required this.label,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              displayValue,
              style: AppTypography.caption.copyWith(
                color: AppColors.coinGold,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            key: sliderKey,
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.brandPrimary,
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

/// CustomPainter rendering a 4-Band Parametric EQ curve on a frequency graph
class _EqCurvePainter extends CustomPainter {
  final StemEqBands eq;

  _EqCurvePainter({required this.eq});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.surfaceSecondary;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (int i = 1; i < 4; i++) {
      final x = size.width * (i / 4.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    final midY = size.height / 2.0;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);

    // Draw Parametric Curve
    final path = Path();
    final points = 64;
    for (int i = 0; i <= points; i++) {
      final xNorm = i / points.toDouble();
      final x = xNorm * size.width;

      // Simulated EQ response based on highpass, lowGain, midGain, and airGain
      final lowInfluence = (1.0 - xNorm) * (eq.lowGainDb / 12.0);
      final midCenter = (eq.midFreqHz - 50.0) / 4950.0;
      final midDist = (xNorm - midCenter).abs();
      final midInfluence =
          math.exp(-midDist * 12.0) * (eq.midGainDb / 12.0);
      final airInfluence = xNorm * (eq.airGainDb / 12.0);

      final totalDb = (lowInfluence + midInfluence + airInfluence).clamp(-1.0, 1.0);
      final y = midY - (totalDb * (size.height * 0.4));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final curvePaint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    return oldDelegate.eq != eq;
  }
}

