import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/lyrics_review_provider.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'voice_clone_recorder_sheet.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../sound_signature/domain/dsp/bantu_phonology.dart';
import '../../../sound_signature/domain/dsp/bantu_similarity.dart';

/// Section id of the stanza editor the creator focused most recently while
/// the cockpit has been open (`null` when none has been focused this session).
///
/// Focus *gains* are recorded but never cleared on blur: tapping an idiom
/// chip unfocuses the editor before the chip's `onPressed` fires, so clearing
/// on blur would misroute the insert to the fallback stanza. Reset when the
/// cockpit closes or approves (Mission 1 / REQ-LYR-06).
final _activeStanzaIdProvider = StateProvider<String?>((ref) => null);

/// Studio lyrics review cockpit (T12.5 / REQ-LYR-02 → REQ-LYR-09).
///
/// Desktop viewports (> 1024px) get a centred elevated dialog; mobile gets an
/// expandable 90% bottom sheet.
class LyricsReviewModal extends ConsumerStatefulWidget {
  const LyricsReviewModal({super.key});

  static Future<void> show(BuildContext context) {
    if (!ResponsiveUtils.isDesktop(context)) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceModal,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.modalBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        builder: (_) => const LyricsReviewModal(),
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceModal,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: const LyricsReviewModal(),
        ),
      ),
    );
  }

  @override
  ConsumerState<LyricsReviewModal> createState() => _LyricsReviewModalState();
}

class _LyricsReviewModalState extends ConsumerState<LyricsReviewModal> {
  bool _storyMode = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(lyricsReviewProvider);

    // The cockpit only mounts while a draft exists — guard disposal races
    // (approve → pop, regenerate → dispose).
    if (draft == null) return const SizedBox.shrink();

