# Phase 70 Technical Design Specification (Compilable Reference Implementation)

- **Document ID:** `VHUNAMBI-SPEC-P70-DESIGN-V1`
- **Phase:** `Phase 70` (`phase_70_song_cockpit_and_visitor_profile_glass_overhaul`)
- **Upstream Blueprint & Requirements:** [blueprint.md](./blueprint.md) | [requirements.md](./requirements.md)
- **Strict Code Standard:** 100% compilable Dart (`package:vhunambi_client`), TypeScript (`apps/vhunambi_api`), and PostgreSQL/SQLite SQL. Zero `// TODO` placeholders, zero unused private fields, zero raw Unicode emojis (`STD-UIUX-001`), zero stock Material `Icons.*` in new/overhauled widgets.

---

## PART I — OVERHAUL PASS 1 (`M70.1` – `M70.2`): GLASS SYSTEM, `VhunambiMood`, `ViewerRole` & ROLE-AWARE SONG COCKPIT

### §1. `VhunambiGlassSurface` (`EP-P70-GLASS-SURFACE`)
**Target File:** `apps/vhunambi_client/lib/core/widgets/vhunambi_glass_surface.dart`

```dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';

/// Visual elevation tier for [VhunambiGlassSurface] (`REQ-P70-GLASS-01`).
enum VhunambiGlassVariant {
  /// Standard frosted card for content sections (telemetry, bio, song rows).
  card,

  /// Interactive pill or chip with elevated contrast for Light & Dark modes.
  pill,

  /// Elevated chrome surface (sticky header / hero floating capsule).
  chrome,
}

/// Dual-theme 3-layer glassmorphism primitive calibrated for Warm African Daylight
/// ("Morning Mist") and Obsidian Studio ("Obsidian Night") (`EP-P70-GLASS-SURFACE`).
///
/// Android 60 FPS Guardrail (`REQ-P70-GLASS-02`):
/// - [enableLiveBlur] defaults to `false` so repeating list/grid cards never
///   allocate per-item `BackdropFilter` offscreen render targets.
/// - Opt-in live blur clamps [blurSigma] to `[0.0, 16.0]` inside a `ClipRRect`
///   and `RepaintBoundary`.
class VhunambiGlassSurface extends StatelessWidget {
  final Widget child;
  final VhunambiGlassVariant variant;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableLiveBlur;
  final double blurSigma;
  final Color? tintAccent;
  final Color? borderColorOverride;
  final double borderWidth;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const VhunambiGlassSurface({
    super.key,
    required this.child,
    this.variant = VhunambiGlassVariant.card,
    this.borderRadius,
    this.padding,
    this.margin,
    this.enableLiveBlur = false,
    this.blurSigma = 14.0,
    this.tintAccent,
    this.borderColorOverride,
    this.borderWidth = 1.0,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedRadius =
        borderRadius ??
        switch (variant) {
          VhunambiGlassVariant.card => AppRadius.cardBorder,
          VhunambiGlassVariant.pill => AppRadius.pillBorder,
          VhunambiGlassVariant.chrome => AppRadius.cardBorder,
        };

    final LinearGradient fillGradient = _buildGradient(isDark);
    final Color strokeColor = borderColorOverride ?? _resolveBorder(isDark);
    final List<BoxShadow> shadows = _resolveShadows(isDark);

    final Widget decorated = Container(
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        gradient: fillGradient,
        borderRadius: resolvedRadius,
        border: Border.all(color: strokeColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (!enableLiveBlur) {
      if (margin != null) {
        return Padding(padding: margin!, child: decorated);
      }
      return decorated;
    }

    final clampedSigma = blurSigma.clamp(0.0, 16.0);
    final Widget blurred = RepaintBoundary(
      child: ClipRRect(
        borderRadius: resolvedRadius is BorderRadius
            ? resolvedRadius
            : AppRadius.cardBorder,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: clampedSigma,
            sigmaY: clampedSigma,
          ),
          child: decorated,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: blurred);
    }
    return blurred;
  }

  LinearGradient _buildGradient(bool isDark) {
    if (variant == VhunambiGlassVariant.pill) {
      final base = isDark
          ? AppColors.darkSurfaceSecondary
          : AppColors.lightSurfaceSecondary;
      final topColor = tintAccent != null
          ? Color.alphaBlend(
              tintAccent!.withValues(alpha: isDark ? 0.16 : 0.12),
              base.withValues(alpha: 0.88),
            )
          : base.withValues(alpha: 0.88);
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[topColor, base.withValues(alpha: isDark ? 0.78 : 0.80)],
      );
    }

    if (isDark) {
      final topBase = AppColors.darkSurfaceSecondary.withValues(alpha: 0.74);
      final bottomBase = AppColors.darkSurfaceElevated.withValues(alpha: 0.58);
      final top = tintAccent != null
          ? Color.alphaBlend(tintAccent!.withValues(alpha: 0.10), topBase)
          : topBase;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[top, bottomBase],
      );
    }

    final topBase = AppColors.lightSurfaceElevated.withValues(alpha: 0.78);
    final bottomBase = AppColors.lightSurfaceModal.withValues(alpha: 0.62);
    final top = tintAccent != null
        ? Color.alphaBlend(tintAccent!.withValues(alpha: 0.08), topBase)
        : topBase;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[top, bottomBase],
    );
  }

  Color _resolveBorder(bool isDark) {
    if (isDark) {
      return Color.alphaBlend(
        Colors.white.withValues(alpha: 0.12),
        AppColors.darkBorderSubtle,
      );
    }
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.65),
      AppColors.lightBorderSubtle,
    );
  }

  List<BoxShadow> _resolveShadows(bool isDark) {
    if (variant == VhunambiGlassVariant.pill) {
      return const <BoxShadow>[];
    }
    return <BoxShadow>[
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : const Color(0xFF121216).withValues(alpha: 0.06),
        blurRadius: isDark ? 20 : 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
```

---

### §2. `VhunambiAmbientMeshBackdrop` (`REQ-P70-GLASS-03`)
**Target File:** `apps/vhunambi_client/lib/core/widgets/vhunambi_ambient_mesh_backdrop.dart`

