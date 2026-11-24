import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../content_studio/presentation/views/kinetic_reel_studio_view.dart';
import '../../../explore/domain/models/social_music_post.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../marketplace/domain/models/marketplace_models.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../media/domain/models/uploaded_media_asset.dart';
import '../../../media/presentation/providers/media_upload_queue_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

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

  final TextEditingController _titleController = TextEditingController(
    text: 'Limpopo Midnight Jam',
  );
  final TextEditingController _bpmController = TextEditingController(
    text: '112',
  );
  final TextEditingController _creditsController = TextEditingController(
    text: '5',
  );

  String _selectedGenre = 'Amapiano';
  String _selectedKey = 'F# Minor';
  AudioProvenanceType _provenanceType = AudioProvenanceType.humanDawMaster;
  bool _publishToExplore = true;
  bool _listOnMarketplace = true;
  String _selectedFileName = 'Tap to select MP3, M4A, or WAV file';
  Uint8List? _selectedAudioBytes;
  String? _selectedLocalPath;
  String _selectedMimeType = 'audio/mpeg';
  bool _hasPickedRealFile = false;
  bool _isUploading = false;
  bool _titleEditedByUser = false;

  static const int _maxAudioBytes = 25 * 1024 * 1024;

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

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).clamp(1, 9999).round()} KB';
  }

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
          if (!_hasPickedRealFile) {
            _selectedFileName = 'Tap to select MP3, M4A, or WAV master';
          }
          break;
        case _UploadWorkflow.liveVocalStem:
          _provenanceType = AudioProvenanceType.liveVocalRecording;
          if (!_hasPickedRealFile) {
            _selectedFileName = 'Tap to select vocal/stem recording (MP3/WAV)';
          }
          break;
        case _UploadWorkflow.cameraReel:
          _provenanceType = AudioProvenanceType.liveVocalRecording;
          if (!_hasPickedRealFile) {
            _selectedFileName = 'Launch camera to record live reel';
          }
          break;
      }
    });
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
      try {
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
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Audio picker failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        return;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not read audio bytes from selected file.'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    if (bytes.length > _maxAudioBytes) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Audio file exceeds the 25 MB upload limit.'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    var persistedPath = pickedPath;
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

  Future<void> _handleSubmit() async {
    if (_isUploading) return;
    HapticFeedback.mediumImpact();

    if (_workflow == _UploadWorkflow.cameraReel) {
      Navigator.of(context).pop();
      KineticReelStudioView.show(context, initialCameraMode: true);
      return;
    }

    if (!_hasPickedRealFile ||
        _selectedAudioBytes == null ||
        _selectedAudioBytes!.isEmpty) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Please tap to select an MP3, M4A, or WAV audio file.',
            ),
            backgroundColor: AppColors.brandPrimary,
          ),
        );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final staged = await ref
          .read(mediaUploadQueueProvider.notifier)
          .stageAndEnqueue(
            bytes: _selectedAudioBytes!,
            filename: _selectedFileName,
            mimeType: _selectedMimeType,
            kind: MediaAssetKind.audio,
            title: _titleController.text.trim(),
            sourceSurface: 'daw_upload',
            awaitUpload: true,
          );
      if (!mounted) return;
      if (staged.status == MediaUploadStatus.failed) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Upload saved locally in My Uploads — reconnect and tap Retry.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        return;
      }

      final effectiveLocalPath = staged.localFilePath ?? _selectedLocalPath;
      final normalizedRemoteUrl = AppConstants.normalizeCloudMediaUrl(
        staged.remoteUrl ?? effectiveLocalPath ?? '',
      );
      final title = _titleController.text.trim();
      final bpm = int.tryParse(_bpmController.text.trim()) ?? 112;
      final price = int.tryParse(_creditsController.text.trim()) ?? 5;
      final now = DateTime.now();
      final owner = ref.read(ownerProfileProvider);
      final session = ref.read(authSessionProvider);
      final resolvedCreatorId = owner.id.isNotEmpty && owner.id != 'me'
          ? owner.id
          : (session.canonicalCreatorId.isNotEmpty
                ? session.canonicalCreatorId
                : 'creator_cern');
      final resolvedName = owner.displayName.isNotEmpty
          ? owner.displayName
          : (session.displayName.isNotEmpty ? session.displayName : 'Cern');
      final rawHandle = owner.handle.isNotEmpty
          ? owner.handle
          : (session.rawUsername.isNotEmpty ? session.rawUsername : 'cern');
      final resolvedHandle = rawHandle.startsWith('@')
          ? rawHandle
          : '@$rawHandle';

      final newTrack = Track(
        id: 'upl_track_${now.millisecondsSinceEpoch}',
        title: title.isNotEmpty ? title : 'Untitled Creation',
        creatorName: resolvedName,
        creatorHandle: resolvedHandle,
        genre: _selectedGenre,
        duration: const Duration(minutes: 3, seconds: 15),
        audioUrl: normalizedRemoteUrl,
        provenanceType: _provenanceType,
      );

      // 1. Save to User Vault (Library) & Owner Profile (always visible in Songs!)
      ref
          .read(libraryTracksProvider.notifier)
          .addTrack(
            LibraryTrack(
              id: newTrack.id,
              title: newTrack.title,
              creatorName: newTrack.creatorName,
              creatorId: resolvedCreatorId,
              creatorHandle: resolvedHandle,
              genre: newTrack.genre,
              language: newTrack.language,
              durationSeconds: newTrack.duration.inSeconds,
              remoteAudioUrl: normalizedRemoteUrl,
              localAudioFilePath: effectiveLocalPath,
              createdAt: now,
              syncStatus: effectiveLocalPath != null
                  ? TrackSyncStatus.cachedLocally
                  : TrackSyncStatus.synced,
              isInstrumental: false,
              bpm: bpm,
            ),
          );

      // 2. Publish to Explore Feed
      if (_publishToExplore) {
        final newPost = SocialMusicPost(
          id: 'post_upl_${now.millisecondsSinceEpoch}',
          creatorId: resolvedCreatorId,
          creatorName: resolvedName,
          creatorHandle: resolvedHandle,
          creatorAvatarUrl: owner.avatarUrl,
          isCreatorVerified: owner.isVerified,
          publishedAt: now,
          caption: _workflow == _UploadWorkflow.dawMaster
              ? 'Fresh DAW master exported straight to Vhunambi! Stems open for co-creation.'
              : 'Natural acoustic recording dropped into the ecosystem! #LiveCraft',
          track: newTrack,
          provenanceType: _provenanceType,
          audioAttachment: KineticPostAudioAttachment(
            sourceType: KineticAudioSourceType.librarySong,
            clipStartSec: 0.0,
            clipDurationSec: 30.0,
            originalCreatorId: resolvedCreatorId,
            originalCreatorHandle: resolvedHandle,
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
          producerId: resolvedCreatorId,
          producerName: resolvedName,
          producerHandle: resolvedHandle,
          genre: _selectedGenre,
          bpm: bpm,
          musicalKey: _selectedKey,
          priceInCredits: price,
          previewAudioUrl: normalizedRemoteUrl,
          createdAt: now,
          assetCategory: category,
          provenanceType: _provenanceType,
        );
        ref.read(marketplaceBeatsProvider.notifier).addListing(listing);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded "${newTrack.title}" to Library & ${_publishToExplore ? 'Explore' : 'Profile'}!',
            ),
            backgroundColor: AppColors.brandPrimary,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Audio upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
              InkWell(
                key: const Key('direct_upload_pick_file_btn'),
                onTap: _workflow == _UploadWorkflow.cameraReel
                    ? _handleSubmit
                    : _pickAudioFile,
                borderRadius: AppRadius.cardBorder,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedOf(context),
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(
                      color: _hasPickedRealFile
                          ? AppColors.success.withValues(alpha: 0.7)
                          : AppColors.brandPrimary.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      PhosphorIcon(
                        _hasPickedRealFile
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.fileAudio,
                        size: 36,
                        color: _hasPickedRealFile
                            ? AppColors.success
                            : AppColors.brandPrimary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedFileName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasPickedRealFile && _selectedAudioBytes != null
                            ? '${_formatBytes(_selectedAudioBytes!.length)} • $_selectedMimeType (tap to replace)'
                            : 'Tap to browse MP3, M4A, or WAV from device storage',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title Input
              TextField(
                controller: _titleController,
                onChanged: (_) => _titleEditedByUser = true,
                style: TextStyle(color: AppColors.textPrimaryOf(context)),
                decoration: InputDecoration(
                  labelText: 'Title / Track Name',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.borderSubtleOf(context),
                    ),
                    borderRadius: AppRadius.inputBorder,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.textPrimaryOf(
                        context,
                      ).withValues(alpha: 0.22),
                    ),
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
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Genre',
                        labelStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      items: _genres
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
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
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Key',
                        labelStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      items: _keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
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
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'BPM',
                        labelStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
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
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Audio Provenance',
                        labelStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
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
                                  Text(
                                    p.displayName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _provenanceType = v ?? _provenanceType,
                      ),
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
                  onPressed: _isUploading ? null : _handleSubmit,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandContrast,
                          ),
                        )
                      : const PhosphorIcon(
                          PhosphorIconsRegular.paperPlaneRight,
                          color: AppColors.brandContrast,
                          size: 18,
                        ),
                  label: Text(
                    _isUploading
                        ? 'Uploading to Vault...'
                        : (_workflow == _UploadWorkflow.cameraReel
                              ? 'Open Camera Reel Recorder'
                              : 'Publish to Vault & Ecosystem'),
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
