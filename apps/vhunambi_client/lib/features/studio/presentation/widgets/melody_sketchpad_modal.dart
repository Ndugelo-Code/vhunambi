import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../providers/melody_sketchpad_provider.dart';
import 'studio_sound_pack_sheet.dart';

/// Phase 32 Studio-Grade Multi-Track Master Groove Sketchpad Modal.
///
/// Implements the FL Studio-style 5-channel sequencer (Lead, Chords, Bass, Drums, Hats)
/// adhering strictly to `STD-UIUX-001`:
/// - Row 1: Compact Curvy Top Bar (48dp) with Instrument/Kit picker, Key/Scale picker,
///   Sound Packs launcher, Fullscreen expansion toggle, and Close button.
/// - Row 2: Sliding Curvy Channel Rack Tabs (44dp) with Solo/Mute indicators and long-press mixer popover.
/// - Row 3: Curvy 16-Step Matrix with rounded pill squircle cells (>= 44x44dp), dynamic
///   drum rack voice labels, and long-press note inspector.
/// - Row 4: Minimal Master Transport Dock (52dp) with Master Play/Pause, BPM control,
///   Euclidean Auto-Beat, Glide, Clear, Vault Save, and Song Reference Attach.
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
          backgroundColor: const Color(
            0xFF16161C,
          ), // 100% Opaque surface (REQ-P51-FIX-03)
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 840),
            child: MelodySketchpadModal(initialInstrument: initialInstrument),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: Material(
          color: const Color(
            0xFF16161C,
          ), // 100% Opaque surface (REQ-P51-FIX-03)
          borderRadius: AppRadius.modalBorder,
          clipBehavior: Clip.antiAlias,
          child: MelodySketchpadModal(initialInstrument: initialInstrument),
        ),
      ),
    );
  }

  @override
  ConsumerState<MelodySketchpadModal> createState() =>
      _MelodySketchpadModalState();
}

