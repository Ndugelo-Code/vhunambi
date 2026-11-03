import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/idealizer/pitch_trajectory_editor.dart';
import '../../domain/idealizer/sound_signature_resynthesizer.dart';
import '../../domain/models/recording_quality_profile.dart';
import '../../domain/models/sound_idealizer_recipe.dart';
import '../../domain/models/sound_signature_dna.dart';
import 'pitch_formant_painter.dart';
import 'vhu_sig_badge.dart';

/// Modal bottom sheet for interactive vocal idealization and timbre sculpting (REQ-SIG-UI-01 / Design 7.1).
///
/// Adheres strictly to `STD-UIUX-001`: Phosphor vector icons only, 44x44dp touch targets,
/// dynamic `AppColors` getters (zero const over colors, zero raw emojis).
class SoundSignatureIdealizerSheet extends StatefulWidget {
  const SoundSignatureIdealizerSheet({
    super.key,
    required this.signature,
    this.rawPcm441,
    this.onSaveRecipe,
    this.onApplyStem,
    this.onSendToSketchpad,
    this.onUseAsVoiceClone,
    this.onDelete,
  });

  final SoundSignatureDna signature;
  final Float32List? rawPcm441;
  final void Function(SoundIdealizerRecipe recipe)? onSaveRecipe;
  final void Function(Float32List idealizedPcm)? onApplyStem;
  final void Function(SoundSignatureDna signature)? onSendToSketchpad;
  final void Function(SoundSignatureDna signature)? onUseAsVoiceClone;
  final VoidCallback? onDelete;

  @override
  State<SoundSignatureIdealizerSheet> createState() =>
      _SoundSignatureIdealizerSheetState();
}