```dart
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';

/// Static ambient radial mesh backdrop painted behind scrollable glass screens
/// (`TrackDetailView`, `ArtistProfileView`).
///
/// Wrapped in a [RepaintBoundary] so scrolling content above it never triggers
/// radial shader re-rasterization on mid-range Android GPUs (`REQ-P70-GLASS-03`).
class VhunambiAmbientMeshBackdrop extends StatelessWidget {
  final Color primaryGlow;
  final Color secondaryGlow;
  final Widget child;

  const VhunambiAmbientMeshBackdrop({
    super.key,
    this.primaryGlow = AppColors.brandPrimary,
    this.secondaryGlow = const Color(0xFF38BDF8),
    required this.child,
  });

  /// Deterministically maps a genre string to a curated ambient glow pair.
  factory VhunambiAmbientMeshBackdrop.forGenre({
    Key? key,
    required String genre,
    required Widget child,
  }) {
    final g = genre.trim().toLowerCase();
    final (Color primary, Color secondary) = switch (g) {
      'amapiano' => (const Color(0xFFF59E0B), const Color(0xFFD97706)),
      'gqom' => (const Color(0xFF6366F1), const Color(0xFF312E81)),
      'maskandi' => (const Color(0xFF10B981), const Color(0xFF065F46)),
      'afro house' || 'afro-house' => (
        const Color(0xFFEA580C),
        const Color(0xFF7C2D12),
      ),
      'afro jazz' || 'afro-jazz' => (
        const Color(0xFF3B82F6),
        const Color(0xFF1E3A8A),
      ),
      'kwaito' => (const Color(0xFFEF4444), const Color(0xFF991B1B)),
      _ => (AppColors.brandPrimary, const Color(0xFFF59E0B)),
    };
    return VhunambiAmbientMeshBackdrop(
      key: key,
      primaryGlow: primary,
      secondaryGlow: secondary,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = AppColors.surfaceCanvasOf(context);
    final primaryAlpha = isDark ? 0.22 : 0.16;
    final secondaryAlpha = isDark ? 0.16 : 0.12;

    return ColoredBox(
      color: canvas,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.82),
                      radius: 1.05,
                      colors: <Color>[
                        primaryGlow.withValues(alpha: primaryAlpha),
                        canvas.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.85, 0.25),
                        radius: 1.15,
                        colors: <Color>[
                          secondaryGlow.withValues(alpha: secondaryAlpha),
                          canvas.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
```

---

### §3. Canonical `VhunambiMood` (`EP-P70-MOOD-TAXONOMY`)
**Target File:** `apps/vhunambi_client/lib/core/design_system/tokens/vhunambi_mood.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';

/// Canonical 6-mood wire taxonomy unifying `design_enums.dart`, `StudioFormState`,
/// `exploreMoodFilterProvider`, `TrackDetailEntity`, and `apps/vhunambi_api`
/// (`EP-P70-MOOD-TAXONOMY`, `REQ-P70-MOOD-01..03`).
enum VhunambiMood {
  uplifting(
    moodId: 'uplifting',
    label: 'Uplifting',
    icon: PhosphorIconsFill.sunHorizon,
    accentColor: Color(0xFFF59E0B),
  ),
  soulful(
    moodId: 'soulful',
    label: 'Soulful',
    icon: PhosphorIconsFill.heartHalf,
    accentColor: Color(0xFFD97706),
  ),
  energetic(
    moodId: 'energetic',
    label: 'Energetic',
    icon: PhosphorIconsFill.lightning,
    accentColor: Color(0xFFEF4444),
  ),
  chill(
    moodId: 'chill',
    label: 'Chill',
    icon: PhosphorIconsFill.moonStars,
    accentColor: Color(0xFF0EA5E9),
  ),
  hypnotic(
    moodId: 'hypnotic',
    label: 'Hypnotic',
    icon: PhosphorIconsFill.spiral,
    accentColor: Color(0xFF7C3AED),
  ),
  romantic(
    moodId: 'romantic',
    label: 'Romantic',
    icon: PhosphorIconsFill.sparkle,
    accentColor: Color(0xFFEC4899),
  );

  final String moodId;
  final String label;
  final IconData icon;
  final Color accentColor;

  const VhunambiMood({
    required this.moodId,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  /// Lossless normalizer absorbing all legacy Studio, Explore, Design Enum,
  /// and backend (`edge_persistence_bridge.ts`) mood strings (`REQ-P70-MOOD-02`).
  static VhunambiMood normalize(String? raw) {
    final cleaned = (raw ?? '').trim().toLowerCase();
    if (cleaned.isEmpty) return VhunambiMood.uplifting;

    return switch (cleaned) {
      'uplifting' || 'vibrant' || 'joyful' || 'happy' || 'celebratory' =>
        VhunambiMood.uplifting,
      'soulful' ||
      'soulful & nostalgic' ||
      'nostalgic' ||
      'melancholic' ||
      'warm' ||
      'reflective' =>
        VhunambiMood.soulful,
      'energetic' || 'electrifying' || 'party' || 'hype' || 'club' =>
        VhunambiMood.energetic,
      'chill' || 'peaceful' || 'calm' || 'relaxed' || 'laid-back' =>
        VhunambiMood.chill,
      'hypnotic' || 'deep' || 'dark' || 'atmospheric' || 'minimal' =>
        VhunambiMood.hypnotic,
      'romantic' || 'sensual' || 'intimate' || 'love' =>
        VhunambiMood.romantic,
      _ => _fuzzyMatch(cleaned),
    };
  }

  static VhunambiMood _fuzzyMatch(String cleaned) {
    if (cleaned.contains('soul') ||
        cleaned.contains('nostalg') ||
        cleaned.contains('melanchol')) {
      return VhunambiMood.soulful;
    }
    if (cleaned.contains('energ') ||
        cleaned.contains('party') ||
        cleaned.contains('electr')) {
      return VhunambiMood.energetic;
    }
    if (cleaned.contains('chill') ||
        cleaned.contains('calm') ||
        cleaned.contains('peace')) {
      return VhunambiMood.chill;
    }
    if (cleaned.contains('hypno') ||
        cleaned.contains('deep') ||
        cleaned.contains('dark') ||
        cleaned.contains('atmos')) {
      return VhunambiMood.hypnotic;
    }
    if (cleaned.contains('roman')) {
      return VhunambiMood.romantic;
    }
    return VhunambiMood.uplifting;
  }

  /// Bridges legacy onboarding [Mood] enum values into canonical [VhunambiMood].
  static VhunambiMood fromLegacyMood(Mood legacy) {
    return switch (legacy) {
      Mood.joyful => VhunambiMood.uplifting,
      Mood.melancholic => VhunambiMood.soulful,
      Mood.energetic => VhunambiMood.energetic,
      Mood.calm => VhunambiMood.chill,
      Mood.romantic => VhunambiMood.romantic,
    };
  }

  /// Projects canonical [VhunambiMood] back onto legacy [Mood] for `MoodColorChip`.
  Mood toLegacyMood() {
    return switch (this) {
      VhunambiMood.uplifting => Mood.joyful,
      VhunambiMood.soulful => Mood.melancholic,
      VhunambiMood.energetic => Mood.energetic,
      VhunambiMood.chill => Mood.calm,
      VhunambiMood.hypnotic => Mood.calm,
      VhunambiMood.romantic => Mood.romantic,
    };
  }
}
```

