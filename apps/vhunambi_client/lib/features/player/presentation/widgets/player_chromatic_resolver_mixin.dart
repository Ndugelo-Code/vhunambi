import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/post_chromatic_palette_resolver.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Shared sync-first + async-refined chromatic palette mixin for all Player chrome
/// (`EP-P77-CHROMATIC-PLAYER-CHROME`, consuming `EP-P73-POST-CHROMATIC-SYNTH`).
mixin PlayerChromaticPaletteMixin<T extends StatefulWidget> on State<T> {
  String _lastChromaticSig = '';
  PostChromaticPalette? _resolvedChromaticPalette;

  PostChromaticPalette resolvePlayerChromaticPalette(
    BuildContext context,
    Track? track,
  ) {
    final brightness = Theme.of(context).brightness;
    if (track == null) {
      return PostChromaticPalette.themeDefault(brightness);
    }
    final rawMood = track.mood;
    final artUrl = track.coverUrl;
    final sig = '${brightness.name}|${rawMood ?? ''}|${artUrl ?? ''}|${track.id}';

    final syncPalette = PostChromaticPaletteResolver.resolveSync(
      brightness: brightness,
      rawMood: rawMood,
      artworkUrl: artUrl,
      hasAudioAttachment: true,
    );

    if (_lastChromaticSig != sig) {
      _lastChromaticSig = sig;
      _resolvedChromaticPalette = syncPalette;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final asyncPalette = await PostChromaticPaletteResolver.resolveAsync(
          brightness: brightness,
          rawMood: rawMood,
          artworkUrl: artUrl,
          hasAudioAttachment: true,
        );
        if (!mounted || _lastChromaticSig != sig) return;
        if (asyncPalette.primaryGlow != _resolvedChromaticPalette?.primaryGlow ||
            asyncPalette.accent != _resolvedChromaticPalette?.accent ||
            asyncPalette.tier != _resolvedChromaticPalette?.tier) {
          setState(() => _resolvedChromaticPalette = asyncPalette);
        }
      });
    }

    return _resolvedChromaticPalette ?? syncPalette;
  }

  /// Builds a WCAG AA Light/Dark-safe ambient stage gradient over [baseSurface].
  BoxDecoration buildChromaticStageDecoration({
    required BuildContext context,
    required PostChromaticPalette palette,
    required Color baseSurface,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topAlpha = isDark ? 0.28 : 0.14;
    final midAlpha = isDark ? 0.14 : 0.07;

    return BoxDecoration(
      color: baseSurface,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.alphaBlend(
            palette.primaryGlow.withValues(alpha: topAlpha),
            baseSurface,
          ),
          Color.alphaBlend(
            palette.secondaryGlow.withValues(alpha: midAlpha),
            baseSurface,
          ),
          baseSurface,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ),
    );
  }
}