    final notifier = ref.read(lyricsReviewProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LyricsReviewHeader(
            draft: draft,
            isStoryMode: _storyMode,
            onToggleStoryMode: () => setState(() => _storyMode = !_storyMode),
            onOpenCognateFinder: () => _openCognateFinder(context, draft),
            onClose: () => _handleClose(context, ref),
            onCopy: () => unawaited(_handleCopyLyrics(context, draft)),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PromptSummaryCard(draft: draft),
                  if (_storyMode) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withAlpha(25),
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(
                          color: AppColors.brandPrimary.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Story-to-Lyrics Mode Active: Original narrative mapped into authentic ${draft.genre} structure without rewriting your words.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (!draft.isRawEditorMode) ...[
                    for (final section in draft.sections) ...[
                      _LyricsSectionCard(
                        section: section,
                        onLinesChanged: (lines) =>
                            notifier.updateSectionLines(section.id, lines),
                        onFocusGained: () =>
                            ref.read(_activeStanzaIdProvider.notifier).state =
                                section.id,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    _CulturalIdiomsRail(
                      idioms: draft.culturalIdioms,
                      onInsert: (idiom) =>
                          _handleIdiomInsert(context, ref, idiom),
                    ),
                  ] else
                    _RawLyricsEditor(
                      draft: draft,
                      onChanged: notifier.updateRawText,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          _LyricsReviewActionBar(draft: draft),
        ],
      ),
    );
  }

  /// REQ-LYR-09 — confirms before dropping an edited draft.
  void _openCognateFinder(BuildContext context, LyricsReviewDraft draft) {
    const structuralStopwords = <String>{
      'intro',
      'verse',
      'chorus',
      'bridge',
      'outro',
      'hook',
      'pre-chorus',
      'interlude',
    };

    final lang = BantuLanguage.fromCode(draft.language) ?? BantuLanguage.zu;

    // Strip any bracketed tags [Intro], [Chorus], etc. and extract lyric tokens only (REQ-P56-COG-01)
    final lyricBody =
        (draft.allLines.isNotEmpty ? draft.allLines.join(' ') : draft.rawText)
            .replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    final words = lyricBody
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ')
        .split(RegExp(r'\s+'))
        .where(
          (w) =>
              w.length >= 3 && !structuralStopwords.contains(w.toLowerCase()),
        )
        .take(5)
        .toList();

    final results = <BantuSimilarityResult>[];
    for (final w in words) {
      for (final target in BantuLanguage.values) {
        if (target != lang) {
          final res = BantuSimilarity.compare(w, lang, w, target);
          if (res.score >= 50) {
            results.add(res);
          }
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.treeStructure(PhosphorIconsStyle.regular),
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Bantu Cognate & Rhyme Finder',
                    style: AppTypography.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Peer-branch sound correspondences (indicative):',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'No direct cognates found above 50% threshold for current stanza words.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.take(8).length,
                        separatorBuilder: (_, _) => const Divider(height: 8),
                        itemBuilder: (_, i) {
                          final r = results[i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${r.sourceWord} (${r.source.code}) ➔ ${r.targetWord} (${r.target.code})',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Score: ${r.score}% • Route: ${r.route.isIntraBranch ? "Intra-branch identity" : "Cross-branch pairwise shift"}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleClose(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(lyricsReviewProvider.notifier);
    final navigator = Navigator.of(context);

    // A new session must fall back to the first verse, not the stanza that
    // happened to be focused last time (Mission 1).
    void close() {
      ref.read(_activeStanzaIdProvider.notifier).state = null;
      navigator.pop();
    }

    if (!notifier.hasEdits) {
      close();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        title: Text('Discard lyric changes?', style: AppTypography.titleMedium),
        content: Text(
          'Your edits are kept in memory until you regenerate or leave.',
          style: AppTypography.bodySmall,
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('lyrics_keep_editing'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep editing', style: AppTypography.bodySmall),
          ),
          TextButton(
            key: const Key('lyrics_discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Discard changes',
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (discard ?? false) close();
  }
}

/// Header: title, genre • language pills, copy action and the dismissal
/// trigger (Mission 2).
class _LyricsReviewHeader extends StatelessWidget {
  const _LyricsReviewHeader({
    required this.draft,
    required this.isStoryMode,
    required this.onToggleStoryMode,
    required this.onOpenCognateFinder,
    required this.onClose,
    required this.onCopy,
  });

  final LyricsReviewDraft draft;
  final bool isStoryMode;
  final VoidCallback onToggleStoryMode;
  final VoidCallback onOpenCognateFinder;
  final VoidCallback onClose;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lyrics_rounded,
            size: 20,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review Lyrics', style: AppTypography.titleMedium),
                Text(
                  '${draft.genre} • ${draft.language}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          // Story-to-Lyrics Mode Toggle (REQ-BANTU-STORY-07)
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('lyrics_story_mode_toggle'),
              tooltip: 'Story-to-Lyrics Mode',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                PhosphorIcons.bookOpen(PhosphorIconsStyle.regular),
                size: 18,
                color: isStoryMode
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
              ),
              onPressed: onToggleStoryMode,
            ),
          ),
          // Bantu Cognate & Rhyme Finder (REQ-BANTU-STORY-07, REQ-BANTU-STORY-08)
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('lyrics_cognate_finder_btn'),
              tooltip: 'Bantu Cognate & Rhyme Finder',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                PhosphorIcons.treeStructure(PhosphorIconsStyle.regular),
                size: 18,
                color: AppColors.brandPrimary,
              ),
              onPressed: onOpenCognateFinder,
            ),
          ),
          IconButton(
            key: const Key('lyrics_copy'),
            tooltip: 'Copy lyrics',
            onPressed: onCopy,
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          IconButton(
            key: const Key('lyrics_close'),
            tooltip: 'Close',
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt + draft summary card.
class _PromptSummaryCard extends StatelessWidget {
  const _PromptSummaryCard({required this.draft});

  final LyricsReviewDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'AI draft • ${draft.sectionCount} sections',
                style: AppTypography.badge.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            draft.prompt.isEmpty ? 'No prompt provided' : draft.prompt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One inline-editable stanza card (REQ-LYR-04).
class _LyricsSectionCard extends StatefulWidget {
  const _LyricsSectionCard({
    required this.section,
    required this.onLinesChanged,
    this.onFocusGained,
  });

  final LyricsSection section;
  final ValueChanged<List<String>> onLinesChanged;

  /// Fired when this stanza's editor gains keyboard focus so the idiom rail
  /// knows where to insert (Mission 1 / REQ-LYR-06).
  final VoidCallback? onFocusGained;

  @override
  State<_LyricsSectionCard> createState() => _LyricsSectionCardState();
}

class _LyricsSectionCardState extends State<_LyricsSectionCard> {
  bool _isEditing = false;

  /// Live editor buffer so externally-driven changes (an idiom insert) land
  /// in the focused field immediately, while the user's own keystrokes are
  /// never clobbered by the model round-trip.
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Mirrors the text this card last pushed into [_controller] — the
  /// [didUpdateWidget] guard that separates "user typed it" from "the model
  /// changed underneath".
  late String _lastSyncedLines;

  @override
  void initState() {
    super.initState();
    _lastSyncedLines = widget.section.lines.join('\n');
    _controller = TextEditingController(text: _lastSyncedLines);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) widget.onFocusGained?.call();
  }

  @override
  void didUpdateWidget(covariant _LyricsSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.section.lines.join('\n');
    if (incoming != _lastSyncedLines) {
      _lastSyncedLines = incoming;
      _controller.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(30),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  section.header,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('stanza_edit_${section.id}'),
                tooltip: _isEditing ? 'Done editing' : 'Edit stanza',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                  size: 16,
                  color: _isEditing
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!_isEditing)
            for (final line in section.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  line,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              )
          else
            TextFormField(
              key: Key('stanza_editor_${section.id}'),
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              onChanged: (value) {
                _lastSyncedLines = value;
                widget.onLinesChanged(value.split('\n'));
              },
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Write the lines for this section',
              ),
            ),
          if (section.rhymeNotes.isNotEmpty)
            Text(
              'Rhyme: ${section.rhymeNotes.join(' • ')}',
              style: AppTypography.caption,
            ),
        ],
      ),
    );
  }
}

/// Horizontal one-tap idiom / ad-lib injection tray (REQ-LYR-06).
class _CulturalIdiomsRail extends StatelessWidget {
  const _CulturalIdiomsRail({required this.idioms, required this.onInsert});

  final List<String> idioms;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    if (idioms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cultural idioms & ad-libs',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: idioms.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xxs),
            itemBuilder: (context, index) => ActionChip(
              key: Key('idiom_chip_$index'),
              label: Text(
                idioms[index],
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: AppColors.surfaceSecondary,
              side: BorderSide(color: AppColors.borderSubtle),
              onPressed: () => onInsert(idioms[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Raw markdown surface, bi-directionally synced with the stanza cards
/// (REQ-LYR-05).
class _RawLyricsEditor extends StatefulWidget {
  const _RawLyricsEditor({required this.draft, required this.onChanged});

  final LyricsReviewDraft draft;
  final ValueChanged<String> onChanged;

  @override
  State<_RawLyricsEditor> createState() => _RawLyricsEditorState();
}

class _RawLyricsEditorState extends State<_RawLyricsEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.rawText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: TextField(
        key: const Key('lyrics_raw_editor'),
        controller: _controller,
        maxLines: null,
        minLines: 12,
        keyboardType: TextInputType.multiline,
        onChanged: widget.onChanged,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: '[Verse 1]\nWrite or paste your lyrics here',
        ),
      ),
    );
  }
}

/// Footer actions: regenerate, voice clone recorder, mode toggle and synthesis handoff.
class _LyricsReviewActionBar extends ConsumerWidget {
  const _LyricsReviewActionBar({required this.draft});

  final LyricsReviewDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(lyricsReviewProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          OutlinedButton.icon(
            key: const Key('lyrics_regenerate'),
            onPressed: () => unawaited(notifier.regenerate()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.borderSubtle),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Regenerate Lyrics',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('lyrics_review_clone_voice_btn'),
            onPressed: () => VoiceCloneRecorderSheet.show(
              context,
              lyrics: draft.rebuildRawText(),
              language: draft.language,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coinGold,
              side: BorderSide(color: AppColors.coinGold.withAlpha(110)),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            icon: const Icon(
              Icons.mic_external_on_rounded,
              size: 16,
              color: AppColors.coinGold,
            ),
            label: Text(
              'Clone My Voice (3 Lines)',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.coinGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const Key('lyrics_toggle_raw'),
            onPressed: notifier.toggleEditorMode,
            child: Text(
              draft.isRawEditorMode ? 'Section View' : 'Raw Editor',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          ElevatedButton.icon(
            key: const Key('lyrics_approve'),
            onPressed: () => _approveDraft(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.brandContrast,
            ),
            label: Text(
              'Approve & Produce Beat ➔',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// REQ-LYR-08 — persists the approved lyrics, queues the synthesis FSM and
/// dismisses the cockpit.
void _approveDraft(BuildContext context, WidgetRef ref) {
  final navigator = Navigator.of(context);
  final review = ref.read(lyricsReviewProvider.notifier);
  final formNotifier = ref.read(studioFormProvider.notifier);
  final formState = ref.read(studioFormProvider);

  final lyrics = review.lyricsForSynthesis;
  formNotifier.approveLyrics(lyrics);
  // Fresh cockpit session next time — no stale focus target (Mission 1).
  ref.read(_activeStanzaIdProvider.notifier).state = null;

  final musicalKey =
      formState.referenceAudioPath?.startsWith('sketchpad://') == true
          ? ref.read(melodySketchpadProvider).attachedPattern?.musicalKey ??
              formState.toSongMetadataDna().musical.key
          : formState.toSongMetadataDna().musical.key;

  unawaited(
    ref
        .read(generationProgressProvider.notifier)
        .submitAndStartGeneration(
          trackTitle: formState.resolvedTitle,
          genre: formState.genre,
          language: formState.language,
          lyrics: lyrics,
          isInstrumental: formState.isInstrumental,
          tempoBpm: formState.tempo.defaultBpm,
          musicalKey: musicalKey,
        ),
  );

  navigator.pop();
}

/// Mission 1 — cultural idiom chip micro-interaction: haptic tick, append the
/// phrase into the stanza being edited (first verse when nothing is focused)
/// and a themed confirmation toast.
void _handleIdiomInsert(BuildContext context, WidgetRef ref, String idiom) {
  unawaited(HapticFeedback.lightImpact());

  final draft = ref.read(lyricsReviewProvider);
  final activeId = ref.read(_activeStanzaIdProvider);
  final sections = draft?.sections ?? const <LyricsSection>[];

  // Active stanza (still present in the draft) wins; otherwise fall back to
  // the first verse — `null` lets the notifier use its own last-stanza
  // default for degenerate drafts with no verse at all.
  final targetId =
      activeId != null && sections.any((section) => section.id == activeId)
      ? activeId
      : _firstVerseId(sections);

  ref
      .read(lyricsReviewProvider.notifier)
      .insertIdiom(idiom, sectionId: targetId);

  _showLyricsToast(context, 'Inserted idiom into lyrics', Icons.lyrics_rounded);
}

/// First stanza typed as a verse, or `null` when the draft has none.
String? _firstVerseId(List<LyricsSection> sections) {
  for (final section in sections) {
    if (section.type == LyricsSectionType.verse) return section.id;
  }
  return null;
}

/// Mission 2 — compiles every draft section into bracketed markdown
/// (`[Intro] … [Verse 1] …`), copies it to the clipboard, buzzes and toasts.
Future<void> _handleCopyLyrics(
  BuildContext context,
  LyricsReviewDraft draft,
) async {
  final fullLyrics = draft.rebuildRawText();

  await Clipboard.setData(ClipboardData(text: fullLyrics));
  unawaited(HapticFeedback.mediumImpact());

  if (!context.mounted) return;
  _showLyricsToast(context, 'Lyrics copied to clipboard', Icons.copy_rounded);
}

/// Toast currently on screen, if any — replaced rather than stacked.
OverlayEntry? _activeToastEntry;

/// Themed floating confirmation above the cockpit.
///
/// Rendered through the [Overlay] (inserted on top of the route stack) so it
/// is visible above both the desktop dialog and the mobile bottom sheet —
/// the cockpit itself has no [Scaffold] to host a [SnackBar], and the root
/// Scaffold sits *behind* the modal barrier.
void _showLyricsToast(BuildContext context, String message, IconData icon) {
  final previous = _activeToastEntry;
  if (previous != null && previous.mounted) previous.remove();
  _activeToastEntry = null;

  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(
            // Clears the ~72px cockpit action bar on mobile so the toast
            // never covers "Approve & Produce Beat".
            bottom: AppSpacing.section * 2,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
          ),
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 160),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceModal,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: AppColors.brandPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        message,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _activeToastEntry = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);

  Future.delayed(const Duration(seconds: 2), () {
    if (entry.mounted) entry.remove();
    if (identical(_activeToastEntry, entry)) _activeToastEntry = null;
  });
}