---

### §4. Deterministic `ViewerRole` Policy (`EP-P70-VIEWER-ROLE`)
**Target File:** `apps/vhunambi_client/lib/core/auth/viewer_role.dart`

```dart
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

/// Deterministic viewer ownership classification for Track & Creator domains
/// (`EP-P70-VIEWER-ROLE`, `REQ-P70-ROLE-01..02`).
enum ViewerRole {
  /// The signed-in creator owns this track/resource and has full studio access.
  owner,

  /// An outside listener or follower viewing another creator's work.
  visitor,
}

const Set<String> _localSeedOwnerAliases = <String>{
  'me',
  'usr_me',
  'user_current',
  'current_user',
  'creator_me',
};

/// Resolves whether the active signed-in user owns a resource attributed to
/// [ownerCreatorId] / [ownerHandle] (`REQ-P70-ROLE-01..02`).
///
/// Fails closed to [ViewerRole.visitor] whenever [ownerCreatorId] and
/// [ownerHandle] are both blank, or belong to a different creator (`@lerato`,
/// `@fifi`, `@makhadzi`, etc.).
ViewerRole resolveViewerRole({
  required String? ownerCreatorId,
  String? ownerHandle,
  required String activeCreatorId,
  String? activeHandle,
}) {
  final rawOwnerId = (ownerCreatorId ?? '').trim().toLowerCase();
  final rawOwnerHandle = (ownerHandle ?? '')
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '');

  if (rawOwnerId.isEmpty && rawOwnerHandle.isEmpty) {
    return ViewerRole.visitor;
  }

  final canonicalActive = canonicalizeCreatorId(activeCreatorId);
  final activeSlug = extractRawCreatorId(canonicalActive).toLowerCase();
  final normalizedActiveHandle = (activeHandle ?? '')
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '');

  // Explicit local-user placeholder aliases created in offline/demo studio flows.
  if (_localSeedOwnerAliases.contains(rawOwnerId)) {
    return ViewerRole.owner;
  }

  if (rawOwnerId.isNotEmpty) {
    final canonicalOwner = canonicalizeCreatorId(
      rawOwnerId,
      fallback: '__unowned__',
    );
    if (canonicalOwner != '__unowned__' && canonicalOwner == canonicalActive) {
      return ViewerRole.owner;
    }
    final ownerSlug = extractRawCreatorId(rawOwnerId).toLowerCase();
    if (ownerSlug.isNotEmpty &&
        (ownerSlug == activeSlug ||
            (normalizedActiveHandle.isNotEmpty &&
                ownerSlug == normalizedActiveHandle))) {
      return ViewerRole.owner;
    }
  }

  if (rawOwnerHandle.isNotEmpty) {
    final canonicalHandleOwner = canonicalizeCreatorId(
      rawOwnerHandle,
      fallback: '__unowned__',
    );
    if (canonicalHandleOwner != '__unowned__' &&
        canonicalHandleOwner == canonicalActive) {
      return ViewerRole.owner;
    }
    if (normalizedActiveHandle.isNotEmpty &&
        rawOwnerHandle == normalizedActiveHandle) {
      return ViewerRole.owner;
    }
  }

  return ViewerRole.visitor;
}
```

---

### §5. `MiniPlayerHost` Pushed-Route Suppression (`REQ-P70-MINI-01..02`)
**Target Files:**
- `apps/vhunambi_client/lib/core/navigation/navigation_providers.dart`
- `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`
- `apps/vhunambi_client/lib/features/player/presentation/providers/mini_player_controller.dart`

**Additive Providers in `navigation_providers.dart`:**
```dart
/// Reference-counted tracker for mounted `TrackDetailView` routes that already
/// render an inline `WaveformScrubber` (`Phase 70`, `REQ-P70-MINI-01`).
/// When > 0, `MiniPlayerHost` suppresses itself to avoid duplicate audio bars.
final trackDetailInlinePlayerMountedProvider = StateProvider<int>((ref) => 0);

/// Reference-counted tracker for pushed full-screen routes rendered outside
/// `RootShell`'s 56dp bottom navigation bar (`ArtistProfileView`, etc.)
/// (`Phase 70`, `REQ-P70-MINI-02`).
final pushedFullScreenOverlayCountProvider = StateProvider<int>((ref) => 0);
```

**Update in `mini_player_host.dart` (`_shouldHide` & `calculateAutoPosition` call site):**
```dart
    // Phase 70 (REQ-P70-MINI-01): Suppress floating MiniPlayerHost whenever
    // TrackDetailView renders its own inline WaveformScrubber.
    final trackDetailInlineCount = ref.watch(
      trackDetailInlinePlayerMountedProvider,
    );
    if (trackDetailInlineCount > 0) return true;

    // Phase 70 (REQ-P70-MINI-02): Suppress floating MiniPlayerHost on pushed
    // full-screen visitor profiles so it never occludes mid-screen tabs/cards.
    final pushedOverlayCount = ref.watch(pushedFullScreenOverlayCountProvider);
    if (pushedOverlayCount > 0) return true;
```

*(Note: Preserving the default `0` state for both providers ensures `test/features/player/widgets/mini_player_host_test.dart` and `test/features/player/phase33_adaptive_mini_player_test.dart` remain 100% untouched and green!)*

---

### §6. Extended `TrackDetailEntity` & Hydration (`REQ-P70-TRACK-01..02`)
**Target Files:**
- `apps/vhunambi_client/lib/features/track/domain/models/track_detail_models.dart`
- `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`

**Key Additions in `track_detail_models.dart`:**
1. Remove raw Unicode emojis from `reactionGlyphs` (replace with a Phosphor icon getter or remove emoji strings) and `licenseBadge` (replace `'⚖️ Commercial Use' : '🛡️ Personal Use'` with clean `'Commercial License' : 'Personal Rights'` while keeping icon rendering in Phosphor widgets!).
2. Add the 7 structured fields to `TrackDetailEntity`:
```dart
  final String? coverUrl;
  final String description;
  final DateTime? createdAt;
  final int bpm;
  final String musicalKey;
  final String moodId;
  final bool allowOpenStemsRemix;
```
With defaults in the constructor:
```dart
    this.coverUrl,
    this.description = '',
    this.createdAt,
    this.bpm = 113,
    this.musicalKey = 'F#m',
    this.moodId = 'uplifting',
    this.allowOpenStemsRemix = false,
```
And preserve all 7 fields in `copyWith(...)`, plus clean getters:
```dart
  /// Canonical `VhunambiMood` resolved from [moodId].
  VhunambiMood get canonicalMood => VhunambiMood.normalize(moodId);

  /// Clean license label without raw Unicode emojis (`STD-UIUX-001`).
  String get licenseBadge =>
      isCommercial ? 'Commercial License' : 'Personal Use';

  /// Visitor-safe provenance line (`REQ-P70-GATE-01`).
  String get visitorProvenanceNotice => allowOpenStemsRemix
      ? 'Created by $creatorHandle · Open Stems Allowed'
      : 'Created by $creatorHandle · All Rights Reserved';
```

