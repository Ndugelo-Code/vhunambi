import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../providers/melody_sketchpad_provider.dart';

/// Phase 27 Device-Adaptive In-Key 16-Step Melody, Chord & Log-Drum Sketchpad Modal (REQ-SKP-08..11).
///
/// Branches automatically on viewport width:
/// - **Mobile (< 768px):** Bar-Paginated 4-Step HIG Matrix (`>= 44x44dp` cells) + 8-Pad Live Scale Deck.
/// - **Desktop (> 1024px):** Full 16-Step × 8-Row Split DAW Piano Roll + Chord Voicing Stamp +
///   16-Column Velocity/Glide Stalk Lane + QWERTY Keyboard Synth.
class MelodySketchpadModal extends ConsumerStatefulWidget {
  const MelodySketchpadModal({super.key, this.initialInstrument});

  final SketchpadInstrument? initialInstrument;

  static Future<void> show(
    BuildContext context, {
    SketchpadInstrument? initialInstrument,
  }) {
    if (ResponsiveUtils.isDesktop(context)) {
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surfaceModal,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
            child: MelodySketchpadModal(initialInstrument: initialInstrument),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: MelodySketchpadModal(initialInstrument: initialInstrument),
      ),
    );
  }

  @override
  ConsumerState<MelodySketchpadModal> createState() =>
      _MelodySketchpadModalState();
}

class _MelodySketchpadModalState extends ConsumerState<MelodySketchpadModal> {
  final FocusNode _keyboardFocusNode = FocusNode();

  static const List<String> _musicalKeys = ['F#m', 'Am', 'Cm', 'Dm', 'Em', 'G'];

