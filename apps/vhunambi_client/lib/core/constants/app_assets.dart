import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_constants.dart';

/// Centralized asset registry for all production branding marks, African voice
/// timbre portraits, and crate artwork (REQ-BRD-01).
abstract final class AppAssets {
  // ---------------------------------------------------------------------------
  // Branding Tokens (assets/branding/)
  // ---------------------------------------------------------------------------
  static const String brandingDir = 'assets/branding';

  /// Primary high-resolution brush wordmark with transparent alpha channel.
  static const String vhunambiWordmark = '$brandingDir/vhunambi_wordmark.png';

  /// Raw wordmark with original textured background.
  static const String vhunambiWordmarkRaw = '$brandingDir/vhunambi_wordmark_raw.png';

  /// Isolated 512x512 golden crest monogram glyph.
  static const String vhunambiGlyph = '$brandingDir/vhunambi_glyph.png';

  /// High-res 1024x1024 squircle launcher icon (Dark Silhouette).
  static const String appIconDark = '$brandingDir/app_icon_dark.png';

  /// High-res 1024x1024 squircle launcher icon (Morning Mist).
  static const String appIconLight = '$brandingDir/app_icon_light.png';

  /// Full-bleed 1024x1024 launcher store asset.
  static const String appIconFullBleed = '$brandingDir/app_icon_fullbleed.png';

  /// Compact brand mark SVG (header) — VH-006.
  static const String vhunambiCompactMark = '$brandingDir/vhunambi_compact_mark.svg';

  /// Full lockup SVG (wordmark + icon) for splash/onboarding — VH-006.
  static const String vhunambiFullLockup = '$brandingDir/vhunambi_full_lockup.svg';

  /// Master brand showcase artboard.
  static const String brandShowcase = '$brandingDir/Vhunambi Music Brand Showcase.png';

  /// Master moodboard artboard.
  static const String appMoodboard = '$brandingDir/Vhunambi Music App Moodboard.png';

  // ---------------------------------------------------------------------------
  // Artwork & Voice Timbres (assets/artwork/)
  // ---------------------------------------------------------------------------
  static const String artworkDir = 'assets/artwork';

  /// 512x512 portrait of the Venda Folk Elder (Griot).
  static const String timbreElder = '$artworkDir/timbre_elder.png';

  /// 512x512 portrait of the Youthful Poet / Limpopo Pop Queen.
  static const String timbrePoet = '$artworkDir/timbre_poet.png';

  /// 512x512 portrait of the Soweto Soul Lead Crooner.
  static const String timbreCrooner = '$artworkDir/timbre_crooner.png';

  /// 512x512 portrait of the Maskandi Acoustic Bard / Ceremonial Cantor.
  static const String timbreCantor = '$artworkDir/timbre_cantor.png';

  /// 512x512 portrait of the Durban Gqom Producer / Chanter.
  static const String timbreProducer = '$artworkDir/timbre_producer.png';

  /// 512x512 Heritage Crate vinyl artwork (African Sunset Melodies).
  static const String heritageCrateCover = '$artworkDir/heritage_crate_cover.png';

  /// 720x1280 mobile portrait hero backdrop (Music, Feel, Escape).
  static const String splashHero = '$artworkDir/splash_hero.png';

  /// Phase 68: Additional studio artworks registered under assets/artwork/.
  static const String sunsetMelodiesCover =
      '$artworkDir/Vhunambi_ African Sunset Melodies.png';
  static const String fiveVoicesCover =
      '$artworkDir/Vhunambi_ Five Voices, One Vision.png';
  static const String musicFeelEscapeCover =
      '$artworkDir/Vhunambi_ Music, Feel, Escape.png';

  /// Ordered rotation pool used when an unfamiliar genre/track has no explicit URL.
  static const List<String> allBundledArtworkAssets = <String>[
    sunsetMelodiesCover,
    timbreProducer,
    timbreCrooner,
    timbreElder,
    timbreCantor,
    heritageCrateCover,
    timbrePoet,
    fiveVoicesCover,
    musicFeelEscapeCover,
    splashHero,
  ];

  // ---------------------------------------------------------------------------
  // Profile & Timbre Lookup Bridges
  // ---------------------------------------------------------------------------

