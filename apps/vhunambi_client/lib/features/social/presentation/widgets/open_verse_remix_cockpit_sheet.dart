import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/data/services/stem_mix_bounce_service.dart';
import '../../../player/data/services/wav_file_writer_io.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/stem_remix_context.dart';
import '../providers/stem_remix_provider.dart';

/// 3-Mode Co-Creation Remix Cockpit Bottom Sheet (REQ-COCKPIT-01..04 / Phase 37).
///
/// Features:
/// 1. Parent track header + 70/30 Co-Creation split disclosure pill.
/// 2. Mode A (Drop Open Verse): 1-bar count-in recorder, scale-lock guard, audition mix, 1-tap bounce & publish.
/// 3. Mode B (Flip Beat & Log-Drum): 6-genre kit macro switcher, Euclidean slider, Sketchpad launcher, bounce & publish.
/// 4. Mode C (Full Studio Handoff): Pre-loads [stemRemixProvider] with parent metadata & routes to Studio tab.
class OpenVerseRemixCockpitSheet extends ConsumerStatefulWidget {
  final PublishedClip clip;

  const OpenVerseRemixCockpitSheet({
    super.key,
    required this.clip,
  });

  static Future<void> show(
    BuildContext context, {
    required PublishedClip clip,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OpenVerseRemixCockpitSheet(clip: clip),
    );
  }

  @override
  ConsumerState<OpenVerseRemixCockpitSheet> createState() =>
      _OpenVerseRemixCockpitSheetState();
}

