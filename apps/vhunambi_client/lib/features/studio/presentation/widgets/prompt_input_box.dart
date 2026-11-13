import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../domain/models/prompt_enhancement_result.dart';
import '../../domain/models/studio_form_state.dart';
import '../../domain/services/studio_prompt_intelligence.dart';
import '../providers/studio_form_provider.dart';
import '../utils/studio_haptics.dart';
import 'prompt_intelligence_overlay.dart';
import 'pulsing_aura_container.dart';

class PromptInputBox extends ConsumerStatefulWidget {
  const PromptInputBox({super.key});

  @override
  ConsumerState<PromptInputBox> createState() => _PromptInputBoxState();
}

class _PromptInputBoxState extends ConsumerState<PromptInputBox> {
  late final TextEditingController _controller;

  /// Debounce timer driving the AI prompt refinement pass (M10 / REQ-PRI-03).
  Timer? _enhanceTimer;

  PromptEnhancementResult? _intelligenceResult;
  final Set<String> _dismissedSuggestions = <String>{};

  static const Duration _typingPause = Duration(milliseconds: 1500);

  /// 9-preset inspiration pool; 3 are shown at a time, DNA-routed
  /// (M10 / REQ-PRI-01). Keys `studio_preset_chip_0` … `studio_preset_chip_8`
  /// address each pool entry.
  static const List<_PromptPreset> _presetPool = [
    _PromptPreset(
      shortLabel: 'A heartbreak track...',
      genreTag: '',
      fullPrompt:
          'A heartbreak track about leaving the village for the city lights, with mournful log drums and deep emotion.',
    ),
    _PromptPreset(
      shortLabel: 'Late-night log drum...',
      genreTag: 'amapiano',
      fullPrompt:
          'Late-night log drum session, dark heavy basslines with hypnotic jazz chords and energetic township chants.',
    ),
    _PromptPreset(
      shortLabel: 'Township love story...',
      genreTag: 'afrobeats',
      fullPrompt:
          'Township love story — two people meeting at a street festival on a warm sunny afternoon in Soweto.',
    ),
    _PromptPreset(
      shortLabel: 'Gospel choir anthem...',
      genreTag: 'gospel',
      fullPrompt:
          'Powerful gospel choir anthem with rich SATB harmonies, organ swells, and a triumphant testimony-style lead vocal.',
    ),
    _PromptPreset(
      shortLabel: 'Dark Durban gqom...',
      genreTag: 'gqom',
      fullPrompt:
          'Underground Durban gqom banger with heavy 808 sub hits, metallic claps, and dark hypnotic tension.',
    ),
    _PromptPreset(
      shortLabel: 'Maskandi homecoming...',
      genreTag: 'maskandi',
      fullPrompt:
          'A reflective Maskandi acoustic guitar storytelling piece about homecoming in KwaZulu-Natal with melodic call-and-response.',
    ),
    _PromptPreset(
      shortLabel: 'Sunny Afrobeats...',
      genreTag: 'afrobeats',
      fullPrompt:
          'Sunny Afrobeats anthem with bright electric guitar plucks, upbeat percussion groove, and catchy melodic duet vocals.',
    ),
    _PromptPreset(
      shortLabel: 'Afro Soul lament...',
      genreTag: 'soul',
      fullPrompt:
          'A soulful Afro Soul lament with warm rhodes chords, gentle shakers, and emotive vocals carrying deep ancestral wisdom.',
    ),
    _PromptPreset(
      shortLabel: 'Kwaito street party...',
      genreTag: 'kwaito',
      fullPrompt:
          'A raw Kwaito street party jam with township basslines, whistles, and hyped group chants from the block.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(studioFormProvider).prompt,
    );
  }

  @override
  void dispose() {
    _enhanceTimer?.cancel();
    _enhanceTimer = null;
    _controller.dispose();
    super.dispose();
  }

  /// Schedules the debounced prompt intelligence pass (M10 / REQ-PRI-03).
  void _onPromptChanged(String value) {
    ref.read(studioFormProvider.notifier).updatePrompt(value);
    _enhanceTimer?.cancel();
    _enhanceTimer = Timer(_typingPause, () => _runPromptIntelligence(value));
  }

  /// Runs the pure-Dart enhancement pass and surfaces the overlay when
  /// meaningful signals were detected (REQ-PRI-04).
  void _runPromptIntelligence(String rawPrompt) {
    if (!mounted) return;
    final dna = ref.read(creatorDnaProvider);
    final form = ref.read(studioFormProvider);
    final result = StudioPromptIntelligence.enhance(
      rawPrompt,
      dna: dna.onboardingCompleted ? dna : null,
      currentForm: form,
    );
    setState(() {
      _dismissedSuggestions.clear();
      _intelligenceResult = result.hasOverrides && rawPrompt.trim().length >= 10
          ? result
          : null;
    });
  }

  void _applyOverride(String fieldName, Object? value) {
    final notifier = ref.read(studioFormProvider.notifier);
    switch (fieldName) {
      case 'genre':
        notifier.setGenre(value.toString());
      case 'language':
        notifier.setLanguage(value.toString());
      case 'mood':
        notifier.setMood(value.toString());
      case 'vocalGender':
        notifier.setVocalGender(
          VocalGender.values.firstWhere(
            (g) => g.name == value.toString(),
            orElse: () => VocalGender.mixed,
          ),
        );
      case 'vocalMode':
        notifier.setVocalMode(
          VocalMode.values.firstWhere(
            (m) => m.name == value.toString(),
            orElse: () => VocalMode.auto,
          ),
        );
    }
  }

