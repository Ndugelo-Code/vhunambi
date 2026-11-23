# Phase 78 Technical Design Specification (`design.md`)

**Phase ID:** `P78` — Vault, Explore & Profile Continuity, Real Audio/Video Uploads & Unified Glass Tabs  
**Standard:** All-Gemini Anti-Bait-and-Switch Design (`package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, `STD-UIUX-001` zero stock `Icons.*` & zero raw emojis, zero `// TODO` stubs).

---

## 1. Pass 1 — `M78.1`: Real Audio Upload & Camera/Gallery Video Capture (`VA-02`)

### 1.1 Backend R2 Audio MIME Parity (`apps/vhunambi_api/src/routes/social_routes.ts`)
Extend `ALLOWED_SOCIAL_MEDIA_MIMES` (`#L127-L136`) so DAW uploads (`.wav`, `.aac`, `.ogg`) succeed cleanly at `POST /api/social/media/upload`:

```ts
const ALLOWED_SOCIAL_MEDIA_MIMES: Record<string, string> = {
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'audio/mpeg': 'mp3',
  'audio/mp4': 'm4a',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/aac': 'aac',
  'audio/ogg': 'ogg',
};
```

### 1.2 `DirectDawVocalUploadSheet` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart`)
Replace the static placeholder `_selectedFileName` + non-interactive dropzone + fabricated `cdn.vhunambi.com` URL + `isInstrumental: true` black-hole with a real `FilePicker` + local persistence + R2 upload workflow:

```dart
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
```

State additions on `_DirectDawVocalUploadSheetState`:
```dart
  static const int _maxAudioBytes = 25 * 1024 * 1024;
  Uint8List? _selectedAudioBytes;
  String? _selectedLocalPath;
  String _selectedMimeType = 'audio/mpeg';
  bool _hasPickedRealFile = false;
  bool _isUploading = false;
  bool _titleEditedByUser = false;

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _inferAudioMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mpeg';
  }

  Future<void> _pickAudioFile() async {
    if (_isUploading) return;
    HapticFeedback.selectionClick();

    Uint8List? bytes;
    String? pickedName;
    String? pickedPath;

    if (_isTestEnv) {
      pickedName = _workflow == _UploadWorkflow.liveVocalStem
          ? 'vocal_take_01.wav'
          : 'daw_master_import.mp3';
      bytes = Uint8List.fromList(<int>[0x49, 0x44, 0x33, 0x03, 0x00, 0x00]);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['mp3', 'm4a', 'wav', 'aac', 'ogg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      pickedName = file.name;
      pickedPath = file.path;
      bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && pickedPath != null) {
        final f = File(pickedPath);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
    }

    if (bytes == null || bytes.isEmpty || pickedName == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not read selected audio file.'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    if (bytes.length > _maxAudioBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Audio file exceeds the 25 MB upload limit.'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    // Persist locally into app documents so offline/local playback never breaks
    String? persistedPath = pickedPath;
    if (!_isTestEnv && !kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final safeName = pickedName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final outFile = File(
          '${docs.path}/vhunambi_uploads_${DateTime.now().millisecondsSinceEpoch}_$safeName',
        );
        await outFile.writeAsBytes(bytes, flush: true);
        persistedPath = outFile.path;
      } catch (_) {}
    }

    if (!mounted) return;
    final cleanStem = pickedName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    setState(() {
      _selectedFileName = pickedName!;
      _selectedAudioBytes = bytes;
      _selectedLocalPath = persistedPath;
      _selectedMimeType = _inferAudioMime(pickedName);
      _hasPickedRealFile = true;
      if (!_titleEditedByUser && cleanStem.isNotEmpty) {
        _titleController.text = cleanStem.replaceAll('_', ' ');
      }
    });
  }
```

Updated async `_handleSubmit()`:
1. If `_workflow == _UploadWorkflow.cameraReel`: pop sheet and launch `KineticReelStudioView.show(context, initialCameraMode: true)`.
2. Require `_hasPickedRealFile && _selectedAudioBytes != null` (or show clear validation SnackBar `'Select an MP3, M4A, or WAV audio file first.'`).
3. Set `setState(() => _isUploading = true)` and upload bytes via `ref.read(socialRepositoryProvider).uploadReelMedia(bytes: _selectedAudioBytes!, filename: _selectedFileName, mimeType: _selectedMimeType)`.
4. Normalize URL (`AppConstants.normalizeCloudMediaUrl(upload.url)`), construct `LibraryTrack` with `creatorId: resolvedCreatorId`, `creatorHandle: resolvedHandle`, `creatorName: resolvedName`, `localAudioFilePath: _selectedLocalPath`, `remoteAudioUrl: resolvedAudioUrl`, `syncStatus: _selectedLocalPath != null ? TrackSyncStatus.cachedLocally : TrackSyncStatus.synced`, and **`isInstrumental: false`** so the uploaded track immediately lands in **both** `LibraryCategory.songs` (`LibraryView`) and `OwnerProfileView` (`Your Songs`).
5. Wrap the File Import Dropzone (`#L320-L356`) in `InkWell(key: const Key('direct_upload_pick_file_btn'), onTap: _pickAudioFile, ...)` displaying selected filename, byte size (`KB`/`MB`), or `"Tap to select audio file (MP3, M4A, WAV)"` prompt.

### 1.3 `PublishedClip` Local Video Continuity (`apps/vhunambi_client/lib/features/social/domain/models/published_clip.dart`)
Add optional `final String? localVideoPath;` to `PublishedClip` constructor, `copyWith`, `toJson` (`if (localVideoPath != null) 'localVideoPath': localVideoPath`), and `fromJson` (`localVideoPath: json['localVideoPath'] as String?`).

### 1.4 `KineticReelStudioView` Real Camera Recording, Stage 2 `VideoPlayerController` & Wide Audio Pill (`apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`)
1. Add optional `final bool initialCameraMode;` to `KineticReelStudioView` & `KineticReelStudioView.show(...)`; when `initialCameraMode == true`, initialize `_backdropMode = _BackdropMode.camera`, `_mediaKind = 'camera_video'`, and call `_initCameraIfAllowed()` in `initState`.
2. Add recording & Stage 2 preview fields:
   ```dart
   String? _customMediaLocalPath;
   bool _isRecordingVideo = false;
   int _recordingElapsedSec = 0;
   Timer? _recordingTicker;
   VideoPlayerController? _stage2VideoController;
   bool _stage2VideoReady = false;
   ```
3. In `_initCameraIfAllowed()`, use `enableAudio: true` on non-test devices (so real vocal/ambient performances record audio cleanly, with fallback retry to `enableAudio: false` if mic permission is denied). Wire Flash button (`_flashOn`) to `_cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off)`.
4. Implement real `_startVideoCapture()` / `_stopVideoCapture()` called by `_handleShutterTap()`:
   - If `_isRecordingVideo`: call `_stopVideoCapture()` -> `final XFile file = await ctrl.stopVideoRecording();` -> read `bytes = await file.readAsBytes()`, set `_customMediaLocalPath = file.path`, `_customMediaBytes = bytes`, `_customMediaFilename = file.name`, `_customMediaMime = 'video/mp4'`, `_mediaKind = 'camera_video'`, initialize `_initStage2VideoPreview(file.path)`, and set `_stage = _ReelStudioStage.editor`.
   - Else if `_cameraController != null && _cameraController!.value.isInitialized`: call `await ctrl.startVideoRecording();`, set `_isRecordingVideo = true`, `_recordingElapsedSec = 0`, start 1-second `_recordingTicker` auto-stopping at `_lengthSteps[_lengthIdx]`.
   - Else (artwork/vision mode or headless test): keep deterministic transition to `_stage = _ReelStudioStage.editor`.
5. In `_pickGalleryMedia()`: store `_customMediaLocalPath = media.path`, persist bytes to temp file if `media.path` is empty, and if `isVideo`, call `unawaited(_initStage2VideoPreview(media.path))` before entering `_ReelStudioStage.editor`.
6. Stage 2 Backdrop Stack (`#L381-L415`):
   - When `_stage == _ReelStudioStage.editor && (_mediaKind == 'camera_video' || _mediaKind == 'gallery_video') && _stage2VideoReady && _stage2VideoController != null`: render `FittedBox(key: const Key('reel_studio_stage2_video_preview'), fit: BoxFit.cover, child: SizedBox(width: ..., height: ..., child: VideoPlayer(_stage2VideoController!)))` beneath `KineticPreviewCanvas(..., transparentBackground: true)`.
   - When `_stage == _ReelStudioStage.editor && _mediaKind == 'gallery_photo' && _customMediaBytes != null`: render `Image.memory(_customMediaBytes!, key: const Key('reel_studio_stage2_photo_preview'), fit: BoxFit.cover)` beneath `KineticPreviewCanvas(..., transparentBackground: true)`.
   - Pass `customMediaLocalPath: _customMediaLocalPath` to `KineticReelPublishView` -> `PublishedClip(localVideoPath: widget.customMediaLocalPath, ...)`.
   - Dispose `_recordingTicker` and `_stage2VideoController` cleanly in `dispose()`.
7. Declutter Top Chrome (`#L453-L554`):
   - Keep **only** 3 items in the top `Row`:
     1. `IconButton(key: const Key('reel_studio_close_btn'), ...)`
     2. `Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 168, maxWidth: 240), child: GestureDetector(key: const Key('reel_studio_audio_pill'), ...))))`
     3. `IconButton(key: const Key('reel_studio_rail_side_btn'), ...)`
   - Relocate `Key('reel_studio_flash_btn')`, `Key('reel_studio_speed_btn')`, and `Key('reel_studio_timer_btn')` into the vertical tool rail (`#L562-L643`) so every existing key & tap behavior works while the top Audio pill displays full track titles without crushing to `[🎵 U...]`.

---

## 2. Pass 1 — `M78.2`: Ephemeral Reactions, `MiniPlayerHost` Discipline, `@aistudio` Rescue & Sanitizer Hardening (`VA-03`, `VA-05`, `VA-06`, `VA-09`)

### 2.1 `KineticReelsModal` Ephemeral Love Counter, Overlay Ref-Count & Video Backing (`apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`)
1. **Overlay Suppression (`VA-05`):** Mirror `OwnerProfileView` (`owner_profile_view.dart#L68-L90`) and `KineticReelStudioView`:
   ```dart
   StateController<int>? _pushedOverlayCounter;
   bool _didIncrementOverlay = false;
   ```
   Increment in `initState`'s `addPostFrameCallback` and safely decrement via microtask in `dispose()` checking `counter.mounted && counter.state > 0`.
2. **Kill `Loved 39x!` SnackBar Bomb (`VA-03`):**
   - Delete `messenger.showSnackBar(...)` at `#L935-L943`.
   - Add ephemeral state on `_RightActionRailState`:
     ```dart
     int _ephemeralLoveCount = 0;
     bool _showLovePill = false;
     Timer? _lovePillTimer;
     ```
   - Inside `_recordLove`:
     ```dart
     setState(() {
       _ephemeralLoveCount = count;
       _showLovePill = true;
     });
     _lovePillTimer?.cancel();
     _lovePillTimer = Timer(const Duration(milliseconds: 800), () {
       if (mounted) setState(() => _showLovePill = false);
     });
     ```
   - Render `AnimatedOpacity` + `VhunambiGlassSurface(key: const Key('reel_ephemeral_love_pill'), variant: VhunambiGlassVariant.pill, enableLiveBlur: false, ...)` displaying `PhosphorIcon(AppIcons.heart, size: 13, color: AppColors.brandPrimary)` + `Text('Loved ${_ephemeralLoveCount}x')` right above the Heart button. Cancel `_lovePillTimer` in `dispose()`.
3. **Never Render Blank Black Reel Canvas (`VA-09`) & Local File Playback:**
   - Update `_ReelVideoBackingLayer` (`#L1534-L1629`) to accept optional `String? localVideoPath` and `Widget fallbackArtwork`.
   - Initialize `VideoPlayerController.file(File(localVideoPath))` when `localVideoPath != null && File(localVideoPath).existsSync()`, else `VideoPlayerController.networkUrl(uri)` only when `uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')`.
   - When `!_initialized || _controller == null`, return `widget.fallbackArtwork` (`VhunambiTrackArtwork(coverUrl: clip.coverUrl, genre: clip.genre, trackId: clip.trackId)`) — **never** `ColoredBox(color: Colors.black)`!

### 2.2 `RootShell._switchTab` Auto-Dock Reset (`apps/vhunambi_client/lib/main.dart`)
In `_switchTab` (`#L176-L182`):
```dart
    final playerController = ref.read(miniPlayerControllerProvider);
    if (playerController.mode == PlayerMode.manual) {
      ref
          .read(miniPlayerControllerProvider.notifier)
          .resetToDock(MediaQuery.maybeSizeOf(context));
    } else if (playerController.form == PlayerForm.pill) {
      ref.read(miniPlayerControllerProvider.notifier).setForm(PlayerForm.bar);
    }
```

### 2.3 Authenticated Creator Stamping & Legacy `@aistudio` Rescue (`VA-06`)
1. **`generation_pipeline_providers.dart#L431-L456`:** Resolve authenticated creator from `authSessionProvider` + `ownerProfileProvider`:
   ```dart
   final session = _ref.read(authSessionProvider);
   final ownerProfile = _ref.read(ownerProfileProvider);
   final resolvedCreatorId = ownerProfile.id.isNotEmpty && ownerProfile.id != 'me'
       ? canonicalizeCreatorId(ownerProfile.id)
       : canonicalizeCreatorId(session.canonicalCreatorId);
   final resolvedName = ownerProfile.displayName.trim().isNotEmpty
       ? ownerProfile.displayName.trim()
       : (session.displayName.trim().isNotEmpty ? session.displayName.trim() : 'Cern');
   final rawHandle = ownerProfile.handle.trim().isNotEmpty
       ? ownerProfile.handle.trim()
       : (session.rawUsername.trim().isNotEmpty
             ? '@${session.rawUsername.trim()}'
             : handleFromCreatorId(resolvedCreatorId));
   final resolvedHandle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';
   ```
   Stamp `creatorId: resolvedCreatorId`, `creatorHandle: resolvedHandle`, and `creatorName: resolvedName` on `LibraryTrack` (and update `TrackEntity.toTrack({String? creatorName, String? creatorHandle})` default fallback cleanly).
2. **`viewer_role.dart#L13-L20` & `#L50-L53`:** Expand `_localSeedOwnerAliases` with `'ai_studio'`, `'aistudio'`, `'creator_ai_studio'`, `'creator_aistudio'`, and check **both** `rawOwnerId` and `rawOwnerHandle` against `_localSeedOwnerAliases` so legacy local library songs stamped `'AI Studio'` / `@aistudio` immediately resolve to `ViewerRole.owner`.
3. **`track_providers.dart#L405-L420` & `owner_profile_view.dart#L241-L262`:** When a `LibraryTrack` in the local vault has legacy `creatorName == 'AI Studio'` (or blank `creatorId` with `'AI Studio'`), normalize its displayed `creatorId`, `creatorName`, and `creatorHandle` to the active signed-in creator (`currentCreatorIdProvider` / `ownerProfileProvider`) so `TrackDetailView` displays the user's real handle (never `@aistudio`) and `OwnerProfileView._resolveOwnerSongs` includes it cleanly.

### 2.4 `LyricKaraokeSanitizer` & `LyricsTeleprompter` Hardening (`VA-06`, `VA-09`)
1. **`lyric_karaoke_sanitizer.dart`:**
   - Add unclosed/arbitrary parenthetical cue sanitizers:
     ```dart
     static final RegExp _anyBalancedParenCue = RegExp(r'\([^)]*\)');
     static final RegExp _unclosedParenLineCue = RegExp(r'\([^)\n]*$');
     static final RegExp _danglingCloseParen = RegExp(r'^[^(\n]*\)');
     static final RegExp _nonSungBookendHeader = RegExp(
       r'^\[\s*(?:intro|outro|instrumental|break|breakdown|interlude|drop(?:\s*\d+)?|final\s*drop)\s*\]$',
       caseSensitive: false,
     );
     ```
   - In `cleanLyricTextForKaraoke(String rawLyrics)`: strip `_anyBalancedParenCue`, `_unclosedParenLineCue`, and strip stray `(` / `)` in token cleanup (`RegExp(r'^[\[\]()+*#]+|[\[\]()+*#]+$')`).
   - Add `cleanLyricsForPlayback(String rawLyrics)`: runs `cleanLyricsForTeleprompter(rawLyrics)` and drops `_nonSungBookendHeader` lines (`[INTRO]`, `[OUTRO]`, `[Instrumental]`, `[Break]`) so `LyricsTeleprompter` never displays raw `[INTRO]` during playback while **preserving** `[Verse 1]` and `[Chorus]` (keeping `expanded_cockpit_modal_test.dart#L83` and `phase75_studio_connectome_closure_test.dart#L554-L555` 100% green!).
2. **`lyrics_teleprompter.dart#L73`:** Switch from `cleanLyricsForTeleprompter` to `cleanLyricsForPlayback`.

---

## 3. Pass 2 — `M78.3`: Explore $\leftrightarrow$ Library $\leftrightarrow$ Owner Profile Continuity (`VA-01`)

### 3.1 Recency-Pinned `trendingReelsProvider` (`apps/vhunambi_client/lib/features/social/presentation/providers/trending_reels_provider.dart`)
Pin active-creator / non-seed newly published clips (newest-first) ahead of virality-sorted catalog clips:
```dart
final trendingReelsProvider = Provider<List<PublishedClip>>((ref) {
  final feedState = ref.watch(socialFeedProvider);
  final activeGenre = ref.watch(trendingReelsGenreProvider);
  final activeCreatorId = canonicalizeCreatorId(
    ref.watch(currentCreatorIdProvider),
  );

  var list = List<PublishedClip>.from(feedState.clips);
  if (activeGenre != 'All') {
    final cleanGenre = activeGenre.replaceAll('#', '').trim().toLowerCase();
    list = list
        .where((c) => c.genre.trim().toLowerCase() == cleanGenre)
        .toList();
  }

  final now = DateTime.now();
  bool isPinnedFresh(PublishedClip c) {
    final isOwned = canonicalizeCreatorId(c.creatorId) == activeCreatorId ||
        c.creatorId == 'creator_me';
    final isFreshCustom = !c.id.startsWith('clip_seed_') &&
        now.difference(c.publishedAt).inHours.abs() <= 24;
    return isFreshCustom || (isOwned && !c.id.startsWith('clip_seed_'));
  }

  final pinned = list.where(isPinnedFresh).toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  final rest = list.where((c) => !isPinnedFresh(c)).toList()
    ..sort((a, b) {
      final scoreA = a.playCount + (a.likeCount * 3) + (a.commentCount * 5);
      final scoreB = b.playCount + (b.likeCount * 3) + (b.commentCount * 5);
      return scoreB.compareTo(scoreA);
    });

  return <PublishedClip>[...pinned, ...rest];
});
```

### 3.2 `LibraryCategory.reels` & `ReelsVaultView` (`EP-P78-CREATOR-REELS-HUB`)
1. **`library_models.dart#L8`:** `enum LibraryCategory { songs, reels, playlists, collections, beats, licensing, trash }`
2. **`social_feed_provider.dart`:** Add `void deleteClip(String clipId)` removing matching clip from `state.clips` and calling `_persistCustomClips()`.
3. **`library_providers.dart`:**
   - Add `ownerVaultReelsProvider`: watches `socialFeedProvider` and `currentCreatorIdProvider`, returning owner's published clips (`canonicalizeCreatorId(c.creatorId) == canonicalOwner || c.creatorId == 'creator_me'`), newest-first.
   - Update `libraryCategoryCountsProvider`: set `LibraryCategory.reels: ref.watch(ownerVaultReelsProvider).length`.
   - Update `_matchesCategory` (`#L501`): include `LibraryCategory.reels` returning `false` (rendered by dedicated `ReelsVaultView`).
4. **New `apps/vhunambi_client/lib/features/library/presentation/views/reels_vault_view.dart`:**
   - Renders `Key('library_reels_vault_view')`, header count + `+ Create Reel` button (`Key('library_reels_create_btn')` -> `KineticReelStudioView.show(context)`), responsive 2-column (mobile) / 4-column (desktop) 9:16 grid of `CreatorReelThumbnailCard` items with tap-to-open `KineticReelsModal`, quick Share (copy `clip.shareUrl`), and Delete (`socialFeedProvider.notifier.deleteClip(clip.id)`). Uses `LibraryEmptyState(category: LibraryCategory.reels)` when empty.
5. **`library_view.dart` & `library_empty_state.dart`:** Mount `ReelsVaultView` when `category == LibraryCategory.reels`, add search placeholder `'Search my reels...'`, and add `LibraryCategory.reels` copy in `_EmptyStateCopy.forCategory`.

### 3.3 `CreatorReelThumbnailCard` Artwork Parity & `OwnerProfileView` Deduplication
1. **`creator_reel_thumbnail_card.dart`:**
   - Replace `_CoverArt` completely with `VhunambiTrackArtwork(coverUrl: clip.coverUrl, genre: clip.genre, trackId: clip.trackId, borderRadius: BorderRadius.zero, showSubtleBorder: false)`.
   - Replace `Icons.play_arrow_rounded` (`#L60`) and `Icon(...)` (`#L145`) with `PhosphorIcon(PhosphorIconsFill.play, size: 11, color: Colors.white)` — **zero** stock `Icons.*`!
   - Replace static dark `AppColors.surfaceCanvas`/`AppColors.textPrimary` on overlay badges with `Colors.black.withValues(alpha: 0.58)` and `Colors.white` (always over dark bottom gradient scrim).
2. **`owner_profile_view.dart#L719-L725`:** Remove `const _OwnerReelsShelf()` from the `OwnerStudioTab.songs` branch (`#L721-L722`) so `Songs` renders `Your Songs` + `_OwnerKineticPostsShelf()`, while `Reels` exclusively renders `_OwnerReelsShelf()`.

---

## 4. Pass 2 — `M78.4`: Unified `VhunambiGlassTabBar` (`EP-P78-GLASS-TAB-BAR`), Explore Visuals & Polish Seams (`VA-04`, `VA-09`)

### 4.1 New `apps/vhunambi_client/lib/core/widgets/vhunambi_glass_tab_bar.dart`
```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';

@immutable
class VhunambiGlassTabItem {
  final Key? key;
  final String label;
  final IconData? icon;
  final int? badgeCount;

  const VhunambiGlassTabItem({
    this.key,
    required this.label,
    this.icon,
    this.badgeCount,
  });
}

class VhunambiGlassTabBar extends StatelessWidget {
  final List<VhunambiGlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  const VhunambiGlassTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    final track = VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      enableLiveBlur: false,
      padding: const EdgeInsets.all(4),
      borderColorOverride: borderSubtle,
      child: Row(
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < items.length; i++)
            _buildTabPill(
              context: context,
              item: items[i],
              index: i,
              isSelected: i == selectedIndex,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderSubtle: borderSubtle,
            ),
        ],
      ),
    );

    if (!scrollable) {
      return Padding(padding: padding, child: track);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: track,
    );
  }

  Widget _buildTabPill({
    required BuildContext context,
    required VhunambiGlassTabItem item,
    required int index,
    required bool isSelected,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
  }) {
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.92);
    final activeRim = isSelected
        ? AppColors.brandPrimary.withValues(alpha: isDark ? 0.55 : 0.45)
        : Colors.transparent;
    final fgColor = isSelected ? textPrimary : textSecondary;
    final iconColor = isSelected ? AppColors.brandPrimary : textSecondary;

    final pill = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        key: item.key,
        borderRadius: AppRadius.pillBorder,
        onTap: () {
          HapticsService().selectionClick();
          onSelected(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: activeRim, width: isSelected ? 1.1 : 0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                PhosphorIcon(item.icon!, size: 15, color: iconColor),
                const SizedBox(width: 6),
              ],
              Text(
                item.label,
                maxLines: 1,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: fgColor,
                ),
              ),
              if (item.badgeCount != null && item.badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandPrimary.withValues(alpha: 0.16)
                        : AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: AppTypography.badge.copyWith(
                      color: isSelected ? AppColors.brandPrimary : textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return scrollable ? pill : Expanded(child: pill);
  }
}
```
Include `VhunambiGlassTabBarHeaderDelegate extends SliverPersistentHeaderDelegate` (`minExtent: 64`, `maxExtent: 64`) syncing cleanly with `DefaultTabController.of(context)` so `ArtistProfileView` drops its Material 2 underline `TabBar` seamlessly while preserving `TabBarView` swipe gestures and `Key('visitor_tab_*')` test keys.

### 4.2 Explore `CatalogFilterBar`, `TrackListTile` & Polish Seams (`VA-04`, `VA-09`)
1. **`catalog_filter_bar.dart`:** Replace vertical `Wrap` (`#L137-L155`) with a single-row horizontal `SingleChildScrollView(key: const Key('catalog_mood_rail'), scrollDirection: Axis.horizontal)` displaying `_LanguageDropdown` + canonical `VhunambiMood.values` pills (`PhosphorIcon(mood.icon, size: 14, color: mood.accentColor)` + `mood.label`, matching `exploreMoodFilterProvider` via `VhunambiMood.normalize` / label matching). Migrate all static `AppColors.surfaceSecondary` / `surfaceElevated` / `borderSubtle` / `textSecondary` in `_FilterPill` & `_LanguageDropdown` to `*Of(context)`.
2. **`track_list_tile.dart#L40-L65`:** Replace `Container(gradient: AppGradients.forGenre(track.genre), child: PhosphorIcon(...))` with `VhunambiTrackArtwork(key: Key('track_list_tile_artwork_${track.id}'), coverUrl: track.coverUrl, genre: track.genre, trackId: track.id, width: 48, height: 48, borderRadius: BorderRadius.circular(AppRadius.input))` and migrate tile surface/border/text colors to `*Of(context)`.
3. **`kinetic_post_focus_view.dart#L292-L305`:** Wrap `Key('kpost_focus_tip_btn')` into a frosted `VhunambiGlassSurface` pill (`minHeight: 44`) showing `PhosphorIcon(AppIcons.coin, color: AppColors.coinGold, size: 16)` + `'Tip'`.
4. **`social_music_post.dart#L454-L513`:** Normalize legacy `'current_user'` / `'@current_user'` in `creatorId`, `creatorHandle`, `repostedFromCreatorHandle`, and `'You'` display name inside `SocialMusicPost.fromJson`.
5. **`create_kinetic_post_sheet.dart#L168-L197`:** Resolve offline/fallback Vision AI artwork through distinct deterministic `asset:${AppAssets.resolveGenreCoverAsset(...)}` variants seeded by prompt hash + `_attachedImages.length` instead of a single dead `cdn.vhunambi.com` URL.
