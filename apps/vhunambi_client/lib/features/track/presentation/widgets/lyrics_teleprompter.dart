import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/domain/services/bantu_lyric_translation_service.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/domain/utils/synced_lyric_timeline.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/bantu_word_glossary_sheet.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Synchronized / Clean Karaoke Lyrics Teleprompter (`REQ-TRK-08`, `REQ-P77-LYR-01..05`).
class LyricsTeleprompter extends ConsumerStatefulWidget {
  final TrackDetailEntity track;
  final Color? accentColorOverride;
  final bool embeddedInPlayer;

  const LyricsTeleprompter({
    super.key,
    required this.track,
    this.accentColorOverride,
    this.embeddedInPlayer = false,
  });

  @override
  ConsumerState<LyricsTeleprompter> createState() => _LyricsTeleprompterState();
}

class _LyricsTeleprompterState extends ConsumerState<LyricsTeleprompter> {
  bool _translateActive = false;
  int _lastScrolledLineIdx = -1;
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};

  GlobalKey _keyForLine(int index) =>
      _lineKeys.putIfAbsent(index, () => GlobalKey());

  void _seekToLine({
    required int lineIndex,
    required int lineCount,
    required Duration effectiveDuration,
  }) {
    final notifier = ref.read(playerStateProvider.notifier);
    final playerState = ref.read(playerStateProvider);
    final target = SyncedLyricTimeline.seekTargetForLine(
      lineIndex: lineIndex,
      lineCount: lineCount,
      duration: effectiveDuration,
    );

    if (playerState.currentTrack?.id != widget.track.id) {
      notifier.playTrack(
        Track(
          id: widget.track.id,
          title: widget.track.title,
          creatorName: widget.track.creatorName,
          genre: widget.track.genre,
          language: widget.track.language,
          duration: widget.track.duration,
          audioUrl: widget.track.audioUrl,
          coverUrl: widget.track.coverUrl,
        ),
      );
    }
    notifier.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final sanitizedLyrics = LyricKaraokeSanitizer.cleanLyricsForPlayback(
      widget.track.lyrics,
    );
    final lines = SyncedLyricTimeline.extractLines(sanitizedLyrics);
    final playerState = ref.watch(playerStateProvider);
    final isTrackActive = playerState.currentTrack?.id == widget.track.id;
    final effectiveDuration = playerState.duration.inMilliseconds > 0
        ? playerState.duration
        : widget.track.duration;
    final activeIdx = isTrackActive
        ? SyncedLyricTimeline.resolveActiveLineIndex(
            lineCount: lines.length,
            position: playerState.position,
            duration: effectiveDuration,
          )
        : -1;

    if (activeIdx >= 0 &&
        activeIdx != _lastScrolledLineIdx &&
        lines.isNotEmpty) {
      _lastScrolledLineIdx = activeIdx;
      final lineKey = _lineKeys[activeIdx];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lineCtx = lineKey?.currentContext;
        if (mounted && lineCtx != null) {
          Scrollable.ensureVisible(
            lineCtx,
            alignment: 0.35,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    final accent = widget.accentColorOverride ?? AppColors.brandPrimary;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header
        Row(
          children: [
            PhosphorIcon(AppIcons.songsOutline, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              'LYRICS',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: textSecondary,
              ),
            ),
            const Spacer(),
            // 9-Language Bantu Sing-Along & Word Glossary Toggle (`REQ-P77-LYR-03..04`)
            SizedBox(
              width: 44,
              height: 44,
              child: KeyedSubtree(
                key: const Key('track_translate_lyrics_toggle'),
                child: IconButton(
                  key: const Key('synced_lyrics_bantu_toggle'),
                  tooltip: 'Bantu Sing-Along & Word Definitions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.translate,
                    size: 18,
                    color: _translateActive ? accent : textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _translateActive = !_translateActive),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: borderSubtle),
              ),
              child: Text(
                widget.track.language,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (lines.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No lyrics available for this generation.',
                style: AppTypography.bodySmall.copyWith(
                  color: textSecondary.withValues(alpha: 0.72),
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < lines.length; i++)
            _buildSyncedLineRow(
              context: context,
              line: lines[i],
              index: i,
              lineCount: lines.length,
              isActive: i == activeIdx,
              isPast: activeIdx >= 0 && i < activeIdx,
              effectiveDuration: effectiveDuration,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
            ),
      ],
    );

    if (widget.embeddedInPlayer) {
      return bodyContent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: borderSubtle),
      ),
      child: bodyContent,
    );
  }

  Widget _buildSyncedLineRow({
    required BuildContext context,
    required String line,
    required int index,
    required int lineCount,
    required bool isActive,
    required bool isPast,
    required Duration effectiveDuration,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final baseLineColor = isPast
        ? textSecondary.withValues(alpha: 0.72)
        : textPrimary;
    final lineKey = _keyForLine(index);

    if (!_translateActive) {
      return InkWell(
        key: isActive ? const Key('synced_lyrics_active_line') : lineKey,
        onTap: () => _seekToLine(
          lineIndex: index,
          lineCount: lineCount,
          effectiveDuration: effectiveDuration,
        ),
        borderRadius: AppRadius.thumbBorder,
        child: AnimatedContainer(
          key: isActive ? lineKey : null,
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
                : Colors.transparent,
            borderRadius: AppRadius.thumbBorder,
            border: isActive
                ? Border(left: BorderSide(color: accent, width: 3))
                : null,
          ),
          child: Text(
            line,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: isActive ? 16 : 15,
              height: 1.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? accent : baseLineColor,
            ),
          ),
        ),
      );
    }

    // Interactive 9-Language Bantu Sing-Along & Tap-to-Define mode
    final langCode = BantuLyricTranslationService.resolveLanguageCode(
      widget.track.language,
    );
    final trans = BantuLyricTranslationService.translateLine(
      line: line,
      baseLanguageCode: langCode,
    );
    final words = line
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);

    return InkWell(
      key: isActive ? const Key('synced_lyrics_active_line') : lineKey,
      onTap: () => _seekToLine(
        lineIndex: index,
        lineCount: lineCount,
        effectiveDuration: effectiveDuration,
      ),
      borderRadius: AppRadius.thumbBorder,
      child: AnimatedContainer(
        key: isActive ? lineKey : null,
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
              : Colors.transparent,
          borderRadius: AppRadius.thumbBorder,
          border: isActive
              ? Border(left: BorderSide(color: accent, width: 3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final word in words)
                  GestureDetector(
                    onTap: () {
                      final def = BantuLyricTranslationService.lookupWord(
                        word,
                        baseLanguageCode: langCode,
                      );
                      BantuWordGlossarySheet.show(
                        context,
                        definition: def,
                        accentColor: accent,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.10 : 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        word,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? accent : textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            BantuLyricTranslationService.buildStyledPhoneticGuide(
              trans.phoneticSingAlongGuide,
              baseStyle: AppTypography.caption.copyWith(
                color: accent.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
              accentColor: accent,
            ),
            if (trans.hasMeaning)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  trans.translatedMeaning,
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (trans.cognateMatches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Cognate: ${trans.cognateMatches.first.target.displayName} (${trans.cognateMatches.first.score}%) · tap word to explore 9 Bantu languages',
                    style: AppTypography.badge.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
