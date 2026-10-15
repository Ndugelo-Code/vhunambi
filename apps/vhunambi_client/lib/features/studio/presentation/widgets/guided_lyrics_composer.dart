import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/models/lyrics_section_scaffold.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/lyrics_review_provider.dart';
import '../providers/studio_form_provider.dart';
import '../utils/studio_haptics.dart';
import 'bantu_language_switcher.dart';
import 'tactile_pressable.dart';

/// Sequential section-by-section lyrics authoring scaffold (M10 /
/// REQ-GLC-01 → REQ-GLC-08).
///
/// Guides the creator through Intro → Verse 1 → Chorus → Verse 2 → Bridge →
/// Outro with genre-aware atmosphere chips, a debounced AI hint panel, and
/// an integrated [BantuLanguageSwitcher]. On completion the assembled lyrics
/// land in `studioFormProvider.customLyrics` (and the open lyrics review
/// draft when one exists).
class GuidedLyricsComposer extends ConsumerStatefulWidget {
  const GuidedLyricsComposer({super.key, this.onDone});

  /// Key: `Key('guided_lyrics_composer')`.
  static const Key composerKey = Key('guided_lyrics_composer');

  /// Presents the composer as a mobile bottom sheet / desktop dialog.
  static Future<void> show(BuildContext context, {VoidCallback? onDone}) {
    if (!ResponsiveUtils.isDesktop(context)) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceModal,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.modalBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        builder: (_) => GuidedLyricsComposer(onDone: onDone),
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceModal,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: GuidedLyricsComposer(onDone: onDone),
        ),
      ),
    );
  }

  /// Invoked after the assembled lyrics are handed to the form.
  final VoidCallback? onDone;

  @override
  ConsumerState<GuidedLyricsComposer> createState() =>
      _GuidedLyricsComposerState();
}

class _GuidedLyricsComposerState extends ConsumerState<GuidedLyricsComposer> {
  int _currentIndex = 0;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, List<String>> _sectionLines = <String, List<String>>{};

  Timer? _hintTimer;
  String? _hint;
  bool _hintShown = false;

  static const Duration _hintPause = Duration(milliseconds: 1500);

  TextEditingController _controllerFor(String title) => _controllers.putIfAbsent(
        title,
        () => TextEditingController(),
      );

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintTimer = null;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _hintFor(LyricsSectionScaffold scaffold) => switch (scaffold.type) {
        LyricsSectionType.intro =>
          'Open with an image: place the listener somewhere specific (a taxi '
              'rank at dawn, a Limpopo riverbank).',
        LyricsSectionType.verse =>
          'Ground the story in details — names, places, smells. Concrete '
              'beats abstract every time.',
        LyricsSectionType.chorus =>
          'Aim for a line you could chant with friends: short, rhythmic, '
              'and repeatable.',
        LyricsSectionType.bridge =>
          'Flip the perspective or raise the stakes before the final chorus.',
        LyricsSectionType.outro =>
          'End with a callback to your opening line — songs love circular '
              'endings.',
        LyricsSectionType.hook =>
          'Make it the catchiest 1–2 lines of the whole song.',
      };

  void _onSectionChanged(String title, String scaffoldHint) {
    if (_hintTimer?.isActive ?? false) _hintTimer?.cancel();
    if (_hintShown) return;
    _hintTimer = Timer(_hintPause, () {
      if (!mounted || _hintShown) return;
      setState(() {
        _hint = scaffoldHint;
        _hintShown = true;
      });
    });
  }

