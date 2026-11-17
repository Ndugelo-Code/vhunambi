# Phase 68 — Home Dashboard "Main Room & Studio Utility" Overhaul Design Specification

> **Document ID:** `VHUNAMBI-SPEC-P68-DESIGN-V1`  
> **Architectural Target:** `apps/vhunambi_client` (`HomeDashboardView`, `AppAssets`, `VhunambiTrackArtwork`, `CreatorAllowanceNotifier`, `NowPlayingHomeCard`, `MiniPlayerHost`, `Explore` & `Library` Seed Artworks, `STD-UIUX-001` Cleanups)  
> **Argon Standard Compliance:** 100% Compilable Production Dart Code — Zero Placeholders, Zero Raw Emojis, Zero Stock `Icons.*`, 100% Dynamic `*Of(context)` Dual-Theme Tokens

---

## 1. Visual Geometry & Runtime Architecture Contract

### 1.1 Main Room 5-Zone Layout Constants & Spacing
- **Canvas Background:** `AppColors.surfaceCanvasOf(context)`
- **Horizontal Padding:** `isDesktop ? 32.0 : 16.0`
- **Vertical Zone Rhythm:** `14.0dp` between Zones 1 $\to$ 1.5 $\to$ 2 $\to$ 3 $\to$ 4 $\to$ 5 (replacing `20.0–24.0dp` bloated gaps).
- **Bottom Scroll Clearance:** `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false)` on mobile because `MiniPlayerHost` auto-suppresses on Tab 0 whenever `homeInlineNowPlayingMountedProvider == true`.
- **Desktop Split Breakpoint (`ResponsiveUtils.isDesktop(context)`):** Width $\ge 1025\text{dp}$ uses a 2-column layout (`flex: 7` left primary `NowPlayingHomeCard` + `HorizontalGenreTrackShelf`; `flex: 5` right utility `Create in Studio` + 2x2 `CreationLaunchStrip` + `EditorialRhythmSpotlightCard`).

### 1.2 Artwork Resolution Fallback Curve (`VhunambiTrackArtwork`)
```
coverUrl / coverImageUrl
  ├─ http(s)://...  ──▶ Image.network(normalized, fit: BoxFit.cover) ──[errorBuilder]──┐
  ├─ asset:assets/... -> Image.asset(strippedPath, fit: BoxFit.cover) ──[errorBuilder]─┤
  └─ null / empty  ────────────────────────────────────────────────────────────────────▼
                         Image.asset(AppAssets.resolveGenreCoverAsset(genre, trackId)) ─[error]─▶ Branded Gradient + PhosphorIcon(musicNotes)
```

### 1.3 Editorial Spotlight Dark Scrim Alpha Curve
Over `AppAssets.resolveGenreCoverAsset(spotlight.genre)`, paint:
- Stop 0.0 (`Alignment.topLeft`): `Colors.black.withValues(alpha: 0.48)`
- Stop 0.55: `Colors.black.withValues(alpha: 0.70)`
- Stop 1.0 (`Alignment.bottomRight`): `Colors.black.withValues(alpha: 0.90)`
This preserves vibrant African artwork depth while guaranteeing `>= 7:1` contrast for white editorial headlines in **both Light Mode ("Morning Mist") and Dark Mode ("Night")**.

---

## 2. Pass 1 Foundations: `AppAssets`, `AfricanGreetingResolver` & `VhunambiTrackArtwork`

### 2.1 `apps/vhunambi_client/lib/core/constants/app_assets.dart`
Add all 3 unregistered artwork constants + `resolveGenreCoverAsset` + `resolveTrackCoverAsset`:

```dart
  // Phase 68: Complete 10-artwork bundled studio registry (`assets/artwork/`)
  static const String sunsetMelodiesCover =
      'assets/artwork/Vhunambi_ African Sunset Melodies.png';
  static const String fiveVoicesCover =
      'assets/artwork/Vhunambi_ Five Voices, One Vision.png';
  static const String musicFeelEscapeCover =
      'assets/artwork/Vhunambi_ Music, Feel, Escape.png';

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

  /// Deterministically resolves one of the 10 bundled artworks for [genre]
  /// (and optional [seedId] to ensure distinct adjacent cards within the same genre).
  static String resolveGenreCoverAsset(String genre, {String? seedId}) {
    final g = genre.toLowerCase().trim();
    if (g.contains('amapiano') || g.contains('afro house') || g.contains('private')) {
      if (seedId != null && seedId.hashCode.isOdd) return musicFeelEscapeCover;
      return sunsetMelodiesCover;
    }
    if (g.contains('gqom') || g.contains('bacardi') || g.contains('3-step')) {
      return timbreProducer;
    }
    if (g.contains('maskandi') || g.contains('mbaqanga') || g.contains('isicathamiya')) {
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
```

### 2.2 `apps/vhunambi_client/lib/features/home/presentation/utils/african_greeting_resolver.dart`
Purges all raw unicode emojis (`✨`, `☀️`, `🌙`) while maintaining existing `getGreeting(...)` and `getTimeGlyph()` call compatibility:

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Semantic time-of-day icon discriminator replacing raw unicode emojis (`STD-UIUX-001`).
enum GreetingIconType { morningSun, middaySun, eveningHorizon, nightMoon }

