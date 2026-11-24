import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/resilience/safe_audio_orchestrator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../media/domain/models/uploaded_media_asset.dart';
import '../../../media/presentation/providers/media_upload_queue_provider.dart';
import '../../../sound_signature/domain/services/audio_import_service.dart';
import '../../data/services/pre_gen_r2_upload_service.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';
import 'voice_clone_recorder_sheet.dart';

class ReferenceAudioDropzone extends ConsumerStatefulWidget {
  const ReferenceAudioDropzone({super.key});

  @override
  ConsumerState<ReferenceAudioDropzone> createState() =>
      _ReferenceAudioDropzoneState();
}

class _ReferenceAudioDropzoneState
    extends ConsumerState<ReferenceAudioDropzone> {
  bool _isExpanded = false;
  bool _isPlayingPreview = false;
  AudioPlayer? _previewPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;

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
  void dispose() {
    SafeAudioOrchestrator.instance.unregisterSlot(
      AudioEngineSlot.studioPreview,
    );
    unawaited(_playerStateSub?.cancel());
    if (!_isTestEnv) {
      unawaited(_previewPlayer?.dispose());
    }
    super.dispose();
  }

  Future<void> _pausePreview() async {
    if (!_isTestEnv && _previewPlayer != null) {
      await SafeAudioOrchestrator.guardAudioOp<void>(
        source: 'studio_dropzone_pause',
        action: () => _previewPlayer!.pause(),
      );
    }
    if (mounted) {
      setState(() => _isPlayingPreview = false);
    }
  }

  Future<void> _togglePreviewPlayback(String? audioSource) async {
    if (audioSource == null || audioSource.trim().isEmpty) return;
    unawaited(HapticFeedback.selectionClick());

    if (_isPlayingPreview) {
      await _pausePreview();
      SafeAudioOrchestrator.instance.releaseSlot(AudioEngineSlot.studioPreview);
      return;
    }

    if (_isTestEnv) {
      await SafeAudioOrchestrator.instance.acquireSlot(
        AudioEngineSlot.studioPreview,
        onPreemptPause: _pausePreview,
      );
      if (mounted) {
        setState(() => _isPlayingPreview = true);
      }
      return;
    }

    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.studioPreview,
      onPreemptPause: _pausePreview,
    );
    _previewPlayer ??= AudioPlayer();
    _playerStateSub ??= _previewPlayer!.playerStateStream.listen((playerState) {
      if (!mounted) return;
      if (playerState.processingState == ProcessingState.completed) {
        setState(() => _isPlayingPreview = false);
        SafeAudioOrchestrator.instance.releaseSlot(
          AudioEngineSlot.studioPreview,
        );
      }
    });

    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'studio_dropzone_play',
      action: () async {
        final trimmed = audioSource.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          await _previewPlayer!.setUrl(trimmed);
        } else {
          await _previewPlayer!.setFilePath(trimmed);
        }
        if (mounted) {
          setState(() => _isPlayingPreview = true);
        }
        await _previewPlayer!.play();
      },
    );
  }

  void _showUploadsPicker(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    final uploadedAudio = ref
        .read(mediaUploadQueueProvider)
        .where((a) => a.kind == MediaAssetKind.audio)
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderActive,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Attach from My Uploads',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reuse audio files stored in your Sovereign Media Vault.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (uploadedAudio.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        'No uploaded audio files in My Uploads yet.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final asset in uploadedAudio)
                          ListTile(
                            leading: const PhosphorIcon(
                              PhosphorIconsFill.fileAudio,
                              color: AppColors.brandPrimary,
                            ),
                            title: Text(
                              asset.title,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            subtitle: Text(
                              asset.filename,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            onTap: () {
                              final chosenSource =
                                  asset.bestPlayableOrRenderableSource ??
                                  asset.filename;
                              ref
                                  .read(studioFormProvider.notifier)
                                  .setReferenceAudio(chosenSource);
                              Navigator.of(sheetCtx).pop();
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBeatPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    final allTracks = ref.read(libraryTracksProvider);
    final licensed = allTracks
        .where(
          (t) =>
              !t.isDeleted &&
              (t.id.startsWith('market_') ||
                  (t.isInstrumental &&
                      t.licenseType.trim().isNotEmpty &&
                      t.licenseType != 'Commercial')),
        )
        .toList();
    final produced = ref.read(beatsProvider);
    final hasAny = licensed.isNotEmpty || produced.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark
          ? AppColors.darkSurfaceElevated
          : AppColors.lightSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderActive,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Select Backing Beat',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Select a licensed or produced beat to lock tempo, key, and style.',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!hasAny)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        'No beats found in your vault yet.',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (licensed.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Licensed Vault Beats',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.coinGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          for (final track in licensed)
                            ListTile(
                              leading: const PhosphorIcon(
                                AppIcons.beatstore,
                                color: AppColors.coinGold,
                              ),
                              title: Text(
                                track.title,
                                style: AppTypography.bodySmall,
                              ),
                              subtitle: Text(
                                '${track.creatorName} • ${track.genre} • ${track.licenseType}',
                                style: AppTypography.caption,
                              ),
                              onTap: () {
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setReferenceAudio(
                                      track.effectiveAudioPath ??
                                          track.remoteAudioUrl,
                                    );
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setGenre(track.genre);
                                ref
                                    .read(melodySketchpadProvider.notifier)
                                    .initializeFromRemixDna(genre: track.genre);
                                Navigator.of(bottomSheetContext).pop();
                              },
                            ),
                        ],
                        if (produced.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'My Produced Beats',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          for (final beat in produced)
                            ListTile(
                              leading: const PhosphorIcon(
                                AppIcons.waveform,
                                color: AppColors.brandPrimary,
                              ),
                              title: Text(
                                beat.title,
                                style: AppTypography.bodySmall,
                              ),
                              subtitle: Text(
                                '${beat.bpm} BPM • ${beat.musicalKey} • ${beat.genre}',
                                style: AppTypography.caption,
                              ),
                              onTap: () {
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setReferenceAudio(beat.previewAudioUrl);
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setGenre(beat.genre);
                                ref
                                    .read(melodySketchpadProvider.notifier)
                                    .initializeFromRemixDna(
                                      musicalKey: beat.musicalKey,
                                      bpm: beat.bpm,
                                      genre: beat.genre,
                                    );
                                Navigator.of(bottomSheetContext).pop();
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUploadAudio() async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      const importService = AudioImportService();
      final result = await importService.pickAndDecodeAudioFile();
      if (result == null || !mounted) {
        return;
      }
      final uploadedAsset = await ref
          .read(mediaUploadQueueProvider.notifier)
          .stageAndEnqueue(
            bytes: result.takeResult.wavBytes,
            filename: result.fileName,
            mimeType: 'audio/wav',
            kind: MediaAssetKind.audio,
            title: result.fileName,
            sourceSurface: 'studio',
          );
      if (!mounted) return;
      ref
          .read(studioFormProvider.notifier)
          .setReferenceAudio(
            uploadedAsset.bestPlayableOrRenderableSource ?? result.fileName,
          );
      final r2Url = await ref
          .read(preGenR2UploadServiceProvider)
          .uploadReferenceAudioStem(
            fileName: result.fileName,
            bytes: result.takeResult.wavBytes,
          );
      if (r2Url != null && r2Url.isNotEmpty && mounted) {
        ref.read(studioFormProvider.notifier).setReferenceAudio(r2Url);
      }
    } catch (err) {
      debugPrint('ReferenceAudioDropzone upload skipped: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final refAudioPath = ref.watch(
      studioFormProvider.select((s) => s.referenceAudioPath),
    );
    final audioMode = ref.watch(studioFormProvider.select((s) => s.audioMode));
    final language = ref.watch(studioFormProvider.select((s) => s.language));
    final attachedPattern = ref.watch(
      melodySketchpadProvider.select((s) => s.attachedPattern),
    );
    final isPlayingSketchpad = ref.watch(
      melodySketchpadProvider.select((s) => s.isPlayingPreview),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFile =
        (refAudioPath != null && refAudioPath.isNotEmpty) ||
        attachedPattern != null;

    return VhunambiGlassSurface(
      borderRadius: BorderRadius.circular(14),
      borderColorOverride: hasFile
          ? AppColors.brandPrimary.withValues(alpha: 0.6)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Full-width Header (Zero truncation of 'Reference Audio (optional)')
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                PhosphorIcon(
                  hasFile
                      ? PhosphorIconsFill.fileAudio
                      : PhosphorIconsRegular.waveform,
                  size: 16,
                  color: hasFile
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasFile
                        ? (refAudioPath ??
                              attachedPattern?.name ??
                              'Reference Audio (optional)')
                        : 'Reference Audio (optional)',
                    style: AppTypography.bodySmall.copyWith(
                      color: hasFile
                          ? AppColors.brandPrimary
                          : AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasFile && refAudioPath != null && refAudioPath.isNotEmpty)
                  IconButton(
                    key: const Key('dropzone_preview_audio_btn'),
                    icon: PhosphorIcon(
                      _isPlayingPreview
                          ? PhosphorIconsFill.pauseCircle
                          : PhosphorIconsFill.playCircle,
                      size: 20,
                    ),
                    color: AppColors.brandPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => _togglePreviewPlayback(refAudioPath),
                  ),
                if (hasFile)
                  IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    color: AppColors.error,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      unawaited(_pausePreview());
                      ref
                          .read(studioFormProvider.notifier)
                          .setReferenceAudio(null);
                      if (attachedPattern != null) {
                        ref
                            .read(melodySketchpadProvider.notifier)
                            .detachSongReference();
                      }
                    },
                  )
                else
                  PhosphorIcon(
                    _isExpanded
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
                    size: 15,
                    color: AppColors.textSecondaryOf(context),
                  ),
              ],
            ),
          ),

          if (attachedPattern != null) ...[
            const SizedBox(height: 6),
            Container(
              key: const Key('dropzone_active_sketchpad_badge'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(30),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.success.withAlpha(90)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        PhosphorIcon(
                          attachedPattern.instrument.icon,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${attachedPattern.name} (${attachedPattern.musicalKey})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => ref
                        .read(melodySketchpadProvider.notifier)
                        .togglePreviewPlayback(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: PhosphorIcon(
                        isPlayingSketchpad
                            ? PhosphorIconsFill.pauseCircle
                            : PhosphorIconsFill.playCircle,
                        size: 18,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => ref
                        .read(melodySketchpadProvider.notifier)
                        .detachSongReference(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: PhosphorIcon(
                        AppIcons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Row 2: Responsive Source Action Strip (Upload Audio, From My Uploads, Record Tune, My Beats, Sketchpad)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickActionPill(
                key: const Key('dropzone_upload_audio_btn'),
                icon: PhosphorIconsBold.uploadSimple,
                label: hasFile ? 'Swap Audio' : '+ Upload Audio',
                accentColor: AppColors.brandPrimary,
                isDark: isDark,
                onTap: _handleUploadAudio,
              ),
              _buildQuickActionPill(
                key: const Key('dropzone_from_uploads_btn'),
                icon: PhosphorIconsRegular.folderOpen,
                label: 'From My Uploads',
                accentColor: AppColors.brandPrimary,
                isDark: isDark,
                onTap: () => _showUploadsPicker(context),
              ),
              _buildQuickActionPill(
                key: const Key('dropzone_record_tune_btn'),
                icon: PhosphorIconsRegular.microphone,
                label: 'Record Tune',
                accentColor: AppColors.accentElectric,
                isDark: isDark,
                onTap: () =>
                    VoiceCloneRecorderSheet.show(context, language: language),
              ),
              _buildQuickActionPill(
                key: const Key('dropzone_load_licensed_beat_btn'),
                icon: PhosphorIconsFill.disc,
                label: 'My Beats',
                accentColor: AppColors.coinGold,
                isDark: isDark,
                onTap: () => _showBeatPicker(context),
              ),
              _buildQuickActionPill(
                key: const Key('dropzone_open_sketchpad_btn'),
                icon: PhosphorIconsRegular.pianoKeys,
                label: 'Sketchpad',
                accentColor: AppColors.brandSecondary,
                isDark: isDark,
                onTap: () {
                  MelodySketchpadModal.show(context);
                },
              ),
            ],
          ),

          // Row 3: 4 Recreate / Audio Mode Selector Tiles when reference audio is attached
          if (hasFile) ...[
            const SizedBox(height: 10),
            Text(
              'Recreate Mode',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mode in const <ReferenceAudioMode>[
                  ReferenceAudioMode.remix,
                  ReferenceAudioMode.cover,
                  ReferenceAudioMode.reference,
                  ReferenceAudioMode.inspiration,
                ])
                  InkWell(
                    key: Key('audio_mode_${mode.wireValue}'),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      ref.read(studioFormProvider.notifier).setAudioMode(mode);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 74,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: audioMode == mode
                            ? AppColors.brandPrimary.withValues(alpha: 0.16)
                            : AppColors.surfaceSecondaryOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: audioMode == mode
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtleOf(context),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.label,
                            style: AppTypography.caption.copyWith(
                              color: audioMode == mode
                                  ? AppColors.brandPrimary
                                  : AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            mode.description,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (_isExpanded) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _handleUploadAudio,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground.withValues(alpha: 0.45)
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFile
                        ? AppColors.brandPrimary
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(
                      hasFile
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.cloudArrowUp,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasFile
                            ? 'Attached: ${refAudioPath ?? attachedPattern?.name} (Tap to clear/swap)'
                            : 'Tap to attach reference WAV/MP3 stem (Max 50MB)',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionPill({
    required Key key,
    required IconData icon,
    required String label,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 13, color: accentColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