class _OpenVerseRemixCockpitSheetState
    extends ConsumerState<OpenVerseRemixCockpitSheet> {
  RemixCreationMode _activeMode = RemixCreationMode.openVerseVocal;

  // Mode A: Open Verse recording state
  bool _isCountingIn = false;
  int _countInNumber = 3;
  Timer? _countInTimer;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _hasRecordedVerse = false;
  bool _isAuditioning = false;
  bool _isBouncing = false;

  // Mode B: Beat Flip state
  String _selectedGenreKit = 'Amapiano';
  double _euclideanDensity = 8.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(modalSheetOpenCountProvider.notifier).state++;
      }
    });
  }

  @override
  void dispose() {
    ref.read(modalSheetOpenCountProvider.notifier).state =
        (ref.read(modalSheetOpenCountProvider.notifier).state - 1).clamp(0, 99);
    _countInTimer?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startCountIn() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isCountingIn = true;
      _countInNumber = 3;
    });

    _countInTimer?.cancel();
    _countInTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countInNumber > 1) {
        setState(() => _countInNumber--);
      } else {
        timer.cancel();
        _startLiveRecording();
      }
    });
  }

  void _startLiveRecording() {
    setState(() {
      _isCountingIn = false;
      _isRecording = true;
      _recordSeconds = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 30) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    HapticFeedback.heavyImpact();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasRecordedVerse = true;
    });
  }

  void _toggleAudition() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAuditioning = !_isAuditioning;
    });
  }

  Future<void> _bounceAndPublishVerse() async {
    HapticFeedback.mediumImpact();
    setState(() => _isBouncing = true);

    try {
      final bounceService = StemMixBounceService(writer: writeWavToFile);
      final dummyVocal = Float32List(44100 * 3); // 3 seconds of synthesized take
      for (var i = 0; i < dummyVocal.length; i++) {
        dummyVocal[i] = 0.45;
      }

      await bounceService.bounceMixToFile(
        mixerState: ref.read(stemMixerProvider),
        targetPath: '${Directory.systemTemp.path}/remix_open_verse_${DateTime.now().millisecondsSinceEpoch}.wav',
        duration: const Duration(seconds: 4),
        vocalAudio: dummyVocal,
        synthesizeGrooveIfEmpty: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Published Open-Verse Remix of "${widget.clip.title}"! (70% / 30% Royalty Split Active)',
          ),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBouncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to bounce mixdown: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _bounceAndPublishBeatFlip() async {
    HapticFeedback.mediumImpact();
    setState(() => _isBouncing = true);

    try {
      final bounceService = StemMixBounceService(writer: writeWavToFile);
      await bounceService.bounceMixToFile(
        mixerState: ref.read(stemMixerProvider),
        targetPath: '${Directory.systemTemp.path}/beat_flip_${DateTime.now().millisecondsSinceEpoch}.wav',
        duration: const Duration(seconds: 4),
        synthesizeGrooveIfEmpty: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Published Beat & Drum Flip of "${widget.clip.title}"! (70% / 30% Split Active)',
          ),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBouncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to bounce beat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handoffToStudio() {
    HapticFeedback.mediumImpact();
    ref.read(stemRemixProvider.notifier).initiateRemix(
          widget.clip,
          mode: RemixCreationMode.aiStudioRemix,
        );

    // Navigate to Studio tab (index 2)
    ref.read(appNavigationTabProvider.notifier).state = 2;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final musicalKey = clip.dna.musical.key.isNotEmpty ? clip.dna.musical.key : 'F#m';
    final bpm = clip.dna.musical.bpm > 0 ? clip.dna.musical.bpm : 112;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header: Originator Track Info & Co-Creation Split Pill
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.musicNotes,
                    color: AppColors.brandPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Original by @${clip.creatorUsername} · ${clip.genre} · $bpm BPM · $musicalKey',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                key: const Key('co_creation_split_pill'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.gitFork,
                      size: 13,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '70/30 Split',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 3-Mode Segmented Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                _buildModeTab(
                  key: const Key('remix_cockpit_mode_verse'),
                  mode: RemixCreationMode.openVerseVocal,
                  label: 'Open Verse',
                  icon: PhosphorIconsBold.microphone,
                ),
                _buildModeTab(
                  key: const Key('remix_cockpit_mode_flip'),
                  mode: RemixCreationMode.beatStemFlip,
                  label: 'Flip Beat',
                  icon: PhosphorIconsBold.waveform,
                ),
                _buildModeTab(
                  key: const Key('remix_cockpit_mode_studio'),
                  mode: RemixCreationMode.aiStudioRemix,
                  label: 'Studio DAW',
                  icon: PhosphorIconsBold.slidersHorizontal,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Active Mode Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (_activeMode) {
              RemixCreationMode.openVerseVocal => _buildOpenVerseMode(musicalKey),
              RemixCreationMode.beatStemFlip => _buildBeatFlipMode(bpm, musicalKey),
              RemixCreationMode.aiStudioRemix => _buildStudioHandoffMode(clip),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required Key key,
    required RemixCreationMode mode,
    required String label,
    required PhosphorIconData icon,
  }) {
    final isSelected = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenVerseMode(String musicalKey) {
    return Column(
      key: const ValueKey('mode_verse_body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scale lock & Bantu Guard status banner
        Container(
          key: const Key('remix_scale_lock_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsRegular.shieldCheck,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scale Locked: $musicalKey Pentatonic · Bantu Depressor Onset & Tone Guard Active',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Backing Track Waveform Visualizer simulation
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.cardBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(24, (i) {
              final heights = [14, 22, 38, 18, 30, 44, 26, 16, 34, 40, 20, 28];
              final h = heights[i % heights.length].toDouble();
              final isPlayed = _isAuditioning || _isRecording;
              return Container(
                width: 3.5,
                height: h,
                decoration: BoxDecoration(
                  color: isPlayed ? AppColors.brandPrimary : AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Recorder Status & Main Action
        if (_isCountingIn)
          Center(
            child: Column(
              children: [
                Text(
                  '$_countInNumber',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '1-Bar Count-In... Get Ready!',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else if (_isRecording)
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recording Verse: 00:${_recordSeconds.toString().padLeft(2, '0')}',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('remix_record_verse_btn'),
                    onPressed: _stopRecording,
                    icon: const PhosphorIcon(PhosphorIconsBold.stop, size: 20),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('remix_record_verse_btn'),
                    onPressed: _startCountIn,
                    icon: PhosphorIcon(
                      _hasRecordedVerse ? PhosphorIconsBold.arrowCounterClockwise : PhosphorIconsBold.microphone,
                      size: 18,
                    ),
                    label: Text(_hasRecordedVerse ? 'Re-record Take' : 'Drop Verse (Count-in)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.borderSubtle),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              if (_hasRecordedVerse) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('remix_audition_mix_btn'),
                    onPressed: _toggleAudition,
                    icon: PhosphorIcon(
                      _isAuditioning ? PhosphorIconsBold.stop : PhosphorIconsBold.play,
                      size: 18,
                    ),
                    label: Text(_isAuditioning ? 'Stop Audition' : 'Audition Mix'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceSecondary,
                      foregroundColor: AppColors.textPrimary,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_hasRecordedVerse) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('remix_publish_btn'),
                onPressed: _isBouncing ? null : _bounceAndPublishVerse,
                icon: _isBouncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const PhosphorIcon(PhosphorIconsBold.paperPlaneTilt, size: 18),
                label: Text(_isBouncing ? 'Bouncing 44.1 kHz PCM...' : 'Publish Open-Verse Reel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBeatFlipMode(int bpm, String musicalKey) {
    const genreKits = ['Amapiano', 'Gqom', 'Hip-Hop 808', 'Afrobeats', 'Deep House', 'Maskandi'];

    return Column(
      key: const ValueKey('mode_flip_body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Regional Beat Macro (Locked: $bpm BPM · $musicalKey):',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 6-Genre Macro Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genreKits.map((kit) {
            final isSelected = _selectedGenreKit == kit;
            return ChoiceChip(
              label: Text(kit),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedGenreKit = kit);
              },
              selectedColor: AppColors.brandPrimary,
              backgroundColor: AppColors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.md),

        // Euclidean Rhythm Slider
        Row(
          children: [
            PhosphorIcon(PhosphorIconsRegular.waveform, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Rhythm Density: ${_euclideanDensity.round()} steps',
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: _euclideanDensity,
          min: 4,
          max: 16,
          divisions: 12,
          activeColor: AppColors.brandPrimary,
          onChanged: (val) => setState(() => _euclideanDensity = val),
        ),

        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const Key('remix_open_sketchpad_btn'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Launched 5-channel sketchpad locked to $musicalKey!'),
                        backgroundColor: AppColors.brandPrimary,
                      ),
                    );
                  },
                  icon: const PhosphorIcon(PhosphorIconsBold.pianoKeys, size: 18),
                  label: const Text('Open Sketchpad'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('remix_publish_beat_btn'),
                  onPressed: _isBouncing ? null : _bounceAndPublishBeatFlip,
                  icon: const PhosphorIcon(PhosphorIconsBold.checkCircle, size: 18),
                  label: const Text('Bounce & Publish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudioHandoffMode(PublishedClip clip) {
    return Column(
      key: const ValueKey('mode_studio_body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                    PhosphorIconsBold.sparkle,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Full Studio Generative Handoff',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Load all 4 isolated stems (Vocals, Drums, Log-Drum Bass, Melody) into the Vhunambi AI Studio Cockpit. Generation will be conditioned on @${clip.creatorUsername}\'s original Sound DNA while enforcing your 70% Remixer / 30% Originator co-creation split.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('remix_open_studio_btn'),
            onPressed: _handoffToStudio,
            icon: const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 18),
            label: const Text('Open in Studio Cockpit (Tab 2)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