  @override
  void initState() {
    super.initState();
    if (widget.initialInstrument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(melodySketchpadProvider.notifier)
            .setInstrument(widget.initialInstrument!);
      });
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final notifier = ref.read(melodySketchpadProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      notifier.togglePreviewPlayback();
    } else if (key == LogicalKeyboardKey.keyG) {
      notifier.toggleGlideMode();
    } else if (key == LogicalKeyboardKey.keyA) {
      notifier.triggerLiveScalePad(0);
    } else if (key == LogicalKeyboardKey.keyS) {
      notifier.triggerLiveScalePad(1);
    } else if (key == LogicalKeyboardKey.keyD) {
      notifier.triggerLiveScalePad(2);
    } else if (key == LogicalKeyboardKey.keyF) {
      notifier.triggerLiveScalePad(3);
    } else if (key == LogicalKeyboardKey.keyG) {
      notifier.triggerLiveScalePad(4);
    } else if (key == LogicalKeyboardKey.keyH) {
      notifier.triggerLiveScalePad(5);
    } else if (key == LogicalKeyboardKey.keyJ) {
      notifier.triggerLiveScalePad(6);
    } else if (key == LogicalKeyboardKey.keyK) {
      notifier.triggerLiveScalePad(7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(melodySketchpadProvider);
    final notifier = ref.read(melodySketchpadProvider.notifier);
    final pattern = state.activePattern;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: isDesktop,
      onKeyEvent: _handleKeyEvent,
      child: SafeArea(
        key: const Key('melody_sketchpad_modal'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Bar
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.amapiano,
                      borderRadius: AppRadius.inputBorder,
                    ),
                    child: const Icon(
                      Icons.piano_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDesktop
                              ? 'In-Key 16-Step Melody, Chord & Log-Drum Workstation'
                              : 'In-Key Melody & Log-Drum Sketchpad',
                          style: AppTypography.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${pattern.name} • ${pattern.musicalKey} ${pattern.scaleMode.label} • ${pattern.bpm} BPM (${pattern.notes.length} notes)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('sketchpad_close_btn'),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (state.attachedPattern != null) ...[
                Container(
                  key: const Key('sketchpad_attached_ready_badge'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(28),
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(color: AppColors.success.withAlpha(90)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Attached as Song Reference & Phase 25 Master Layer (35% Mix): ${state.attachedPattern!.name}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],

              // 2. Instrument Selector Rail
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SketchpadInstrument.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final inst = SketchpadInstrument.values[index];
                    final isSelected = pattern.instrument == inst;
                    return ChoiceChip(
                      key: Key('sketchpad_inst_${inst.name}'),
                      selected: isSelected,
                      label: Text(
                        '${inst.emoji} ${inst.label}',
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selectedColor: AppColors.brandPrimary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                      onSelected: (_) => notifier.setInstrument(inst),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // 3. Key, Scale Mode & Starter Presets Rail
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Root Key Selector Pills
                    for (final keyStr in _musicalKeys) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xxs),
                        child: ActionChip(
                          key: Key('sketchpad_key_$keyStr'),
                          backgroundColor: pattern.musicalKey == keyStr
                              ? AppColors.coinGold
                              : AppColors.surfaceElevated,
                          side: BorderSide(
                            color: pattern.musicalKey == keyStr
                                ? AppColors.coinGold
                                : AppColors.borderSubtle,
                          ),
                          label: Text(
                            keyStr,
                            style: AppTypography.caption.copyWith(
                              color: pattern.musicalKey == keyStr
                                  ? AppColors.brandContrast
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => notifier.setMusicalKey(keyStr),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    // Scale Modes
                    for (final scale in AfricanScaleMode.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xxs),
                        child: ActionChip(
                          key: Key('sketchpad_scale_${scale.name}'),
                          backgroundColor: pattern.scaleMode == scale
                              ? AppColors.brandPrimary.withAlpha(45)
                              : AppColors.surfaceElevated,
                          side: BorderSide(
                            color: pattern.scaleMode == scale
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtle,
                          ),
                          label: Text(
                            scale.label,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onPressed: () => notifier.setScaleMode(scale),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    // Starter Presets
                    for (final preset in state.starterPresets) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xxs),
                        child: ActionChip(
                          key: Key('sketchpad_preset_${preset.id}'),
                          backgroundColor: pattern.id == preset.id
                              ? AppColors.surfaceSecondary
                              : AppColors.surfaceElevated,
                          side: BorderSide(
                            color: pattern.id == preset.id
                                ? AppColors.coinGold
                                : AppColors.borderSubtle,
                          ),
                          label: Text(
                            'Preset: ${preset.name}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.coinGold,
                            ),
                          ),
                          onPressed: () => notifier.loadPattern(preset),
                        ),
                      ),
                    ],
                    // Saved Vault Patterns
                    for (final saved in state.savedPatterns) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xxs),
                        child: ActionChip(
                          key: Key('sketchpad_saved_${saved.id}'),
                          backgroundColor: AppColors.surfaceSecondary,
                          side: const BorderSide(color: AppColors.brandPrimary),
                          label: Text(
                            '💾 ${saved.name}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => notifier.loadPattern(saved),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // 4. Toolbar: Glide Mode, Euclidean Groove, Clear & Device-Specific Mode Controls
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    key: const Key('sketchpad_glide_mode_btn'),
                    selected: state.isGlideModeEnabled,
                    selectedColor: AppColors.brandPrimary,
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: state.isGlideModeEnabled
                          ? AppColors.brandPrimary
                          : AppColors.borderSubtle,
                    ),
                    label: Text(
                      '↘ Glide Slide (-5st)',
                      style: AppTypography.caption.copyWith(
                        color: state.isGlideModeEnabled
                            ? AppColors.brandContrast
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onSelected: (_) => notifier.toggleGlideMode(),
                  ),
                  ActionChip(
                    key: const Key('sketchpad_euclidean_groove_btn'),
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.coinGold),
                    label: Text(
                      '⚡ Euclidean Groove (${state.euclideanPulses} hits)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      final nextPulses = state.euclideanPulses >= 9
                          ? 5
                          : state.euclideanPulses + 1;
                      notifier.applyEuclideanGroove(pulses: nextPulses);
                    },
                  ),
                  if (!isDesktop)
                    ActionChip(
                      key: const Key('mobile_input_mode_toggle'),
                      backgroundColor: AppColors.surfaceSecondary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      label: Text(
                        state.isMobileLivePadMode
                            ? '🔢 Switch to 4-Step Grid'
                            : '🎛️ Switch to 8-Pad Scale Deck',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: notifier.toggleMobileInputMode,
                    ),
                  if (isDesktop) ...[
                    for (final mode in ChordStampMode.values)
                      ChoiceChip(
                        key: Key('desktop_chord_stamp_${mode.name}'),
                        selected: state.chordStampMode == mode,
                        selectedColor: AppColors.coinGold,
                        backgroundColor: AppColors.surfaceElevated,
                        label: Text(
                          mode.label,
                          style: AppTypography.caption.copyWith(
                            color: state.chordStampMode == mode
                                ? AppColors.brandContrast
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onSelected: (_) => notifier.setChordStampMode(mode),
                      ),
                  ],
                  ActionChip(
                    key: const Key('sketchpad_clear_grid_btn'),
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    label: Text(
                      'Clear',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onPressed: notifier.clearGrid,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // 5. Device-Adaptive Sequencer Surface
              Expanded(
                child: isDesktop
                    ? _DesktopWorkstationMatrix(
                        state: state,
                        notifier: notifier,
                      )
                    : _MobileAdaptiveSurface(state: state, notifier: notifier),
              ),
              const SizedBox(height: AppSpacing.xs),

              // 6. Bottom Action & Conditioning Deck
              Row(
                children: [
                  Text(
                    'Ref: ${(pattern.conditioningStrength * 100).round()}%',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(
                        context,
                      ).copyWith(overlayShape: SliderComponentShape.noOverlay),
                      child: Slider(
                        key: const Key('sketchpad_conditioning_slider'),
                        value: pattern.conditioningStrength.clamp(0.15, 0.95),
                        min: 0.15,
                        max: 0.95,
                        activeColor: AppColors.brandPrimary,
                        inactiveColor: AppColors.surfaceSecondary,
                        onChanged: notifier.setConditioningStrength,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('sketchpad_play_toggle_btn'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: state.isPlayingPreview ? 'Stop Loop' : 'Play Loop',
                    onPressed: notifier.togglePreviewPlayback,
                    icon: Icon(
                      state.isPlayingPreview
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AppColors.brandPrimary,
                      size: 26,
                    ),
                  ),
                  IconButton(
                    key: const Key('sketchpad_save_vault_btn'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'Save to Local Hive Vault',
                    onPressed: () async {
                      await notifier.saveCurrentToVault();
                    },
                    icon: const Icon(
                      Icons.bookmark_add_rounded,
                      color: AppColors.coinGold,
                      size: 22,
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('sketchpad_attach_reference_btn'),
                    onPressed: () {
                      notifier.attachAsSongReferenceAndMasterLayer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(110, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                    icon: const Icon(Icons.track_changes_rounded, size: 16),
                    label: Text(
                      isDesktop ? 'Attach Reference' : 'Attach',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📱 Mobile Native Surface (< 768px): Bar-Paginated 4-Step HIG Matrix + 8-Pad Live Scale Deck.
class _MobileAdaptiveSurface extends StatelessWidget {
  const _MobileAdaptiveSurface({required this.state, required this.notifier});

  final MelodySketchpadState state;
  final MelodySketchpadNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final pattern = state.activePattern;

    if (state.isMobileLivePadMode) {
      return GridView.builder(
        key: const Key('mobile_live_pad_deck'),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 2.2,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          final row = 7 - index; // High notes top, root sub-bass bottom
          final noteLabel = resolveScaleNoteLabel(
            pattern.musicalKey,
            pattern.scaleMode,
            row,
            instrument: pattern.instrument,
          );
          final freqHz = resolveScaleFrequencyHz(
            pattern.musicalKey,
            pattern.scaleMode,
            row,
            instrument: pattern.instrument,
          );

          return InkWell(
            key: Key('mobile_scale_pad_$row'),
            onTap: () => notifier.triggerLiveScalePad(row),
            borderRadius: AppRadius.cardBorder,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.coinGold.withAlpha(110)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Degree ${row + 1} • $noteLabel',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${freqHz.toStringAsFixed(1)} Hz',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coinGold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final barStartStep = state.activeMobileBarPage * 4;

    return Column(
      key: const Key('mobile_bar_grid'),
      children: [
        // 4 Bar Page Tabs ([Bar 1: 1-4] .. [Bar 4: 13-16])
        Row(
          children: List.generate(4, (barIdx) {
            final isSelected = state.activeMobileBarPage == barIdx;
            final startNum = barIdx * 4 + 1;
            final endNum = startNum + 3;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: barIdx < 3 ? AppSpacing.xxs : 0,
                ),
                child: InkWell(
                  key: Key('mobile_bar_page_$barIdx'),
                  onTap: () => notifier.setMobileBarPage(barIdx),
                  borderRadius: AppRadius.inputBorder,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.surfaceElevated,
                      borderRadius: AppRadius.inputBorder,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      'Bar ${barIdx + 1} ($startNum–$endNum)',
                      style: AppTypography.caption.copyWith(
                        color: isSelected
                            ? AppColors.brandContrast
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),

        // 8 Scale Rows × 4 Steps per Bar Page (Every cell >= 44x44dp!)
        Expanded(
          child: ListView.separated(
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, listIdx) {
              final row = 7 - listIdx;
              final noteLabel = resolveScaleNoteLabel(
                pattern.musicalKey,
                pattern.scaleMode,
                row,
                instrument: pattern.instrument,
              );

              return Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      noteLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (var offset = 0; offset < 4; offset++) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _SequencerCellWidget(
                          row: row,
                          step: barStartStep + offset,
                          note: pattern.noteAt(row, barStartStep + offset),
                          isPlayhead:
                              state.isPlayingPreview &&
                              state.currentPlayheadStep ==
                                  (barStartStep + offset),
                          onTap: () =>
                              notifier.toggleCell(row, barStartStep + offset),
                          onLongPress: () => notifier.toggleCell(
                            row,
                            barStartStep + offset,
                            forceGlide: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 🖥️ Desktop Native Workstation (> 1024px): Full 16-Step × 8-Row Split DAW Matrix + Velocity/Glide Lane.
class _DesktopWorkstationMatrix extends StatelessWidget {
  const _DesktopWorkstationMatrix({
    required this.state,
    required this.notifier,
  });

  final MelodySketchpadState state;
  final MelodySketchpadNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final pattern = state.activePattern;

    return Column(
      key: const Key('desktop_piano_roll_grid'),
      children: [
        // 8 Scale Rows × 16 Steps
        Expanded(
          child: ListView.separated(
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 3),
            itemBuilder: (context, listIdx) {
              final row = 7 - listIdx;
              final noteLabel = resolveScaleNoteLabel(
                pattern.musicalKey,
                pattern.scaleMode,
                row,
                instrument: pattern.instrument,
              );

              return Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      noteLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (var step = 0; step < 16; step++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: (step % 4 == 0 && step > 0) ? 4.0 : 1.5,
                          right: 1.5,
                        ),
                        child: _SequencerCellWidget(
                          row: row,
                          step: step,
                          note: pattern.noteAt(row, step),
                          isPlayhead:
                              state.isPlayingPreview &&
                              state.currentPlayheadStep == step,
                          onTap: () => notifier.toggleCell(row, step),
                          onLongPress: () =>
                              notifier.toggleCell(row, step, forceGlide: true),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Synchronized Bottom 16-Step Velocity & Glide Stalk Lane
        Container(
          key: const Key('desktop_velocity_lane'),
          height: 54,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.inputBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Vel/Glide',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              for (var step = 0; step < 16; step++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final stepNotes = pattern.notes
                          .where((n) => n.stepIndex == step)
                          .toList();
                      final maxVel = stepNotes.isEmpty
                          ? 0.0
                          : stepNotes
                                .map((n) => n.velocity)
                                .reduce((a, b) => a > b ? a : b);
                      final hasAnyGlide = stepNotes.any((n) => n.hasGlide);

                      return InkWell(
                        key: Key('desktop_step_glide_$step'),
                        onTap: () => notifier.toggleStepColumnGlide(step),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              hasAnyGlide ? '↘' : '${step + 1}',
                              style: AppTypography.badge.copyWith(
                                color: hasAnyGlide
                                    ? AppColors.brandPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 8,
                              height: (24.0 * maxVel).clamp(3.0, 24.0),
                              decoration: BoxDecoration(
                                color: stepNotes.isEmpty
                                    ? AppColors.borderSubtle
                                    : (hasAnyGlide
                                          ? AppColors.brandPrimary
                                          : AppColors.coinGold),
                                borderRadius: AppRadius.pillBorder,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SequencerCellWidget extends StatelessWidget {
  const _SequencerCellWidget({
    required this.row,
    required this.step,
    required this.note,
    required this.isPlayhead,
    required this.onTap,
    required this.onLongPress,
  });

  final int row;
  final int step;
  final MelodyStepNote? note;
  final bool isPlayhead;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isActive = note != null;
    final hasGlide = note?.hasGlide ?? false;

    return GestureDetector(
      key: Key('sketchpad_cell_${row}_$step'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? (hasGlide ? AppColors.brandPrimary : AppColors.coinGold)
              : (step % 4 == 0
                    ? AppColors.surfaceSecondary
                    : AppColors.surfaceElevated),
          borderRadius: AppRadius.thumbBorder,
          border: Border.all(
            color: isPlayhead
                ? AppColors.textPrimary
                : (isActive ? AppColors.brandContrast : AppColors.borderSubtle),
            width: isPlayhead ? 2.0 : 1.0,
          ),
        ),
        child: isActive
            ? Text(
                hasGlide ? '↘' : '●',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}