class _MelodySketchpadModalState extends ConsumerState<MelodySketchpadModal> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isFullscreenLocal = false;
  StateController<int>? _modalSheetCounter;
  bool _didIncrementModalCount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(modalSheetOpenCountProvider.notifier);
      _modalSheetCounter = counter;
      _didIncrementModalCount = true;
      counter.state++;
      if (widget.initialInstrument != null) {
        ref
            .read(melodySketchpadProvider.notifier)
            .setInstrument(widget.initialInstrument!);
      }
    });
  }

  @override
  void dispose() {
    final counter = _modalSheetCounter;
    if (_didIncrementModalCount && counter != null) {
      _didIncrementModalCount = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
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

  void _openInstrumentPicker(BuildContext context, MelodySketchpadState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _InstrumentPickerSheet(
          activeInstrument: state.activePattern.instrument,
          activeBeatKit: state.currentChannelTrack.beatKit,
          isDrumsChannel: state.isDrumOrHatChannel,
          onSelectInstrument: (inst) {
            ref.read(melodySketchpadProvider.notifier).setInstrument(inst);
            Navigator.of(context).pop();
          },
          onSelectBeatKit: (kit) {
            ref.read(melodySketchpadProvider.notifier).setBeatKitGenre(kit);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openKeyScalePicker(BuildContext context, MelodySketchpadState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => _KeyScalePickerSheet(
        currentKey: state.activePattern.musicalKey,
        currentScale: state.activePattern.scaleMode,
        starterPresets: state.starterPresets,
        savedPatterns: state.savedPatterns,
        onSelectKey: (k) {
          ref.read(melodySketchpadProvider.notifier).setMusicalKey(k);
        },
        onSelectScale: (s) {
          ref.read(melodySketchpadProvider.notifier).setScaleMode(s);
        },
        onSelectPattern: (p) {
          ref.read(melodySketchpadProvider.notifier).loadPattern(p);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openChannelMixer(BuildContext context, SketchpadChannelRole role) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => _ChannelMixerSheet(role: role),
    );
  }

  void _openStepNoteInspector(
    BuildContext context,
    int row,
    int step,
    MelodyStepNote? currentNote,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => _StepNoteInspectorSheet(
        row: row,
        step: step,
        currentNote: currentNote,
      ),
    );
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===============================================================
              // Row 1: Compact Curvy Top Bar (48dp)
              // ===============================================================
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Instrument / Kit Selector Dropdown Pill
                            InkWell(
                              key: const Key(
                                'sketchpad_instrument_dropdown_btn',
                              ),
                              onTap: () =>
                                  _openInstrumentPicker(context, state),
                              borderRadius: AppRadius.pillBorder,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: AppColors.brandPrimary.withAlpha(
                                      120,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      state.isDrumOrHatChannel
                                          ? PhosphorIconsFill.waveform
                                          : _resolveInstrumentIcon(
                                              pattern.instrument,
                                            ),
                                      color: AppColors.brandPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 130,
                                      ),
                                      child: Text(
                                        state.isDrumOrHatChannel
                                            ? state
                                                  .currentChannelTrack
                                                  .beatKit
                                                  .label
                                            : pattern.instrument.label,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    PhosphorIcon(
                                      PhosphorIconsRegular.caretDown,
                                      color: AppColors.textSecondary,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),

                            // Musical Key & Scale Dropdown Pill
                            InkWell(
                              key: const Key(
                                'sketchpad_key_scale_dropdown_btn',
                              ),
                              onTap: () => _openKeyScalePicker(context, state),
                              borderRadius: AppRadius.pillBorder,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${pattern.musicalKey} • ${pattern.scaleMode.label} • ${pattern.bpm} BPM',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.coinGold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const PhosphorIcon(
                                      PhosphorIconsRegular.caretDown,
                                      color: AppColors.coinGold,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),

                    // In-App Sound Packs Launcher Button
                    IconButton(
                      key: const Key('sketchpad_open_sound_packs_btn'),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'Sound Packs & Expansion Kits',
                      onPressed: () => StudioSoundPackSheet.show(context),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.package,
                        color: AppColors.coinGold,
                        size: 20,
                      ),
                    ),

                    // Fullscreen Expansion Toggle Button
                    IconButton(
                      key: const Key('sketchpad_fullscreen_toggle_btn'),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: _isFullscreenLocal
                          ? 'Exit Fullscreen'
                          : 'Fullscreen Workstation',
                      onPressed: () {
                        setState(() {
                          _isFullscreenLocal = !_isFullscreenLocal;
                        });
                        notifier.toggleFullscreen();
                      },
                      icon: PhosphorIcon(
                        _isFullscreenLocal
                            ? PhosphorIconsRegular.cornersIn
                            : PhosphorIconsRegular.cornersOut,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),

                    // Close Modal Button
                    IconButton(
                      key: const Key('sketchpad_close_btn'),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: () {
                        notifier.stopPreviewPlayback();
                        Navigator.of(context).maybePop();
                      },
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.x,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Attached Reference Status Banner (if attached)
              if (state.attachedPattern != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    key: const Key('sketchpad_attached_ready_badge'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(28),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.success.withAlpha(90),
                      ),
                    ),
                    child: Row(
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsFill.checkCircle,
                          color: AppColors.success,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Attached (35% Master Mix): ${state.attachedPattern!.name}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ===============================================================
              // Row 2: Sliding Curvy Channel Rack Tabs (44dp)
              // ===============================================================
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SketchpadChannelRole.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final role = SketchpadChannelRole.values[index];
                    final isSelected = state.activeChannelRole == role;
                    final channel =
                        state.multiTrackGroove.channels[role] ??
                        state.multiTrackGroove.channels[SketchpadChannelRole
                            .lead]!;
                    final hasNotes = channel.steps.isNotEmpty;

                    return InkWell(
                      key: Key('sketchpad_channel_tab_${role.name}'),
                      onTap: () => notifier.switchChannel(role),
                      onLongPress: () => _openChannelMixer(context, role),
                      borderRadius: AppRadius.pillBorder,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandPrimary.withAlpha(36)
                              : AppColors.surfaceElevated,
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : (channel.isSolo
                                      ? AppColors.coinGold
                                      : AppColors.borderSubtle),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              _resolveChannelRoleIcon(role),
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : (channel.isMuted
                                        ? AppColors.textTertiary
                                        : AppColors.textSecondary),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              role.label,
                              style: AppTypography.caption.copyWith(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : (channel.isMuted
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (hasNotes) ...[
                              const SizedBox(width: 5),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            if (channel.isMuted) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withAlpha(40),
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                child: Text(
                                  'M',
                                  style: AppTypography.badge.copyWith(
                                    color: AppColors.error,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            if (channel.isSolo) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.coinGold.withAlpha(45),
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                child: Text(
                                  'S',
                                  style: AppTypography.badge.copyWith(
                                    color: AppColors.coinGold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Quick Actions Sub-strip (Apply DNA, Undo DNA, Euclidean Groove, Glide, Input Mode, Clear)
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (!isDesktop) ...[
                      ActionChip(
                        key: const Key('mobile_input_mode_toggle'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.surfaceSecondary,
                        side: BorderSide(color: AppColors.borderSubtle),
                        avatar: PhosphorIcon(
                          state.isMobileLivePadMode
                              ? PhosphorIconsRegular.squaresFour
                              : PhosphorIconsRegular.faders,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                        label: Text(
                          state.isMobileLivePadMode
                              ? '4-Step Grid'
                              : '8-Pad Deck',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: notifier.toggleMobileInputMode,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    // Phase 57: Apply DNA (Jev System-1 Calibrated Co-Creator)
                    ActionChip(
                      key: const Key('sketchpad_apply_dna_btn'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.brandPrimary.withAlpha(42),
                      side: const BorderSide(color: AppColors.brandPrimary),
                      avatar: const PhosphorIcon(
                        PhosphorIconsFill.dna,
                        size: 13,
                        color: AppColors.brandPrimary,
                      ),
                      label: Text(
                        'Apply DNA',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => notifier.applyDnaResynthesis(),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    // Phase 57: Conditional Undo DNA Button (10-State LIFO Stack)
                    if (state.canUndoDna) ...[
                      ActionChip(
                        key: const Key('sketchpad_undo_dna_btn'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.coinGold),
                        avatar: const PhosphorIcon(
                          PhosphorIconsRegular.arrowCounterClockwise,
                          size: 13,
                          color: AppColors.coinGold,
                        ),
                        label: Text(
                          'Undo (${state.dnaUndoStack.length})',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: notifier.undoDnaResynthesis,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    ActionChip(
                      key: const Key('sketchpad_euclidean_groove_btn'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.surfaceElevated,
                      side: const BorderSide(color: AppColors.coinGold),
                      avatar: const PhosphorIcon(
                        PhosphorIconsFill.sparkle,
                        size: 13,
                        color: AppColors.coinGold,
                      ),
                      label: Text(
                        'Groove (${state.euclideanPulses})',
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
                    const SizedBox(width: AppSpacing.xxs),
                    FilterChip(
                      key: const Key('sketchpad_glide_mode_btn'),
                      visualDensity: VisualDensity.compact,
                      selected: state.isGlideModeEnabled,
                      selectedColor: AppColors.brandPrimary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: state.isGlideModeEnabled
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                      avatar: PhosphorIcon(
                        PhosphorIconsRegular.arrowDownRight,
                        size: 13,
                        color: state.isGlideModeEnabled
                            ? AppColors.brandContrast
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        'Glide',
                        style: AppTypography.caption.copyWith(
                          color: state.isGlideModeEnabled
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onSelected: (_) => notifier.toggleGlideMode(),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    if (isDesktop) ...[
                      for (final mode in ChordStampMode.values) ...[
                        ChoiceChip(
                          key: Key('desktop_chord_stamp_${mode.name}'),
                          visualDensity: VisualDensity.compact,
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
                        const SizedBox(width: AppSpacing.xxs),
                      ],
                    ],
                    ActionChip(
                      key: const Key('sketchpad_clear_grid_btn'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(color: AppColors.borderSubtle),
                      avatar: PhosphorIcon(
                        PhosphorIconsRegular.trash,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
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
              ),
              if (state.lastDnaReport != null) ...[
                const SizedBox(height: 4),
                Container(
                  key: const Key('sketchpad_dna_report_banner'),
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(28),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: AppColors.brandPrimary.withAlpha(95),
                    ),
                  ),
                  child: Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.dna,
                        color: AppColors.brandPrimary,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.lastDnaReport!.summaryLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        key: const Key('sketchpad_dismiss_dna_report_btn'),
                        onTap: notifier.dismissDnaReport,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.x,
                            color: AppColors.textSecondary,
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),

              // ===============================================================
              // Row 3: Curvy 16-Step Matrix (Mobile 4-bar or Desktop 16-step)
              // ===============================================================
              Expanded(
                child: isDesktop
                    ? _DesktopWorkstationMatrix(
                        state: state,
                        notifier: notifier,
                        onInspectStep: (row, step, note) =>
                            _openStepNoteInspector(context, row, step, note),
                      )
                    : _MobileAdaptiveSurface(
                        state: state,
                        notifier: notifier,
                        onInspectStep: (row, step, note) =>
                            _openStepNoteInspector(context, row, step, note),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ===============================================================
              // Row 4: Minimal Master Transport Dock (52dp)
              // ===============================================================
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // Master Play/Pause Toggle Button
                    IconButton(
                      key: const Key('sketchpad_play_toggle_btn'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      tooltip: state.isPlayingPreview
                          ? 'Stop Master Groove'
                          : 'Play Master Groove',
                      onPressed: notifier.togglePreviewPlayback,
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPrimary.withAlpha(70),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PhosphorIcon(
                          state.isPlayingPreview
                              ? PhosphorIconsFill.stop
                              : PhosphorIconsFill.play,
                          color: AppColors.brandContrast,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Master Reference Conditioning Slider
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Ref: ${(pattern.conditioningStrength * 100).round()}%',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                overlayShape: SliderComponentShape.noOverlay,
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                key: const Key('sketchpad_conditioning_slider'),
                                value: pattern.conditioningStrength.clamp(
                                  0.15,
                                  0.95,
                                ),
                                min: 0.15,
                                max: 0.95,
                                activeColor: AppColors.brandPrimary,
                                inactiveColor: AppColors.surfaceSecondary,
                                onChanged: notifier.setConditioningStrength,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),

                    // Save to Vault Button
                    IconButton(
                      key: const Key('sketchpad_save_vault_btn'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      tooltip: 'Save Groove to Hive Vault',
                      onPressed: () async {
                        await notifier.saveCurrentToVault();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Master Groove saved to Local Vault',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.bookmarkSimple,
                        color: AppColors.coinGold,
                        size: 22,
                      ),
                    ),

                    // Attach as Song Reference Button
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
                        minimumSize: const Size(96, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonBorder,
                        ),
                      ),
                      icon: const PhosphorIcon(
                        PhosphorIconsFill.musicNotes,
                        size: 16,
                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _resolveInstrumentIcon(SketchpadInstrument inst) {
    switch (inst) {
      case SketchpadInstrument.concertGrandPiano:
      case SketchpadInstrument.classicPiano:
      case SketchpadInstrument.privateSchoolRhodes:
      case SketchpadInstrument.mbaqangaOrgan:
        return PhosphorIconsRegular.pianoKeys;
      case SketchpadInstrument.maskandiGuitar:
      case SketchpadInstrument.nylonGuitar:
      case SketchpadInstrument.electricGuitar:
        return PhosphorIconsRegular.guitar;
      case SketchpadInstrument.soloViolin:
        return PhosphorIconsRegular.waveSine;
      case SketchpadInstrument.vendaMbira:
      case SketchpadInstrument.marimbaWood:
        return PhosphorIconsRegular.dotsThreeOutline;
      case SketchpadInstrument.amapianoLogDrum:
      case SketchpadInstrument.hipHop808Sub:
      case SketchpadInstrument.gqomDarkSub:
        return PhosphorIconsRegular.speakerLow;
      case SketchpadInstrument.bambooFlute:
      case SketchpadInstrument.sopranoSax:
        return PhosphorIconsRegular.wind;
      case SketchpadInstrument.neoSoulPad:
        return PhosphorIconsRegular.sparkle;
    }
  }

  static IconData _resolveChannelRoleIcon(SketchpadChannelRole role) {
    switch (role) {
      case SketchpadChannelRole.lead:
        return PhosphorIconsRegular.pianoKeys;
      case SketchpadChannelRole.chords:
        return PhosphorIconsRegular.musicNotesPlus;
      case SketchpadChannelRole.bass:
        return PhosphorIconsRegular.waveSine;
      case SketchpadChannelRole.drums:
        return PhosphorIconsRegular.waveform;
      case SketchpadChannelRole.hats:
        return PhosphorIconsRegular.speakerHigh;
    }
  }
}

// =============================================================================
// Helper Component: Instrument & Drum Kit Picker Sheet
// =============================================================================
class _InstrumentPickerSheet extends StatelessWidget {
  const _InstrumentPickerSheet({
    required this.activeInstrument,
    required this.activeBeatKit,
    required this.isDrumsChannel,
    required this.onSelectInstrument,
    required this.onSelectBeatKit,
  });

  final SketchpadInstrument activeInstrument;
  final BeatKitGenre activeBeatKit;
  final bool isDrumsChannel;
  final ValueChanged<SketchpadInstrument> onSelectInstrument;
  final ValueChanged<BeatKitGenre> onSelectBeatKit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsFill.slidersHorizontal,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Select Instrument or Kit',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: [
                  // Studio Drum Kits
                  _buildSectionHeader('Studio Drum Kits (6 Genres)'),
                  for (final kit in BeatKitGenre.values) ...[
                    ListTile(
                      key: Key('sketchpad_kit_${kit.name}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadius.thumbBorder,
                        ),
                        child: const PhosphorIcon(
                          PhosphorIconsFill.waveform,
                          color: AppColors.brandPrimary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        kit.label,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Studio Rhythm Engine',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      trailing: activeBeatKit == kit && isDrumsChannel
                          ? const PhosphorIcon(
                              PhosphorIconsFill.checkCircle,
                              color: AppColors.brandPrimary,
                              size: 20,
                            )
                          : null,
                      onTap: () => onSelectBeatKit(kit),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // Melodic Keys & Strings
                  _buildSectionHeader('Melodic Keys & Strings'),
                  for (final inst in [
                    SketchpadInstrument.concertGrandPiano,
                    SketchpadInstrument.classicPiano,
                    SketchpadInstrument.privateSchoolRhodes,
                    SketchpadInstrument.maskandiGuitar,
                    SketchpadInstrument.nylonGuitar,
                    SketchpadInstrument.electricGuitar,
                    SketchpadInstrument.soloViolin,
                    SketchpadInstrument.vendaMbira,
                    SketchpadInstrument.marimbaWood,
                  ]) ...[_buildInstrumentTile(inst)],
                  const SizedBox(height: AppSpacing.md),

                  // Bass & Low-End
                  _buildSectionHeader('Bass & Low-End Engines'),
                  for (final inst in [
                    SketchpadInstrument.amapianoLogDrum,
                    SketchpadInstrument.hipHop808Sub,
                    SketchpadInstrument.gqomDarkSub,
                  ]) ...[_buildInstrumentTile(inst)],
                  const SizedBox(height: AppSpacing.md),

                  // Traditional, Wind & Pads
                  _buildSectionHeader('Traditional, Wind & Pads'),
                  for (final inst in [
                    SketchpadInstrument.bambooFlute,
                    SketchpadInstrument.sopranoSax,
                    SketchpadInstrument.neoSoulPad,
                    SketchpadInstrument.mbaqangaOrgan,
                  ]) ...[_buildInstrumentTile(inst)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.badge.copyWith(
          color: AppColors.coinGold,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInstrumentTile(SketchpadInstrument inst) {
    final isSelected = activeInstrument == inst && !isDrumsChannel;
    return ListTile(
      key: Key('sketchpad_inst_${inst.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.thumbBorder,
        ),
        child: PhosphorIcon(
          _MelodySketchpadModalState._resolveInstrumentIcon(inst),
          color: AppColors.coinGold,
          size: 18,
        ),
      ),
      title: Text(
        inst.label,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const PhosphorIcon(
              PhosphorIconsFill.checkCircle,
              color: AppColors.brandPrimary,
              size: 20,
            )
          : null,
      onTap: () => onSelectInstrument(inst),
    );
  }
}

// =============================================================================
// Helper Component: Key & Scale Picker Sheet
// =============================================================================
class _KeyScalePickerSheet extends StatelessWidget {
  const _KeyScalePickerSheet({
    required this.currentKey,
    required this.currentScale,
    required this.starterPresets,
    required this.savedPatterns,
    required this.onSelectKey,
    required this.onSelectScale,
    required this.onSelectPattern,
  });

  final String currentKey;
  final AfricanScaleMode currentScale;
  final List<MelodyPatternEntity> starterPresets;
  final List<MelodyPatternEntity> savedPatterns;
  final ValueChanged<String> onSelectKey;
  final ValueChanged<AfricanScaleMode> onSelectScale;
  final ValueChanged<MelodyPatternEntity> onSelectPattern;

  static const List<String> _musicalKeys = ['F#m', 'Am', 'Cm', 'Dm', 'Em', 'G'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ROOT MUSICAL KEY',
              style: AppTypography.badge.copyWith(
                color: AppColors.coinGold,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                for (final keyStr in _musicalKeys)
                  ActionChip(
                    key: Key('sketchpad_key_$keyStr'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: currentKey == keyStr
                        ? AppColors.coinGold
                        : AppColors.surfaceElevated,
                    side: BorderSide(
                      color: currentKey == keyStr
                          ? AppColors.coinGold
                          : AppColors.borderSubtle,
                    ),
                    label: Text(
                      keyStr,
                      style: AppTypography.caption.copyWith(
                        color: currentKey == keyStr
                            ? AppColors.brandContrast
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => onSelectKey(keyStr),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'SCALE MODE',
              style: AppTypography.badge.copyWith(
                color: AppColors.coinGold,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                for (final scale in AfricanScaleMode.values)
                  ActionChip(
                    key: Key('sketchpad_scale_${scale.name}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: currentScale == scale
                        ? AppColors.brandPrimary.withAlpha(45)
                        : AppColors.surfaceElevated,
                    side: BorderSide(
                      color: currentScale == scale
                          ? AppColors.brandPrimary
                          : AppColors.borderSubtle,
                    ),
                    label: Text(
                      scale.label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: currentScale == scale
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    onPressed: () => onSelectScale(scale),
                  ),
              ],
            ),
            if (starterPresets.isNotEmpty || savedPatterns.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'STARTER PRESETS & VAULT',
                style: AppTypography.badge.copyWith(
                  color: AppColors.coinGold,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final preset in starterPresets) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          key: Key('sketchpad_preset_${preset.id}'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.surfaceElevated,
                          side: BorderSide(color: AppColors.borderSubtle),
                          label: Text(
                            preset.name,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.coinGold,
                            ),
                          ),
                          onPressed: () => onSelectPattern(preset),
                        ),
                      ),
                    ],
                    for (final saved in savedPatterns) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          key: Key('sketchpad_saved_${saved.id}'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.surfaceSecondary,
                          side: const BorderSide(color: AppColors.brandPrimary),
                          avatar: const PhosphorIcon(
                            PhosphorIconsRegular.bookmarkSimple,
                            size: 13,
                            color: AppColors.coinGold,
                          ),
                          label: Text(
                            saved.name,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => onSelectPattern(saved),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Component: Channel Mixer Popover Sheet
// =============================================================================
class _ChannelMixerSheet extends ConsumerWidget {
  const _ChannelMixerSheet({required this.role});

  final SketchpadChannelRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(melodySketchpadProvider);
    final notifier = ref.read(melodySketchpadProvider.notifier);
    final channel =
        state.multiTrackGroove.channels[role] ??
        state.multiTrackGroove.channels[SketchpadChannelRole.lead]!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                PhosphorIcon(
                  _MelodySketchpadModalState._resolveChannelRoleIcon(role),
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${role.label} Channel Mixer',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Volume Slider
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.speakerHigh,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Volume (${(channel.volume * 100).round()}%)',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: channel.volume.clamp(0.0, 1.2),
                    min: 0.0,
                    max: 1.2,
                    activeColor: AppColors.brandPrimary,
                    inactiveColor: AppColors.surfaceSecondary,
                    onChanged: (vol) => notifier.setChannelVolume(role, vol),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Mute / Solo / Clear Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: channel.isMuted
                          ? AppColors.error
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: channel.isMuted
                            ? AppColors.error
                            : AppColors.borderSubtle,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                    onPressed: () => notifier.toggleChannelMute(role),
                    icon: PhosphorIcon(
                      channel.isMuted
                          ? PhosphorIconsFill.speakerSlash
                          : PhosphorIconsRegular.speakerHigh,
                      size: 16,
                    ),
                    label: Text(channel.isMuted ? 'Muted' : 'Mute'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: channel.isSolo
                          ? AppColors.coinGold
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: channel.isSolo
                            ? AppColors.coinGold
                            : AppColors.borderSubtle,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                    onPressed: () => notifier.toggleChannelSolo(role),
                    icon: PhosphorIcon(
                      channel.isSolo
                          ? PhosphorIconsFill.waveform
                          : PhosphorIconsRegular.waveform,
                      size: 16,
                    ),
                    label: Text(channel.isSolo ? 'Soloed' : 'Solo'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderSubtle),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                    onPressed: () {
                      notifier.clearChannel(role);
                      Navigator.of(context).pop();
                    },
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.trash,
                      size: 16,
                    ),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Component: Step Note Inspector Sheet (Long-Press Step Cell)
// =============================================================================
class _StepNoteInspectorSheet extends ConsumerStatefulWidget {
  const _StepNoteInspectorSheet({
    required this.row,
    required this.step,
    required this.currentNote,
  });

  final int row;
  final int step;
  final MelodyStepNote? currentNote;

  @override
  ConsumerState<_StepNoteInspectorSheet> createState() =>
      _StepNoteInspectorSheetState();
}

class _StepNoteInspectorSheetState
    extends ConsumerState<_StepNoteInspectorSheet> {
  late double _velocity;
  late bool _hasGlide;

  @override
  void initState() {
    super.initState();
    _velocity = widget.currentNote?.velocity ?? 0.85;
    _hasGlide = widget.currentNote?.hasGlide ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(melodySketchpadProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Step ${widget.step + 1} • Note Settings',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            // Velocity Slider
            Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.faders,
                  color: AppColors.coinGold,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Velocity: ${(_velocity * 100).round()}%',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _velocity.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    activeColor: AppColors.coinGold,
                    inactiveColor: AppColors.surfaceSecondary,
                    onChanged: (v) {
                      setState(() => _velocity = v);
                      // Toggle/update cell
                      notifier.toggleCell(
                        widget.row,
                        widget.step,
                        forceGlide: _hasGlide,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Glide Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pitch Glide (-5 Semitones)'),
              subtitle: const Text('Smooth Portamento slide transition'),
              value: _hasGlide,
              activeTrackColor: AppColors.brandPrimary,
              onChanged: (g) {
                setState(() => _hasGlide = g);
                notifier.toggleCell(widget.row, widget.step, forceGlide: g);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBorder,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Mobile Viewport Surface (< 768px): Bar-Paginated 4-Step HIG Matrix + 8-Pad Deck
// =============================================================================
class _MobileAdaptiveSurface extends StatelessWidget {
  const _MobileAdaptiveSurface({
    required this.state,
    required this.notifier,
    required this.onInspectStep,
  });

  final MelodySketchpadState state;
  final MelodySketchpadNotifier notifier;
  final void Function(int row, int step, MelodyStepNote? note) onInspectStep;

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
          final noteLabel = resolveChannelRowLabel(
            role: state.activeChannelRole,
            musicalKey: pattern.musicalKey,
            scale: pattern.scaleMode,
            scaleRow: row,
            instrument: pattern.instrument,
          );
          final freqHz = resolveScaleFrequencyHz(
            pattern.musicalKey,
            pattern.scaleMode,
            row,
            instrument: pattern.instrument,
            role: state.activeChannelRole,
          );

          return InkWell(
            key: Key('mobile_scale_pad_$row'),
            onTap: () => notifier.triggerLiveScalePad(row),
            borderRadius: AppRadius.cardBorder,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
                    state.isDrumOrHatChannel
                        ? noteLabel
                        : 'Degree ${row + 1} • $noteLabel',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    state.isHatsChannel
                        ? 'High-Freq Hat & Perc'
                        : (state.isDrumOrHatChannel
                              ? 'Studio Drum Voice'
                              : '${freqHz.toStringAsFixed(1)} Hz'),
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
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
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

        // 8 Rows × 4 Steps per Bar Page (Every cell >= 44x44dp!)
        Expanded(
          child: ListView.separated(
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, listIdx) {
              final row = 7 - listIdx;
              final noteLabel = resolveChannelRowLabel(
                role: state.activeChannelRole,
                musicalKey: pattern.musicalKey,
                scale: pattern.scaleMode,
                scaleRow: row,
                instrument: pattern.instrument,
              );

              return Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      noteLabel,
                      style: AppTypography.caption.copyWith(
                        color: state.isDrumOrHatChannel
                            ? AppColors.badgeCyan
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (var offset = 0; offset < 4; offset++) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _SequencerCellWidget(
                          row: row,
                          step: barStartStep + offset,
                          isDrumTrack: state.isDrumOrHatChannel,
                          note: pattern.noteAt(row, barStartStep + offset),
                          isPlayhead:
                              state.isPlayingPreview &&
                              state.currentPlayheadStep ==
                                  (barStartStep + offset),
                          onTap: () =>
                              notifier.toggleCell(row, barStartStep + offset),
                          onLongPress: () {
                            final existingNote = pattern.noteAt(
                              row,
                              barStartStep + offset,
                            );
                            if (existingNote != null) {
                              onInspectStep(
                                row,
                                barStartStep + offset,
                                existingNote,
                              );
                            } else {
                              notifier.toggleCell(
                                row,
                                barStartStep + offset,
                                forceGlide: true,
                              );
                            }
                          },
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

// =============================================================================
// Desktop Workstation Surface (> 1024px): 16-Step × 8-Row Piano Roll + Stalk Lane
// =============================================================================
class _DesktopWorkstationMatrix extends StatelessWidget {
  const _DesktopWorkstationMatrix({
    required this.state,
    required this.notifier,
    required this.onInspectStep,
  });

  final MelodySketchpadState state;
  final MelodySketchpadNotifier notifier;
  final void Function(int row, int step, MelodyStepNote? note) onInspectStep;

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
              final noteLabel = resolveChannelRowLabel(
                role: state.activeChannelRole,
                musicalKey: pattern.musicalKey,
                scale: pattern.scaleMode,
                scaleRow: row,
                instrument: pattern.instrument,
              );

              return Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      noteLabel,
                      style: AppTypography.caption.copyWith(
                        color: state.isDrumOrHatChannel
                            ? AppColors.badgeCyan
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                          isDrumTrack: state.isDrumOrHatChannel,
                          note: pattern.noteAt(row, step),
                          isPlayhead:
                              state.isPlayingPreview &&
                              state.currentPlayheadStep == step,
                          onTap: () => notifier.toggleCell(row, step),
                          onLongPress: () {
                            final existing = pattern.noteAt(row, step);
                            if (existing != null) {
                              onInspectStep(row, step, existing);
                            } else {
                              notifier.toggleCell(row, step, forceGlide: true);
                            }
                          },
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
                width: 58,
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
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              hasAnyGlide ? 'GL' : '${step + 1}',
                              style: AppTypography.badge.copyWith(
                                color: hasAnyGlide
                                    ? AppColors.brandPrimary
                                    : AppColors.textTertiary,
                                fontSize: 9,
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

// =============================================================================
// Sequencer Cell Widget: Rounded Squircle with Zero-Bleed Touch Physics
// =============================================================================
class _SequencerCellWidget extends StatelessWidget {
  const _SequencerCellWidget({
    required this.row,
    required this.step,
    required this.isDrumTrack,
    required this.note,
    required this.isPlayhead,
    required this.onTap,
    required this.onLongPress,
  });

  final int row;
  final int step;
  final bool isDrumTrack;
  final MelodyStepNote? note;
  final bool isPlayhead;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isActive = note != null;
    final hasGlide = note?.hasGlide ?? false;

    Color activeColor;
    if (isDrumTrack) {
      activeColor = AppColors.badgeCyan;
    } else if (hasGlide) {
      activeColor = AppColors.brandPrimary;
    } else {
      activeColor = AppColors.coinGold;
    }

    return GestureDetector(
      key: Key('sketchpad_cell_${row}_$step'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor
              : (step % 4 == 0
                    ? AppColors.surfaceSecondary
                    : AppColors.surfaceElevated),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlayhead
                ? AppColors.textPrimary
                : (isActive ? AppColors.brandContrast : AppColors.borderSubtle),
            width: isPlayhead ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(90),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: isActive
            ? (hasGlide
                  ? const PhosphorIcon(
                      PhosphorIconsRegular.arrowDownRight,
                      color: AppColors.brandContrast,
                      size: 14,
                    )
                  : Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.brandContrast,
                        shape: BoxShape.circle,
                      ),
                    ))
            : null,
      ),
    );
  }
}
