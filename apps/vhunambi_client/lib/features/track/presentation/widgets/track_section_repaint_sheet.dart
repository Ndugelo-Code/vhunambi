import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../studio/presentation/providers/studio_lora_registry_provider.dart';
import '../../../studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart';
import '../../../studio/presentation/widgets/lora_factory_status_sheet.dart';
import '../../domain/models/track_detail_models.dart';
import '../providers/track_providers.dart';

/// Post-Generation Section Repaint, Stem Inpainting & African LoRA Sheet (`EP-P83-TRACK-REPAINT-COCKPIT`).
///
/// Hosts the relocated & STD-UIUX-001 hardened [CockpitQuantumEntanglementRack], BPM-aware
/// `[startSec..endSec]` range scrubber, ACE-Step 1.5 XL-Base task mode selector, and
/// Sovereign African LoRA Pack + blend weight controls.
class TrackSectionRepaintSheet extends ConsumerStatefulWidget {
  final TrackDetailEntity track;

  const TrackSectionRepaintSheet({super.key, required this.track});

  static Future<void> show(
    BuildContext context, {
    required TrackDetailEntity track,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: TrackSectionRepaintSheet(track: track),
      ),
    );
  }

  @override
  ConsumerState<TrackSectionRepaintSheet> createState() =>
      _TrackSectionRepaintSheetState();
}

