import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../studio/domain/services/bantu_lyric_translation_service.dart';
import '../../domain/models/track_detail_models.dart';

/// Synchronized / Formatted Lyrics Teleprompter (REQ-TRK-08 & Phase 36 REQ-BANTU-LYR-04).
class LyricsTeleprompter extends StatefulWidget {
  final TrackDetailEntity track;

  const LyricsTeleprompter({super.key, required this.track});

  @override
  State<LyricsTeleprompter> createState() => _LyricsTeleprompterState();
}

class _LyricsTeleprompterState extends State<LyricsTeleprompter> {
  bool _translateActive = false;

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.track.lyrics.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Icon(
                PhosphorIcons.musicNotes(PhosphorIconsStyle.regular),
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'LYRICS',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Translation & Phonetic Sing-Along Toggle (REQ-BANTU-LYR-04)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: const Key('track_translate_lyrics_toggle'),
                  tooltip: 'Bantu Sing-Along & Meaning',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(
                    PhosphorIcons.translate(PhosphorIconsStyle.regular),
                    size: 18,
                    color: _translateActive
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _translateActive = !_translateActive),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  widget.track.language,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Lyrical Stanzas
          if (lyrics.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No lyrics available for this generation.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ..._buildFormattedLines(lyrics),
        ],
      ),
    );
  }

  List<Widget> _buildFormattedLines(String lyricsText) {
    final lines = lyricsText.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // Check for bracketed structural tags like [Verse 1], [Chorus], [Bridge]
      if (line.startsWith('[') && line.endsWith(']')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      } else {
        if (!_translateActive) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        } else {
          // Translation & Phonetic sing-along active (REQ-BANTU-LYR-01..06)
          final trans = BantuLyricTranslationService.translateLine(
            line: line,
            baseLanguageCode: widget.track.language,
          );

          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trans.phoneticSingAlongGuide,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (trans.hasMeaning)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        trans.translatedMeaning,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (trans.cognateMatches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withAlpha(20),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: AppColors.brandPrimary.withAlpha(50),
                          ),
                        ),
                        child: Text(
                          'Cognate: ${trans.cognateMatches.first.target.displayName} (${trans.cognateMatches.first.score}%) • indicative',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.brandPrimary,
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
    }

    return widgets;
  }
}
