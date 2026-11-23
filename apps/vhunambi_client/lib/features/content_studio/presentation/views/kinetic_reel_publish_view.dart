import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _submitPublish() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final repo = ref.read(socialRepositoryProvider);
      final session = ref.read(authSessionProvider);

      String? uploadedVideoUrl;
      String resolvedCoverUrl = widget.audio.coverUrl;
      String resolvedAudioUrl = widget.audio.audioUrl;

      if (widget.customMediaBytes != null &&
          widget.customMediaBytes!.isNotEmpty &&
          widget.customMediaMime != null) {
        final upload = await repo.uploadReelMedia(
          bytes: widget.customMediaBytes!,
          filename: widget.customMediaFilename ?? 'reel_media.mp4',
          mimeType: widget.customMediaMime!,
        );
        if (widget.customMediaMime!.startsWith('image/')) {
          resolvedCoverUrl = upload.url;
        } else {
          uploadedVideoUrl = upload.url;
        }
      }

      if (widget.audio.importedAudioBytes != null &&
          widget.audio.importedAudioBytes!.isNotEmpty &&
          widget.audio.importedAudioMime != null) {
        final audioUpload = await repo.uploadReelMedia(
          bytes: widget.audio.importedAudioBytes!,
          filename: '${widget.audio.trackId}.mp3',
          mimeType: widget.audio.importedAudioMime!,
        );
        resolvedAudioUrl = audioUpload.url;
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
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    VhunambiTrackArtwork(
                      coverUrl: widget.audio.coverUrl,
                      genre: widget.audio.genre,
                      trackId: widget.audio.trackId,
                      borderRadius: AppRadius.cardBorder,
                    ),
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
          const SizedBox(height: 20),
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
              label: Text(_isPublishing ? 'Publishing...' : 'Publish Reel'),
            ),
          ),
        ],
      ),
    );
  }
}
