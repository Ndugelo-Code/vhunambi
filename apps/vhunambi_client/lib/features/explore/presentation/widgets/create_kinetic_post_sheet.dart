import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';

/// Full-featured authoring workstation for publishing Kinetic Posts (REQ-KPOST-01..05).
/// Supports static images (1–4), Vhunambi Vision AI generation, resizable aspect ratios,
/// and universal 4-category audio vault attachment with duration trimming.
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

  // Audio Attachment State
  KineticAudioSourceType _selectedAudioCategory =
      KineticAudioSourceType.librarySong;
  Track? _selectedTrack;
  double _clipStartSec = 0.0;
  double _clipDurationSec = 30.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(modalSheetOpenCountProvider.notifier).state++;
      }
    });
    // Default fallback track from explore catalog
    final initialTracks = ref.read(exploreTracksProvider);
    if (initialTracks.isNotEmpty) {
      _selectedTrack = initialTracks.first;
    }
    // If opened via quick action
    if (widget.initialTab == 1) {
      _mockPickImage();
    } else if (widget.initialTab == 2) {
      _visionPromptController.text = 'Polokwane Sunset Studio Session';
    }
  }

  @override
  void dispose() {
    ref.read(modalSheetOpenCountProvider.notifier).state =
        (ref.read(modalSheetOpenCountProvider.notifier).state - 1).clamp(0, 99);
    _captionController.dispose();
    _visionPromptController.dispose();
    super.dispose();
  }

  void _mockPickImage({String? mockUrl}) {
    HapticFeedback.lightImpact();
    final url = mockUrl ?? 'https://cdn.vhunambi.com/covers/custom_post_art.jpg';

    // Strict No-MP4 Guard (REQ-KPOST-NO-MP4)
    if (!isAllowedKineticPostMedia(url)) {
      _showVideoFormatRejectionDialog();
      return;
    }

    if (_attachedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 static images per Kinetic Post.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _attachedImages.add(
        KineticPostImageAttachment(
          imageUrl: url,
          aspectRatio: _selectedAspectRatio,
        ),
      );
    });
  }

  void _generateVisionAiArtwork() async {
    HapticFeedback.mediumImpact();
    final prompt = _visionPromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isGeneratingVision = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _isGeneratingVision = false;
      _attachedImages.add(
        KineticPostImageAttachment(
          imageUrl: 'https://cdn.vhunambi.com/vision/generated_${DateTime.now().millisecondsSinceEpoch}.jpg',
          isAiGeneratedVision: true,
          visionPrompt: prompt,
          aspectRatio: _selectedAspectRatio,
        ),
      );
    });
  }

  void _showVideoFormatRejectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsRegular.videoCameraSlash,
              color: AppColors.brandPrimary,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Video Media Detected', style: AppTypography.titleMedium),
          ],
        ),
        content: Text(
          'Kinetic Posts are strictly reserved for high-res static images and sonic audio cards.\n\nTo share immersive 9:16 video performances, publish a Kinetic Reel!',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
    final now = DateTime.now();

    final owner = ref.read(ownerProfileProvider);
    final creatorName = owner.displayName.isNotEmpty ? owner.displayName : 'Cern';
    final creatorHandle = owner.handle.isNotEmpty ? owner.handle : '@cern';
    final creatorId = owner.id.isNotEmpty ? owner.id : 'creator_cern';

    final trackToAttach = _selectedTrack ??
        Track(
          id: 'kpost_track_default',
          title: 'Vhunambi Sonic Groove',
          creatorName: creatorName,
          creatorHandle: creatorHandle,
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          duration: const Duration(minutes: 3, seconds: 0),
        );

    final post = SocialMusicPost(
      id: 'kpost_${now.millisecondsSinceEpoch}',
      creatorId: creatorId,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      creatorAvatarUrl: owner.avatarUrl,
      publishedAt: now,
      location: 'Limpopo / Polokwane',
      caption: caption,
      track: trackToAttach,
      imageAttachment: _attachedImages.isNotEmpty ? _attachedImages.first : null,
      imageAttachments: _attachedImages,
      audioAttachment: KineticPostAudioAttachment(
        sourceType: _selectedAudioCategory,
        clipStartSec: _clipStartSec,
        clipDurationSec: _clipDurationSec,
        originalCreatorId: creatorId,
        originalCreatorHandle: creatorHandle,
      ),
    );

    ref.read(socialFeedPostsProvider.notifier).addPost(post);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kinetic Post published to Explore feed! 🚀'),
        backgroundColor: AppColors.brandPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final allTracks = ref.watch(exploreTracksProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
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
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Create Kinetic Post',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
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

          Divider(height: 1, color: AppColors.borderSubtle),

          // Main Scrollable Workstation Body
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
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Tell the story behind your sound, beat, or take... (#amapiano, @collaborator)',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // 2. Aspect Ratio Selector
                Container(
                  key: const Key('kpost_aspect_ratio_selector'),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      for (final ratio in KineticPostAspectRatio.values)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedAspectRatio = ratio);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedAspectRatio == ratio
                                    ? AppColors.brandPrimary
                                    : Colors.transparent,
                                borderRadius: AppRadius.pillBorder,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ratio.label,
                                style: AppTypography.caption.copyWith(
                                  color: _selectedAspectRatio == ratio
                                      ? AppColors.brandContrast
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 3. Visual Attachment Deck (Upload / Vhunambi Vision)
                Row(
                  children: [
                    // Upload Photo Button
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('kpost_upload_photo_btn'),
                        onPressed: _mockPickImage,
                        icon: const PhosphorIcon(
                          PhosphorIconsRegular.image,
                          size: 18,
                        ),
                        label: Text(
                          'Add Photo (${_attachedImages.length}/4)',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderSubtle),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),

                    // Vhunambi Vision AI Button
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('kpost_vision_ai_btn'),
                        onPressed: _generateVisionAiArtwork,
                        icon: const PhosphorIcon(
                          PhosphorIconsFill.sparkle,
                          size: 18,
                          color: AppColors.badgeCyan,
                        ),
                        label: _isGeneratingVision
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Vision AI',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSecondary,
                          side: const BorderSide(color: AppColors.badgeCyan),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),

                // Vision Prompt input if user desires
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const Key('kpost_vision_prompt_input'),
                  controller: _visionPromptController,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Prompt Vhunambi Vision (e.g. "Polokwane Golden Hour")',
                    hintStyle: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const PhosphorIcon(
                      PhosphorIconsRegular.paintBrush,
                      size: 16,
                      color: AppColors.badgeCyan,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),

                // Attached Visual Thumbnails
                if (_attachedImages.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachedImages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, idx) {
                        final img = _attachedImages[idx];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                img.imageUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.brandPrimary.withValues(alpha: 0.8),
                                        AppColors.badgeCyan.withValues(alpha: 0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: PhosphorIcon(
                                      PhosphorIconsFill.sparkle,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attachedImages.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const PhosphorIcon(
                                    PhosphorIconsRegular.x,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                Divider(color: AppColors.borderSubtle),
                const SizedBox(height: AppSpacing.xs),

                // 4. Universal Vault Audio Attachment Picker (Songs, Beats, Voice DNA, Grooves)
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.musicNote,
                      color: AppColors.brandPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Attach Sound / Snippet',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Category Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final cat in KineticAudioSourceType.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat.label),
                            selected: _selectedAudioCategory == cat,
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedAudioCategory = cat);
                              }
                            },
                            selectedColor: AppColors.brandPrimary,
                            labelStyle: TextStyle(
                              color: _selectedAudioCategory == cat
                                  ? AppColors.brandContrast
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            backgroundColor: AppColors.surfaceSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                              side: BorderSide(color: AppColors.borderSubtle),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Selected Track Picker Carousel / Dropdown
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsRegular.waveform,
                            size: 20,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _selectedTrack?.title ?? 'No Track Attached',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<Track>(
                            icon: PhosphorIcon(
                              PhosphorIconsRegular.caretDown,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onSelected: (track) {
                              setState(() => _selectedTrack = track);
                            },
                            itemBuilder: (_) {
                              List<Track> items;
                              switch (_selectedAudioCategory) {
                                case KineticAudioSourceType.librarySong:
                                  items = allTracks.take(8).toList();
                                  break;
                                case KineticAudioSourceType.beatListing:
                                  items = const [
                                    Track(id: 'beat_01', title: 'Pretoria Deep 112 BPM', creatorName: 'Kabza Producer', creatorHandle: '@kabza', genre: 'Amapiano', duration: Duration(minutes: 2)),
                                    Track(id: 'beat_02', title: 'Durban Gqom Sgubhu 127', creatorName: 'Makhadzi Beats', creatorHandle: '@makhadzi', genre: 'Gqom', duration: Duration(minutes: 2)),
                                    Track(id: 'beat_03', title: 'Polokwane Sunset Groove', creatorName: 'Sigwa Riffs', creatorHandle: '@sigwa', genre: 'Afro-fusion', duration: Duration(minutes: 2)),
                                    Track(id: 'beat_04', title: '3-Step African Soul 115', creatorName: 'Fifi Sound', creatorHandle: '@fifi', genre: 'Afro House', duration: Duration(minutes: 2)),
                                  ];
                                  break;
                                case KineticAudioSourceType.voiceSignature:
                                  items = const [
                                    Track(id: 'dna_01', title: 'Venda Folk Warmth (98% Timbre)', creatorName: 'Vocal DNA Studio', creatorHandle: '@cern', genre: 'Folk / Choral', duration: Duration(seconds: 45)),
                                    Track(id: 'dna_02', title: 'Soprano Harmonies (94% Match)', creatorName: 'Makhadzi Clone', creatorHandle: '@makhadzi', genre: 'Amapiano', duration: Duration(seconds: 45)),
                                    Track(id: 'dna_03', title: 'Deep Baritone Chant (96% Match)', creatorName: 'Zulu Heritage DNA', creatorHandle: '@sigwa', genre: 'Gqom', duration: Duration(seconds: 45)),
                                  ];
                                  break;
                                case KineticAudioSourceType.sketchpadGroove:
                                  items = const [
                                    Track(id: 'sk_01', title: 'Midnight Log Drum Pattern A', creatorName: 'Pocket DAW', creatorHandle: '@cern', genre: 'Amapiano', duration: Duration(seconds: 30)),
                                    Track(id: 'sk_02', title: 'Private School Rhodes Chords', creatorName: 'Sketchpad 3-Step', creatorHandle: '@cern', genre: 'Afro House', duration: Duration(seconds: 30)),
                                    Track(id: 'sk_03', title: 'Euclidean African Percussion', creatorName: 'Groove Sequencer', creatorHandle: '@cern', genre: 'Afro-fusion', duration: Duration(seconds: 30)),
                                  ];
                                  break;
                              }
                              return items
                                  .map(
                                    (t) => PopupMenuItem(
                                      value: t,
                                      child: Text(
                                        '${t.title} (${t.genre})',
                                        style: AppTypography.bodySmall,
                                      ),
                                    ),
                                  )
                                  .toList();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Duration Trimming Pills (15s, 30s, 60s, Full)
                      Row(
                        children: [
                          _buildTrimPill(
                            key: const Key('kpost_trim_15s'),
                            label: '15s Hook',
                            durationSec: 15.0,
                          ),
                          const SizedBox(width: 6),
                          _buildTrimPill(
                            key: const Key('kpost_trim_30s'),
                            label: '30s Hook',
                            durationSec: 30.0,
                          ),
                          const SizedBox(width: 6),
                          _buildTrimPill(
                            key: const Key('kpost_trim_60s'),
                            label: '60s Verse',
                            durationSec: 60.0,
                          ),
                          const SizedBox(width: 6),
                          _buildTrimPill(
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
          if (durationSec <= 30.0) {
            _clipStartSec = 15.0; // Standard hook start offset
          } else {
            _clipStartSec = 0.0;
          }
        });
      },
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