  void _applyAllSuggestions() {
    final result = _intelligenceResult;
    if (result == null) return;
    for (final entry in result.suggestedOverrides.entries) {
      if (_dismissedSuggestions.contains(entry.key)) continue;
      _applyOverride(entry.key, entry.value);
    }
    ref.read(studioFormProvider.notifier).updatePrompt(result.enhancedPrompt);
    setState(() => _intelligenceResult = null);
  }

  /// 1-tap DNA pre-fill: enriches the current draft with on-device taste
  /// signals and applies the resulting overrides (M10 / REQ-PRI-02).
  void _applyDnaPrefill() {
    final dna = ref.read(creatorDnaProvider);
    final form = ref.read(studioFormProvider);
    final base = form.prompt.trim().isEmpty
        ? 'A soulful track that fits my sound'
        : form.prompt;
    final result = StudioPromptIntelligence.enhance(
      base,
      dna: dna,
      currentForm: form,
    );
    for (final entry in result.suggestedOverrides.entries) {
      _applyOverride(entry.key, entry.value);
    }
    ref.read(studioFormProvider.notifier).updatePrompt(result.enhancedPrompt);
    unawaited(StudioHaptics.successPulse());
    setState(() {
      _dismissedSuggestions.clear();
      _intelligenceResult = null;
    });
  }

  /// 3 preset chips are shown; DNA top-genre matches win the slots.
  List<_PromptPreset> _visiblePresets(CreatorDnaProfile dna) {
    if (!dna.onboardingCompleted || dna.genreWeights.isEmpty) {
      return _presetPool.take(3).toList();
    }
    final ranked = dna.topGenres(3);
    final matched = <_PromptPreset>[
      for (final genre in ranked)
        ..._presetPool.where(
          (p) =>
              p.genreTag.isNotEmpty && genre.toLowerCase().contains(p.genreTag),
        ),
    ];
    if (matched.isEmpty) return _presetPool.take(3).toList();
    final seen = <String>{};
    final routed = <_PromptPreset>[
      for (final preset in matched)
        if (seen.add(preset.shortLabel)) preset,
    ];
    for (final preset in _presetPool) {
      if (routed.length >= 3) break;
      if (seen.add(preset.shortLabel)) routed.add(preset);
    }
    return routed.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dna = ref.watch(creatorDnaProvider);

    // Synchronize controller text when changed externally (e.g. inspire me or presets)
    ref.listen(studioFormProvider.select((s) => s.prompt), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('Describe your song', style: AppTypography.titleMedium),
            const Spacer(),
            // DNA pre-fill (M10 / REQ-PRI-02) — only once taste exists.
            if (dna.onboardingCompleted && dna.strengthPercent > 0)
              InkWell(
                key: const Key('studio_dna_prefill_btn'),
                onTap: _applyDnaPrefill,
                borderRadius: AppRadius.pillBorder,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(20),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: AppColors.brandPrimary.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧬', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Use My DNA',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Multiline Input Box (breathing AI aura while refining — REQ-KIN-04)
        PulsingAuraContainer(
          isPulsing:
              _intelligenceResult != null || (_enhanceTimer?.isActive ?? false),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onPromptChanged,
              maxLines: 5,
              minLines: 3,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.brandPrimary,
              decoration: InputDecoration(
                hintText:
                    'A powerful anthem about rising from hardship, full of hope and energy...',
                hintStyle: AppTypography.bodyMuted.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorder,
                  borderSide: const BorderSide(
                    color: AppColors.brandPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        // AI refinement overlay (M10 / REQ-PRI-04) — appears after a
        // 1500ms typing pause when meaningful signals were detected.
        if (_intelligenceResult != null)
          PromptIntelligenceOverlay(
            result: _intelligenceResult!,
            dismissedFields: _dismissedSuggestions,
            onApplyOverride: (field, value) {
              _applyOverride(field, value);
              setState(() => _dismissedSuggestions.add(field));
            },
            onDismissSuggestion: (field) {
              setState(() => _dismissedSuggestions.add(field));
            },
            onApplyAll: _applyAllSuggestions,
            onDismiss: () => setState(() => _intelligenceResult = null),
          ),
        const SizedBox(height: AppSpacing.sm),

        // Quick Preset Chips and Inspire Me Row (DNA-routed, M10 / REQ-PRI-01)
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._visiblePresets(dna).asMap().entries.map(
              (entry) => InkWell(
                key: Key('studio_preset_chip_${entry.key}'),
                onTap: () {
                  unawaited(StudioHaptics.chipSnap());
                  ref
                      .read(studioFormProvider.notifier)
                      .applyPromptPreset(entry.value.fullPrompt);
                },
                borderRadius: AppRadius.pillBorder,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    entry.value.shortLabel,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            // Inspire Me Button
            InkWell(
              onTap: () {
                ref.read(studioFormProvider.notifier).inspireMe();
              },
              borderRadius: AppRadius.pillBorder,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.brandPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Inspire Me',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromptPreset {
  final String shortLabel;

  /// Lowercase genre keyword used to DNA-route this preset (`''` = generic).
  final String genreTag;
  final String fullPrompt;

  const _PromptPreset({
    required this.shortLabel,
    required this.genreTag,
    required this.fullPrompt,
  });
}