  void _saveCurrentSection() {
    final scaffold = kGuidedComposerScaffold[_currentIndex];
    final text = _controllerFor(scaffold.title).text;
    _sectionLines[scaffold.title] = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _appendAtmosphere(AtmosphereDescriptor descriptor) {
    final scaffold = kGuidedComposerScaffold[_currentIndex];
    final controller = _controllerFor(scaffold.title);
    unawaited(StudioHaptics.chipSnap());
    setState(() {
      final existing = controller.text.trim();
      controller.text = existing.isEmpty
          ? descriptor.label
          : '$existing\n${descriptor.label}';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    });
  }

  void _goBack() {
    if (_currentIndex == 0) return;
    _saveCurrentSection();
    unawaited(StudioHaptics.deckSwitch());
    setState(() => _currentIndex--);
  }

  void _goNext() {
    _saveCurrentSection();
    if (_currentIndex >= kGuidedComposerScaffold.length - 1) {
      _finish();
      return;
    }
    unawaited(StudioHaptics.deckSwitch());
    setState(() => _currentIndex++);
  }

  void _skipSection() {
    _saveCurrentSection();
    if (_currentIndex >= kGuidedComposerScaffold.length - 1) {
      _finish();
      return;
    }
    unawaited(StudioHaptics.chipSnap());
    setState(() => _currentIndex++);
  }

  /// Assembles the authored sections and hands them to the studio form (and
  /// the open lyrics review draft when present) — REQ-GLC-07 / REQ-GLC-08.
  void _finish() {
    _saveCurrentSection();

    final buffer = StringBuffer();
    for (final scaffold in kGuidedComposerScaffold) {
      final lines = _sectionLines[scaffold.title] ?? const <String>[];
      if (lines.isEmpty) continue;
      buffer.writeln('[${scaffold.title}]');
      for (final line in lines) {
        buffer.writeln(line);
      }
    }
    final rawLyrics = buffer.toString().trim();
    if (rawLyrics.isEmpty) {
      widget.onDone?.call();
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final formNotifier = ref.read(studioFormProvider.notifier);
    formNotifier.setCustomLyrics(rawLyrics);
    formNotifier.setLyricsMode(LyricsMode.myOwn);

    // Pre-populate an open review draft stanza-by-stanza (REQ-GLC-07) so the
    // review cockpit opens with the authored content already in place.
    final reviewDraft = ref.read(lyricsReviewProvider);
    if (reviewDraft != null) {
      final reviewNotifier = ref.read(lyricsReviewProvider.notifier);
      var sectionIndex = 0;
      for (final scaffold in kGuidedComposerScaffold) {
        final lines = _sectionLines[scaffold.title] ?? const <String>[];
        if (lines.isEmpty) continue;
        if (sectionIndex >= reviewDraft.sections.length) break;
        reviewNotifier.updateSectionLines(
          reviewDraft.sections[sectionIndex].id,
          lines,
        );
        sectionIndex++;
      }
    }

    unawaited(StudioHaptics.successPulse());
    widget.onDone?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = kGuidedComposerScaffold[_currentIndex];
    final controller = _controllerFor(scaffold.title);
    final formState = ref.watch(studioFormProvider);
    final genre = formState.genre;

    final genreMap = kGenreAtmosphereLibrary[genre] ??
        kGenreAtmosphereLibrary['Amapiano'] ??
        const <String, List<AtmosphereDescriptor>>{};
    final atmosphereList = genreMap[scaffold.type.name] ??
        const <AtmosphereDescriptor>[];

    final isLastSection = _currentIndex == kGuidedComposerScaffold.length - 1;

    return Container(
      key: GuidedLyricsComposer.composerKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: title, step counter, close button
          Row(
            children: [
              Text(
                'Guided Lyrics Composer',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(30),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: AppColors.brandPrimary.withAlpha(80),
                  ),
                ),
                child: Text(
                  '${_currentIndex + 1} of ${kGuidedComposerScaffold.length}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const Key('guided_composer_close_btn'),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Linear Step Indicator Dots (REQ-GLC-06)
          Row(
            children: List.generate(kGuidedComposerScaffold.length, (idx) {
              final isActive = idx == _currentIndex;
              final isCompleted = idx < _currentIndex;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: idx < kGuidedComposerScaffold.length - 1 ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.brandPrimary
                        : isCompleted
                            ? AppColors.accentSuccess
                            : AppColors.borderSubtle,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: AppSpacing.md),

          // Bantu Language Switcher Row (REQ-BLS-01)
          BantuLanguageSwitcher(
            currentLanguage: formState.language,
            readLyrics: () => controller.text,
            writeLyrics: (translated) {
              setState(() {
                controller.text = translated;
              });
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Section Title & Guidance Copy
          Text(
            scaffold.title,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scaffold.guidanceText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Multi-line Section Text Editor
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCanvas,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TextField(
              key: Key('guided_section_input_${scaffold.title}'),
              controller: controller,
              maxLines: 4,
              minLines: 3,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Write your ${scaffold.title} lines here...',
                hintStyle: AppTypography.bodyMuted.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              onChanged: (text) => _onSectionChanged(
                scaffold.title,
                _hintFor(scaffold),
              ),
            ),
          ),

          // Optional AI Coaching / Grammar Hint (REQ-GLC-05)
          if (_hint != null && _hintShown) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withAlpha(25),
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.accentGold.withAlpha(90),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppColors.accentGold,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _hint!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14),
                    color: AppColors.accentGold,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () => setState(() => _hintShown = false),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Atmosphere Descriptors for current Genre + Section (REQ-GLC-03, REQ-GLC-04)
          if (atmosphereList.isNotEmpty) ...[
            Text(
              '✦ Atmosphere for $genre ${scaffold.title}:',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: atmosphereList.map((descriptor) {
                return TactilePressable(
                  onTap: () => _appendAtmosphere(descriptor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(descriptor.emoji),
                        const SizedBox(width: 4),
                        Text(
                          descriptor.label,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Bottom Action Bar: Back, Skip, Next / Finish (REQ-GLC-02)
          Row(
            children: [
              if (_currentIndex > 0)
                TactilePressable(
                  onTap: _goBack,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '← Back',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: AppSpacing.xs),
              if (scaffold.isOptional)
                TextButton(
                  key: const Key('guided_composer_skip_btn'),
                  onPressed: _skipSection,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Skip',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              const Spacer(),
              TactilePressable(
                onTap: _goNext,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    isLastSection ? 'Finish & Apply ➔' : 'Next →',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