/// Resolves culturally-authentic African multilingual greetings and typed Phosphor glyphs.
class AfricanGreetingResolver {
  static String getGreeting({
    String? language,
    DateTime? currentTime,
  }) {
    final hour = (currentTime ?? DateTime.now()).hour;
    final lang = (language ?? 'Tshivenḓa').trim().toLowerCase();

    if (lang.contains('tshiven') || lang.contains('venda')) {
      if (hour < 12) return 'Ndi matsheloni';
      if (hour < 17) return 'Ndi masiari';
      return 'Ndi madekwana';
    }
    if (lang.contains('zulu')) {
      if (hour < 12) return 'Sawubona';
      if (hour < 17) return 'Sanibonani';
      return 'Ulale kahle';
    }
    if (lang.contains('xhosa')) {
      if (hour < 12) return 'Molo';
      if (hour < 17) return 'Bhota';
      return 'Rhonanai';
    }
    if (lang.contains('tsonga') || lang.contains('xitsonga')) {
      if (hour < 12) return 'Avuxeni';
      if (hour < 17) return 'Nhlwelo';
      return 'Riperile';
    }
    if (lang.contains('yoruba')) {
      if (hour < 12) return 'E kaaro';
      if (hour < 17) return 'E kaasan';
      return 'E kaale';
    }
    if (lang.contains('swahili') || lang.contains('kiswahili')) {
      if (hour < 12) return 'Habari ya asubuhi';
      if (hour < 17) return 'Habari ya mchana';
      return 'Habari ya jioni';
    }

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Returns a semantic [GreetingIconType] with zero raw unicode emojis.
  static GreetingIconType getGreetingIconType({DateTime? currentTime}) {
    final hour = (currentTime ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 11) return GreetingIconType.morningSun;
    if (hour >= 11 && hour < 17) return GreetingIconType.middaySun;
    if (hour >= 17 && hour < 21) return GreetingIconType.eveningHorizon;
    return GreetingIconType.nightMoon;
  }

  /// Resolves the matching Phosphor glyph for [GreetingIconType].
  static IconData resolvePhosphorIcon({DateTime? currentTime}) {
    return switch (getGreetingIconType(currentTime: currentTime)) {
      GreetingIconType.morningSun => PhosphorIconsFill.sunHorizon,
      GreetingIconType.middaySun => PhosphorIconsFill.sun,
      GreetingIconType.eveningHorizon => PhosphorIconsFill.sparkle,
      GreetingIconType.nightMoon => PhosphorIconsFill.moonStars,
    };
  }

  /// Human-readable time-of-day descriptor kept emoji-free for legacy callers.
  static String getTimeGlyph({DateTime? currentTime}) {
    return switch (getGreetingIconType(currentTime: currentTime)) {
      GreetingIconType.morningSun => 'Dawn Session',
      GreetingIconType.middaySun => 'Daylight Session',
      GreetingIconType.eveningHorizon => 'Sunset Session',
      GreetingIconType.nightMoon => 'Night Session',
    };
  }
}
```

### 2.3 Unified Cover Art Component: `apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_gradients.dart';

/// Unified rounded cover artwork renderer shared across Home, Now Playing, and shelves.
///
/// Resolution order (`REQ-P68-ART-02`):
/// 1. Normalized `http(s)://` URL -> [Image.network] with asset error fallback.
/// 2. `asset:...` URI or `assets/...` path -> [Image.asset].
/// 3. Deterministic cultural genre artwork -> [AppAssets.resolveGenreCoverAsset].
/// 4. Branded [AppGradients.forGenre] + [PhosphorIconsFill.musicNotes] badge.
class VhunambiTrackArtwork extends StatelessWidget {
  final String? coverUrl;
  final String genre;
  final String? trackId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double badgeIconSize;
  final bool showSubtleBorder;

  const VhunambiTrackArtwork({
    super.key,
    this.coverUrl,
    required this.genre,
    this.trackId,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.badgeIconSize = 24,
    this.showSubtleBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedSource = AppAssets.resolveTrackCoverSource(
      coverUrl: coverUrl,
      genre: genre,
      seedId: trackId,
    );
    final genreAssetFallback = AppAssets.resolveGenreCoverAsset(
      genre,
      seedId: trackId,
    );
    final isRemote = resolvedSource.startsWith('http://') ||
        resolvedSource.startsWith('https://');

    Widget buildGradientFallback() {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.forGenre(genre),
        ),
        child: Center(
          child: PhosphorIcon(
            PhosphorIconsFill.musicNotes,
            size: badgeIconSize,
            color: AppColors.textPrimaryOf(context).withValues(alpha: 0.90),
          ),
        ),
      );
    }

    Widget buildAssetImage(String assetPath) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => buildGradientFallback(),
      );
    }

    final Widget imageWidget = isRemote
        ? Image.network(
            resolvedSource,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => buildAssetImage(genreAssetFallback),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  buildAssetImage(genreAssetFallback),
                  Container(
                    color: AppColors.surfaceCanvasOf(context).withValues(alpha: 0.18),
                  ),
                ],
              );
            },
          )
        : buildAssetImage(resolvedSource);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showSubtleBorder
            ? Border.all(
                color: AppColors.borderSubtleOf(context).withValues(alpha: 0.75),
                width: 1,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      ),
    );
  }
}
```

### 2.4 Seeded Artwork Backfill in `explore_providers.dart` & `library_providers.dart`
Assign deterministic `'asset:${AppAssets.*}'` URIs across every seeded track in `explore_providers.dart` (`_buildFallbackExploreCatalog`) and `library_providers.dart` (`_buildStarterTracks`) — for example:
- `exp_track_001` (*Amapiano Midnight*) -> `'asset:${AppAssets.sunsetMelodiesCover}'`
- `exp_track_002` (*Venda Vibes*) -> `'asset:${AppAssets.timbreCantor}'`
- `exp_track_003` (*Durban Gqom Night*) -> `'asset:${AppAssets.timbreProducer}'`
- `exp_track_004` (*Johannesburg Soul*) -> `'asset:${AppAssets.fiveVoicesCover}'`
- `exp_track_005` (*Tshivenḓa Anthem*) -> `'asset:${AppAssets.heritageCrateCover}'`
- `exp_track_006` (*Maskandi Strings of Natal*) -> `'asset:${AppAssets.timbreElder}'`
- `exp_track_007` (*Afro Sunset Melodies*) -> `'asset:${AppAssets.musicFeelEscapeCover}'`
- `exp_track_008` (*Lagos Pulse*) -> `'asset:${AppAssets.timbreCrooner}'`
And on `LibraryTrack` in `_buildStarterTracks` (keeping all metadata intact, only populating `coverImageUrl: 'asset:${AppAssets.resolveGenreCoverAsset(genre)}'` when `coverImageUrl == null`).

---

## 3. Pass 2 State Engine: `CreatorAllowanceNotifier` (`GET /api/wallet/allowance`)

### 3.1 `apps/vhunambi_client/lib/features/home/domain/models/creator_allowance_state.dart`

```dart
import 'package:flutter/foundation.dart';

/// Immutable creator monthly generation allowance snapshot synchronized from
/// `GET /api/wallet/allowance` (Phase 67 M67.4) with local Hive warm-start.
@immutable
class CreatorAllowanceState {
  static const int defaultMonthlyFreeLimit = 10;

  final String creatorId;
  final String planTier;
  final int freeMonthlySongsLimit;
  final int freeMonthlySongsUsed;
  final int freeMonthlySongsRemaining;
  final DateTime? cycleResetAt;
  final bool isLoading;
  final bool isFromCache;

  const CreatorAllowanceState({
    required this.creatorId,
    this.planTier = 'free',
    this.freeMonthlySongsLimit = defaultMonthlyFreeLimit,
    this.freeMonthlySongsUsed = 0,
    this.freeMonthlySongsRemaining = defaultMonthlyFreeLimit,
    this.cycleResetAt,
    this.isLoading = false,
    this.isFromCache = false,
  });

  bool get isPaidUnlimited =>
      planTier.toLowerCase() != 'free' || freeMonthlySongsLimit < 0;