**Hydration Update in `track_providers.dart` (`_lookupInitialTrack`):**
- When matching a `LibraryTrack` from `libraryTracksProvider`:
  - Map `coverUrl: libraryMatch.coverImageUrl`, `createdAt: libraryMatch.createdAt`, `description: 'Mastered studio composition in ${libraryMatch.genre} (${libraryMatch.language}).'`, `bpm: _defaultBpmForGenre(libraryMatch.genre)`, `musicalKey: 'F#m'`, `moodId: VhunambiMood.normalize(null).moodId`, and preserve the creator identity (`creatorId: activeCreatorId`, `creatorHandle: activeHandle`) so owned library tracks resolve cleanly to `ViewerRole.owner`.
- When matching an `Explore` `Track` from `exploreTracksProvider`:
  - Map `coverUrl: exploreMatch.coverUrl`, `moodId: VhunambiMood.normalize(exploreMatch.mood).moodId`, `bpm: _defaultBpmForGenre(exploreMatch.genre)`, `musicalKey: _defaultKeyForGenre(exploreMatch.genre)`, `description: '${exploreMatch.title} by ${exploreMatch.creatorName} — ${exploreMatch.genre} crafted in ${exploreMatch.language}.'`, `creatorId: canonicalizeCreatorId(exploreMatch.creatorHandle ?? exploreMatch.creatorName)`, `creatorHandle: exploreMatch.creatorHandle ?? handleFromCreatorId(exploreMatch.creatorName)`.
- Enrich `seededTrackDetails` (`seed-01` .. `seed-06`) with realistic `description`, `bpm`, `musicalKey`, `moodId`, `createdAt`, and `allowOpenStemsRemix` values (setting `seed-04` `'Soweto Sunset Groove'` by `@lerato_prod` with `allowOpenStemsRemix: false` so visitor sovereignty tests verify locked IP by default).

---

### §7. Role-Aware Song Cockpit Widgets & `TrackDetailView` (`M70.2`)

#### §7.1 `TrackHeroSection` (Role-Gated Provenance + `VhunambiTrackArtwork`)
**Target File:** `apps/vhunambi_client/lib/features/track/presentation/widgets/track_hero_section.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

class TrackHeroSection extends StatelessWidget {
  final TrackDetailEntity track;
  final ViewerRole viewerRole;
  final VoidCallback onCreatorTap;

  const TrackHeroSection({
    super.key,
    required this.track,
    required this.viewerRole,
    required this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = viewerRole == ViewerRole.owner;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: VhunambiTrackArtwork(
              key: const Key('track_hero_artwork'),
              coverUrl: track.coverUrl,
              genre: track.genre,
              trackId: track.id,
              width: 220,
              height: 220,
              borderRadius: BorderRadius.circular(24),
              badgeIconSize: 44,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          track.title,
          textAlign: TextAlign.center,
          style: AppTypography.displayMedium.copyWith(color: textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const Key('track_hero_creator_link'),
          onTap: onCreatorTap,
          borderRadius: AppRadius.pillBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${track.creatorName} (${track.creatorHandle})',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                const PhosphorIcon(
                  AppIcons.verified,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isOwner)
          VhunambiGlassSurface(
            key: const Key('track_owner_deed_card'),
            variant: VhunambiGlassVariant.card,
            tintAccent: AppColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PhosphorIcon(
                  PhosphorIconsFill.shieldCheck,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Created by you · ${track.licenseBadge}',
                        style: AppTypography.titleSmall.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TrackDetailEntity.ownershipNotice,
                        style: AppTypography.bodySmall.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          VhunambiGlassSurface(
            key: const Key('track_visitor_provenance_pill'),
            variant: VhunambiGlassVariant.pill,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PhosphorIcon(
                  track.allowOpenStemsRemix
                      ? PhosphorIconsFill.sparkle
                      : PhosphorIconsFill.lockSimple,
                  size: 15,
                  color: track.allowOpenStemsRemix
                      ? AppColors.brandPrimary
                      : textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    track.visitorProvenanceNotice,
                    style: AppTypography.bodySmall.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

#### §7.2 Light-Mode Safe `TrackActionsBar` (`SC-04`)
**Target File:** `apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

class TrackActionsBar extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onTip;
  final VoidCallback? onAddToPlaylist;

  const TrackActionsBar({
    super.key,
    required this.track,
    required this.onLike,
    required this.onShare,
    required this.onTip,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final likeAccent = track.isLiked ? AppColors.error : textPrimary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _GlassActionPill(
          pillKey: const Key('track_like_pill'),
          icon: track.isLiked ? AppIcons.heart : AppIcons.heartOutline,
          iconColor: likeAccent,
          label: '${track.likeCount}',
          labelColor: likeAccent,
          tintAccent: track.isLiked ? AppColors.error : null,
          onTap: onLike,
        ),
        _GlassActionPill(
          pillKey: const Key('track_plays_pill'),
          icon: AppIcons.play,
          iconColor: textPrimary,
          label: '${track.playCount}',
          labelColor: textPrimary,
          onTap: null,
        ),
        if (onAddToPlaylist != null)
          _GlassActionPill(
            pillKey: const Key('track_playlist_pill'),
            icon: AppIcons.playlist,
            iconColor: textPrimary,
            label: 'Save',
            labelColor: textPrimary,
            onTap: onAddToPlaylist,
          ),
        _GlassActionPill(
          pillKey: const Key('track_share_pill'),
          icon: AppIcons.share,
          iconColor: textPrimary,
          label: 'Share',
          labelColor: textPrimary,
          onTap: onShare,
        ),
        _GlassActionPill(
          pillKey: const Key('track_tip_pill'),
          icon: AppIcons.coin,
          iconColor: AppColors.coinGold,
          label: 'Tip Artist',
          labelColor: textPrimary,
          tintAccent: AppColors.coinGold,
          onTap: onTip,
        ),
      ],
    );
  }
}

class _GlassActionPill extends StatelessWidget {
  final Key pillKey;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final Color? tintAccent;
  final VoidCallback? onTap;