class _TrackSectionRepaintSheetState
    extends ConsumerState<TrackSectionRepaintSheet> {
  late double _maxSec;
  late double _startSec;
  late double _endSec;
  String _task = 'repaint';
  String _targetStem = 'full';
  String? _selectedLoraId;
  double _loraWeight = 0.85;
  bool _isSubmitting = false;
  late final TextEditingController _lyricsController;

  StateController<int>? _modalSheetCounter;
  bool _didIncrementModalCount = false;

  @override
  void initState() {
    super.initState();
    _maxSec = math.max(10.0, widget.track.duration.inSeconds.toDouble());
    _startSec = math.min(16.0, math.max(0.0, _maxSec * 0.15));
    _endSec = math.min(_maxSec, math.max(_startSec + 4.0, _startSec + 16.0));
    if (widget.track.activeLoras.isNotEmpty) {
      _selectedLoraId = widget.track.activeLoras.first;
    }
    _lyricsController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(modalSheetOpenCountProvider.notifier);
      _modalSheetCounter = counter;
      _didIncrementModalCount = true;
      counter.state++;
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
    _lyricsController.dispose();
    super.dispose();
  }

  String _barSpanLabel() {
    final bpm = math.max(50, widget.track.bpm);
    final barSec = 240.0 / bpm;
    final startBar = (_startSec / barSec).floor() + 1;
    final endBar = math.max(startBar, (_endSec / barSec).ceil());
    return 'Bar $startBar-$endBar · ${_startSec.toStringAsFixed(1)}s - ${_endSec.toStringAsFixed(1)}s';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final stemLockMap = ref
        .read(studioFormProvider)
        .branchStemLockModes
        .map((k, v) => MapEntry(k, v.name));

    final loras = _selectedLoraId != null
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'loraId': _selectedLoraId!,
              'weight': _loraWeight,
            },
          ]
        : null;

    final err = await ref
        .read(trackDetailFamilyProvider(widget.track.id).notifier)
        .submitSectionRepaint(
          startSec: _startSec,
          endSec: _endSec,
          task: _task,
          targetStem: _targetStem,
          stemLocks: stemLockMap,
          editLyrics: _lyricsController.text,
          loras: loras,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Queued ${_task.toUpperCase()} (${_startSec.toStringAsFixed(1)}s-${_endSec.toStringAsFixed(1)}s) on ACE-Step 1.5 XL-Base.',
        ),
        backgroundColor: AppColors.surfaceElevatedOf(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    final controlsLeft = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VhunambiGlassSurface(
          variant: VhunambiGlassVariant.card,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SECTION WINDOW',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    _barSpanLabel(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              RangeSlider(
                key: const Key('repaint_range_slider'),
                min: 0.0,
                max: _maxSec,
                activeColor: AppColors.brandPrimary,
                inactiveColor: AppColors.borderSubtleOf(context),
                values: RangeValues(_startSec, _endSec),
                onChanged: (values) {
                  var nextStart = values.start;
                  var nextEnd = values.end;
                  if (nextEnd - nextStart < 2.0) {
                    if (nextStart + 2.0 <= _maxSec) {
                      nextEnd = nextStart + 2.0;
                    } else {
                      nextStart = math.max(0.0, _maxSec - 2.0);
                      nextEnd = _maxSec;
                    }
                  }
                  setState(() {
                    _startSec = nextStart;
                    _endSec = nextEnd;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  for (final entry in <String, String>{
                    'repaint': 'Repaint',
                    'lego': 'Stem Lego',
                    'complete': 'Extend',
                  }.entries) ...[
                    if (entry.key != 'repaint') const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        key: Key('repaint_task_${entry.key}'),
                        borderRadius: AppRadius.pillBorder,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _task = entry.key);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _task == entry.key
                                ? AppColors.brandPrimary.withValues(alpha: 0.18)
                                : AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: _task == entry.key
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Text(
                            entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: _task == entry.key
                                  ? AppColors.brandPrimary
                                  : textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final stem in const <String>[
                    'full',
                    'vocals',
                    'drums',
                    'bass',
                    'melodic',
                  ])
                    InkWell(
                      key: Key('repaint_target_stem_$stem'),
                      borderRadius: AppRadius.pillBorder,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _targetStem = stem);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _targetStem == stem
                              ? AppColors.badgeCyan.withValues(alpha: 0.16)
                              : AppColors.surfaceSecondaryOf(context),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: _targetStem == stem
                                ? AppColors.badgeCyan
                                : AppColors.borderSubtleOf(context),
                          ),
                        ),
                        child: Text(
                          stem[0].toUpperCase() + stem.substring(1),
                          style: AppTypography.caption.copyWith(
                            color: _targetStem == stem
                                ? AppColors.badgeCyan
                                : textPrimary,
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
        const CockpitQuantumEntanglementRack(),
      ],
    );

    final controlsRight = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VhunambiGlassSurface(
          variant: VhunambiGlassVariant.card,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PhosphorIcon(
                    PhosphorIconsRegular.vinylRecord,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sovereign African LoRA Pack',
                      style: AppTypography.titleSmall.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('repaint_open_lora_factory_btn'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => LoraFactoryStatusSheet.show(context),
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.cpu,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    label: Text(
                      'Factory',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedLoraId == null
                        ? 'Auto'
                        : _loraWeight.toStringAsFixed(2),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                key: const Key('repaint_lora_picker'),
                height: 44,
                child: Builder(
                  builder: (context) {
                    final factoryPacks = ref
                        .watch(studioLoraRegistryProvider)
                        .packs;
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: factoryPacks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final pack = factoryPacks[idx];
                        final selected = _selectedLoraId == pack.loraId;
                        final statusDot = pack.isActive
                            ? AppColors.success
                            : (pack.hasEnoughSourceTracks
                                  ? AppColors.coinGold
                                  : AppColors.borderSubtleOf(context));
                        return InkWell(
                          key: Key('repaint_lora_chip_${pack.loraId}'),
                          borderRadius: AppRadius.pillBorder,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedLoraId = selected ? null : pack.loraId;
                              _loraWeight = pack.defaultWeight;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brandPrimary.withValues(
                                      alpha: 0.18,
                                    )
                                  : AppColors.surfaceSecondaryOf(context),
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(
                                color: selected
                                    ? AppColors.brandPrimary
                                    : AppColors.borderSubtleOf(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: statusDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  pack.label,
                                  style: AppTypography.caption.copyWith(
                                    color: selected
                                        ? AppColors.brandPrimary
                                        : textPrimary,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_selectedLoraId != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Slider(
                  min: 0.10,
                  max: 1.20,
                  divisions: 22,
                  activeColor: AppColors.brandPrimary,
                  value: _loraWeight,
                  onChanged: (v) => setState(() => _loraWeight = v),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('repaint_edit_lyrics_field'),
                controller: _lyricsController,
                maxLines: 2,
                style: AppTypography.bodySmall.copyWith(color: textPrimary),
                decoration: InputDecoration(
                  hintText:
                      'Optional section lyrics or instrumental drop cue...',
                  hintStyle: AppTypography.caption.copyWith(
                    color: textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSecondaryOf(context),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorder,
                    borderSide: BorderSide(
                      color: AppColors.borderSubtleOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('repaint_submit_btn'),
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            icon: _isSubmitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandContrast,
                    ),
                  )
                : const PhosphorIcon(PhosphorIconsBold.magicWand, size: 18),
            label: Text(
              _isSubmitting
                  ? 'Dispatching XL-Base...'
                  : 'Repaint ${_startSec.toStringAsFixed(0)}s-${_endSec.toStringAsFixed(0)}s',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      key: const Key('track_section_repaint_sheet'),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: AppRadius.modalBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtleOf(context),
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.x,
                      color: textPrimary,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section Repaint & Inpaint',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.track.title} · ${widget.track.bpm} BPM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PhosphorIcon(
                    AppIcons.sparkle,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: controlsLeft),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(flex: 9, child: controlsRight),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          controlsLeft,
                          const SizedBox(height: AppSpacing.md),
                          controlsRight,
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
