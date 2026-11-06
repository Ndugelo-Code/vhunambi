import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/studio_form_provider.dart';

/// Venda dental consonants (highlighted gold).
const Set<String> _vendaDentals = {'ḓ', 'ṱ', 'ṋ', 'ḽ', 'Ḓ', 'Ṱ', 'Ṋ', 'Ḽ'};

/// Nguni click consonants (highlighted cyan).
const Set<String> _nguniClicks = {'c', 'q', 'x'};

const Set<String> _vowels = {'a', 'e', 'i', 'o', 'u', 'A', 'E', 'I', 'O', 'U'};

/// Live phonetic alignment preview for drafted lyrics (REQ-VOX-03).
///
/// Surfaces the phonetic richness of indigenous lyrics before generation:
/// Venda dental consonants (gold), Nguni click consonants (cyan), and the
/// penultimate stressed vowel (bold accent) that drives Bantu elongation.
class LivePhoneticAlignmentPreview extends ConsumerWidget {
  const LivePhoneticAlignmentPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = (ref.watch(studioFormProvider).customLyrics ?? '').trim();
    final words = lyrics.isEmpty
        ? const <String>[]
        : lyrics.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              const Icon(
                Icons.record_voice_over_rounded,
                color: AppColors.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Phonetic Alignment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 12,
            children: [
              _LegendDot(color: AppColors.coinGold, label: 'Venda dental'),
              _LegendDot(color: AppColors.badgeCyan, label: 'Nguni click'),
              _LegendDot(
                color: AppColors.brandPrimary,
                label: 'Stressed vowel',
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (words.isEmpty)
            Text(
              'Add your lyrics to preview indigenous phonetic alignment.',
              style: AppTypography.bodyMuted,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final word in words) _WordChip(word: word)],
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool bold;
  const _LegendDot({
    required this.color,
    required this.label,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  const _WordChip({required this.word});

  /// Index of the penultimate vowel (Bantu stress target), or -1.
  int _penultimateVowelIndex() {
    final vowelIdx = <int>[];
    for (var i = 0; i < word.length; i++) {
      if (_vowels.contains(word[i])) vowelIdx.add(i);
    }
    if (vowelIdx.length < 2) return -1;
    return vowelIdx[vowelIdx.length - 2];
  }

  @override
  Widget build(BuildContext context) {
    final stressIdx = _penultimateVowelIndex();
    final spans = <InlineSpan>[];
    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      TextStyle style = AppTypography.bodyLarge;
      if (_vendaDentals.contains(ch)) {
        style = AppTypography.bodyLarge.copyWith(
          color: AppColors.coinGold,
          fontWeight: FontWeight.bold,
        );
      } else if (_nguniClicks.contains(ch)) {
        style = AppTypography.bodyLarge.copyWith(
          color: AppColors.badgeCyan,
          fontWeight: FontWeight.bold,
        );
      } else if (i == stressIdx) {
        style = AppTypography.bodyLarge.copyWith(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.w800,
        );
      }
      spans.add(TextSpan(text: ch, style: style));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}
