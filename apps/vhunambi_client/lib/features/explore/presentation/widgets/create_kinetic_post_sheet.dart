import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/media/vhunambi_media_upload_service.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/resilience/safe_audio_orchestrator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_glass_tab_bar.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../media/domain/models/uploaded_media_asset.dart';
import '../../../media/domain/utils/media_mime_utils.dart';
import '../../../media/presentation/providers/media_upload_queue_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';

/// Glass Cockpit v2 authoring workstation for publishing Kinetic Posts
/// (`EP-P79-POST-COCKPIT-V2`, `REQ-P79-KPOST-01..02`).
class CreateKineticPostSheet extends ConsumerStatefulWidget {
  final int initialTab;

  const CreateKineticPostSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateKineticPostSheet(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<CreateKineticPostSheet> createState() =>
      _CreateKineticPostSheetState();
}

class _CreateKineticPostSheetState
    extends ConsumerState<CreateKineticPostSheet> {
  final _captionController = TextEditingController();
  final _visionPromptController = TextEditingController();

  // Visual Attachments State
  final List<KineticPostImageAttachment> _attachedImages = [];
  KineticPostAspectRatio _selectedAspectRatio =
      KineticPostAspectRatio.square1x1;
  bool _isGeneratingVision = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingAudio = false;
  String? _visionUnavailableNotice;

  // Audio Attachment State (0: My Uploads, 1: My Vault, 2: Trending)
  int _audioSourceTabIndex = 0;
  KineticAudioSourceType _selectedAudioCategory =
      KineticAudioSourceType.librarySong;
  Track? _selectedTrack;
  double _clipStartSec = 0.0;
  double _clipDurationSec = 30.0;
  AudioPlayer? _auditionPlayer;
  bool _isAuditioning = false;

  StateController<int>? _modalSheetCounter;
  bool _didIncrementModalCount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(modalSheetOpenCountProvider.notifier);
      _modalSheetCounter = counter;
      _didIncrementModalCount = true;
      counter.state++;
    });
    if (widget.initialTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAndUploadPhoto();
      });
    } else if (widget.initialTab == 2) {
      _visionPromptController.text = 'Polokwane Sunset Studio Session';
    }
  }

  @override
  void dispose() {
    _auditionPlayer?.dispose();
    SafeAudioOrchestrator.instance.unregisterSlot(
      AudioEngineSlot.studioPreview,
    );
    final counter = _modalSheetCounter;
    if (_didIncrementModalCount && counter != null) {
      _didIncrementModalCount = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    _captionController.dispose();
    _visionPromptController.dispose();
    super.dispose();
  }

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _pauseAudition() async {
    try {
      await _auditionPlayer?.pause();
    } catch (_) {}
    if (mounted) setState(() => _isAuditioning = false);
  }

  Future<void> _toggleAudioAudition() async {
    final track = _selectedTrack;
    if (track == null) return;
    HapticFeedback.selectionClick();
    if (_isAuditioning) {
      await _pauseAudition();
      return;
    }
    if (_detectTestMode()) {
      setState(() => _isAuditioning = true);
      return;
    }
    final rawSrc = (track.audioUrl ?? '').trim();
    if (rawSrc.isEmpty) {
      setState(() => _isAuditioning = true);
      return;
    }
    try {
      ref.read(playerStateProvider.notifier).pause();
    } catch (_) {}
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.studioPreview,
      onPreemptPause: _pauseAudition,
    );
    final player = _auditionPlayer ??= AudioPlayer();
    try {
      if (!kIsWeb &&
          !rawSrc.startsWith('http://') &&
          !rawSrc.startsWith('https://') &&
          !rawSrc.startsWith('/r2/') &&
          File(rawSrc).existsSync()) {
        await player.setFilePath(rawSrc);
      } else {
        await player.setUrl(AppConstants.normalizeCloudMediaUrl(rawSrc));
      }
      await player.seek(Duration(seconds: _clipStartSec.round()));
      unawaited(player.play());
      if (mounted) setState(() => _isAuditioning = true);
    } catch (_) {
      if (mounted) setState(() => _isAuditioning = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto || _attachedImages.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() => _isUploadingPhoto = true);

    try {
      Uint8List bytes;
      String filename;
      String mimeType;

      if (_detectTestMode()) {
        bytes = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
        filename = 'kpost_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        mimeType = 'image/jpeg';
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 88,
        );
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        filename = picked.name.isNotEmpty
            ? picked.name
            : 'kpost_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        mimeType = VhunambiMediaUploadService.inferImageMimeType(filename);
      }

      if (!isAllowedKineticPostMedia(filename) &&
          !isAllowedKineticPostMedia(mimeType)) {
        if (mounted) _showVideoFormatRejectionDialog();
        return;
      }

      final staged = await ref
          .read(mediaUploadQueueProvider.notifier)
          .stageAndEnqueue(
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
            kind: MediaAssetKind.image,
            sourceSurface: 'kinetic_post',
            awaitUpload: true,
          );
      if (!mounted || _attachedImages.length >= 4) return;
      if (staged.status != MediaUploadStatus.synced ||
          staged.remoteUrl == null ||
          staged.remoteUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              staged.errorMessage ??
                  'Photo upload failed. Saved in My Uploads — tap Retry.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final resolvedUrl = AppConstants.normalizeCloudMediaUrl(
        staged.remoteUrl!,
      );

      setState(() {
        _attachedImages.add(
          KineticPostImageAttachment(
            imageUrl: resolvedUrl,
            localFilePath: staged.localFilePath,
            uploadAssetId: staged.id,
            aspectRatio: _selectedAspectRatio,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showPickFromUploadsSheet() {
    final imageUploads = ref
        .read(mediaUploadQueueProvider)
        .where((u) => u.kind == MediaAssetKind.image)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final textPrimary = AppColors.textPrimaryOf(ctx);
        final textSecondary = AppColors.textSecondaryOf(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            key: const Key('kpost_from_uploads_sheet'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Select from My Uploads',
                  style: AppTypography.titleMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (imageUploads.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No uploaded images yet. Add a photo to save it here for reuse.',
                        style: AppTypography.bodySmall.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUploads.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, idx) {
                        final item = imageUploads[idx];
                        return GestureDetector(
                          key: Key('kpost_reuse_upload_${item.id}'),
                          onTap: () {
                            if (_attachedImages.length < 4) {
                              setState(() {
                                _attachedImages.add(
                                  KineticPostImageAttachment(
                                    imageUrl:
                                        item.remoteUrl ??
                                        item.localFilePath ??
                                        '',
                                    localFilePath: item.localFilePath,
                                    uploadAssetId: item.id,
                                    aspectRatio: _selectedAspectRatio,
                                  ),
                                );
                              });
                            }
                            Navigator.of(ctx).pop();
                          },
                          child: Column(
                            children: <Widget>[
                              VhunambiTrackArtwork(
                                coverUrl: item.bestPlayableOrRenderableSource,
                                genre: _selectedTrack?.genre ?? 'Amapiano',
                                trackId: item.id,
                                width: 108,
                                height: 108,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 108,
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAudio() async {
    if (_isUploadingAudio) return;
    HapticFeedback.lightImpact();
    setState(() => _isUploadingAudio = true);

    try {
      Uint8List bytes;
      String filename;
      String mimeType;

      if (_detectTestMode()) {
        bytes = Uint8List.fromList(<int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00]);
        filename = 'zania_track_${DateTime.now().millisecondsSinceEpoch}.mp3';
        mimeType = 'audio/mpeg';
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const <String>[
            'mp3',
            'wav',
            'm4a',
            'aac',
            'ogg',
            'flac',
          ],
          withData: true,
        );
        if (picked == null || picked.files.isEmpty) return;
        final file = picked.files.first;
        var resolvedBytes = file.bytes;
        if ((resolvedBytes == null || resolvedBytes.isEmpty) &&
            !kIsWeb &&
            file.path != null &&
            file.path!.isNotEmpty) {
          final f = File(file.path!);
          if (await f.exists()) {
            resolvedBytes = await f.readAsBytes();
          }
        }
        if (resolvedBytes == null || resolvedBytes.isEmpty) return;
        bytes = resolvedBytes;
        filename = file.name.isNotEmpty
            ? file.name
            : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        mimeType = inferMimeTypeFromMedia(
          filename: filename,
          fallbackKind: MediaAssetKind.audio,
        );
      }

      final synced = await ref
          .read(mediaUploadQueueProvider.notifier)
          .stageAndEnqueue(
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
            kind: MediaAssetKind.audio,
            title: filename.replaceAll(RegExp(r'\.[^.]+$'), ''),
            sourceSurface: 'kinetic_post',
            awaitUpload: true,
          );
      if (!mounted) return;
      if (synced.status != MediaUploadStatus.synced ||
          synced.remoteUrl == null ||
          synced.remoteUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced.errorMessage ??
                  'Audio upload failed. Saved in My Uploads — tap Retry.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final owner = ref.read(ownerProfileProvider);
      final creatorName = synced.artist?.trim().isNotEmpty == true
          ? synced.artist!.trim()
          : (owner.displayName.isNotEmpty ? owner.displayName : 'Creator');
      final creatorHandle = owner.handle.isNotEmpty ? owner.handle : '@creator';

      setState(() {
        _audioSourceTabIndex = 0;
        _selectedAudioCategory = KineticAudioSourceType.librarySong;
        _selectedTrack = Track(
          id: synced.id,
          title: synced.title,
          creatorName: creatorName,
          creatorHandle: creatorHandle,
          genre: synced.genre ?? 'Amapiano',
          duration: Duration(milliseconds: synced.durationMs ?? 180000),
          audioUrl: AppConstants.normalizeCloudMediaUrl(synced.remoteUrl!),
          coverUrl: synced.bestCoverSource != null
              ? AppConstants.normalizeCloudMediaUrl(synced.bestCoverSource!)
              : null,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAudio = false);
      }
    }
  }

  Future<void> _generateVisionAiArtwork() async {
    HapticFeedback.mediumImpact();
    final prompt = _visionPromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGeneratingVision = true;
      _visionUnavailableNotice = null;
    });

    if (_detectTestMode()) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() {
        _isGeneratingVision = false;
        _visionUnavailableNotice =
            'Vision AI unavailable offline. Upload a real photo from your gallery.';
      });
      return;
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      dio.interceptors.add(ref.read(authDioInterceptorProvider));
      final res = await dio.post<Map<String, dynamic>>(
        '${AppConstants.apiBaseUrl}/vision/generate',
        data: <String, dynamic>{
          'prompt': prompt,
          'genre': _selectedTrack?.genre ?? 'Amapiano',
          'language': _selectedTrack?.language ?? 've',
          'width': 768,
          'height': 1344,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final isMock = data['isMock'] == true;
      final remoteUrl = (data['outputImageUrl'] ?? '').toString().trim();
      if (isMock || remoteUrl.isEmpty || remoteUrl.startsWith('asset:')) {
        if (!mounted) return;
        setState(() {
          _isGeneratingVision = false;
          _visionUnavailableNotice =
              'Vision AI renderer is currently offline — please upload a real photo instead.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isGeneratingVision = false;
        _visionUnavailableNotice = null;
        _attachedImages.add(
          KineticPostImageAttachment(
            imageUrl: AppConstants.normalizeCloudMediaUrl(remoteUrl),
            isAiGeneratedVision: true,
            visionPrompt: prompt,
            aspectRatio: _selectedAspectRatio,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGeneratingVision = false;
        _visionUnavailableNotice =
            'Vision AI could not reach GPU renderer — upload a photo from your device.';
      });
    }
  }

  void _showVideoFormatRejectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedOf(ctx),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsRegular.videoCameraSlash,
              color: AppColors.brandPrimary,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Video Media Detected',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryOf(ctx),
              ),
            ),
          ],
        ),
        content: Text(
          'Kinetic Posts are strictly reserved for high-res static images and sonic audio cards.\n\nTo share immersive 9:16 video performances, publish a Kinetic Reel!',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryOf(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _publishKineticPost() {
    if (_isUploadingPhoto || _isUploadingAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for your media upload to finish syncing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _attachedImages.isEmpty && _selectedTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a caption, image, or sound to publish.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    unawaited(_pauseAudition());
    final now = DateTime.now();

    final owner = ref.read(ownerProfileProvider);
    final creatorName = owner.displayName.isNotEmpty
        ? owner.displayName
        : 'Cern';
    final creatorHandle = owner.handle.isNotEmpty ? owner.handle : '@cern';
    final creatorId = owner.id.isNotEmpty ? owner.id : 'creator_cern';

    final queueById = <String, UploadedMediaAsset>{
      for (final item in ref.read(mediaUploadQueueProvider)) item.id: item,
    };
    final finalizedImages = _attachedImages
        .map((att) {
          final tracked = att.uploadAssetId != null
              ? queueById[att.uploadAssetId!]
              : null;
          final effectiveUrl =
              (tracked?.remoteUrl != null && tracked!.remoteUrl!.isNotEmpty)
              ? AppConstants.normalizeCloudMediaUrl(tracked.remoteUrl!)
              : att.imageUrl;
          return KineticPostImageAttachment(
            imageUrl: effectiveUrl,
            localFilePath: att.localFilePath ?? tracked?.localFilePath,
            uploadAssetId: att.uploadAssetId,
            isAiGeneratedVision: att.isAiGeneratedVision,
            visionPrompt: att.visionPrompt,
            aspectRatio: _selectedAspectRatio,
          );
        })
        .toList(growable: false);

    final resolvedTrack = _selectedTrack;
    final carrierTrack =
        resolvedTrack ??
        Track(
          id: 'kpost_visual_${now.millisecondsSinceEpoch}',
          title: caption.isNotEmpty ? caption : 'Visual Post',
          creatorName: creatorName,
          creatorHandle: creatorHandle,
          genre: 'Visual',
          language: 'English',
          duration: Duration.zero,
          coverUrl: finalizedImages.isNotEmpty
              ? finalizedImages.first.imageUrl
              : null,
        );

    final post = SocialMusicPost(
      id: 'kpost_${now.millisecondsSinceEpoch}',
      creatorId: creatorId,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      creatorAvatarUrl: owner.avatarUrl,
      publishedAt: now,
      location: 'South Africa',
      caption: caption,
      track: carrierTrack,
      imageAttachment: finalizedImages.isNotEmpty
          ? finalizedImages.first
          : null,
      imageAttachments: finalizedImages,
      audioAttachment: resolvedTrack != null
          ? KineticPostAudioAttachment(
              sourceType: _selectedAudioCategory,
              clipStartSec: _clipStartSec,
              clipDurationSec: _clipDurationSec,
              originalCreatorId: creatorId,
              originalCreatorHandle: creatorHandle,
            )
          : null,
    );

    ref.read(socialFeedPostsProvider.notifier).addPost(post);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kinetic Post published to Explore feed!'),
        backgroundColor: AppColors.brandPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Track> _tracksForActiveAudioTab(
    List<UploadedMediaAsset> queueItems,
    List<Track> vaultTracks,
    List<Track> trendingTracks,
    String creatorHandle,
  ) {
    return switch (_audioSourceTabIndex) {
      0 =>
        queueItems
            .where((u) => u.kind == MediaAssetKind.audio)
            .map(
              (u) => Track(
                id: u.id,
                title: u.title,
                creatorName: u.artist?.trim().isNotEmpty == true
                    ? u.artist!.trim()
                    : creatorHandle.replaceFirst(RegExp(r'^@+'), ''),
                creatorHandle: creatorHandle,
                genre: u.genre ?? 'Amapiano',
                duration: Duration(milliseconds: u.durationMs ?? 90000),
                audioUrl: u.bestPlayableOrRenderableSource,
                coverUrl: u.bestCoverSource,
              ),
            )
            .toList(growable: false),
      1 => vaultTracks,
      _ => trendingTracks.take(10).toList(growable: false),
    };
  }

  Widget _buildLiveVisualStageCarousel(
    BuildContext context,
    List<UploadedMediaAsset> queueAssets,
  ) {
    if (_attachedImages.isEmpty) return const SizedBox.shrink();
    final byId = <String, UploadedMediaAsset>{
      for (final item in queueAssets) item.id: item,
    };

    return Padding(
      key: const Key('kpost_media_preview_carousel'),
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachedImages.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, idx) {
            final img = _attachedImages[idx];
            final tracked = img.uploadAssetId != null
                ? byId[img.uploadAssetId!]
                : null;
            final frameWidth = (148 * _selectedAspectRatio.ratio).clamp(
              112.0,
              224.0,
            );
            return SizedBox(
              width: frameWidth,
              height: 148,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  VhunambiTrackArtwork(
                    coverUrl: img.bestRenderPath,
                    genre: _selectedTrack?.genre ?? 'Amapiano',
                    trackId: '${_selectedTrack?.id ?? "kpost"}_$idx',
                    width: frameWidth,
                    height: 148,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  if (tracked != null &&
                      tracked.status == MediaUploadStatus.uploading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              value: tracked.progress,
                              strokeWidth: 2.6,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(tracked.progress * 100).round()}%',
                            style: AppTypography.badge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (tracked != null &&
                      tracked.status == MediaUploadStatus.failed)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        key: Key('kpost_retry_image_$idx'),
                        onPressed: () async {
                          final retried = await ref
                              .read(mediaUploadQueueProvider.notifier)
                              .retryUpload(tracked.id);
                          if (retried != null &&
                              retried.remoteUrl != null &&
                              mounted) {
                            setState(() {
                              _attachedImages[idx] = KineticPostImageAttachment(
                                imageUrl: AppConstants.normalizeCloudMediaUrl(
                                  retried.remoteUrl!,
                                ),
                                localFilePath: retried.localFilePath,
                                uploadAssetId: retried.id,
                                aspectRatio: _selectedAspectRatio,
                              );
                            });
                          }
                        },
                        icon: const PhosphorIcon(
                          AppIcons.remix,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                        label: Text(
                          'Retry',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      key: Key('kpost_remove_image_$idx'),
                      onTap: () =>
                          setState(() => _attachedImages.removeAt(idx)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const PhosphorIcon(
                          AppIcons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final allTracks = ref.watch(exploreTracksProvider);
    final vaultTracks = ref
        .watch(libraryTracksProvider)
        .where((t) => !t.isDeleted)
        .map((t) => t.toTrack())
        .toList(growable: false);
    final queueItems = ref.watch(mediaUploadQueueProvider);
    final activeHandle = ref.watch(currentCreatorHandleProvider);

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final surfaceSecondary = AppColors.surfaceSecondaryOf(context);

    final audioCandidates = _tracksForActiveAudioTab(
      queueItems,
      vaultTracks,
      allTracks,
      activeHandle,
    );

    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.chrome,
      enableLiveBlur: false,
      height: MediaQuery.of(context).size.height * 0.90,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      borderColorOverride: borderSubtle,
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 22),
                  color: textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Create Kinetic Post',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ElevatedButton(
                  key: const Key('kpost_publish_submit_btn'),
                  onPressed: _publishKineticPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Post',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandContrast,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderSubtle),

          // Main Scrollable Glass Cockpit Body
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl + bottomInset,
              ),
              children: [
                // 1. Caption & Context Story Editor
                TextField(
                  key: const Key('kpost_caption_input'),
                  controller: _captionController,
                  maxLines: 4,
                  minLines: 2,
                  style: AppTypography.bodyMedium.copyWith(color: textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Tell the story behind your sound, beat, or take... (#amapiano, @collaborator)',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: textSecondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),

                // 2. Above-the-Fold Live Visual Stage (`REQ-P79-KPOST-01`)
                _buildLiveVisualStageCarousel(context, queueItems),

                const SizedBox(height: AppSpacing.xs),

                // 3. Aspect Ratio Selector (Glass Pill Strip)
                VhunambiGlassSurface(
                  key: const Key('kpost_aspect_ratio_selector'),
                  variant: VhunambiGlassVariant.pill,
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      for (final ratio in KineticPostAspectRatio.values)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedAspectRatio = ratio;
                                for (
                                  var i = 0;
                                  i < _attachedImages.length;
                                  i++
                                ) {
                                  final current = _attachedImages[i];
                                  _attachedImages[i] =
                                      KineticPostImageAttachment(
                                        imageUrl: current.imageUrl,
                                        localFilePath: current.localFilePath,
                                        uploadAssetId: current.uploadAssetId,
                                        isAiGeneratedVision:
                                            current.isAiGeneratedVision,
                                        visionPrompt: current.visionPrompt,
                                        aspectRatio: ratio,
                                      );
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedAspectRatio == ratio
                                    ? AppColors.brandPrimary.withValues(
                                        alpha: 0.22,
                                      )
                                    : Colors.transparent,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(
                                  color: _selectedAspectRatio == ratio
                                      ? AppColors.brandPrimary
                                      : Colors.transparent,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ratio.label,
                                style: AppTypography.caption.copyWith(
                                  color: _selectedAspectRatio == ratio
                                      ? textPrimary
                                      : textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // 4. Visual Attachment Action Strip (Add Photo / My Uploads / Vision AI)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Opacity(
                      opacity: _attachedImages.length >= 4 ? 0.45 : 1.0,
                      child: KeyedSubtree(
                        key: const Key('kpost_pick_photo_btn'),
                        child: OutlinedButton.icon(
                          key: const Key('kpost_upload_photo_btn'),
                          onPressed:
                              (_attachedImages.length >= 4 || _isUploadingPhoto)
                              ? null
                              : _pickAndUploadPhoto,
                          icon: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const PhosphorIcon(
                                  PhosphorIconsRegular.image,
                                  size: 16,
                                ),
                          label: Text(
                            _isUploadingPhoto
                                ? 'Staging...'
                                : 'Add Photo (${_attachedImages.length}/4)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderSubtle),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('kpost_pick_from_uploads_btn'),
                      onPressed: _attachedImages.length >= 4
                          ? null
                          : _showPickFromUploadsSheet,
                      icon: const PhosphorIcon(AppIcons.upload, size: 15),
                      label: Text(
                        'My Uploads',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                    Opacity(
                      opacity: _attachedImages.length >= 4 ? 0.45 : 1.0,
                      child: ElevatedButton.icon(
                        key: const Key('kpost_vision_ai_btn'),
                        onPressed: _attachedImages.length >= 4
                            ? null
                            : _generateVisionAiArtwork,
                        icon: const PhosphorIcon(
                          PhosphorIconsFill.sparkle,
                          size: 16,
                          color: AppColors.badgeCyan,
                        ),
                        label: _isGeneratingVision
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    textPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Vision AI',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: surfaceSecondary,
                          side: const BorderSide(color: AppColors.badgeCyan),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_attachedImages.length >= 4) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    key: const Key('kpost_max_images_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Text(
                      '4/4 Max images attached',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xs),
                if (_visionUnavailableNotice != null) ...[
                  Container(
                    key: const Key('kpost_vision_unavailable_notice'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceSecondary,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _visionUnavailableNotice!,
                      style: AppTypography.caption.copyWith(color: textPrimary),
                    ),
                  ),
                ],
                TextField(
                  key: const Key('kpost_vision_prompt_input'),
                  controller: _visionPromptController,
                  style: AppTypography.caption.copyWith(color: textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Prompt Vhunambi Vision (e.g. "Polokwane Golden Hour")',
                    hintStyle: AppTypography.caption.copyWith(
                      color: textSecondary,
                    ),
                    prefixIcon: const PhosphorIcon(
                      PhosphorIconsRegular.paintBrush,
                      size: 16,
                      color: AppColors.badgeCyan,
                    ),
                    filled: true,
                    fillColor: surfaceSecondary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide(color: borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide(color: borderSubtle),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                Divider(color: borderSubtle),
                const SizedBox(height: AppSpacing.xs),

                // 5. Interactive Sound Attachment Deck (`REQ-P84-KPOST-01`)
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.musicNote,
                      color: AppColors.brandPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Attach Sound / Snippet',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: OutlinedButton.icon(
                        key: const Key('kpost_upload_audio_btn'),
                        onPressed: _isUploadingAudio
                            ? null
                            : _pickAndUploadAudio,
                        icon: _isUploadingAudio
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const PhosphorIcon(
                                PhosphorIconsBold.uploadSimple,
                                size: 15,
                                color: AppColors.brandPrimary,
                              ),
                        label: Text(
                          _isUploadingAudio ? 'Uploading...' : 'Upload Audio',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.brandPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                VhunambiGlassTabBar(
                  key: const Key('kpost_audio_source_tabs'),
                  selectedIndex: _audioSourceTabIndex,
                  onSelected: (idx) {
                    setState(() {
                      _audioSourceTabIndex = idx;
                      _selectedAudioCategory =
                          KineticAudioSourceType.librarySong;
                    });
                  },
                  items: const <VhunambiGlassTabItem>[
                    VhunambiGlassTabItem(
                      label: 'My Uploads',
                      icon: AppIcons.upload,
                    ),
                    VhunambiGlassTabItem(
                      label: 'My Vault',
                      icon: AppIcons.songs,
                    ),
                    VhunambiGlassTabItem(
                      label: 'Trending',
                      icon: AppIcons.flame,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Frosted Interactive Audio Attachment Card with Artwork + Audition Player
                VhunambiGlassSurface(
                  key: const Key('kpost_audio_attachment_card'),
                  variant: VhunambiGlassVariant.card,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          VhunambiTrackArtwork(
                            coverUrl: _selectedTrack?.coverUrl,
                            genre: _selectedTrack?.genre ?? 'Amapiano',
                            trackId: _selectedTrack?.id ?? 'kpost_sound',
                            width: 48,
                            height: 48,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedTrack?.title ?? 'No Track Attached',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedTrack?.genre ?? "Amapiano"} • ${_selectedTrack?.creatorHandle ?? activeHandle}',
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('kpost_audio_audition_btn'),
                            tooltip: _isAuditioning
                                ? 'Pause Preview'
                                : 'Play Preview',
                            onPressed: _toggleAudioAudition,
                            icon: PhosphorIcon(
                              _isAuditioning ? AppIcons.pause : AppIcons.play,
                              size: 20,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),

                      if (audioCandidates.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: audioCandidates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, idx) {
                              final candidate = audioCandidates[idx];
                              final selected =
                                  _selectedTrack?.id == candidate.id;
                              return GestureDetector(
                                key: Key('kpost_audio_chip_${candidate.id}'),
                                onTap: () {
                                  unawaited(_pauseAudition());
                                  setState(() => _selectedTrack = candidate);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.brandPrimary.withValues(
                                            alpha: 0.18,
                                          )
                                        : surfaceSecondary,
                                    borderRadius: AppRadius.pillBorder,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.brandPrimary
                                          : borderSubtle,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    candidate.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: selected
                                          ? AppColors.brandPrimary
                                          : textPrimary,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.sm),

                      // Duration Trimming Pills (15s, 30s, 60s, Full)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildTrimPill(
                            context: context,
                            key: const Key('kpost_trim_15s'),
                            label: '15s Hook',
                            durationSec: 15.0,
                          ),
                          _buildTrimPill(
                            context: context,
                            key: const Key('kpost_trim_30s'),
                            label: '30s Hook',
                            durationSec: 30.0,
                          ),
                          _buildTrimPill(
                            context: context,
                            key: const Key('kpost_trim_60s'),
                            label: '60s Verse',
                            durationSec: 60.0,
                          ),
                          _buildTrimPill(
                            context: context,
                            key: const Key('kpost_trim_full'),
                            label: 'Full Song',
                            durationSec:
                                _selectedTrack?.duration.inSeconds.toDouble() ??
                                180.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimPill({
    required BuildContext context,
    required Key key,
    required String label,
    required double durationSec,
  }) {
    final isSelected = (_clipDurationSec - durationSec).abs() < 1.0;
    return InkWell(
      key: key,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _clipDurationSec = durationSec;
          _clipStartSec = durationSec <= 30.0 ? 15.0 : 0.0;
        });
      },
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.surfaceElevatedOf(context),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.borderSubtleOf(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.textSecondaryOf(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
