import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Stage 3 full-screen Publish View for `KineticReelStudioView` (`REQ-P74-STU-05`).
class KineticReelPublishView extends ConsumerStatefulWidget {
  final ReelStudioAudioSelection audio;
  final String mediaKind;
  final Uint8List? customMediaBytes;
  final String? customMediaFilename;
  final String? customMediaMime;
  final String? customMediaLocalPath;
  final int audioStartMs;
  final int audioEndMs;
  final String effectPreset;
  final double effectIntensity;
  final LyricTypographyPreset typographyPreset;
  final double speedRate;
  final String? stickerId;
  final VoidCallback onBackToEditor;
  final VoidCallback onPublishComplete;

  const KineticReelPublishView({
    super.key,
    required this.audio,
    required this.mediaKind,
    this.customMediaBytes,
    this.customMediaFilename,
    this.customMediaMime,
    this.customMediaLocalPath,
    required this.audioStartMs,
    required this.audioEndMs,
    required this.effectPreset,
    required this.effectIntensity,
    required this.typographyPreset,
    required this.speedRate,
    this.stickerId,
    required this.onBackToEditor,
    required this.onPublishComplete,
  });

  @override
  ConsumerState<KineticReelPublishView> createState() =>
      _KineticReelPublishViewState();
}

class _KineticReelPublishViewState
    extends ConsumerState<KineticReelPublishView> {
  static const List<String> _suggestedTags = <String>[
    '#Amapiano',
    '#LimpopoGroove',
    '#VhunambiStudio',
    '#BantuSoul',
    '#60FPS',
  ];

  final TextEditingController _captionController = TextEditingController();
  final Set<String> _selectedTags = <String>{'#Amapiano', '#VhunambiStudio'};
  ClipVisibility _visibility = ClipVisibility.public;
  bool _alsoShareToExplore = false; // MUST default to false (REQ-P74-STU-05)
  bool _isPublishing = false;
  double _uploadProgress = 0.0;
  String? _publishError;
  String? _stagedCustomAssetId;
  String? _stagedAudioAssetId;
  VideoPlayerController? _posterVideoController;
  bool _posterVideoReady = false;

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initPosterVideoFrame());
  }

  Future<void> _initPosterVideoFrame() async {
    final isVideo =
        widget.mediaKind == 'camera_video' ||
        widget.mediaKind == 'gallery_video';
    final path = widget.customMediaLocalPath;
    if (_isTestEnv || kIsWeb || !isVideo || path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      await ctrl.pause();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _posterVideoController = ctrl;
        _posterVideoReady = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _posterVideoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _submitPublish() async {
    if (_isPublishing) return;
    setState(() {
      _isPublishing = true;
      _publishError = null;
      _uploadProgress = 0.08;
    });

    try {
      final repo = ref.read(socialRepositoryProvider);
      final queueNotifier = ref.read(mediaUploadQueueProvider.notifier);
      final session = ref.read(authSessionProvider);

      String? uploadedVideoUrl;
      String resolvedCoverUrl = widget.audio.coverUrl;
      String resolvedAudioUrl = widget.audio.audioUrl;

      if (widget.customMediaBytes != null &&
          widget.customMediaBytes!.isNotEmpty &&
          widget.customMediaMime != null) {
        final isImage = widget.customMediaMime!.startsWith('image/');
        UploadedMediaAsset uploadResult;
        if (_stagedCustomAssetId != null) {
          final retried = await queueNotifier.retryUpload(
            _stagedCustomAssetId!,
          );
          if (retried != null) {
            uploadResult = retried;
          } else {
            uploadResult = await queueNotifier.stageAndEnqueue(
              bytes: widget.customMediaBytes!,
              filename: widget.customMediaFilename ?? 'reel_media.mp4',
              mimeType: widget.customMediaMime!,
              kind: isImage ? MediaAssetKind.image : MediaAssetKind.video,
              title: widget.audio.title,
              sourceSurface: 'reel_publish',
              awaitUpload: true,
            );
          }
        } else {
          uploadResult = await queueNotifier.stageAndEnqueue(
            bytes: widget.customMediaBytes!,
            filename: widget.customMediaFilename ?? 'reel_media.mp4',
            mimeType: widget.customMediaMime!,
            kind: isImage ? MediaAssetKind.image : MediaAssetKind.video,
            title: widget.audio.title,
            sourceSurface: 'reel_publish',
            awaitUpload: true,
          );
          _stagedCustomAssetId = uploadResult.id;
        }
        if (uploadResult.status == MediaUploadStatus.failed ||
            uploadResult.remoteUrl == null ||
            uploadResult.remoteUrl!.isEmpty) {
          throw StateError(
            uploadResult.errorMessage ??
                'Connection dropped while uploading media. Saved locally in My Uploads — tap Retry Publish.',
          );
        }
        if (isImage) {
          resolvedCoverUrl = uploadResult.remoteUrl!;
        } else {
          uploadedVideoUrl = uploadResult.remoteUrl!;
        }
        if (mounted) setState(() => _uploadProgress = 0.72);
      }

      if (widget.audio.importedAudioBytes != null &&
          widget.audio.importedAudioBytes!.isNotEmpty &&
          widget.audio.importedAudioMime != null) {
        UploadedMediaAsset audioResult;
        if (_stagedAudioAssetId != null) {
          audioResult =
              await queueNotifier.retryUpload(_stagedAudioAssetId!) ??
              await queueNotifier.stageAndEnqueue(
                bytes: widget.audio.importedAudioBytes!,
                filename: '${widget.audio.trackId}.mp3',
                mimeType: widget.audio.importedAudioMime!,
                kind: MediaAssetKind.audio,
                title: widget.audio.title,
                sourceSurface: 'reel_publish',
                awaitUpload: true,
              );
        } else {
          audioResult = await queueNotifier.stageAndEnqueue(
            bytes: widget.audio.importedAudioBytes!,
            filename: '${widget.audio.trackId}.mp3',
            mimeType: widget.audio.importedAudioMime!,
            kind: MediaAssetKind.audio,
            title: widget.audio.title,
            sourceSurface: 'reel_publish',
            awaitUpload: true,
          );
          _stagedAudioAssetId = audioResult.id;
        }
        if (audioResult.status == MediaUploadStatus.failed ||
            audioResult.remoteUrl == null ||
            audioResult.remoteUrl!.isEmpty) {
          throw StateError(
            audioResult.errorMessage ??
                'Audio upload failed. Saved in My Uploads — tap Retry Publish.',
          );
        }
        resolvedAudioUrl = audioResult.remoteUrl!;
        if (mounted) setState(() => _uploadProgress = 0.88);
      }

      final caption = _captionController.text.trim();
      final payload = <String, dynamic>{
        'trackId': widget.audio.trackId,
        'title': widget.audio.title,
        'caption': caption,
        'tags': _selectedTags.toList(growable: false),
        'visibility': _visibility.name,
        'genre': widget.audio.genre,
        'audioUrl': resolvedAudioUrl,
        'coverUrl': resolvedCoverUrl,
        'videoUrl': ?uploadedVideoUrl,
        'mediaKind': widget.mediaKind,
        'audioStartMs': widget.audioStartMs,
        'audioEndMs': widget.audioEndMs,
        'effectPreset': widget.effectPreset,
        'effectIntensity': widget.effectIntensity,
        'typographyPreset': widget.typographyPreset.name,
        'speedRate': widget.speedRate,
        'stickerId': ?widget.stickerId,
        'dna': widget.audio.dna.toJson(),
      };

      final published = await repo.publishClip(payload);
      final username = session.rawUsername.isNotEmpty
          ? session.rawUsername
          : 'creator';
      final newClip = PublishedClip(
        id: published.clipId,
        trackId: widget.audio.trackId,
        creatorId: session.canonicalCreatorId,
        creatorUsername: username,
        creatorDisplayName: session.displayName,
        creatorAvatarUrl: null,
        isCreatorVerified: true,
        title: widget.audio.title,
        caption: caption,
        tags: _selectedTags.toList(growable: false),
        genre: widget.audio.genre,
        audioUrl: resolvedAudioUrl,
        coverUrl: resolvedCoverUrl,
        videoUrl: uploadedVideoUrl,
        localVideoPath: widget.customMediaLocalPath,
        mediaKind: widget.mediaKind,
        audioStartMs: widget.audioStartMs,
        audioEndMs: widget.audioEndMs,
        effectPreset: widget.effectPreset,
        effectIntensity: widget.effectIntensity,
        typographyPreset: widget.typographyPreset.name,
        speedRate: widget.speedRate,
        stickerId: widget.stickerId,
        dna: widget.audio.dna,
        playCount: 0,
        likeCount: 0,
        commentCount: 0,
        publishedAt: published.publishedAt,
      );

      ref.read(socialFeedProvider.notifier).prependClip(newClip);

      // Opt-in ONLY — NEVER auto-inject promotional Explore feed spam (REQ-P74-STU-05)
      if (_alsoShareToExplore) {
        ref.read(socialFeedPostsProvider.notifier).addPost(
              SocialMusicPost(
                id: 'post_reel_${published.clipId}',
                creatorId: newClip.creatorId,
                creatorName: newClip.creatorDisplayName,
                creatorHandle: '@${newClip.creatorUsername}',
                creatorAvatarUrl: newClip.creatorAvatarUrl,
                isCreatorVerified: newClip.isCreatorVerified,
                publishedAt: published.publishedAt,
                location: 'South Africa',
                caption: caption.isNotEmpty ? caption : newClip.title,
                track: Track(
                  id: newClip.trackId,
                  title: newClip.title,
                  creatorName: newClip.creatorDisplayName,
                  creatorHandle: '@${newClip.creatorUsername}',
                  genre: newClip.genre,
                  mood: widget.audio.mood,
                  duration: Duration(seconds: newClip.dna.musical.durationSec),
                  audioUrl: newClip.audioUrl,
                  coverUrl: newClip.coverUrl,
                  isNew: true,
                ),
                likeCount: 0,
                commentCount: 0,
                remixCount: 0,
                tipCountCoins: 0,
                isFollowingCreator: false,
              ),
            );
      }

      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);
      final messenger = ScaffoldMessenger.maybeOf(context);
      widget.onPublishComplete();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Kinetic Reel published'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 2500),
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() {
          _publishError = e.toString().replaceFirst('Bad state: ', '');
          _uploadProgress = 0.0;
        });
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildPosterArtwork() {
    final isVideo =
        widget.mediaKind == 'camera_video' ||
        widget.mediaKind == 'gallery_video';
    if (isVideo &&
        (widget.customMediaLocalPath != null ||
            widget.customMediaBytes != null)) {
      return ClipRRect(
        key: const Key('publish_video_poster_preview'),
        borderRadius: AppRadius.cardBorder,
        child: _posterVideoReady && _posterVideoController != null
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _posterVideoController!.value.size.width > 0
                      ? _posterVideoController!.value.size.width
                      : 96,
                  height: _posterVideoController!.value.size.height > 0
                      ? _posterVideoController!.value.size.height
                      : 156,
                  child: VideoPlayer(_posterVideoController!),
                ),
              )
            : Container(
                color: AppColors.darkSurfaceSecondary,
                alignment: Alignment.center,
                child: const PhosphorIcon(
                  AppIcons.reels,
                  color: AppColors.brandPrimary,
                  size: 30,
                ),
              ),
      );
    }

    if (widget.mediaKind == 'gallery_photo' &&
        (widget.customMediaLocalPath != null ||
            widget.customMediaBytes != null)) {
      return ClipRRect(
        key: const Key('publish_photo_poster_preview'),
        borderRadius: AppRadius.cardBorder,
        child: !kIsWeb &&
                widget.customMediaLocalPath != null &&
                File(widget.customMediaLocalPath!).existsSync()
            ? Image.file(
                File(widget.customMediaLocalPath!),
                fit: BoxFit.cover,
              )
            : (widget.customMediaBytes != null &&
                  widget.customMediaBytes!.isNotEmpty)
            ? Image.memory(
                widget.customMediaBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => VhunambiTrackArtwork(
                  coverUrl: widget.audio.coverUrl,
                  genre: widget.audio.genre,
                  trackId: widget.audio.trackId,
                  borderRadius: AppRadius.cardBorder,
                ),
              )
            : VhunambiTrackArtwork(
                coverUrl: widget.audio.coverUrl,
                genre: widget.audio.genre,
                trackId: widget.audio.trackId,
                borderRadius: AppRadius.cardBorder,
              ),
      );
    }

    return VhunambiTrackArtwork(
      coverUrl: widget.audio.coverUrl,
      genre: widget.audio.genre,
      trackId: widget.audio.trackId,
      borderRadius: AppRadius.cardBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueItems = ref.watch(mediaUploadQueueProvider);
    final trackedCustom = _stagedCustomAssetId != null
        ? queueItems.where((a) => a.id == _stagedCustomAssetId).firstOrNull
        : null;
    final effectiveProgress =
        (trackedCustom != null &&
            trackedCustom.status == MediaUploadStatus.uploading &&
            trackedCustom.progress > _uploadProgress)
        ? trackedCustom.progress
        : _uploadProgress;
    final durationSec =
        ((widget.audioEndMs - widget.audioStartMs) / 1000).round();
    return Scaffold(
      key: const Key('reel_studio_stage_publish'),
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: widget.onBackToEditor,
          icon: const PhosphorIcon(AppIcons.arrowLeft),
        ),
        title: const Text('Publish Kinetic Reel'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 96,
                height: 156,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildPosterArtwork(),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${durationSec}s',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('reel_publish_caption_input'),
                  controller: _captionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption for your Kinetic Reel...',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTags
                .map((tag) {
                  final active = _selectedTags.contains(tag);
                  return FilterChip(
                    selected: active,
                    label: Text(tag),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              ChoiceChip(
                key: const Key('reel_publish_visibility_public'),
                selected: _visibility == ClipVisibility.public,
                label: const Text('Public'),
                onSelected: (_) =>
                    setState(() => _visibility = ClipVisibility.public),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('reel_publish_visibility_followers'),
                selected: _visibility == ClipVisibility.followers,
                label: const Text('Followers Only'),
                onSelected: (_) =>
                    setState(() => _visibility = ClipVisibility.followers),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('reel_publish_share_to_explore_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Also share to Explore Feed'),
            subtitle: const Text(
              'Off by default — publish exclusively to Reels unless toggled',
            ),
            value: _alsoShareToExplore,
            onChanged: (v) => setState(() => _alsoShareToExplore = v),
          ),
          const SizedBox(height: 16),
          if (_isPublishing) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Uploading media to Vhunambi Cloud...',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(effectiveProgress * 100).round()}%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                key: const Key('reel_publish_progress_bar'),
                value: effectiveProgress > 0 ? effectiveProgress : null,
                minHeight: 6,
                color: AppColors.brandPrimary,
                backgroundColor: AppColors.surfaceSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_publishError != null) ...<Widget>[
            VhunambiGlassSurface(
              key: const Key('reel_publish_error_card'),
              tintAccent: AppColors.error,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _publishError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('reel_publish_retry_btn'),
                    onPressed: _isPublishing ? null : _submitPublish,
                    icon: const PhosphorIcon(
                      AppIcons.remix,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    label: const Text('Retry Publish'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('reel_publish_submit_btn'),
              onPressed: _isPublishing ? null : _submitPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
              ),
              icon: const PhosphorIcon(AppIcons.upload, size: 18),
              label: Text(
                _isPublishing
                    ? 'Publishing ${(effectiveProgress * 100).round()}%...'
                    : 'Publish Reel',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