  const _GlassActionPill({
    required this.pillKey,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    this.tintAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      tintAccent: tintAccent,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return KeyedSubtree(key: pillKey, child: pill);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: pillKey,
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: pill,
      ),
    );
  }
}
```

#### §7.3 Compact Horizontal Phosphor `EmojiReactionDeck` (`REQ-P70-SCUX-03`)
**Target File:** `apps/vhunambi_client/lib/features/track/presentation/widgets/emoji_reaction_deck.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

class EmojiReactionDeck extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueChanged<String> onReact;

  const EmojiReactionDeck({
    super.key,
    required this.track,
    required this.onReact,
  });

  static const List<({String id, String label, IconData icon, Color color})>
  _specs = <({String id, String label, IconData icon, Color color})>[
    (
      id: 'fire',
      label: 'Fire',
      icon: AppIcons.flame,
      color: AppColors.brandPrimary,
    ),
    (
      id: 'soul',
      label: 'Soul',
      icon: AppIcons.heart,
      color: AppColors.error,
    ),
    (
      id: 'groove',
      label: 'Groove',
      icon: AppIcons.piano,
      color: Color(0xFF0EA5E9),
    ),
    (
      id: 'crown',
      label: 'Royalty',
      icon: AppIcons.crown,
      color: AppColors.coinGold,
    ),
    (
      id: 'spark',
      label: 'Vibe',
      icon: AppIcons.sparkle,
      color: Color(0xFFA855F7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    return SizedBox(
      key: const Key('track_reaction_rail'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _specs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final spec = _specs[index];
          final count = track.reactionCounts[spec.id] ?? 0;
          final isSelected = track.userReaction == spec.id;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('track_reaction_${spec.id}'),
              onTap: () => onReact(spec.id),
              borderRadius: AppRadius.pillBorder,
              child: VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                tintAccent: isSelected ? spec.color : null,
                borderColorOverride: isSelected ? spec.color : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PhosphorIcon(spec.icon, size: 16, color: spec.color),
                    const SizedBox(width: 6),
                    Text(
                      spec.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? spec.color
                              : AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

#### §7.4 `TrackSonicTelemetryCard` (`REQ-P70-SCUX-04`)
**Target File:** `apps/vhunambi_client/lib/features/track/presentation/widgets/track_sonic_telemetry_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

class TrackSonicTelemetryCard extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueChanged<VhunambiMood>? onMoodTap;

  const TrackSonicTelemetryCard({
    super.key,
    required this.track,
    this.onMoodTap,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recent Release';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mood = track.canonicalMood;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final description = track.description.trim().isNotEmpty
        ? track.description.trim()
        : '${track.title} — ${track.genre} production recorded in ${track.language}.';

    return VhunambiGlassSurface(
      key: const Key('track_sonic_telemetry_card'),
      variant: VhunambiGlassVariant.card,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const PhosphorIcon(
                AppIcons.info,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Song Description & Sonic DNA',
                style: AppTypography.titleSmall.copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodyMuted.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _TelemetryChip(
                icon: AppIcons.songs,
                label: track.genre,
              ),
              _TelemetryChip(
                icon: AppIcons.waveform,
                label: '${track.bpm} BPM · ${track.musicalKey}',
              ),
              _TelemetryChip(
                icon: AppIcons.disc,
                label: '${track.language} · ${track.formattedDuration}',
              ),
              _TelemetryChip(
                icon: PhosphorIconsRegular.calendarBlank,
                label: _formatDate(track.createdAt),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('track_mood_chip'),
                  onTap: onMoodTap == null ? null : () => onMoodTap!(mood),
                  borderRadius: AppRadius.pillBorder,
                  child: VhunambiGlassSurface(
                    variant: VhunambiGlassVariant.pill,
                    tintAccent: mood.accentColor,
                    borderColorOverride: mood.accentColor.withValues(
                      alpha: 0.55,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PhosphorIcon(
                          mood.icon,
                          size: 14,
                          color: mood.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mood.label,
                          style: AppTypography.caption.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _TelemetryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TelemetryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

#### §7.5 Role-Gating & Threaded Comments Integration in `TrackDetailView`
**Target File:** `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`

Complete lifecycle & role-gated section builder added to `_TrackDetailViewState`:

```dart
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  StateController<int>? _trackInlinePlayerCounter;
  bool _didIncrementInlinePlayer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(trackDetailInlinePlayerMountedProvider.notifier);
      _trackInlinePlayerCounter = counter;
      _didIncrementInlinePlayer = true;
      counter.state++;
      ref
          .read(reelsCommentsProvider.notifier)
          .syncCommentsForClip(widget.trackId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    final counter = _trackInlinePlayerCounter;
    if (_didIncrementInlinePlayer && counter != null) {
      _didIncrementInlinePlayer = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  Future<void> _submitThreadedTrackComment(TrackDetailEntity track) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    await ref
        .read(reelsCommentsProvider.notifier)
        .addComment(
          clipId: track.id,
          text: text,
          contentCreatorId: track.creatorId,
          contentCreatorHandle: track.creatorHandle,
        );
  }

  Widget _buildRoleGatedStudioOrRemixSection(
    BuildContext context,
    TrackDetailEntity track,
    ViewerRole viewerRole,
    StemSeparationState stemState,
  ) {
    final isTrackOwner = viewerRole == ViewerRole.owner;
    if (!isTrackOwner) {
      if (!track.allowOpenStemsRemix) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('track_visitor_open_stems_remix_btn'),
            onPressed: () => _handleRemix(track),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.brandPrimary),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            icon: const PhosphorIcon(
              AppIcons.remix,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            label: Text(
              'Remix Open Stems',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        UtilityToolDock(
          onDownload: () => _showDownloadDialog(track),
          onExportVideo: () => _openVideoExport(track),
          onRemix: () => _handleRemix(track),
          onCopyEmbed: () => _copyEmbedCode(track),
        ),
        const SizedBox(height: AppSpacing.lg),
        StemSeparationLab(
          trackId: track.id,
          stemState: stemState,
        ),
        const SizedBox(height: AppSpacing.md),
        TrackLivingBiomePreviewCard(track: track),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const Key('track_open_mixer_btn'),
          onPressed: () => _openPocketStemMixer(track),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: AppColors.borderSubtleOf(context)),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.inputBorder,
            ),
          ),
          icon: const PhosphorIcon(
            AppIcons.sliders,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          label: Text(
            'Open Pocket Stem Mixer',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('track_detail_open_mastering_btn'),
          onPressed: () => _openMasteringPolisher(track),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: AppColors.borderSubtleOf(context)),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.inputBorder,
            ),
          ),
          icon: const PhosphorIcon(
            AppIcons.sparkle,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          label: Text(
            'Master Track (Studio Polisher)',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PromptAttributionCard(
          prompt: track.prompt,
          onRemixPrompt: () => _handleRemix(track),
        ),
      ],
    );
  }
```

And inside `TrackDetailView.build`, mount `VhunambiAmbientMeshBackdrop.forGenre(genre: track.genre, child: ...)` as the body root, mount `ThreadedCommentsSection(clipOrPostId: track.id, contentCreatorId: track.creatorId, contentCreatorHandle: track.creatorHandle, onRequestReplyFocus: () => _composerFocusNode.requestFocus())` in place of legacy `CommentsSection`, pin `StudioReactionComposerBar(clipOrPostId: track.id, creatorHandle: track.creatorHandle, controller: _commentController, focusNode: _composerFocusNode, onSubmit: () => _submitThreadedTrackComment(track))` in `Scaffold.bottomNavigationBar`, and replace every `Icons.*` in `track_detail_view.dart`, `waveform_scrubber.dart`, `more_like_this_shelf.dart`, and `prompt_attribution_card.dart` with `PhosphorIcon(AppIcons.* / PhosphorIcons*)`.

---

## PART II — OVERHAUL PASS 2 (`M70.3` – `M70.4`): FACEBOOK-BENCHMARK VISITOR PROFILE, `EP-P58` PRODUCER BEATS & BACKEND PARITY

### §8. High-Contrast Glass `ProfileBannerHeader` (`VP-01`, `VP-05`, `VP-07`)
**Target File:** `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_banner_header.dart`

Key surgical upgrades:
1. Replace all 5 stock `Icons.*` (`piano_rounded`, `album_rounded`, `graphic_eq_rounded`, `verified_rounded`, `monetization_on_rounded`) with `AppIcons.piano`, `AppIcons.releases`, `AppIcons.waveform`, `AppIcons.verified`, `AppIcons.coin`.
2. Fix the Light-Mode white-on-white `'Following'` pill (`VP-01`):
```dart
ElevatedButton(
  key: const Key('profile_follow_btn'),
  onPressed: onToggleFollow,
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(124, 44),
    elevation: 0,
    backgroundColor: profile.isFollowing
        ? AppColors.surfaceSecondaryOf(context)
        : AppColors.brandPrimary,
    foregroundColor: profile.isFollowing
        ? AppColors.textPrimaryOf(context)
        : AppColors.brandContrast,
    side: profile.isFollowing
        ? BorderSide(color: AppColors.borderSubtleOf(context), width: 1.2)
        : BorderSide.none,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      PhosphorIcon(
        profile.isFollowing ? AppIcons.check : AppIcons.plus,
        size: 16,
      ),
      const SizedBox(width: 6),
      Text(
        profile.isFollowing ? 'Following' : 'Follow',
        style: AppTypography.titleSmall.copyWith(
          color: profile.isFollowing
              ? AppColors.textPrimaryOf(context)
              : AppColors.brandContrast,
        ),
      ),
    ],
  ),
)
```
3. Consolidate standalone Share and Report `IconButton`s into a single `[ ••• ]` glass pill (`Key('visitor_profile_overflow_btn')`, `minWidth: 44, minHeight: 44`, `PhosphorIcon(AppIcons.dotsHorizontal)`) invoking `onOpenOverflowMenu`, which opens a clean `showModalBottomSheet` containing `Share Profile`, `Copy @handle`, and `Report Creator`.

---

### §9. Dynamic Visitor Projections & De-Emojified `TopSupportersLeaderboard`
**Target Files:**
- `apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart`
- `apps/vhunambi_client/lib/features/profile/presentation/widgets/top_supporters_leaderboard.dart`
- `apps/vhunambi_client/lib/features/profile/domain/models/profile_models.dart`

**Live Creator Catalog Providers (add to `profile_providers.dart`):**
```dart
/// Dynamically merges live tracks belonging to [artistId] from Explore and
/// Library feeds so `ArtistProfileView` never displays static hardcoded songs
/// (`REQ-P70-PTAB-02`).
final creatorCatalogTracksProvider =
    Provider.family<List<Track>, String>((ref, artistId) {
      final canonicalTarget = canonicalizeCreatorId(artistId);
      final rawTarget = extractRawCreatorId(artistId).toLowerCase();
      final exploreTracks = ref.watch(exploreTracksProvider);
      final seenIds = <String>{};
      final results = <Track>[];

      bool matchesCreator(String? creatorName, String? creatorHandle) {
        final handleSlug = (creatorHandle ?? '')
            .trim()
            .toLowerCase()
            .replaceFirst(RegExp(r'^@+'), '');
        final nameSlug = (creatorName ?? '').trim().toLowerCase();
        final canonicalFromHandle = handleSlug.isNotEmpty
            ? canonicalizeCreatorId(handleSlug, fallback: '')
            : '';
        return handleSlug == rawTarget ||
            nameSlug == rawTarget ||
            canonicalFromHandle == canonicalTarget;
      }

      for (final track in exploreTracks) {
        if (matchesCreator(track.creatorName, track.creatorHandle) &&
            seenIds.add(track.id)) {
          results.add(track);
        }
      }
      return results;
    });

/// Projects Kinetic Posts authored by [artistId] for `Overview` and `Posts & Reels`
/// (`EP-P69-KPOST-FOCUS-ROUTE`, `REQ-P70-PTAB-02`).
final creatorKineticPostsProvider =
    Provider.family<List<SocialMusicPost>, String>((ref, artistId) {
      final canonicalTarget = canonicalizeCreatorId(artistId);
      final rawTarget = extractRawCreatorId(artistId).toLowerCase();
      final posts = ref.watch(socialFeedPostsProvider);

      return posts.where((post) {
        final cid = canonicalizeCreatorId(post.creatorId, fallback: '');
        final handleSlug = post.creatorHandle
            .trim()
            .toLowerCase()
            .replaceFirst(RegExp(r'^@+'), '');
        return cid == canonicalTarget ||
            extractRawCreatorId(post.creatorId).toLowerCase() == rawTarget ||
            handleSlug == rawTarget;
      }).toList();
    });
```

**De-Emojify `profile_models.dart` & `top_supporters_leaderboard.dart`:**
- In `SupporterEntity.rankBadge` (`profile_models.dart#L22-L29`): return `'Gold'`, `'Silver'`, `'Bronze'`, `'Fan'` (zero medal emojis).
- In `TipRecordEntity.amountLabel` (`profile_models.dart#L80-L85`): return `'$amountCoins Coins (R${amountZar.toStringAsFixed(0)})'` / `'$amountCredits Credits'`.
- In `TopSupportersLeaderboard`: replace `Icons.military_tech_outlined` with `PhosphorIcon(AppIcons.trophy, ...)` and replace `_getMedal(supporter.rank)` emoji text with `PhosphorIcon(PhosphorIconsFill.medal, color: rankColor, size: 22)`.

---

### §10. 5-Tab Facebook-Benchmark `ArtistProfileView` (`M70.3`)
**Target File:** `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart`

Complete lifecycle, inline social proof strip, `[ ••• ]` overflow action sheet, and 5-tab visitor body widgets (`Overview`, `Songs`, `Posts & Reels`, `Beats`, `About`) — removing `LoadingOverlay`, `ProfileStatsGrid` (`Day Streak`), `ArtistVoiceShowcaseCard`, `CreatorDnaProfileCard`, and all static `'seed-01'`/`'Fifi'` hardcoding:

```dart
  StateController<int>? _pushedOverlayCounter;
  bool _didIncrementPushedOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(pushedFullScreenOverlayCountProvider.notifier);
      _pushedOverlayCounter = counter;
      _didIncrementPushedOverlay = true;
      counter.state++;
    });
  }

  @override
  void dispose() {
    final counter = _pushedOverlayCounter;
    if (_didIncrementPushedOverlay && counter != null) {
      _didIncrementPushedOverlay = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  String _formatCompactMetric(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  Widget _buildInlineSocialProofStrip(
    BuildContext context,
    ArtistProfileEntity profile,
    int liveSongCount,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final resolvedSongs = liveSongCount > 0 ? liveSongCount : profile.songCount;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: VhunambiGlassSurface(
        key: const Key('visitor_profile_inline_stats'),
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              '${_formatCompactMetric(profile.followerCount)} followers',
              style: AppTypography.bodySmall.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '${_formatCompactMetric(profile.monthlyListenersCount)} monthly listeners',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '$resolvedSongs songs',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '${_formatCompactMetric(profile.playCount)} plays',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfileOverflowSheet(
    BuildContext context,
    ArtistProfileEntity profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalBorder),
      builder: (sheetCtx) {
        final textPrimary = AppColors.textPrimaryOf(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  key: const Key('visitor_overflow_share'),
                  leading: PhosphorIcon(AppIcons.share, color: textPrimary),
                  title: Text(
                    'Share Profile',
                    style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: profile.profileUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${profile.displayName} profile link'),
                      ),
                    );
                  },
                ),
                ListTile(
                  key: const Key('visitor_overflow_copy_handle'),
                  leading: PhosphorIcon(PhosphorIconsRegular.copy, color: textPrimary),
                  title: Text(
                    'Copy ${profile.handle}',
                    style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: profile.handle));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied ${profile.handle}')),
                    );
                  },
                ),
                ListTile(
                  key: const Key('visitor_overflow_report'),
                  leading: const PhosphorIcon(
                    PhosphorIconsRegular.flag,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Report Creator',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Report submitted for ${profile.handle}.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisitorTabsScaffold(
    BuildContext context,
    ArtistProfileEntity profile,
    List<Track> liveTracks,
    List<SocialMusicPost> creatorPosts,
  ) {
    return DefaultTabController(
      length: 5,
      initialIndex: 0,
      child: NestedScrollView(
        headerSliverBuilder: (ctx, _) => <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ProfileBannerHeader(
                  profile: profile,
                  isOwner: false,
                  onToggleFollow: () => ref
                      .read(profileOperationProvider.notifier)
                      .toggleFollow(profile.id),
                  onTipArtist: () => _openTipSheet(profile),
                  onOpenOverflowMenu: () =>
                      _openProfileOverflowSheet(context, profile),
                ),
                _buildInlineSocialProofStrip(
                  context,
                  profile,
                  liveTracks.length,
                ),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.brandPrimary,
                labelColor: AppColors.brandPrimary,
                unselectedLabelColor: AppColors.textSecondaryOf(context),
                tabs: const <Tab>[
                  Tab(key: Key('visitor_tab_overview'), text: 'Overview'),
                  Tab(key: Key('visitor_tab_songs'), text: 'Songs'),
                  Tab(key: Key('visitor_tab_posts_reels'), text: 'Posts & Reels'),
                  Tab(key: Key('visitor_tab_beats'), text: 'Beats'),
                  Tab(key: Key('visitor_tab_about'), text: 'About'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: <Widget>[
            _buildOverviewTab(context, profile, liveTracks, creatorPosts),
            _buildSongsTab(context, profile, liveTracks),
            _buildPostsAndReelsTab(context, profile, creatorPosts),
            _buildBeatsTab(context, profile),
            _buildAboutTab(context, profile),
          ],
        ),
      ),
    );
  }
```

Each of the 5 tab builders (`_buildOverviewTab`, `_buildSongsTab`, `_buildPostsAndReelsTab`, `_buildBeatsTab`, `_buildAboutTab`) renders exclusively with `VhunambiGlassSurface`, `VhunambiTrackArtwork`, `PhosphorIcon(AppIcons.* / PhosphorIcons*)`, live `liveTracks` / `creatorPosts` / `producerBeatsFamilyProvider(profile.id)`, and routes post taps to `KineticPostFocusView.show(context, postId: post.id, initialPost: post)` and song taps to `TrackDetailView(trackId: track.id)` — with zero stock `Icons.*`, zero `'seed-01'`/`'Fifi'`/`'Ndo Mufuna Matibe'` hardcoding, zero `ArtistVoiceShowcaseCard`, and zero `CreatorDnaProfileCard`.

---

### §11. Consume `EP-P58-MKT-VERIFY-PRODUCER` (`GET /api/marketplace/producers/:producerId/beats`)
**Target Files:**
- `apps/vhunambi_client/lib/features/marketplace/domain/repositories/i_marketplace_repository.dart`
- `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`
- `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`

**Interface Addition (`i_marketplace_repository.dart`):**
```dart
  /// Fetches beats published by [producerId] via
  /// `GET /api/marketplace/producers/:producerId/beats` (`EP-P58-MKT-VERIFY-PRODUCER`).
  Future<List<BeatListingEntity>> getProducerBeats(String producerId);
```

**Repository Implementation (`http_marketplace_repository.dart`):**
```dart
  @override
  Future<List<BeatListingEntity>> getProducerBeats(String producerId) async {
    final cleanId = producerId.trim();
    if (cleanId.isEmpty) return const <BeatListingEntity>[];

    if (!_shouldSkipNetwork) {
      try {
        final res = await _dio.get(
          '$_baseUrl/producers/${Uri.encodeComponent(cleanId)}/beats',
        );
        if (res.statusCode == 200 && res.data is Map) {
          final rawList = res.data['beats'] as List? ?? const <dynamic>[];
          return rawList
              .whereType<Map>()
              .map((m) => _fromJson(Map<String, dynamic>.from(m)))
              .map(_overlayPersistedBeatState)
              .toList();
        }
      } catch (_) {}
    }

    final normalized = cleanId.toLowerCase();
    return _fallbackBeats.values
        .map(_overlayPersistedBeatState)
        .where((b) {
          final pid = b.producerId.toLowerCase();
          final handle = b.producerHandle.toLowerCase().replaceFirst('@', '');
          return pid == normalized ||
              pid == 'creator_$normalized' ||
              handle == normalized ||
              'creator_$handle' == normalized;
        })
        .toList();
  }
```

**Live Riverpod Family Provider (`marketplace_providers.dart`):**
```dart
/// Live producer beat catalog consuming `EP-P58-MKT-VERIFY-PRODUCER`
/// (`GET /api/marketplace/producers/:producerId/beats`) with optimistic merge
/// against local `creatorBeatsFamilyProvider` (`REQ-P70-API-01`).
final producerBeatsFamilyProvider =
    FutureProvider.family<List<BeatListingEntity>, String>((ref, producerId) async {
      final repo = ref.watch(marketplaceRepositoryProvider);
      final localBeats = ref.watch(creatorBeatsFamilyProvider(producerId));
      final remoteBeats = await repo.getProducerBeats(producerId);

      final mergedById = <String, BeatListingEntity>{
        for (final b in remoteBeats) b.id: b,
        for (final b in localBeats) b.id: b,
      };
      return mergedById.values.toList();
    });
```

---

### §12. Backend `moodId` & Song Metadata Parity (`M70.4`)

#### §12.1 Supabase Migration
**Target File:** `supabase/migrations/20261119000001_phase70_track_mood_and_metadata.sql`

```sql
-- Phase 70: Canonical VhunambiMood (mood_id), Song Description & Open-Stems Remix Flag
-- Idempotent migration for public.explore_tracks (`REQ-P70-API-02`).

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS mood_id TEXT NOT NULL DEFAULT 'uplifting',
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS allow_open_stems_remix BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_mood_id
  ON public.explore_tracks (mood_id);
```

#### §12.2 Canonical Backend Mood Normalizer
**Target File:** `apps/vhunambi_api/src/utils/mood_taxonomy.ts`

```ts
export type VhunambiMoodId =
  | 'uplifting'
  | 'soulful'
  | 'energetic'
  | 'chill'
  | 'hypnotic'
  | 'romantic';

export const VHUNAMBI_MOOD_IDS: readonly VhunambiMoodId[] = [
  'uplifting',
  'soulful',
  'energetic',
  'chill',
  'hypnotic',
  'romantic',
] as const;

const MOOD_ALIAS_MAP: Record<string, VhunambiMoodId> = {
  uplifting: 'uplifting',
  vibrant: 'uplifting',
  joyful: 'uplifting',
  happy: 'uplifting',
  celebratory: 'uplifting',
  soulful: 'soulful',
  'soulful & nostalgic': 'soulful',
  nostalgic: 'soulful',
  melancholic: 'soulful',
  warm: 'soulful',
  reflective: 'soulful',
  energetic: 'energetic',
  electrifying: 'energetic',
  party: 'energetic',
  hype: 'energetic',
  club: 'energetic',
  chill: 'chill',
  peaceful: 'chill',
  calm: 'chill',
  relaxed: 'chill',
  'laid-back': 'chill',
  hypnotic: 'hypnotic',
  deep: 'hypnotic',
  dark: 'hypnotic',
  atmospheric: 'hypnotic',
  minimal: 'hypnotic',
  romantic: 'romantic',
  sensual: 'romantic',
  intimate: 'romantic',
  love: 'romantic',
};

export function normalizeVhunambiMoodId(raw?: string | null): VhunambiMoodId {
  const cleaned = (raw ?? '').trim().toLowerCase();
  if (!cleaned) return 'uplifting';
  if (MOOD_ALIAS_MAP[cleaned]) return MOOD_ALIAS_MAP[cleaned];
  if (cleaned.includes('soul') || cleaned.includes('nostalg') || cleaned.includes('melanchol')) {
    return 'soulful';
  }
  if (cleaned.includes('energ') || cleaned.includes('party') || cleaned.includes('electr')) {
    return 'energetic';
  }
  if (cleaned.includes('chill') || cleaned.includes('calm') || cleaned.includes('peace')) {
    return 'chill';
  }
  if (cleaned.includes('hypno') || cleaned.includes('deep') || cleaned.includes('dark') || cleaned.includes('atmos')) {
    return 'hypnotic';
  }
  if (cleaned.includes('roman')) {
    return 'romantic';
  }
  return 'uplifting';
}
```

#### §12.3 Dual-Engine Persistence Parity (`vhunambi_db.ts`, `edge_persistence_bridge.ts`, `explore_routes.ts`)

**SQLite Column Migration Guard (`apps/vhunambi_api/src/db/vhunambi_db.ts`):**
```ts
    this.ensureColumnExists(
      'explore_tracks',
      'mood_id',
      "TEXT NOT NULL DEFAULT 'uplifting'",
    );
    this.ensureColumnExists(
      'explore_tracks',
      'description',
      "TEXT NOT NULL DEFAULT ''",
    );
    this.ensureColumnExists(
      'explore_tracks',
      'allow_open_stems_remix',
      'INTEGER NOT NULL DEFAULT 0',
    );
```

**Canonical Mood Query Filter (`apps/vhunambi_api/src/routes/explore_routes.ts`):**
```ts
import { normalizeVhunambiMoodId } from '../utils/mood_taxonomy.js';

exploreRoutes.get('/tracks', (c) => {
  const genre = c.req.query('genre') || undefined;
  const stage = c.req.query('stage') || undefined;
  const sort = c.req.query('sort') || undefined;
  const search = c.req.query('search') || undefined;
  const rawMood = c.req.query('moodId') || c.req.query('mood') || undefined;
  const moodId = rawMood ? normalizeVhunambiMoodId(rawMood) : undefined;
  const limit = Number(c.req.query('limit') || '50');

  const result = vhunambiDb.getExploreTracks({
    genre,
    stage,
    sort,
    search,
    moodId,
    limit,
  });

  return c.json({
    tracks: result.items.map((t) => ({
      ...t,
      moodId: normalizeVhunambiMoodId(t.moodId ?? t.mood),
      description: t.description ?? '',
      allowOpenStemsRemix: Boolean(t.allowOpenStemsRemix),
    })),
    total: result.total,
  });
});
```

Mirror the identical `moodId`, `description`, and `allowOpenStemsRemix` fields and `moodId` filter inside `EdgeIsolateDatabaseEngine.getExploreTracks` and `EdgeIsolateDatabaseEngine.upsertExploreTrack` in `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`.
