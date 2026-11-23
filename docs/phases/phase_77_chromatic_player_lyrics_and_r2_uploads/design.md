# Phase 77 Technical Design Specification (`design.md`)

**Phase ID:** `P77` — Chromatic Full-Screen Player, Synced Sing-Along Lyrics & Unified R2 Media Uploads  
**Verified Baseline:** Flutter `3.44.4` / Dart `3.12.2` · `package:vhunambi_client/...` · `package:phosphor_icons/phosphor_icons.dart`  
**Authentic Token Enforcement:** `AppColors.surfaceCanvasOf(context)`, `surfaceElevatedOf(context)`, `surfaceSecondaryOf(context)`, `surfaceModalOf(context)`, `borderSubtleOf(context)`, `textPrimaryOf(context)`, `textSecondaryOf(context)`; `AppTypography.{displayLarge,displayMedium,titleLarge,titleMedium,titleSmall,bodyLarge,bodyMedium,bodyMuted,bodySmall,caption,badge}`. Zero `AppTypography.labelSmall`/`labelMedium`, zero stock `Icons.*`, zero raw Unicode emojis.

---

## 1. Mathematical & Algorithmic Foundations

### 1.1 Chromatic Palette Resolution & Stale-Response Elimination
Given `Track` $T$ (`coverUrl`, `mood`) and `Brightness` $B$:
$$
\sigma(T, B) = \text{concat}(B.\text{name},\; "|",\; T.\text{mood} ?? "",\; "|",\; T.\text{coverUrl} ?? "")
$$
1. Frame 1 computes $P_0 = \text{PostChromaticPaletteResolver.resolveSync}(B, T.\text{mood}, T.\text{coverUrl}, \text{hasAudioAttachment}: \text{true})$.
2. If $\sigma(T, B) \neq \sigma_{\text{last}}$, update $\sigma_{\text{last}} \leftarrow \sigma(T, B)$ and schedule `WidgetsBinding.instance.addPostFrameCallback` to await $P_1 = \text{resolveAsync}(\dots)$.
3. Commit $P_1$ via `setState` **if and only if** `mounted && _lastSig == sig` and $(P_1.\text{primaryGlow}, P_1.\text{accent}, P_1.\text{tier}) \neq (P_0.\text{primaryGlow}, P_0.\text{accent}, P_0.\text{tier})$.

### 1.2 Synced Lyric Line Timeline & Seek Inversion
For sanitized non-empty lines $L = [l_0, l_1, \dots, l_{N-1}]$ ($N \ge 1$), playback position $p \ge 0$, and track duration $D > 0$:
$$
i_{\text{active}}(p, D, N) =
\begin{cases}
-1 & \text{if } N = 0 \text{ or } D \le 0 \\
\left\lfloor \min\!\left(\max\!\left(\frac{p_{\text{ms}}}{D_{\text{ms}}},\; 0\right),\; 0.9999\right) \cdot N \right\rfloor & \text{otherwise}
\end{cases}
$$
$$
t_{\text{seek}}(k, D, N) = \text{Duration}\!\left(\text{milliseconds}: \left\lfloor \frac{\text{clamp}(k, 0, N-1)}{N} \cdot D_{\text{ms}} \right\rfloor\right)
$$
Invariant: For all $k \in [0, N-1]$ and $D_{\text{ms}} \ge N$, $i_{\text{active}}(t_{\text{seek}}(k, D, N), D, N) = k$ (exact round-trip monotonicity).

---

## 2. Pass 1 — `M77.1`: Living Chromatic Player & Dock Parity

### 2.1 `[NEW]` `apps/vhunambi_client/lib/features/player/presentation/widgets/player_chromatic_resolver_mixin.dart`

Reusable helper so `ExpandedCockpitModal`, `MobileMiniPlayer`, `PillForm`, and `DesktopTransportBar` share identical, race-free chromatic resolution:

```dart
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topAlpha = isDark ? 0.28 : 0.14;
    final midAlpha = isDark ? 0.14 : 0.07;

    return BoxDecoration(
      color: baseSurface,
      borderRadius: borderRadius,
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
```

### 2.2 `[MODIFY]` `apps/vhunambi_client/lib/core/widgets/vhunambi_bottom_dock_kit.dart`
- Add optional `final Color? borderTint;` to `VhunambiFloatingTransportSurface`.
- Replace static Dark tokens inside `VhunambiFloatingTransportSurface.build` (`#L60-95`) and `VhunambiBottomDockSurface.build` (`#L110-129`):
  - `AppColors.surfaceModal.withAlpha(210)` -> `AppColors.surfaceModalOf(context).withValues(alpha: isDark ? 0.86 : 0.94)`
  - `AppColors.borderSubtle` -> `borderTint ?? AppColors.borderSubtleOf(context)`
  - `AppColors.surfaceCanvas.withAlpha(215)` -> `AppColors.surfaceCanvasOf(context).withValues(alpha: isDark ? 0.88 : 0.95)`
  - Drop shadow opacity adapted for Light (`0.12`) vs Dark (`0.35`).

### 2.3 `[MODIFY]` `apps/vhunambi_client/lib/features/player/presentation/widgets/pill_form.dart`
- Remove `import 'package:palette_generator/palette_generator.dart';` and `_extractPalette()` (`#L106-127`).
- Mix in `PlayerChromaticPaletteMixin<PillForm>` and call `final palette = resolvePlayerChromaticPalette(context, track);`.
- Replace `AppColors.textSecondary` (`#L196,216`) with `AppColors.textSecondaryOf(context)` and wrap the pill body in `Key('pill_chromatic_surface')` using `palette.primaryGlow`, `palette.accent`, and `palette.glassBorderTint`.

### 2.4 `[MODIFY]` `apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart`
- Convert `MobileMiniPlayer` to `ConsumerStatefulWidget` with `PlayerChromaticPaletteMixin` (or consume `PostChromaticPaletteResolver` inside a stateful wrapper).
- Resolve `final palette = resolvePlayerChromaticPalette(context, track);`.
- Pass `glow: palette.primaryGlow` and `borderTint: palette.glassBorderTint` to `VhunambiFloatingTransportSurface`.
- Replace `#L159-178` (`AppGradients.forGenre` + `AppIcons.piano`) with:
  ```dart
  VhunambiTrackArtwork(
    key: const Key('mini_player_artwork'),
    coverUrl: track.coverUrl,
    genre: track.genre,
    trackId: track.id,
    width: 44,
    height: 44,
    borderRadius: BorderRadius.circular(10),
    badgeIconSize: 20,
  )
  ```
- Replace all static `AppColors.surfaceModal`, `AppColors.borderSubtle`, `AppColors.textPrimary`, `AppColors.textSecondary` with `AppColors.*Of(context)` and progress bar accent with `palette.accent`.

### 2.5 `[MODIFY]` `apps/vhunambi_client/lib/features/player/presentation/widgets/desktop_transport_bar.dart`
- Convert to `ConsumerStatefulWidget` with `PlayerChromaticPaletteMixin` so desktop transport inherits `palette.accent` and subtle top border tint `palette.glassBorderTint`.
- Replace artwork box (`#L82-90`) with `VhunambiTrackArtwork(key: const Key('desktop_transport_artwork'), coverUrl: track.coverUrl, genre: track.genre, trackId: track.id, width: 44, height: 44, borderRadius: BorderRadius.circular(8), badgeIconSize: 20)`.
- Replace static `AppColors.surfaceElevated` (`#L45`), `borderSubtle`, `textSecondary`, `Colors.white` skip icons with `AppColors.*Of(context)`.
- Replace **3** stock Material `Icons.*` and raw `Icon(...)` calls:
  - `Icons.speed_rounded` (`#L216`) -> `PhosphorIcon(PhosphorIconsRegular.gauge, ...)`
  - `Icons.playlist_add_rounded` (`#L320`) -> `PhosphorIcon(PhosphorIconsRegular.playlist, ...)`
  - `Icons.queue_music_rounded` (`#L332`) -> `PhosphorIcon(PhosphorIconsRegular.queue, ...)`
  - Raw `Icon(...)` (`#L147,178,200,250,298`) -> `PhosphorIcon(...)`.