class _SoundSignatureIdealizerSheetState
    extends State<SoundSignatureIdealizerSheet> {
  late SoundIdealizerRecipe _recipe;
  bool _isAuditioningIdealized = true;
  bool _isRendering = false;
  Float64List? _idealSemitones;
  List<RefusedNote> _refusedNotes = const [];

  static const List<(String, String)> _kArchetypes = [
    ('none', 'Natural Voice'),
    ('soweto_golden', 'Soweto Golden'),
    ('durban_bounce', 'Durban Bounce'),
    ('venda_rain', 'Venda Rain'),
    ('gqom_steel', 'Gqom Steel'),
  ];

  @override
  void initState() {
    super.initState();
    _recipe = widget.signature.recipe;
    _updateTrajectory();
  }

  void _updateTrajectory() {
    final editor = const PitchTrajectoryEditor(frameRateHz: 50);
    final result = editor.editTrajectory(
      rawF0CentsMidi: widget.signature.pitch.f0CentsMidi,
      scaleMode: widget.signature.pitch.scaleMode,
      rootPitchClass: widget.signature.pitch.rootPitchClass,
      recipe: _recipe,
    );
    setState(() {
      _idealSemitones = result.idealSemitones;
      _refusedNotes = result.refusedNotes;
    });
  }

  Future<void> _renderAndSave() async {
    if (widget.rawPcm441 == null || widget.rawPcm441!.isEmpty) {
      widget.onSaveRecipe?.call(_recipe);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isRendering = true);
    try {
      const resynthesizer = SoundSignatureResynthesizer();
      final resynth = await resynthesizer.resynthesize(
        ResynthesizerParams(
          rawAudio441: widget.rawPcm441!,
          signature: widget.signature,
          recipe: _recipe,
        ),
      );

      widget.onSaveRecipe?.call(_recipe);
      widget.onApplyStem?.call(resynth.idealizedAudio);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isRendering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scaleMode = widget.signature.pitch.scaleMode;
    final rootName = widget.signature.pitch.rootPitchClass < 12
        ? ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][widget.signature.pitch.rootPitchClass]
        : 'C';

    return Container(
      key: const Key('sound_signature_idealizer_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderActive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                VhuSigBadge(
                  displayCode: widget.signature.displayCode,
                  source: widget.signature.source,
                ),
                const Spacer(),

                // A/B Audition Toggle
                GestureDetector(
                  key: const Key('sig_ab_toggle'),
                  onTap: () {
                    setState(() {
                      _isAuditioningIdealized = !_isAuditioningIdealized;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _isAuditioningIdealized
                          ? AppColors.brandPrimary.withValues(alpha: 0.15)
                          : AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: _isAuditioningIdealized
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          _isAuditioningIdealized
                              ? PhosphorIconsFill.sparkle
                              : PhosphorIconsRegular.waveform,
                          size: 14,
                          color: _isAuditioningIdealized
                              ? AppColors.brandPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _isAuditioningIdealized ? 'IDEALIZED (B)' : 'RAW (A)',
                          style: AppTypography.badge.copyWith(
                            color: _isAuditioningIdealized
                                ? AppColors.brandPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xs),

                // Close Button
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.x,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pitch & Formant Canvas
                  Container(
                    height: 140,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: PitchFormantPainter(
                        signature: widget.signature,
                        recipe: _recipe,
                        isAuditioningIdealized: _isAuditioningIdealized,
                        refusedNotes: _refusedNotes,
                        idealSemitones: _idealSemitones,
                        brightness: brightness,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Scale & Refusal Legend
                  Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.musicNote,
                        size: 12,
                        color: AppColors.coinGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Locked to $rootName ${scaleMode.label}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_refusedNotes.isNotEmpty) ...[
                        const Spacer(),
                        PhosphorIcon(
                          PhosphorIconsFill.warningCircle,
                          size: 12,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_refusedNotes.length} note(s) kept original (>7st)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Quality Warning if fair
                  if (widget.signature.quality.verdict == RecordingQualityVerdict.fair) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coinGold.withValues(alpha: 0.12),
                        borderRadius: AppRadius.inputBorder,
                        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.warning,
                            size: 14,
                            color: AppColors.coinGold,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.signature.quality.remediationTip,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.coinGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'ACOUSTIC SCULPT ENGINE',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Slider 1: Scale Lock
                  _buildSlider(
                    key: const Key('sig_slider_pitch_lock'),
                    icon: PhosphorIconsRegular.pianoKeys,
                    label: 'Pitch Scale Lock',
                    valueDisplay: '${(_recipe.pitchScaleLock * 100).round()}%',
                    value: _recipe.pitchScaleLock,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      _recipe = _recipe.copyWith(pitchScaleLock: v);
                      _updateTrajectory();
                    },
                  ),

                  // Slider 2: Vibrato Polish
                  _buildSlider(
                    key: const Key('sig_slider_vibrato'),
                    icon: PhosphorIconsRegular.waves,
                    label: 'Vibrato & Sustain Polish',
                    valueDisplay: '${(_recipe.vibratoAndSustainPolish * 100).round()}%',
                    value: _recipe.vibratoAndSustainPolish,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      _recipe = _recipe.copyWith(vibratoAndSustainPolish: v);
                      _updateTrajectory();
                    },
                  ),

                  // Slider 3: Formant Depth
                  _buildSlider(
                    key: const Key('sig_slider_formant'),
                    icon: PhosphorIconsRegular.microphone,
                    label: 'Vocal Tract Formant Depth',
                    valueDisplay: _recipe.formantDepthShiftSemitones == 0.0
                        ? 'Natural'
                        : '${_recipe.formantDepthShiftSemitones > 0 ? '+' : ''}${_recipe.formantDepthShiftSemitones.toStringAsFixed(1)} st',
                    value: _recipe.formantDepthShiftSemitones,
                    min: -3.0,
                    max: 3.0,
                    onChanged: (v) {
                      setState(() {
                        _recipe = _recipe.copyWith(formantDepthShiftSemitones: v);
                      });
                    },
                  ),

                  // Slider 4: Chest & Air
                  _buildSlider(
                    key: const Key('sig_slider_chest_air'),
                    icon: PhosphorIconsRegular.wind,
                    label: 'Chest Warmth & High Air',
                    valueDisplay: '${(_recipe.chestPowerAndAirBoost * 100).round()}%',
                    value: _recipe.chestPowerAndAirBoost,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() {
                        _recipe = _recipe.copyWith(chestPowerAndAirBoost: v);
                      });
                    },
                  ),

                  // Slider 5: 16-Step Pocket
                  _buildSlider(
                    key: const Key('sig_slider_pocket'),
                    icon: PhosphorIconsRegular.metronome,
                    label: '16-Step Groove Pocket',
                    valueDisplay: '${(_recipe.quantizePocketStrength * 100).round()}%',
                    value: _recipe.quantizePocketStrength,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() {
                        _recipe = _recipe.copyWith(quantizePocketStrength: v);
                      });
                    },
                  ),

                  // Slider 6: Denoise & Cleanup
                  _buildSlider(
                    key: const Key('sig_slider_cleanup'),
                    icon: PhosphorIconsRegular.sparkle,
                    label: 'Box Cut & Room Denoise',
                    valueDisplay: '${(_recipe.referenceCleanup * 100).round()}%',
                    value: _recipe.referenceCleanup,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() {
                        _recipe = _recipe.copyWith(referenceCleanup: v);
                      });
                    },
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Regional Voice Archetype Hybrid Picker
                  Text(
                    'REGIONAL AFRICAN VOICE ARCHETYPE',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SingleChildScrollView(
                    key: const Key('sig_hybrid_picker'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _kArchetypes.map((item) {
                        final id = item.$1;
                        final label = item.$2;
                        final isSelected = (_recipe.hybridArchetypeId ?? 'none') == id;

                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _recipe = _recipe.copyWith(
                                    hybridArchetypeId: id == 'none' ? null : id,
                                    clearHybridArchetype: id == 'none',
                                  );
                                });
                              }
                            },
                            selectedColor: AppColors.brandPrimary.withValues(alpha: 0.2),
                            backgroundColor: AppColors.surfaceSecondary,
                            labelStyle: AppTypography.caption.copyWith(
                              color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  // 1. Primary Save / Apply
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('sig_action_save'),
                      onPressed: _isRendering ? null : _renderAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonBorder,
                        ),
                      ),
                      child: _isRendering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsBold.checkCircle,
                                  size: 18,
                                  color: AppColors.brandContrast,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Save Idealized Stem',
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandContrast,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // 2. Hum to Sketchpad Action
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      key: const Key('sig_action_sketchpad'),
                      onPressed: () {
                        widget.onSendToSketchpad?.call(widget.signature);
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.borderActive),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.waveform,
                            size: 16,
                            color: AppColors.coinGold,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Send to Melody Sketchpad',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Set as Voice Clone (Live only)
                  if (widget.signature.isEligibleForVoiceIdentity) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        key: const Key('sig_action_apply'),
                        onPressed: () {
                          widget.onUseAsVoiceClone?.call(widget.signature);
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.success.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.buttonBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.userCheck,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Set as Sovereign Voice Clone',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (widget.onDelete != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton.icon(
                        key: const Key('sig_action_delete'),
                        onPressed: widget.onDelete,
                        icon: PhosphorIcon(
                          PhosphorIconsRegular.trash,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: Text(
                          'Delete Sound Signature',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required Key key,
    required IconData icon,
    required String label,
    required String valueDisplay,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              PhosphorIcon(
                icon,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                valueDisplay,
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: AppColors.borderSubtle,
              thumbColor: AppColors.brandPrimary,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              key: key,
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