  bool get isLowQuota => !isPaidUnlimited && freeMonthlySongsRemaining <= 2;

  bool get isExhausted => !isPaidUnlimited && freeMonthlySongsRemaining <= 0;

  String get pillLabel =>
      isPaidUnlimited ? 'Pro' : '$freeMonthlySongsRemaining/$freeMonthlySongsLimit';

  factory CreatorAllowanceState.fromJson(
    Map<String, dynamic> json, {
    required String fallbackCreatorId,
    bool isFromCache = false,
  }) {
    final limit = (json['freeMonthlySongsLimit'] as num?)?.toInt() ??
        defaultMonthlyFreeLimit;
    final used = ((json['freeMonthlySongsUsed'] as num?)?.toInt() ?? 0).clamp(0, 999);
    final rawRemaining = (json['freeMonthlySongsRemaining'] as num?)?.toInt();
    final remaining = rawRemaining ?? (limit - used).clamp(0, limit);
    return CreatorAllowanceState(
      creatorId: (json['userId'] ?? json['creatorId'] ?? fallbackCreatorId).toString(),
      planTier: (json['planTier'] ?? 'free').toString(),
      freeMonthlySongsLimit: limit,
      freeMonthlySongsUsed: used,
      freeMonthlySongsRemaining: remaining,
      cycleResetAt: json['cycleResetAt'] != null
          ? DateTime.tryParse(json['cycleResetAt'].toString())
          : null,
      isLoading: false,
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'creatorId': creatorId,
        'planTier': planTier,
        'freeMonthlySongsLimit': freeMonthlySongsLimit,
        'freeMonthlySongsUsed': freeMonthlySongsUsed,
        'freeMonthlySongsRemaining': freeMonthlySongsRemaining,
        if (cycleResetAt != null) 'cycleResetAt': cycleResetAt!.toIso8601String(),
      };

  CreatorAllowanceState copyWith({
    String? creatorId,
    String? planTier,
    int? freeMonthlySongsLimit,
    int? freeMonthlySongsUsed,
    int? freeMonthlySongsRemaining,
    DateTime? cycleResetAt,
    bool? isLoading,
    bool? isFromCache,
  }) {
    return CreatorAllowanceState(
      creatorId: creatorId ?? this.creatorId,
      planTier: planTier ?? this.planTier,
      freeMonthlySongsLimit:
          freeMonthlySongsLimit ?? this.freeMonthlySongsLimit,
      freeMonthlySongsUsed: freeMonthlySongsUsed ?? this.freeMonthlySongsUsed,
      freeMonthlySongsRemaining:
          freeMonthlySongsRemaining ?? this.freeMonthlySongsRemaining,
      cycleResetAt: cycleResetAt ?? this.cycleResetAt,
      isLoading: isLoading ?? this.isLoading,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatorAllowanceState &&
          runtimeType == other.runtimeType &&
          creatorId == other.creatorId &&
          planTier == other.planTier &&
          freeMonthlySongsLimit == other.freeMonthlySongsLimit &&
          freeMonthlySongsUsed == other.freeMonthlySongsUsed &&
          freeMonthlySongsRemaining == other.freeMonthlySongsRemaining;

  @override
  int get hashCode => Object.hash(
        creatorId,
        planTier,
        freeMonthlySongsLimit,
        freeMonthlySongsUsed,
        freeMonthlySongsRemaining,
      );
}
```

### 3.2 `apps/vhunambi_client/lib/features/home/presentation/providers/creator_allowance_provider.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/features/home/domain/models/creator_allowance_state.dart';

/// Synchronizes creator free-monthly song quota with `GET /api/wallet/allowance`
/// and isolates cached snapshots by `canonicalCreatorId`.
class CreatorAllowanceNotifier extends StateNotifier<CreatorAllowanceState>
    with SafeNotifierMixin<CreatorAllowanceState> {
  static const String _cachePrefix = 'creator_allowance_cache_';

  final String _creatorId;
  final SovereignApiClient _apiClient;
  final bool Function() _isAuthenticated;
  final String _apiRestBaseUrl;

  CreatorAllowanceNotifier({
    required String creatorId,
    required SovereignApiClient apiClient,
    required bool Function() isAuthenticated,
    String? apiRestBaseUrl,
    bool autoSync = true,
  })  : _creatorId = creatorId,
        _apiClient = apiClient,
        _isAuthenticated = isAuthenticated,
        _apiRestBaseUrl = apiRestBaseUrl ?? AppConstants.apiRestBaseUrl,
        super(
          _hydrateCachedOrDefault(creatorId),
        ) {
    if (autoSync) {
      unawaited(refreshFromServer());
    }
  }

  /// Test-only constructor bypassing Hive and remote HTTP sync.
  CreatorAllowanceNotifier.withInitial(CreatorAllowanceState initial)
      : _creatorId = initial.creatorId,
        _apiClient = SovereignApiClient(
          readSession: () => throw UnimplementedError(),
          refreshSession: () async => null,
        ),
        _isAuthenticated = (() => false),
        _apiRestBaseUrl = AppConstants.apiRestBaseUrl,
        super(initial);

  static String cacheKeyForCreator(String creatorId) =>
      '$_cachePrefix${creatorId.trim().isEmpty ? 'guest' : creatorId.trim()}';

  static CreatorAllowanceState _hydrateCachedOrDefault(String creatorId) {
    try {
      if (!SovereignDomainStorageMode.canHydrateFromStorage(
        AppConstants.prefsBoxKey,
      )) {
        return CreatorAllowanceState(creatorId: creatorId);
      }
      if (!Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        return CreatorAllowanceState(creatorId: creatorId);
      }
      final box = Hive.box<dynamic>(AppConstants.prefsBoxKey);
      final raw = box.get(cacheKeyForCreator(creatorId));
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return CreatorAllowanceState.fromJson(
            decoded,
            fallbackCreatorId: creatorId,
            isFromCache: true,
          );
        }
      } else if (raw is Map) {
        return CreatorAllowanceState.fromJson(
          Map<String, dynamic>.from(raw),
          fallbackCreatorId: creatorId,
          isFromCache: true,
        );
      }
    } catch (_) {
      // Preserve clean default quota on corrupted or headless test storage.
    }
    return CreatorAllowanceState(creatorId: creatorId);
  }

  Future<void> _persistCache(CreatorAllowanceState snapshot) async {
    try {
      if (!SovereignDomainStorageMode.canHydrateFromStorage(
        AppConstants.prefsBoxKey,
      )) {
        return;
      }
      if (!Hive.isBoxOpen(AppConstants.prefsBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.prefsBoxKey);
      await box.put(
        cacheKeyForCreator(_creatorId),
        jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // Persistence errors must never crash UI quota display.
    }
  }

  /// Fetches live quota from `GET /api/wallet/allowance`. Silently preserves
  /// cached or starter counts when offline or unauthenticated.
  Future<void> refreshFromServer() async {
    if (!_isAuthenticated()) return;
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/wallet/allowance');
      final response = await _apiClient.send(
        (headers) => http.Request('GET', uri)..headers.addAll(headers),
        timeout: const Duration(seconds: 6),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final next = CreatorAllowanceState.fromJson(
            decoded,
            fallbackCreatorId: _creatorId,
            isFromCache: false,
          );
          state = next;
          await _persistCache(next);
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Optimistically decrements local remaining allowance after confirmed Studio
  /// generation dispatch while scheduling server reconciliation.
  void consumeOneSongOptimistically() {
    if (state.isPaidUnlimited) return;
    final nextRemaining =
        (state.freeMonthlySongsRemaining - 1).clamp(0, state.freeMonthlySongsLimit);
    final nextUsed = state.freeMonthlySongsUsed + 1;
    final updated = state.copyWith(
      freeMonthlySongsUsed: nextUsed,
      freeMonthlySongsRemaining: nextRemaining,
      isFromCache: false,
    );
    state = updated;
    unawaited(_persistCache(updated));
    unawaited(refreshFromServer());
  }
}

final creatorAllowanceProvider =
    StateNotifierProvider<CreatorAllowanceNotifier, CreatorAllowanceState>((ref) {
  final creatorId = ref.watch(currentCreatorIdProvider);
  final apiClient = ref.watch(sovereignApiClientProvider);
  final overrideRoot = ref.watch(sovereignAuthApiRootUrlProvider);
  final restBase = overrideRoot != null
      ? '${AppConstants.normalizeOriginUrl(overrideRoot)}/api'
      : AppConstants.apiRestBaseUrl;
  return CreatorAllowanceNotifier(
    creatorId: creatorId,
    apiClient: apiClient,
    isAuthenticated: () => ref.read(authSessionProvider).isAuthenticated,
    apiRestBaseUrl: restBase,
  );
});
```

---

## 4. Tab-0 MiniPlayer De-Duplication (`navigation_providers.dart` & `mini_player_host.dart`)

### 4.1 `apps/vhunambi_client/lib/core/navigation/navigation_providers.dart`
Add the opt-in inline mount guard so standalone `MiniPlayerHost` tests never break:

```dart
/// True while `NowPlayingHomeCard` is mounted in the Main Room tree (`Phase 68`).
/// Combined with `appNavigationTabProvider == 0`, prevents floating [MiniPlayerHost]
/// from duplicating playback controls on Home while preserving standalone tests.
final homeInlineNowPlayingMountedProvider = StateProvider<bool>((ref) => false);
```

### 4.2 `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`
Inside `_shouldHide(BuildContext context, MiniPlayerController controller, PlayerState playerState)` right after `if (activeTab == 2) return true;`:

```dart
    // Phase 68 (REQ-P68-PLAYER-02): Suppress floating MiniPlayerHost on Home
    // (Tab 0) when NowPlayingHomeCard renders inline playback controls.
    final isHomeInlineMounted = ref.watch(homeInlineNowPlayingMountedProvider);
    if (activeTab == 0 && isHomeInlineMounted) return true;
```

---

## 5. Main Room Presentation Widgets (Complete Compilable Dart Specifications)

### 5.1 `apps/vhunambi_client/lib/features/home/presentation/widgets/main_room_header.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart';
import 'package:vhunambi_client/features/home/presentation/utils/african_greeting_resolver.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_avatar.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

/// Zone 1: Compact "Main Room" top utility bar (`REQ-P68-FEED-01`, `REQ-P68-QUOTA-03`).
class MainRoomHeader extends ConsumerWidget {
  final bool isDesktop;

  const MainRoomHeader({
    super.key,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfile = ref.watch(ownerProfileProvider);
    final wallet = ref.watch(creatorWalletProvider);
    final allowance = ref.watch(creatorAllowanceProvider);
    final onboarding = ref.watch(onboardingStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userLanguage = onboarding.selectedLanguages.isNotEmpty
        ? onboarding.selectedLanguages.first
        : 'Tshivenḓa';
    final greetingText = AfricanGreetingResolver.getGreeting(
      language: userLanguage,
    );
    final greetingIcon = AfricanGreetingResolver.resolvePhosphorIcon();

    final quotaColor = allowance.isLowQuota
        ? AppColors.warning
        : allowance.isPaidUnlimited
            ? AppColors.accentElectric
            : AppColors.success;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        12,
        isDesktop ? 32 : 16,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              CreatorAvatar(
                avatarKey: const Key('home_avatar_btn'),
                avatarUrl: ownerProfile.avatarUrl,
                monogram: ownerProfile.monogram.isNotEmpty
                    ? ownerProfile.monogram
                    : 'ND',
                size: 42,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticsService().lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OwnerProfileView(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            greetingText,
                            key: const Key('home_greeting_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        PhosphorIcon(
                          greetingIcon,
                          size: 14,
                          color: AppColors.coinGold,
                        ),
                      ],
                    ),
                    Text(
                      ownerProfile.displayName.isNotEmpty
                          ? ownerProfile.displayName
                          : 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...<Widget>[
                _HeaderMetricPill(
                  pillKey: const Key('home_streak_pill'),
                  icon: PhosphorIconsFill.flame,
                  iconColor: AppColors.brandPrimary,
                  label: '${ownerProfile.dayStreak} Streak',
                  semanticLabel: '${ownerProfile.dayStreak} Streak',
                  bgColor: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                  onTap: null,
                ),
                const SizedBox(width: 8),
                _HeaderMetricPill(
                  pillKey: const Key('home_allowance_pill'),
                  icon: PhosphorIconsFill.musicNoteSimple,
                  iconColor: quotaColor,
                  label: allowance.pillLabel,
                  semanticLabel:
                      'Monthly free allowance ${allowance.pillLabel}',
                  bgColor: quotaColor.withValues(alpha: 0.14),
                  borderColor: quotaColor.withValues(alpha: 0.38),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    HapticsService().lightImpact();
                    SubscriptionUpgradeModal.show(context);
                  },
                ),
                const SizedBox(width: 8),
                _HeaderMetricPill(
                  pillKey: const Key('home_coins_pill'),
                  icon: PhosphorIconsFill.coins,
                  iconColor: AppColors.coinGold,
                  label: '${wallet.userCoinsBalance} Coins',
                  semanticLabel: '${wallet.userCoinsBalance} Coins',
                  bgColor: AppColors.coinGold.withValues(alpha: 0.14),
                  borderColor: AppColors.coinGold.withValues(alpha: 0.35),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    HapticsService().lightImpact();
                    SubscriptionUpgradeModal.show(context);
                  },
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: IconButton(
                  key: const Key('home_theme_toggle_btn'),
                  tooltip:
                      isDark ? 'Switch to Morning Mist' : 'Switch to Night Mode',
                  padding: EdgeInsets.zero,
                  icon: PhosphorIcon(
                    isDark ? PhosphorIconsFill.sun : PhosphorIconsFill.moonStars,
                    size: 19,
                    color: isDark ? AppColors.coinGold : AppColors.brandPrimary,
                  ),
                  onPressed: () {
                    HapticsService().selectionClick();
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: NotificationBellButton(
                    key: const Key('home_notifications_btn'),
                    color: AppColors.textPrimaryOf(context),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationsView(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (!isDesktop) ...<Widget>[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _HeaderMetricPill(
                    pillKey: const Key('home_streak_pill'),
                    icon: PhosphorIconsFill.flame,
                    iconColor: AppColors.brandPrimary,
                    label: '${ownerProfile.dayStreak} Streak',
                    semanticLabel: '${ownerProfile.dayStreak} Streak',
                    bgColor: AppColors.brandPrimary.withValues(alpha: 0.14),
                    borderColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                    onTap: null,
                  ),
                  const SizedBox(width: 8),
                  _HeaderMetricPill(
                    pillKey: const Key('home_allowance_pill'),
                    icon: PhosphorIconsFill.musicNoteSimple,
                    iconColor: quotaColor,
                    label: allowance.isPaidUnlimited
                        ? 'Pro Unlimited'
                        : '${allowance.pillLabel} Free',
                    semanticLabel:
                        'Monthly free allowance ${allowance.pillLabel}',
                    bgColor: quotaColor.withValues(alpha: 0.14),
                    borderColor: quotaColor.withValues(alpha: 0.38),
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      HapticsService().lightImpact();
                      SubscriptionUpgradeModal.show(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  _HeaderMetricPill(
                    pillKey: const Key('home_coins_pill'),
                    icon: PhosphorIconsFill.coins,
                    iconColor: AppColors.coinGold,
                    label: '${wallet.userCoinsBalance} Coins',
                    semanticLabel: '${wallet.userCoinsBalance} Coins',
                    bgColor: AppColors.coinGold.withValues(alpha: 0.14),
                    borderColor: AppColors.coinGold.withValues(alpha: 0.35),
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      HapticsService().lightImpact();
                      SubscriptionUpgradeModal.show(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMetricPill extends StatelessWidget {
  final Key pillKey;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticLabel;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _HeaderMetricPill({
    required this.pillKey,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticLabel,
    required this.bgColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillBody = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: GestureDetector(
        key: pillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(child: pillBody),
        ),
      ),
    );
  }
}
```
> **Responsive Header Layout Note:** On mobile viewports (`!isDesktop`), placing avatar, greeting, theme toggle, notification bell, streak, allowance, and coins on a single `Row` can trigger RenderFlex overflow on `360dp` screens. Rendering the status pills in a horizontal pill rail directly beneath the primary greeting row keeps greeting text untruncated, eliminates overflow risk across narrow Android viewports, and preserves `'N Streak'` and `'N Coins'` contract labels across all widget tests.

### 5.2 `apps/vhunambi_client/lib/features/home/presentation/widgets/now_playing_home_card.dart`
Zania-inspired unified inline Home player (`REQ-P68-PLAYER-01`, `REQ-P68-PLAYER-02`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Zone 2: Zania-inspired compact Main Room player & "Jump Back In" deck
/// (`REQ-P68-PLAYER-01`, `REQ-P68-PLAYER-02`).
///
/// Registers [homeInlineNowPlayingMountedProvider] while mounted so [MiniPlayerHost]
/// suppresses duplicate floating playback pills on Home Tab 0.
class NowPlayingHomeCard extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToStudio;

  const NowPlayingHomeCard({
    super.key,
    this.onNavigateToStudio,
  });

  @override
  ConsumerState<NowPlayingHomeCard> createState() => _NowPlayingHomeCardState();
}

class _NowPlayingHomeCardState extends ConsumerState<NowPlayingHomeCard> {
  StateController<bool>? _inlineMountController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inlineMountController =
          ref.read(homeInlineNowPlayingMountedProvider.notifier);
      _inlineMountController?.state = true;
    });
  }

  @override
  void dispose() {
    final controller = _inlineMountController;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.state = false;
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final libraryTracks = ref.watch(libraryTracksProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final ownerProfile = ref.watch(ownerProfileProvider);

    final validVaultTracks = libraryTracks.where((t) => !t.isDeleted).toList();
    final LibraryTrack? latestVault =
        validVaultTracks.isNotEmpty ? validVaultTracks.first : null;

    final Track? targetTrack;
    final List<Track> playbackQueue;
    if (player.hasActiveTrack && player.currentTrack != null) {
      targetTrack = player.currentTrack;
      playbackQueue = player.queue.isNotEmpty ? player.queue : <Track>[targetTrack!];
    } else if (latestVault != null) {
      targetTrack = Track(
        id: latestVault.id,
        title: latestVault.title,
        creatorName: latestVault.creatorName.isNotEmpty
            ? latestVault.creatorName
            : ownerProfile.displayName,
        genre: latestVault.genre,
        language: latestVault.language,
        duration: Duration(seconds: latestVault.durationSeconds),
        audioUrl: latestVault.remoteAudioUrl,
        coverUrl: latestVault.coverImageUrl,
      );
      playbackQueue = <Track>[targetTrack, ...exploreTracks];
    } else if (exploreTracks.isNotEmpty) {
      targetTrack = exploreTracks.first;
      playbackQueue = exploreTracks;
    } else {
      targetTrack = null;
      playbackQueue = const <Track>[];
    }

    if (targetTrack == null) {
      return _buildEmptyStarterCard(context);
    }

    final isThisTrackLoaded =
        player.hasActiveTrack && player.currentTrack?.id == targetTrack.id;
    final isPlayingThis = isThisTrackLoaded && player.isPlaying;
    final progressRatio = isThisTrackLoaded ? player.progressRatio : 0.0;
    final positionLabel = isThisTrackLoaded ? player.formattedPosition : '0:00';
    final durationLabel = isThisTrackLoaded
        ? player.formattedDuration
        : targetTrack.formattedDuration;
    final headerEyebrow =
        isThisTrackLoaded ? 'Now Playing' : 'Jump Back In';

    void ensureActiveAndOpenCockpit() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      if (!isThisTrackLoaded) {
        ref
            .read(playerStateProvider.notifier)
            .playTrack(targetTrack!, queue: playbackQueue);
      }
      ExpandedCockpitModal.show(context);
    }

    void togglePlayback() {
      HapticsService().mediumImpact();
      final notifier = ref.read(playerStateProvider.notifier);
      if (isThisTrackLoaded) {
        notifier.togglePlayPause();
      } else {
        notifier.playTrack(targetTrack!, queue: playbackQueue);
      }
    }

    void openQuickMaster() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: MobileQuickMasterSheet(
            trackId: targetTrack!.id,
            trackTitle: targetTrack.title,
            genre: targetTrack.genre,
          ),
        ),
      );
    }

    return Container(
      key: const Key('home_now_playing_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isPlayingThis
              ? AppColors.brandPrimary.withValues(alpha: 0.55)
              : AppColors.borderSubtleOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                headerEyebrow,
                style: AppTypography.badge.copyWith(
                  color: isPlayingThis
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '$positionLabel / $durationLabel',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: ensureActiveAndOpenCockpit,
                child: VhunambiTrackArtwork(
                  coverUrl: targetTrack.coverUrl,
                  genre: targetTrack.genre,
                  trackId: targetTrack.id,
                  width: 60,
                  height: 60,
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ensureActiveAndOpenCockpit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        targetTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${targetTrack.creatorName} • ${targetTrack.genre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: TextButton.icon(
                    key: const Key('home_jump_back_master_btn'),
                    onPressed: openQuickMaster,
                    style: TextButton.styleFrom(
                      backgroundColor:
                          AppColors.surfaceSecondaryOf(context),
                      foregroundColor: AppColors.textPrimaryOf(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                        side: BorderSide(
                          color: AppColors.borderSubtleOf(context),
                        ),
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.slidersHorizontal,
                      size: 14,
                    ),
                    label: Text(
                      'Polish',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: AppColors.borderSubtleOf(context),
              thumbColor: AppColors.brandPrimary,
            ),
            child: Slider(
              key: const Key('home_player_scrub_slider'),
              value: progressRatio.clamp(0.0, 1.0),
              onChanged: isThisTrackLoaded
                  ? (value) =>
                      ref.read(playerStateProvider.notifier).seekByRatio(value)
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Tap cover for Pocket DAW cockpit',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_prev_btn'),
                      tooltip: 'Previous track',
                      icon: PhosphorIcon(
                        PhosphorIconsFill.skipBack,
                        size: 18,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      onPressed: isThisTrackLoaded && player.queue.length > 1
                          ? () => ref
                              .read(playerStateProvider.notifier)
                              .skipPrevious()
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_play_pause_btn'),
                      tooltip: isPlayingThis ? 'Pause' : 'Play',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                      ),
                      icon: PhosphorIcon(
                        isPlayingThis
                            ? PhosphorIconsFill.pause
                            : PhosphorIconsFill.play,
                        size: 18,
                        color: AppColors.brandContrast,
                      ),
                      onPressed: togglePlayback,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_next_btn'),
                      tooltip: 'Next track',
                      icon: PhosphorIcon(
                        PhosphorIconsFill.skipForward,
                        size: 18,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      onPressed: isThisTrackLoaded && player.queue.length > 1
                          ? () =>
                              ref.read(playerStateProvider.notifier).skipNext()
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStarterCard(BuildContext context) {
    return Container(
      key: const Key('home_now_playing_empty_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: <Widget>[
          PhosphorIcon(
            PhosphorIconsFill.vinylRecord,
            size: 32,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Your Main Room is ready',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Generate or save your first song to resume playback here.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: ElevatedButton(
                onPressed: widget.onNavigateToStudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```
> **Test Contract Note:** Rendering the eyebrow in Title Case (`'Jump Back In'` / `'Now Playing'`) preserves existing Phase 31 (`HOME-002`) and `home_dashboard_view_test.dart` assertions without regression.

### 5.3 `apps/vhunambi_client/lib/features/home/presentation/widgets/horizontal_genre_track_shelf.dart`
Zone 3: Zania-inspired square artwork horizontal track rail (`REQ-P68-FEED-03`, `REQ-P68-FEED-04`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Zone 3: Horizontal square-artwork track carousel (`REQ-P68-FEED-03`, `REQ-P68-FEED-04`).
class HorizontalGenreTrackShelf extends ConsumerWidget {
  final List<Track> tracks;
  final List<String> selectedGenres;
  final VoidCallback? onViewAll;

  const HorizontalGenreTrackShelf({
    super.key,
    required this.tracks,
    required this.selectedGenres,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayed = tracks.take(8).toList();
    final activeTrackId = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id),
    );
    final isPlaying = ref.watch(
      playerStateProvider.select((s) => s.isPlaying),
    );

    return Column(
      key: const Key('home_trending_genres_shelf'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Trending in Your Genres',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      selectedGenres.isNotEmpty
                          ? selectedGenres.take(2).join(' • ')
                          : 'All Regional Genres',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('home_trending_view_all_btn'),
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.brandPrimary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'View all',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const PhosphorIcon(
                      PhosphorIconsBold.caretRight,
                      size: 13,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayed.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final track = displayed[index];
              final isSelected = activeTrackId == track.id;
              return GestureDetector(
                key: Key('home_trending_track_${track.id}'),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticsService().lightImpact();
                  ref
                      .read(playerStateProvider.notifier)
                      .playTrack(track, queue: displayed);
                },
                child: SizedBox(
                  width: 148,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          VhunambiTrackArtwork(
                            coverUrl: track.coverUrl,
                            genre: track.genre,
                            trackId: track.id,
                            width: 148,
                            height: 148,
                            borderRadius: AppRadius.cardBorder,
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                track.genre,
                                style: AppTypography.badge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : Colors.black.withValues(alpha: 0.72),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  isSelected && isPlaying
                                      ? PhosphorIconsFill.pause
                                      : PhosphorIconsFill.play,
                                  size: 14,
                                  color: isSelected
                                      ? AppColors.brandContrast
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        track.handleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

### 5.4 `apps/vhunambi_client/lib/features/home/presentation/widgets/creation_launch_strip.dart`
Zone 4: Compact Studio CTA + 4 non-duplicated Creation Tools (`REQ-P68-HUB-01`, zero raw hexes):

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Zone 4: Slim direct Studio CTA capsule paired with a clean 4-tool strip
/// (`REQ-P68-HUB-01`). Replaces both the 190dp fake prompt wrapper and duplicate
/// `AI Studio` grid card.
class CreationLaunchStrip extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback? onOpenStudio;
  final VoidCallback onOpenVoiceClone;
  final VoidCallback onOpenSketchpad;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenLibrary;

  const CreationLaunchStrip({
    super.key,
    required this.isDesktop,
    this.onOpenStudio,
    required this.onOpenVoiceClone,
    required this.onOpenSketchpad,
    this.onOpenMarket,
    this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final tools = <({
      Key key,
      String label,
      IconData icon,
      Color accent,
      VoidCallback? onTap,
    })>[
      (
        key: const Key('home_hub_voice_clone'),
        label: 'Voice Clone',
        icon: PhosphorIconsFill.microphoneStage,
        accent: AppColors.brandPrimary,
        onTap: onOpenVoiceClone,
      ),
      (
        key: const Key('home_hub_melody_sketchpad'),
        label: 'Sketchpad',
        icon: PhosphorIconsFill.musicNotesPlus,
        accent: AppColors.accentElectric,
        onTap: onOpenSketchpad,
      ),
      (
        key: const Key('home_hub_beats_market'),
        label: 'Beats Market',
        icon: PhosphorIconsFill.storefront,
        accent: AppColors.coinGold,
        onTap: onOpenMarket,
      ),
      (
        key: const Key('home_hub_asset_vault'),
        label: 'Asset Vault',
        icon: PhosphorIconsFill.folderSimpleLock,
        accent: AppColors.badgeCyan,
        onTap: onOpenLibrary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: AppColors.brandPrimary,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            key: const Key('home_create_studio_cta'),
            borderRadius: AppRadius.cardBorder,
            onTap: onOpenStudio,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.sparkle,
                      size: 18,
                      color: AppColors.brandContrast,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create in AI Studio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.brandContrast,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const PhosphorIcon(
                      PhosphorIconsBold.arrowRight,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isDesktop)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: tools
                .map((t) => _CreationToolCard(tool: t))
                .toList(),
          )
        else
          Row(
            children: <Widget>[
              for (var i = 0; i < tools.length; i++) ...<Widget>[
                Expanded(child: _CreationToolCard(tool: tools[i])),
                if (i < tools.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _CreationToolCard extends StatelessWidget {
  final ({
    Key key,
    String label,
    IconData icon,
    Color accent,
    VoidCallback? onTap,
  }) tool;

  const _CreationToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevatedOf(context),
      borderRadius: AppRadius.inputBorder,
      child: InkWell(
        key: tool.key,
        borderRadius: AppRadius.inputBorder,
        onTap: tool.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.inputBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tool.accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: Center(
                  child: PhosphorIcon(
                    tool.icon,
                    size: 16,
                    color: tool.accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tool.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 5.5 `apps/vhunambi_client/lib/features/home/presentation/widgets/editorial_rhythm_spotlight_card.dart`
Zone 5: Scrimmed editorial artwork card replacing the un-scrimmed neon banner (`REQ-P68-SPOT-01`):

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/home/domain/models/african_rhythm_matrix.dart';

/// Zone 5: Editorial Daily Rhythm Spotlight over scrimmed bundled African artwork
/// (`REQ-P68-SPOT-01`). Guarantees high contrast in both Light and Dark themes.
class EditorialRhythmSpotlightCard extends StatelessWidget {
  final DailyRhythmSpotlight spotlight;
  final VoidCallback onTryRhythm;

  const EditorialRhythmSpotlightCard({
    super.key,
    required this.spotlight,
    required this.onTryRhythm,
  });

  @override
  Widget build(BuildContext context) {
    final bgAsset = AppAssets.resolveGenreCoverAsset(
      spotlight.genre,
      seedId: spotlight.dayName,
    );

    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.darkSurfaceElevated,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const <double>[0.0, 0.55, 1.0],
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.48),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.compass,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DAILY RHYTHM SPOTLIGHT • ${spotlight.dayName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badge.copyWith(
                          color: AppColors.brandPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '${spotlight.bpm} BPM',
                        style: AppTypography.badge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  spotlight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spotlight.culturalDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton.icon(
                    key: const Key('home_try_rhythm_btn'),
                    onPressed: onTryRhythm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsFill.sparkle,
                      size: 15,
                      color: AppColors.brandContrast,
                    ),
                    label: Text(
                      'Try Rhythm',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```
*(Notice: preserves exact uppercase `'DAILY RHYTHM SPOTLIGHT • <DAYNAME>'`, `spotlight.title`, `Key('home_try_rhythm_btn')`, and `'Try Rhythm'` so existing Finding `HOME-005` in `phase31_home_dashboard_convergence_test.dart#L221-L250` passes out of the box!)*

### 5.6 Zone 1.5 Compact Telemetry & Creator DNA Strip (`telemetry_and_dna_banner.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';

/// Zone 1.5: Displays live AI pipeline progress when generating (`home_pipeline_progress_card`),
/// or a slim 48dp Creator DNA calibration strip linking to [CreatorDnaHelixLabSheet].
class TelemetryAndDnaBanner extends ConsumerWidget {
  final VoidCallback? onNavigateToStudio;

  const TelemetryAndDnaBanner({
    super.key,
    this.onNavigateToStudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipeline = ref.watch(generationProgressProvider);
    final dna = ref.watch(creatorDnaProvider);

    if (pipeline != null) {
      return Material(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.inputBorder,
        child: InkWell(
          key: const Key('home_pipeline_progress_card'),
          borderRadius: AppRadius.inputBorder,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            onNavigateToStudio?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.inputBorder,
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.waveform,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pipeline.trackTitle} • ${pipeline.genre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(pipeline.progressPercent * 100).round()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pipeline.statusMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: AppRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: pipeline.progressPercent.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.borderSubtleOf(context),
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final topGenre = dna.topGenres(1).isNotEmpty ? dna.topGenres(1).first : 'Adaptive Sound';

    return Material(
      color: AppColors.surfaceElevatedOf(context),
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        key: const Key('home_dna_compact_strip'),
        borderRadius: AppRadius.pillBorder,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          HapticsService().lightImpact();
          CreatorDnaHelixLabSheet.show(context, profile: dna);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: AppColors.accentElectric.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: <Widget>[
              const PhosphorIcon(
                PhosphorIconsFill.dna,
                size: 16,
                color: AppColors.accentElectric,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Creator DNA ${dna.strengthPercent}% calibrated • $topGenre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Helix',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentElectric,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const PhosphorIcon(
                PhosphorIconsBold.caretRight,
                size: 12,
                color: AppColors.accentElectric,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 5.7 `apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart`
Assembles Zones 1–5 with responsive desktop split, `*Of(context)` surfaces, zero fake prompt `TextField`, zero `TrendingReelsShelf`, zero `seed-01` mock, and `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false)`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/home/domain/models/african_rhythm_matrix.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/creation_launch_strip.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/editorial_rhythm_spotlight_card.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/horizontal_genre_track_shelf.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/main_room_header.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/now_playing_home_card.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/telemetry_and_dna_banner.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/melody_sketchpad_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart';

/// Phase 68: Vhunambi Home Dashboard ("Main Room & Studio Utility").
class HomeDashboardView extends ConsumerWidget {
  final VoidCallback? onNavigateToStudio;
  final VoidCallback? onNavigateToExplore;
  final VoidCallback? onNavigateToMarket;
  final VoidCallback? onNavigateToLibrary;
  final int? injectedWeekday;

  const HomeDashboardView({
    super.key,
    this.onNavigateToStudio,
    this.onNavigateToExplore,
    this.onNavigateToMarket,
    this.onNavigateToLibrary,
    this.injectedWeekday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final horizontalPad = isDesktop ? 32.0 : 16.0;
    final onboardingState = ref.watch(onboardingStateProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final spotlight = AfricanRhythmMatrix.forWeekday(injectedWeekday);

    final userGenres = onboardingState.selectedGenres
        .map((g) => g.toLowerCase().trim())
        .toSet();
    final scopedTracks = userGenres.isEmpty
        ? exploreTracks
        : exploreTracks
            .where((t) => userGenres.contains(t.genre.toLowerCase().trim()))
            .toList();
    final displayedGenreTracks =
        scopedTracks.isNotEmpty ? scopedTracks : exploreTracks;

    void openVoiceClone() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      VocalIdentityPickerSheet.show(context);
    }

    void openSketchpad() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      MelodySketchpadModal.show(context);
    }

    void tryRhythmSpotlight() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().mediumImpact();
      ref.read(studioFormProvider.notifier).setGenre(spotlight.genre);
      ref.read(studioFormProvider.notifier).updatePrompt(spotlight.samplePrompt);
      ref.read(melodySketchpadProvider.notifier).initializeFromRemixDna(
            genre: spotlight.genre,
            bpm: spotlight.bpm,
            musicalKey: spotlight.musicalKey,
          );
      onNavigateToStudio?.call();
    }

    // MiniPlayerHost is suppressed on Tab 0 when NowPlayingHomeCard is mounted.
    final bottomInset = isDesktop
        ? 32.0
        : VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      body: SafeArea(
        child: CustomScrollView(
          key: const Key('home_main_room_scroll'),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: MainRoomHeader(isDesktop: isDesktop),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                6,
                horizontalPad,
                bottomInset,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  TelemetryAndDnaBanner(
                    onNavigateToStudio: onNavigateToStudio,
                  ),
                  const SizedBox(height: 14),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              NowPlayingHomeCard(
                                onNavigateToStudio: onNavigateToStudio,
                              ),
                              const SizedBox(height: 18),
                              HorizontalGenreTrackShelf(
                                tracks: displayedGenreTracks,
                                selectedGenres: onboardingState.selectedGenres,
                                onViewAll: onNavigateToExplore,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              CreationLaunchStrip(
                                isDesktop: true,
                                onOpenStudio: onNavigateToStudio,
                                onOpenVoiceClone: openVoiceClone,
                                onOpenSketchpad: openSketchpad,
                                onOpenMarket: onNavigateToMarket,
                                onOpenLibrary: onNavigateToLibrary,
                              ),
                              const SizedBox(height: 16),
                              EditorialRhythmSpotlightCard(
                                spotlight: spotlight,
                                onTryRhythm: tryRhythmSpotlight,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    NowPlayingHomeCard(
                      onNavigateToStudio: onNavigateToStudio,
                    ),
                    const SizedBox(height: 16),
                    HorizontalGenreTrackShelf(
                      tracks: displayedGenreTracks,
                      selectedGenres: onboardingState.selectedGenres,
                      onViewAll: onNavigateToExplore,
                    ),
                    const SizedBox(height: 16),
                    CreationLaunchStrip(
                      isDesktop: false,
                      onOpenStudio: onNavigateToStudio,
                      onOpenVoiceClone: openVoiceClone,
                      onOpenSketchpad: openSketchpad,
                      onOpenMarket: onNavigateToMarket,
                      onOpenLibrary: onNavigateToLibrary,
                    ),
                    const SizedBox(height: 16),
                    EditorialRhythmSpotlightCard(
                      spotlight: spotlight,
                      onTryRhythm: tryRhythmSpotlight,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
> **Layout Note:** On mobile (`!isDesktop`), `MainRoomHeader` stacks the metric pills cleanly on row 2 while `HomeDashboardView` reserves `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false)` for the bottom nav capsule.

---

## 6. Supporting `STD-UIUX-001` Cleanups (`M68.4`)

### 6.1 `apps/vhunambi_client/lib/features/creator_dna/presentation/widgets/dna_insight_card.dart`
- Replace all raw unicode emojis (`'🧬'`, `'✨'`, `'🎯'`) with `PhosphorIcon(PhosphorIconsFill.dna / sparkle / target)`.
- Replace stock `Icon(Icons.close)` with `IconButton(constraints: BoxConstraints(minWidth: 48, minHeight: 48), icon: PhosphorIcon(PhosphorIconsBold.x, size: 16), ...)`.
- Replace hardcoded dark colors with `AppColors.surfaceElevatedOf(context)` / `AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`.

### 6.2 `apps/vhunambi_client/lib/features/home/presentation/widgets/cross_module_synergy_deck.dart`
- Replace all `Icon(PhosphorIcons...)` calls (`L46, L167, L208, L241`) with `PhosphorIcon(...)`.
- Replace static `AppColors.surfaceElevated` / `textPrimary` / `textSecondary` / `borderSubtle` with `*Of(context)` equivalents.

### 6.3 `apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart`
- Replace `Icon(Icons.close_rounded)` (`L80`) with `PhosphorIcon(PhosphorIconsBold.x, size: 18)` inside a `48x48` hit target.
- Replace `Icon(Icons.check_circle_rounded)` (`L436-L437`) with `PhosphorIcon(PhosphorIconsFill.checkCircle, size: 16)`.
- Tokenize billing toggle container (`L92-L94`) using `AppColors.surfaceSecondaryOf(context)` and `AppColors.borderSubtleOf(context)`.

### 6.4 RootShell (`apps/vhunambi_client/lib/main.dart`)
- Wire `onNavigateToExplore: () => _switchTab(1)` onto `HomeDashboardView` inside `RootShell` so `View all >` on Zone 3 (`HorizontalGenreTrackShelf`) switches smoothly to Explore Tab 1.
