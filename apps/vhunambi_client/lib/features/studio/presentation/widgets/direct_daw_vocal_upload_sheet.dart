import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../explore/domain/models/social_music_post.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../marketplace/domain/models/marketplace_models.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../social/presentation/providers/trending_reels_provider.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';

/// Direct DAW & Natural Vocal/Stem Uploader Workstation (Phase 39 REQ-UPL-01).
///
/// Enables traditional producers, natural singers, instrumentalists, and dancers
/// to bring their outside music directly into Vhunambi without AI generation.
class DirectDawVocalUploadSheet extends ConsumerStatefulWidget {
  const DirectDawVocalUploadSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtleOf(context)),
      ),
      builder: (_) => const DirectDawVocalUploadSheet(),
    );
  }

  @override
  ConsumerState<DirectDawVocalUploadSheet> createState() =>
      _DirectDawVocalUploadSheetState();
}

enum _UploadWorkflow { dawMaster, liveVocalStem, cameraReel }

class _DirectDawVocalUploadSheetState
    extends ConsumerState<DirectDawVocalUploadSheet> {
  _UploadWorkflow _workflow = _UploadWorkflow.dawMaster;

  final TextEditingController _titleController =
      TextEditingController(text: 'Limpopo Midnight Jam');
  final TextEditingController _bpmController =
      TextEditingController(text: '112');
  final TextEditingController _creditsController =
      TextEditingController(text: '5');

  String _selectedGenre = 'Amapiano';
  String _selectedKey = 'F# Minor';
  AudioProvenanceType _provenanceType = AudioProvenanceType.humanDawMaster;
  bool _publishToExplore = true;
  bool _listOnMarketplace = true;
  String _selectedFileName = 'limpopo_midnight_master.wav';

  static const List<String> _genres = [
    'Amapiano',
    'Maskandi',
    'Gqom',
    'Kwaito',
    'Afro House',
    'Afrobeats',
    'Afro Jazz',
    'Mbaqanga',
  ];

  static const List<String> _keys = [
    'C Major',
    'A Minor',
    'G Major',
    'E Minor',
    'D Major',
    'B Minor',
    'F# Minor',
    'C# Minor',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bpmController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  void _onWorkflowChanged(_UploadWorkflow workflow) {
    setState(() {
      _workflow = workflow;
      switch (workflow) {
        case _UploadWorkflow.dawMaster:
          _provenanceType = AudioProvenanceType.humanDawMaster;
          _selectedFileName = 'limpopo_midnight_master.wav';
          break;
        case _UploadWorkflow.liveVocalStem:
          _provenanceType = AudioProvenanceType.liveVocalRecording;
          _selectedFileName = 'vocal_take_01_acapella.wav';
          break;
        case _UploadWorkflow.cameraReel:
          _provenanceType = AudioProvenanceType.liveVocalRecording;
          _selectedFileName = 'dance_reel_take.mp4';
          break;
      }
    });
  }

  void _handleSubmit() {
    HapticFeedback.mediumImpact();

    if (_workflow == _UploadWorkflow.cameraReel) {
      Navigator.of(context).pop();
      final reels = ref.read(trendingReelsProvider);
      KineticReelsModal.show(context, clips: reels);
      return;
    }

    final title = _titleController.text.trim();
    final bpm = int.tryParse(_bpmController.text.trim()) ?? 112;
    final price = int.tryParse(_creditsController.text.trim()) ?? 5;
    final now = DateTime.now();

    final newTrack = Track(
      id: 'upl_track_${now.millisecondsSinceEpoch}',
      title: title.isNotEmpty ? title : 'Untitled Creation',
      creatorName: 'You',
      creatorHandle: '@current_user',
      genre: _selectedGenre,
      duration: const Duration(minutes: 3, seconds: 15),
      audioUrl: 'https://cdn.vhunambi.com/uploads/$_selectedFileName',
      provenanceType: _provenanceType,
    );

    // 1. Save to User Vault (Library)
    ref.read(libraryTracksProvider.notifier).addTrack(
          LibraryTrack(
            id: newTrack.id,
            title: newTrack.title,
            creatorName: newTrack.creatorName,
            genre: newTrack.genre,
            language: newTrack.language,
            durationSeconds: newTrack.duration.inSeconds,
            remoteAudioUrl: newTrack.audioUrl ?? '',
            createdAt: now,
            isInstrumental:
                _provenanceType == AudioProvenanceType.humanDawMaster,
          ),
        );

    // 2. Publish to Explore Feed
    if (_publishToExplore) {
      final newPost = SocialMusicPost(
        id: 'post_upl_${now.millisecondsSinceEpoch}',
        creatorId: 'current_user',
        creatorName: 'You',
        creatorHandle: '@current_user',
        isCreatorVerified: true,
        publishedAt: now,
        caption: _workflow == _UploadWorkflow.dawMaster
            ? 'Fresh DAW master exported straight to Vhunambi! Stems open for co-creation. 🎛️'
            : 'Natural acoustic recording dropped into the ecosystem! 🎙️ #LiveCraft',
        track: newTrack,
        provenanceType: _provenanceType,
        audioAttachment: KineticPostAudioAttachment(
          sourceType: KineticAudioSourceType.librarySong,
          clipStartSec: 0.0,
          clipDurationSec: 30.0,
          originalCreatorId: 'current_user',
          originalCreatorHandle: '@current_user',
        ),
      );
      ref.read(socialFeedPostsProvider.notifier).addPost(newPost);
    }

    // 3. List on Marketplace for 85% Royalties
    if (_listOnMarketplace) {
      final category = _workflow == _UploadWorkflow.liveVocalStem
          ? MarketplaceAssetCategory.vocals
          : (_provenanceType == AudioProvenanceType.liveInstrumentStem
              ? MarketplaceAssetCategory.liveInstruments
              : MarketplaceAssetCategory.beats);

      final listing = BeatListingEntity(
        id: 'mkt_upl_${now.millisecondsSinceEpoch}',
        title: newTrack.title,
        producerId: 'current_user',
        producerName: 'You',
        producerHandle: '@current_user',
        genre: _selectedGenre,
        bpm: bpm,
        musicalKey: _selectedKey,
        priceInCredits: price,
        previewAudioUrl: newTrack.audioUrl ?? '',
        createdAt: now,
        assetCategory: category,
        provenanceType: _provenanceType,
      );
      ref.read(marketplaceBeatsProvider.notifier).addListing(listing);
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Master asset published to Vault & ${_publishToExplore ? 'Explore' : 'Marketplace'}! 🚀',
        ),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.uploadSimple,
                        color: AppColors.brandPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Direct DAW & Vocal Uploader',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.x,
                      color: AppColors.textSecondaryOf(context),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Workflow Selector Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Row(
                  children: [
                    _buildTab(
                      label: 'DAW Master',
                      icon: PhosphorIconsRegular.slidersHorizontal,
                      workflow: _UploadWorkflow.dawMaster,
                    ),
                    _buildTab(
                      label: 'Vocal / Stem',
                      icon: PhosphorIconsRegular.microphone,
                      workflow: _UploadWorkflow.liveVocalStem,
                    ),
                    _buildTab(
                      label: 'Dance Reel',
                      icon: PhosphorIconsRegular.personSimpleRun,
                      workflow: _UploadWorkflow.cameraReel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // File Import Dropzone
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedOf(context),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.fileAudio,
                      size: 36,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFileName,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to import (FL Studio, Ableton, Logic, Stems)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title Input
              TextField(
                controller: _titleController,
                style: TextStyle(color: AppColors.textPrimaryOf(context)),
                decoration: InputDecoration(
                  labelText: 'Title / Track Name',
                  labelStyle:
                      TextStyle(color: AppColors.textSecondaryOf(context)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.borderSubtleOf(context)),
                    borderRadius: AppRadius.inputBorder,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.brandPrimary),
                    borderRadius: AppRadius.inputBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Genre & Key Selectors
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGenre,
                      dropdownColor: AppColors.surfaceModalOf(context),
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Genre',
                        labelStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.borderSubtleOf(context)),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      items: _genres
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedGenre = v ?? _selectedGenre),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedKey,
                      dropdownColor: AppColors.surfaceModalOf(context),
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Key',
                        labelStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.borderSubtleOf(context)),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      items: _keys
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedKey = v ?? _selectedKey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // BPM & Provenance
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _bpmController,
                      keyboardType: TextInputType.number,
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'BPM',
                        labelStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.borderSubtleOf(context)),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<AudioProvenanceType>(
                      initialValue: _provenanceType,
                      dropdownColor: AppColors.surfaceModalOf(context),
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Audio Provenance',
                        labelStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.borderSubtleOf(context)),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      items: AudioProvenanceType.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Row(
                                children: [
                                  PhosphorIcon(p.icon, size: 14),
                                  const SizedBox(width: 6),
                                  Text(p.displayName,
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                          () => _provenanceType = v ?? _provenanceType),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Publishing Checkboxes
              SwitchListTile(
                title: Text(
                  'Publish to Explore Social Feed',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Make available for community remixing & discovery',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
                value: _publishToExplore,
                activeTrackColor: AppColors.brandPrimary,
                onChanged: (v) => setState(() => _publishToExplore = v),
              ),
              SwitchListTile(
                title: Text(
                  'List on /market (85% Royalties)',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Earn ZAR/coins whenever other creators license your stems',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
                value: _listOnMarketplace,
                activeTrackColor: AppColors.badgeCyan,
                onChanged: (v) => setState(() => _listOnMarketplace = v),
              ),

              const SizedBox(height: AppSpacing.md),

              // Submit Button (44dp+)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('direct_upload_submit_btn'),
                  onPressed: _handleSubmit,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.paperPlaneRight,
                    color: AppColors.brandContrast,
                    size: 18,
                  ),
                  label: Text(
                    _workflow == _UploadWorkflow.cameraReel
                        ? 'Open Camera Reel Recorder'
                        : 'Publish to Vault & Ecosystem',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandContrast,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required _UploadWorkflow workflow,
  }) {
    final isSelected = _workflow == workflow;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onWorkflowChanged(workflow),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surfaceElevatedOf(context)
                : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.textPrimaryOf(context)
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