  /// Deterministically resolves one of the 10 bundled artworks for [genre]
  /// (and optional [seedId] to ensure distinct adjacent cards within the same genre).
  static String resolveGenreCoverAsset(String genre, {String? seedId}) {
    final g = genre.toLowerCase().trim();
    if (g.contains('amapiano') ||
        g.contains('afro house') ||
        g.contains('private')) {
      if (seedId != null && seedId.hashCode.isOdd) {
        return musicFeelEscapeCover;
      }
      return sunsetMelodiesCover;
    }
    if (g.contains('gqom') || g.contains('bacardi') || g.contains('3-step')) {
      return timbreProducer;
    }
    if (g.contains('maskandi') ||
        g.contains('mbaqanga') ||
        g.contains('isicathamiya')) {
      return timbreElder;
    }
    if (g.contains('afrobeats') || g.contains('r&b') || g.contains('highlife')) {
      return timbreCrooner;
    }
    if (g.contains('tshiven') || g.contains('shangaan') || g.contains('kwaito')) {
      return timbreCantor;
    }
    if (g.contains('spoken') || g.contains('bongo') || g.contains('soul')) {
      return timbrePoet;
    }
    if (g.contains('gospel') || g.contains('choir') || g.contains('ensemble')) {
      return fiveVoicesCover;
    }
    if (g.contains('heritage')) {
      return heritageCrateCover;
    }
    if (seedId != null && seedId.isNotEmpty) {
      final index = seedId.hashCode.abs() % allBundledArtworkAssets.length;
      return allBundledArtworkAssets[index];
    }
    return splashHero;
  }

  /// Resolves either a normalized remote HTTP URL, an `asset:` URI, a direct
  /// `assets/` path, or falls back deterministically via [resolveGenreCoverAsset].
  static String resolveTrackCoverSource({
    String? coverUrl,
    required String genre,
    String? seedId,
  }) {
    final raw = (coverUrl ?? '').trim();
    if (raw.startsWith('asset:')) {
      final stripped = raw.substring('asset:'.length).trim();
      if (stripped.isNotEmpty) return stripped;
    }
    if (raw.startsWith('assets/')) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return AppConstants.normalizeCloudMediaUrl(raw);
    }
    return resolveGenreCoverAsset(genre, seedId: seedId);
  }

  /// Maps a canonical Bantu voice profile ID to its 512x512 portrait asset.
  static String? voiceTimbreForId(String id) {
    switch (id) {
      case 'venda_folk_elder':
        return timbreElder;
      case 'soweto_soul_lead':
        return timbreCrooner;
      case 'durban_gqom_chanter':
        return timbreProducer;
      case 'maskandi_bard':
        return timbreCantor;
      case 'limpopo_pop_queen':
        return timbrePoet;
      default:
        return null;
    }
  }

  /// Reusable widget rendering the golden Vhunambi brand crest glyph with
  /// safe error fallback.
  static Widget glyphImage({
    double size = 32,
    BoxFit fit = BoxFit.contain,
    Key? key,
  }) {
    return Image.asset(
      vhunambiGlyph,
      key: key ?? const Key('vhunambi_brand_glyph_image'),
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF97316),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.6,
          color: Colors.black,
        ),
      ),
    );
  }

  /// Reusable widget rendering the transparent Vhunambi brand wordmark.
  static Widget wordmarkImage({
    double? height = 28,
    double? width,
    BoxFit fit = BoxFit.contain,
    Key? key,
  }) {
    return Image.asset(
      vhunambiWordmark,
      key: key ?? const Key('vhunambi_brand_wordmark_image'),
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Text(
        'VHUNAMBI',
        style: TextStyle(
          fontSize: height != null ? height * 0.7 : 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Reusable widget rendering the compact Vhunambi brand mark (SVG) for the
  /// studio header (VH-006). Falls back to an orange circle glyph when the
  /// asset is unavailable.
  static Widget compactMarkImage({
    double size = 32,
    BoxFit fit = BoxFit.contain,
    Key? key,
  }) {
    return Image.asset(
      vhunambiCompactMark,
      key: key ?? const Key('vhunambi_brand_compact_mark_image'),
      width: size,
      height: size,
      fit: fit,
      color: AppColors.brandPrimary,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.6,
          color: AppColors.brandContrast,
        ),
      ),
    );
  }
}