### 2.6 `[MODIFY]` `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
- Mix in `PlayerChromaticPaletteMixin<ExpandedCockpitModal>` on `_ExpandedCockpitModalState`.
- Resolve `final palette = resolvePlayerChromaticPalette(context, track);` and paint the modal container (`Key('cockpit_chromatic_backdrop')`) using `buildChromaticStageDecoration(context: context, palette: palette, baseSurface: AppColors.surfaceModalOf(context), borderRadius: AppRadius.modalBorder)`.
- Replace the static genre gradient + `AppIcons.piano` hero (`#L379-399`) with `VhunambiTrackArtwork(key: const Key('cockpit_hero_artwork'), coverUrl: track.coverUrl, genre: track.genre, trackId: track.id, width: artSize, height: artSize, borderRadius: BorderRadius.circular(24), badgeIconSize: 56)` inside a chromatic aura `BoxShadow(color: palette.primaryGlow.withValues(alpha: isDark ? 0.36 : 0.22), blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 12))`.
- Replace all static Dark tokens (`AppColors.surfaceModal`, `AppColors.darkSurfaceSecondary`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.borderSubtle`, `Colors.white` controls) with `AppColors.*Of(context)` and `palette.accent` / `palette.onAccent`.
- Replace raw `Icon(...)` on `#L593,638,673` with `PhosphorIcon(...)`.

---

## 3. Pass 1 — `M77.2`: Synced Clean Karaoke & 9-Language Bantu Word Glossary

### 3.1 `[NEW]` `apps/vhunambi_client/lib/features/track/domain/utils/synced_lyric_timeline.dart`

Pure Dart domain calculator (zero Flutter imports):

```dart
/// Pure-Dart playback-to-lyric line synchronization helper (`REQ-P77-LYR-02`).
abstract final class SyncedLyricTimeline {
  /// Splits sanitized lyrics into non-empty displayable lines.
  static List<String> extractLines(String sanitizedLyrics) {
    return sanitizedLyrics
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Resolves the 0-based active line index for [position] inside [duration].
  /// Returns `-1` when [lineCount] <= 0 or [duration] <= Duration.zero.
  static int resolveActiveLineIndex({
    required int lineCount,
    required Duration position,
    required Duration duration,
  }) {
    if (lineCount <= 0 || duration.inMilliseconds <= 0) return -1;
    final ratio = (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 0.9999);
    return (ratio * lineCount).floor().clamp(0, lineCount - 1);
  }

  /// Computes the playback seek target corresponding to tapping [lineIndex].
  static Duration seekTargetForLine({
    required int lineIndex,
    required int lineCount,
    required Duration duration,
  }) {
    if (lineCount <= 0 || duration.inMilliseconds <= 0) return Duration.zero;
    final clampedIdx = lineIndex.clamp(0, lineCount - 1);
    final ms = ((clampedIdx / lineCount) * duration.inMilliseconds).floor();
    return Duration(milliseconds: ms);
  }
}
```

### 3.2 `[MODIFY]` `apps/vhunambi_client/lib/features/studio/domain/services/bantu_lyric_translation_service.dart`

Add 9-language default codes and `lookupWord(...)` returning `BantuWordDefinition`:

```dart
/// Per-word definition, phonetic stress breakdown, and 9-language cognates (`REQ-P77-LYR-04`).
class BantuWordDefinition {
  const BantuWordDefinition({
    required this.originalWord,
    required this.normalizedWord,
    required this.sourceLanguage,
    required this.syllabifiedPhonetic,
    required this.meaning,
    required this.cognates,
    this.isExactGlossaryMatch = false,
  });

  final String originalWord;
  final String normalizedWord;
  final BantuLanguage sourceLanguage;
  final String syllabifiedPhonetic;
  final String meaning;
  final List<BantuSimilarityResult> cognates;
  final bool isExactGlossaryMatch;

  bool get hasMeaning => meaning != kMeaningUnavailable;
  String get branchLabel =>
      '${sourceLanguage.branch.label} (${sourceLanguage.branch.guthrieZone})';
}
```

Inside `BantuLyricTranslationService`:
- Add `static const List<String> allBantuLanguageCodes = <String>['zu', 'xh', 'ss', 'nr', 'nso', 'tn', 'st', 've', 'ts'];`.
- Update default `targetCognateLanguages` in `processLyrics` and `translateLine` from `const ['zu', 'xh', 'nso', 've', 'ts']` to `allBantuLanguageCodes`.
- Add `static BantuWordDefinition lookupWord(String rawWord, {String baseLanguageCode = 'zu'})`:
  1. Normalize `rawWord` stripping punctuation (`RegExp(r'[^\w\u00C0-\u017F]')`).
  2. Resolve exact or single-word match across `kBantuCuratedEntries` (resolving the entry's `language` when matched, else `BantuLanguage.fromCode(baseLanguageCode) ?? BantuLanguage.zu`).
  3. Generate `syllabifiedPhonetic = syllabifyAndMarkPenultimate(rawWord)`.
  4. Compare `normalizedWord` via `BantuSimilarity.compare` across all other 8 `BantuLanguage.values` (`score >= 60`), sorted descending by score, capped at top 6 unique cognates.
- Add `static String resolveLanguageCode(String languageLabel)` normalizing display names (`'Tshivenḓa'` / `'Tshivenda'` -> `'ve'`, `'isiZulu'` -> `'zu'`, `'isiXhosa'` -> `'xh'`, `'siSwati'` -> `'ss'`, `'isiNdebele'` -> `'nr'`, `'Sepedi'` -> `'nso'`, `'Setswana'` -> `'tn'`, `'Sesotho'` -> `'st'`, `'Xitsonga'` -> `'ts'`, default `'zu'`).

### 3.3 `[NEW]` `apps/vhunambi_client/lib/features/track/presentation/widgets/bantu_word_glossary_sheet.dart`

Compact Light/Dark glass modal (`Key('bantu_word_glossary_sheet')`) shown when tapping any lyric word in Bantu Sing-Along mode:
- Wrapped in `VhunambiGlassSurface(variant: VhunambiGlassVariant.chrome, enableLiveBlur: false, borderRadius: AppRadius.modalBorder)`.
- Header: Word (`AppTypography.titleLarge`), language chip (`${definition.sourceLanguage.displayName} · ${definition.branchLabel}`), and `44x44` close `IconButton` (`PhosphorIcon(AppIcons.close)`).
- Pronunciation Card: `BantuLyricTranslationService.buildStyledPhoneticGuide(definition.syllabifiedPhonetic, ...)` with penultimate syllable bolded in `accentColor`.
- Meaning Card: Curated meaning (or helpful cultural phonetic note if `meaning == kMeaningUnavailable`).
- Cross-Language Cognates `Wrap`: Chips showing `${c.target.displayName}: ${c.targetWord} (${c.score}%)` across Nguni, Sotho-Tswana, Tshivenda, and Tswa-Ronga.

### 3.4 `[MODIFY]` `apps/vhunambi_client/lib/features/track/presentation/widgets/lyrics_teleprompter.dart`
- Upgrade `LyricsTeleprompter` from `StatefulWidget` to `ConsumerStatefulWidget`, accepting optional `Color? accentColorOverride` and `bool embeddedInPlayer = false`.
- Sanitize `widget.track.lyrics` via `LyricKaraokeSanitizer.cleanLyricsForTeleprompter(...)` and split via `SyncedLyricTimeline.extractLines(...)`.
- Watch `playerStateProvider`:
  - `final isTrackActive = playerState.currentTrack?.id == widget.track.id;`
  - `final activeIdx = isTrackActive ? SyncedLyricTimeline.resolveActiveLineIndex(lineCount: lines.length, position: playerState.position, duration: playerState.duration) : -1;`
  - When `activeIdx != _lastAutoScrolledIdx && activeIdx >= 0`, schedule `WidgetsBinding.instance.addPostFrameCallback` to call `Scrollable.ensureVisible(lineKey.currentContext, alignment: 0.35, duration: const Duration(milliseconds: 240))`.
- Each line row (`InkWell` on tap -> seeks via `ref.read(playerStateProvider.notifier).seek(SyncedLyricTimeline.seekTargetForLine(...))`):
  - Active row gets `key: const Key('synced_lyrics_active_line')`, `accent.withValues(alpha: isDark ? 0.16 : 0.10)` background tint, and `accent` leading bar.
  - When Bantu Sing-Along toggle (`Key('synced_lyrics_bantu_toggle')`) is ON, renders words in a `Wrap` of interactive word chips/spans; tapping any word calls `BantuWordGlossarySheet.show(context, definition: BantuLyricTranslationService.lookupWord(word, baseLanguageCode: langCode), accentColor: accent)`.
- Replace all static `AppColors.*` tokens with `AppColors.*Of(context)` and replace raw `Icon(PhosphorIcons...)` (`#L44,71`) with `PhosphorIcon(...)`.

### 3.5 `[MODIFY]` `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart` (`_buildLyricsCard`)
- Resolve raw lyrics from `libraryTracksProvider` first, falling back to `ref.watch(trackDetailProvider(track.id)).lyrics` if absent/empty.
- Sanitize copy payload via `LyricKaraokeSanitizer.cleanLyricsForTeleprompter(rawLyrics)` and change `cockpit_copy_lyrics` icon from `AppIcons.edit` (`#L875`) to `PhosphorIconsRegular.copy`.
- Embed `LyricsTeleprompter(track: synthesizedTrackDetail, accentColorOverride: palette.accent, embeddedInPlayer: true)` inside `_buildLyricsCard` so the Full-Screen Player automatically gains clean karaoke sanitization, live playback sync, tap-to-seek, and 9-language Bantu word definitions with zero code duplication!

---

## 4. Pass 2 — `M77.3`: Unified R2 Media Uploads & Visitor "Share as Reel"

### 4.1 `[NEW]` `apps/vhunambi_client/lib/core/media/vhunambi_media_upload_service.dart`

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';

/// Validated R2 upload result returned by [VhunambiMediaUploadService].
@immutable
class VhunambiUploadedMedia {
  final String url;
  final String filename;
  final String mimeType;
  final int sizeBytes;

  const VhunambiUploadedMedia({
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
  });
}

/// Unified gallery image picker + Cloudflare R2 uploader (`EP-P77-UNIFIED-R2-IMAGE-UPLOAD`,
/// consuming `EP-P74-SOCIAL-MEDIA-R2-UPLOAD` -> `POST /api/social/media/upload`).
class VhunambiMediaUploadService {
  static const int maxImageBytes = 25 * 1024 * 1024; // Matches social_routes.ts
  static const Set<String> allowedImageMimes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String inferImageMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Picks an image from the device gallery (or deterministic stub in tests),
  /// validates MIME/size, and uploads bytes to R2 via [socialRepository.uploadReelMedia].
  static Future<VhunambiUploadedMedia?> pickAndUploadImage({
    required ISocialRepository socialRepository,
    required String purposePrefix,
    Uint8List? testBytesOverride,
    String? testFilenameOverride,
  }) async {
    Uint8List bytes;
    String filename;
    String mimeType;

    if (testBytesOverride != null || _isTestEnv) {
      bytes = testBytesOverride ??
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      filename = testFilenameOverride ??
          '${purposePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      mimeType = inferImageMimeType(filename);
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return null;
      bytes = await picked.readAsBytes();
      filename = picked.name.isNotEmpty
          ? picked.name
          : '${purposePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      mimeType = inferImageMimeType(filename);
    }

    if (bytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }
    if (bytes.length > maxImageBytes) {
      throw const FormatException('Selected image exceeds the 25 MB R2 upload limit.');
    }
    if (!allowedImageMimes.contains(mimeType)) {
      throw FormatException('Unsupported image format: $mimeType');
    }

    final uploaded = await socialRepository.uploadReelMedia(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );

    return VhunambiUploadedMedia(
      url: uploaded.url,
      filename: filename,
      mimeType: uploaded.mimeType,
      sizeBytes: uploaded.sizeBytes,
    );
  }
}
```

### 4.2 `[MODIFY]` `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`
- Remove `_mockPickImage({String? mockUrl})` (`#L113-139`) and its dead duplicate ternary.
- Add `bool _isUploadingImage = false;` and `Future<void> _pickAndUploadPhoto()` calling `VhunambiMediaUploadService.pickAndUploadImage(socialRepository: ref.read(socialRepositoryProvider), purposePrefix: 'kpost_photo')`.
- Bind `Key('kpost_pick_photo_btn')` to `_pickAndUploadPhoto`, showing a compact progress spinner while `_isUploadingImage` is true and appending `KineticPostImageAttachment(imageUrl: result.url, ...)` to `_attachedImages`.
- Replace hardcoded `location: 'Limpopo / Polokwane'` (`#L271`) with `(owner.location.isNotEmpty ? owner.location : 'South Africa')` (or check `OwnerProfile` fields before editing; if `OwnerProfile` has no `location` field, default cleanly to `'South Africa'`).
- Migrate static Dark tokens (`#L201-606`, `#L956-969`) to `AppColors.*Of(context)` and wrap sheet in `VhunambiGlassSurface(enableLiveBlur: false)`.

### 4.3 `[MODIFY]` `apps/vhunambi_client/lib/features/playlists/` (`playlist_entity.dart`, `playlists_provider.dart`, `playlists_vault_view.dart`, `playlist_detail_view.dart`)
- **`playlist_entity.dart`:** Update `copyWith` to support `bool clearCoverImage = false`:
  `coverImageUrl: clearCoverImage ? null : (coverImageUrl ?? this.coverImageUrl),`
- **`playlists_provider.dart`:**
  - `Future<PlaylistEntity> createPlaylist(String title, {String? description, String? coverImageUrl})`
  - `Future<void> updatePlaylist(String id, {String? title, String? description, String? coverImageUrl, bool clearCoverImage = false})`
  - Persists seamlessly to Hive + `PUT /api/playlists/:id` -> D1 `cover_image_url` (`vhunambi_db.ts#L3129-3134`).
- **`playlists_vault_view.dart` & `playlist_detail_view.dart`:**
  - Upgrade `_CreatePlaylistDialog` and `_RenamePlaylistDialog` (and `PlaylistDetailView._showRenameDialog`) to `ConsumerStatefulWidget` dialogs with:
    - Live `80x80` preview using `PlaylistCoverArt` / `VhunambiTrackArtwork`,
    - `'Upload Cover'` button (`Key('playlist_pick_cover_btn')`, `PhosphorIconsRegular.image`) invoking `VhunambiMediaUploadService.pickAndUploadImage(socialRepository: ref.read(socialRepositoryProvider), purposePrefix: 'playlist_cover')`,
    - `'Use Auto Collage'` clear button (`Key('playlist_clear_cover_btn')`) when a custom cover is set,
    - `AppColors.surfaceModalOf(context)` / `textPrimaryOf(context)` / `textSecondaryOf(context)`.
  - Add `'Change Cover'` (`Key('playlist_detail_edit_cover_item')`, `PhosphorIconsRegular.image`) to `PlaylistDetailView`'s popup menu.
- **`collections_provider.dart`:** Add optional `String? coverImageUrl` to `createCollection` and `updateCollection` (plus `clearCoverImage` on `CollectionEntity.copyWith`) for clean model parity.

### 4.4 `[MODIFY]` `apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart` & `track_detail_view.dart`
- Add `final VoidCallback? onShareAsReel;` to `TrackActionsBar`.
- Render a glass pill (`Key('track_reel_pill')`, `constraints: const BoxConstraints(minHeight: 44)`) with `PhosphorIcon(AppIcons.reels, size: 18, color: textPrimary)` and `'Reel'` right beside the `'Share'` pill whenever `onShareAsReel != null`.
- In `TrackDetailView`, pass `onShareAsReel: () => _openVideoExport(track)` into `TrackActionsBar(...)` (unconditionally for visitors and owners!).

---

## 5. Pass 2 — `M77.4`: Complete `STD-UIUX-001` Icon, Emoji & Contrast Remediation Map

| File | Current Violation | Replacement |
| :--- | :--- | :--- |
| `desktop_transport_bar.dart` | `Icons.speed_rounded`, `playlist_add_rounded`, `queue_music_rounded` + raw `Icon(...)` | `PhosphorIcon(PhosphorIconsRegular.gauge / playlist / queue)` |
| `queue_drawer.dart` | 8 `Icons.*` + static dark tokens | `PhosphorIcon(PhosphorIconsRegular.queue / trash / x / pianoKeys / dotsSixVertical / musicNotes)` + `Of(context)` |
| `playlist_detail_view.dart` | 7 `Icons.*` + static dark tokens | `PhosphorIcon(PhosphorIconsRegular.dotsThreeVertical / pencilSimple / trash / play / shuffle / dotsSixVertical / x)` + `Of(context)` |
| `add_to_playlist_sheet.dart` | 5 `Icons.*` | `PhosphorIcon(PhosphorIconsRegular.plus / playlist / magnifyingGlass / disc / queue)` |
| `collection_detail_view.dart` | 3 `Icons.*` + 2 emojis (`⚠`, `📄`) + dark tokens | `PhosphorIcon(PhosphorIconsFill.play / Regular.shuffle / fileText)` + plain `'Split Sheet'` + `Of(context)` |
| `collection_form_dialog.dart` | `Icons.event_rounded` + dark tokens | `PhosphorIcon(PhosphorIconsRegular.calendarBlank)` + `Of(context)` |
| `collection_type_badge.dart` | 4 `Icons.*` | `PhosphorIconsRegular.musicNote / disc / vinylRecord / squaresFour` |
| `add_to_collection_sheet.dart` | `Icons.search_rounded` | `PhosphorIconsRegular.magnifyingGlass` |
| `split_sheet_modal.dart` | `'📄 Split Sheet — ...'` | `'Split Sheet — ...'` (pair with `PhosphorIcon(PhosphorIconsRegular.fileText)`) |
| `stem_mix_bounce_service.dart` & `stem_mixer_state.dart` | 8 stem emojis (`🎤`, `🥁`, `🔊`, `🎹`, `🎸`) | Plain icon-free labels / `iconKey` identifiers (rendering via `AppIcons.vocals / drums / sliders / piano / guitar`) |
| `explore_models.dart` | 8 mood emojis (`😊`, `🌧️`, `🕊️`, `🔥`, `📻`, `🌙`, `🎉`, `🖤`) | Clean text labels (`'Uplifting'`, `'Melancholic'`, etc.) paired with `VhunambiMood.normalize(value).icon` |
| `explore_search_view.dart`, `african_charts_banner.dart`, `catalog_filter_bar.dart`, `explore_empty_state.dart`, `genre_glyph.dart`, `track_card.dart`, `track_list_tile.dart` | 36 `Icons.*` | Matching `PhosphorIconsRegular.*` / `PhosphorIconsFill.*` (`arrowLeft`, `magnifyingGlass`, `x`, `trendUp`, `checkCircle`, `caretRight`, `translate`, `check`, `globe`, `caretDown`, `sparkle`, `pianoKeys`, `waveform`, `musicNote`, `disc`, `speakerHigh`, `microphone`, `play`, `pause`, `heart`) |
