import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/fake_bantu_translation_service.dart';
import '../../domain/services/i_bantu_translation_service.dart';
import '../utils/studio_haptics.dart';

/// Injectable translation service (M10 / REQ-BLS-04).
final bantuTranslationServiceProvider = Provider<IBantuTranslationService>(
  (ref) => const FakeBantuTranslationService(),
);

/// The 8 supported Bantu language targets (M10 / REQ-BLS-02).
const List<String> kBantuLanguageTargets = <String>[
  'Tshivenḓa',
  'isiZulu',
  'isiXhosa',
  'Sepedi',
  'Setswana',
  'Afrikaans',
  'Xitsonga',
  'siSwati',
];

/// One-tap lyric translation chip row (M10 / REQ-BLS-01 → REQ-BLS-06).
///
/// Placed in the Guided Lyrics Composer header and the Lyrics Review Modal
/// header. Selecting a different language asks for confirmation, runs the
/// [IBantuTranslationService] behind a blurred loading overlay, then marks
/// the switcher with a 🌐 badge.
class BantuLanguageSwitcher extends ConsumerStatefulWidget {
  const BantuLanguageSwitcher({
    super.key,
    required this.currentLanguage,
    required this.readLyrics,
    required this.writeLyrics,
  });

  /// Key: `Key('bantu_language_switcher')`.
  static const Key switcherKey = Key('bantu_language_switcher');

  /// Language of the lyrics currently being edited.
  final String currentLanguage;

  /// Snapshot callback providing the raw lyrics text to translate.
  final String Function() readLyrics;

  /// Receives the translated lyrics text (prefix stripped).
  final void Function(String translatedText) writeLyrics;

  @override
  ConsumerState<BantuLanguageSwitcher> createState() =>
      _BantuLanguageSwitcherState();
}

class _BantuLanguageSwitcherState
    extends ConsumerState<BantuLanguageSwitcher> {
  String? _translatedTo;
  bool _isTranslating = false;

  static final RegExp _translationPrefix =
      RegExp(r'^\[Translated to [^\]]+\]:\s*');

  Future<void> _confirmAndTranslate(String target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Translate lyrics to $target?',
          style: AppTypography.titleMedium,
        ),
        content: Text(
          'Your current lyrics will be replaced with the translated version. '
          'This cannot be undone.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            key: const Key('bantu_translate_confirm_btn'),
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              minimumSize: const Size(96, 44),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            child: Text(
              'Translate',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _translate(target);
  }

  Future<void> _translate(String target) async {
    final service = ref.read(bantuTranslationServiceProvider);
    final source = widget.readLyrics();

    setState(() => _isTranslating = true);
    try {
      final translated = await service.translate(
        text: source,
        fromLanguage: widget.currentLanguage,
        toLanguage: target,
      );
      widget.writeLyrics(translated.replaceFirst(_translationPrefix, ''));
      if (mounted) {
        unawaited(StudioHaptics.successPulse());
        setState(() {
          _translatedTo = target;
          _isTranslating = false;
        });
      }
    } catch (_) {
      // Translation is best-effort — never crash the composer on failure.
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLanguage = _translatedTo ?? widget.currentLanguage;

    return SizedBox(
      key: BantuLanguageSwitcher.switcherKey,
      height: 44,
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final language in kBantuLanguageTargets)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs),
                    child: InkWell(
                      key: Key('bantu_lang_chip_$language'),
                      onTap: () {
                        unawaited(StudioHaptics.chipSnap());
                        _confirmAndTranslate(language);
                      },
                      borderRadius: AppRadius.pillBorder,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: language == activeLanguage
                              ? AppColors.brandPrimary
                              : AppColors.surfaceSecondary,
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: language == activeLanguage
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          language,
                          style: AppTypography.caption.copyWith(
                            color: language == activeLanguage
                                ? AppColors.brandContrast
                                : AppColors.textSecondary,
                            fontWeight: language == activeLanguage
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_translatedTo != null)
            const Positioned(
              right: 4,
              top: 10,
              child: Text('🌐', style: TextStyle(fontSize: 14)),
            ),
          if (_isTranslating)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: AppRadius.pillBorder,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    color: AppColors.surfaceCanvas.withAlpha(140),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

