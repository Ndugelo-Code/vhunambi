import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/option_preview_descriptor.dart';
import '../providers/studio_form_provider.dart';
import '../utils/studio_haptics.dart';
import 'tactile_pressable.dart';

/// Tactile selection chip with an anchored micro-preview overlay (M10 /
/// REQ-OPT-02, REQ-OPT-03, REQ-NFR-03).
///
/// Layout: `[Label (44px tall)] [ⓘ]` — the ⓘ button (44×44px hit target)
/// opens a themed [OptionPreviewCard] through the nearest [Overlay], and the
/// main body performs the regular selection [onTap]. Existing text labels
/// are preserved verbatim so current `find.text('Slow')`-style finders keep
/// working.
///
/// Uses genre accent tokens from [VhunambiThemeExtension] for the selected
/// chip state instead of legacy `AppColors.brandPrimary`.
class OptionPreviewChip extends ConsumerStatefulWidget {
  const OptionPreviewChip({
    super.key,
    required this.optionKey,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  /// Stable identifier, e.g. `tempo_fast` → keys
  /// `option_preview_chip_tempo_fast` / `option_preview_info_tempo_fast`.
  final String optionKey;

  /// Chip label — rendered exactly as provided.
  final String label;

  /// Optional second line (e.g. the BPM range under a tempo label).
  final String? subtitle;

  final bool isSelected;
  final VoidCallback onTap;

  OptionPreviewDescriptor? get preview => kStudioOptionPreviews[optionKey];

  @override
  ConsumerState<OptionPreviewChip> createState() => _OptionPreviewChipState();
}

class _OptionPreviewChipState extends ConsumerState<OptionPreviewChip> {
  OverlayEntry? _overlayEntry;

  void _showPreview() {
    final preview = widget.preview;
    if (preview == null) return;
    _removeOverlay();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final genreString = ref.read(studioFormProvider).genre;
        final genre = _mapStringToGenre(genreString);
        final extension = VhunambiThemeExtension.of(context);
        final accent = extension.genreAccent(genre);
        return _OptionPreviewCard(
          optionKey: widget.optionKey,
          descriptor: preview,
          onGotIt: () {
            _removeOverlay();
          },
          entryRef: entry,
          accent: accent,
        );
      },
    );
    _overlayEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  @override
  void dispose() {
    // Never leak an overlay when the chip unmounts mid-preview (trap
    // mitigation from tasks.md).
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final preview = widget.preview;
    final genreString = ref.watch(studioFormProvider.select((s) => s.genre));
    final genre = _mapStringToGenre(genreString);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    return TactilePressable(
      hapticType: TactileHapticType.light,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? accent : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? accent : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: widget.subtitle == null
                  ? Text(
                      widget.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected
                            ? _contrastTextColor(accent)
                            : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? _contrastTextColor(accent)
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: AppTypography.caption.copyWith(
                            color: isSelected
                                ? _contrastTextColor(accent)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
            ),
            if (preview != null)
              InkWell(
                key: Key('option_preview_info_${widget.optionKey}'),
                onTap: () {
                  unawaited(StudioHaptics.chipSnap());
                  _showPreview();
                },
                borderRadius: AppRadius.pillBorder,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.badgeCyan,
                  ),
                ),
              )
            else
              const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  /// Maps a free-form [genre] string from [StudioFormState] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }
}

/// Returns a high-contrast text color (black or white) for [background]
/// based on its relative luminance, ensuring WCAG AA readability.
Color _contrastTextColor(Color background) {
  final luminance = background.computeLuminance();
  return luminance > 0.5 ? Colors.black : Colors.white;
}

/// Themed micro-preview card surfaced through the [Overlay] (M10 / REQ-OPT-03).
class _OptionPreviewCard extends StatelessWidget {
  const _OptionPreviewCard({
    required this.optionKey,
    required this.descriptor,
    required this.onGotIt,
    required this.entryRef,
    required this.accent,
  });

  final String optionKey;
  final OptionPreviewDescriptor descriptor;
  final VoidCallback onGotIt;
  final OverlayEntry entryRef;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible dismiss scrim behind the card.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (entryRef.mounted) onGotIt();
            },
            child: const SizedBox.expand(),
          ),
        ),
        Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: Container(
                key: Key('option_preview_card_$optionKey'),
                margin: const EdgeInsets.all(AppSpacing.xl),
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceModal,
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.borderActive),
                  boxShadow: [
                    BoxShadow(
                      color: accent,
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 0),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(descriptor.emoji),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            descriptor.title,
                            style: AppTypography.titleMedium.copyWith(
                              color: _contrastTextColor(accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      descriptor.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        for (final genre in descriptor.bestForGenres)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadius.pillBorder,
                              border:
                                  Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              genre,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: Key('option_preview_got_it_$optionKey'),
                        onPressed: () {
                          if (entryRef.mounted) onGotIt();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(
                          'Got It',
                          style: AppTypography.bodySmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
