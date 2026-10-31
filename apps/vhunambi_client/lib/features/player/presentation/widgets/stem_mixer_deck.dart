import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/stem_mixer_state.dart';
import '../providers/audio_bridge_providers.dart';
import '../providers/multi_stem_audio_provider.dart';
import '../providers/player_provider.dart';
import '../providers/stem_mixer_provider.dart';
import '../../../mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import '../../../mastering/presentation/views/desktop_mastering_studio_view.dart';
import '../../../beats/presentation/providers/beats_provider.dart';

/// Pocket 4-Channel Stem Mixer & Master Bus DSP console (REQ-MIX-01 … 05, REQ-STEM-AUDIO-01 .. 06).
///
/// Tactile DAW-style mixing surface for balancing separated stems, applying
/// Bantu master-bus processing, auditioning with inter-channel drift badges,
/// and preview bouncing.
class StemMixerDeck extends ConsumerStatefulWidget {
  final String? title;
  final String? masterUrl;
  final Map<StemType, String>? stemUrls;

  const StemMixerDeck({super.key, this.title, this.masterUrl, this.stemUrls});

  @override
  ConsumerState<StemMixerDeck> createState() => _StemMixerDeckState();
}

class _StemMixerDeckState extends ConsumerState<StemMixerDeck> {
  bool _wasMasterPlaying = false;

  @override
  void initState() {
    super.initState();
    // Transport handshake (T6b): Pause master player when entering the stem deck.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final handler = ref.read(audioHandlerProvider);
        if (handler.currentPlaybackState.playing) {
          _wasMasterPlaying = true;
          handler.pause();
        }
      } catch (_) {}

      _autoHydrateStems();
    });
  }

  Future<void> _autoHydrateStems() async {
    final engine = ref.read(multiStemAudioEngineProvider);
    if (widget.stemUrls != null && widget.stemUrls!.isNotEmpty) {
      await engine.loadFromManifest(
        masterUrl: widget.masterUrl ?? '',
        stemUrls: widget.stemUrls!,
      );
      if (mounted) setState(() {});
      return;
    }

    try {
      if (ref.exists(playerStateProvider)) {
        final current = ref.read(playerStateProvider).currentTrack;
        if (current != null && current.hasRealStems) {
          await engine.loadFromManifest(
            masterUrl: current.audioUrl ?? '',
            stemUrls: current.stemUrls!,
          );
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Restore master transport on exit if it was playing beforehand.
    if (_wasMasterPlaying) {
      try {
        ref.read(audioHandlerProvider).play();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stemMixerProvider);
    final engine = ref.watch(multiStemAudioEngineProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final hasRealStems = engine.hasRealStems;

    final strips = [
      for (final channel in state.channels)
        _ChannelStrip(channel: channel, isInteractive: hasRealStems),
    ];

    return Container(
      color: AppColors.surfaceCanvas,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Transport
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title ?? 'Pocket Stem Mixer',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '4-Channel Console & Master DSP',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play / Pause Audition Button (T9)
                StreamBuilder<bool>(
                  stream: engine.isPlayingStream,
                  initialData: engine.isPlaying,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      key: const Key('stem_mixer_play_pause_btn'),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: AppColors.brandPrimary,
                        size: 28,
                      ),
                      tooltip: isPlaying ? 'Pause Audition' : 'Play Audition',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isPlaying) {
                          engine.pause();
                        } else {
                          engine.play();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 4),

                // Measured Drift / Mode Badge (T9)
                if (!hasRealStems)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Master Only',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final driftMs = (engine.measuredDrift ?? Duration.zero)
                          .inMilliseconds;
                      final isSynced = driftMs <= 40;
                      final color = isSynced
                          ? AppColors.success
                          : AppColors.accentGold;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSynced
                                  ? Icons.sync_rounded
                                  : Icons.sync_problem_rounded,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '±${driftMs}ms ${isSynced ? 'Sync' : 'Resyncing'}',
                              style: AppTypography.caption.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 8),

                TextButton(
                  key: const Key('mixer_reset_btn'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(stemMixerProvider.notifier).resetMix();
                  },
                  child: Text(
                    'Reset',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),

            // Master-Only Banner (T9)
            if (!hasRealStems) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('stem_master_only_banner'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.accentGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Master-Only Mode: Stems are unavailable or processing on the cloud GPU worker. Channel strips are locked to master balance.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Channel strips
            SizedBox(
              height: 330,
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: strips,
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      children: strips,
                    ),
            ),
            const SizedBox(height: AppSpacing.md),

            _MasterDspSection(title: widget.title),
          ],
        ),
      ),
    );
  }
}

class _ChannelStrip extends ConsumerWidget {
  final StemChannel channel;
  final bool isInteractive;

  const _ChannelStrip({required this.channel, required this.isInteractive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stemMixerProvider.notifier);
    final type = channel.type;

    return Opacity(
      opacity: isInteractive ? 1.0 : 0.45,
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Text(channel.emoji, style: const TextStyle(fontSize: 20)),
            Text(
              channel.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
              ),
              child: Text(
                channel.gainDecibels,
                style: AppTypography.caption.copyWith(
                  color: AppColors.coinGold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 92,
              child: RotatedBox(
                quarterTurns: 3,
                child: Semantics(
                  label: '${channel.name} volume',
                  value: channel.gainDecibels,
                  child: Slider(
                    key: Key('fader_${type.name}'),
                    value: channel.gain.clamp(0.0, 1.5),
                    min: 0.0,
                    max: 1.5,
                    activeColor: AppColors.brandPrimary,
                    inactiveColor: AppColors.surfaceSecondary,
                    onChanged: isInteractive
                        ? (v) {
                            HapticFeedback.selectionClick();
                            notifier.setChannelGain(type, v);
                          }
                        : null,
                  ),
                ),
              ),
            ),
            Semantics(
              label: '${channel.name} stereo pan',
              child: Slider(
                key: Key('pan_${type.name}'),
                value: channel.pan.clamp(-1.0, 1.0),
                min: -1.0,
                max: 1.0,
                activeColor: AppColors.badgeCyan,
                inactiveColor: AppColors.surfaceSecondary,
                onChanged: isInteractive
                    ? (v) {
                        HapticFeedback.selectionClick();
                        notifier.setChannelPan(type, v);
                      }
                    : null,
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'L',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                ),
                Text(
                  'C',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                ),
                Text(
                  'R',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  enabled: isInteractive,
                  label: '${channel.name} mute button',
                  child: _MsButton(
                    key: Key('mute_${type.name}'),
                    label: 'M',
                    active: channel.isMuted,
                    activeColor: AppColors.error,
                    onTap: isInteractive
                        ? () {
                            HapticFeedback.mediumImpact();
                            notifier.toggleMute(type);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  enabled: isInteractive,
                  label: '${channel.name} solo button',
                  child: _MsButton(
                    key: Key('solo_${type.name}'),
                    label: 'S',
                    active: channel.isSolo,
                    activeColor: AppColors.coinGold,
                    onTap: isInteractive
                        ? () {
                            HapticFeedback.mediumImpact();
                            notifier.toggleSolo(type);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MsButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _MsButton({
    super.key,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : AppColors.surfaceSecondary,
          borderRadius: AppRadius.thumbBorder,
          border: Border.all(
            color: active ? activeColor : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: active ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MasterDspSection extends ConsumerWidget {
  final String? title;

  const _MasterDspSection({this.title});

  static const List<String> _presets = [
    'Amapiano Club Banger',
    'Deep Maskandi Acoustic',
    'Clean Vocal Duet',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stemMixerProvider);
    final notifier = ref.read(stemMixerProvider.notifier);
    final dsp = state.masterDsp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.coinGold,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Master Bus DSP',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _DspSlider(
          label: 'Log Drum Saturation',
          value: dsp.logDrumSaturation,
          max: 1.0,
          onChanged: (v) =>
              notifier.updateMasterDsp(dsp.copyWith(logDrumSaturation: v)),
        ),
        _DspSlider(
          label: 'Vocal Plate Reverb',
          value: dsp.vocalPlateReverb,
          max: 1.0,
          onChanged: (v) =>
              notifier.updateMasterDsp(dsp.copyWith(vocalPlateReverb: v)),
        ),
        _DspSlider(
          label: 'Sidechain Compression',
          value: dsp.sidechainCompression,
          max: 1.0,
          onChanged: (v) =>
              notifier.updateMasterDsp(dsp.copyWith(sidechainCompression: v)),
        ),
        _DspSlider(
          label: 'Stereo Width',
          value: dsp.stereoWidth,
          max: 1.5,
          onChanged: (v) =>
              notifier.updateMasterDsp(dsp.copyWith(stereoWidth: v)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preset in _presets)
              ActionChip(
                key: Key('preset_$preset'),
                label: Text(
                  preset,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                backgroundColor: AppColors.surfaceSecondary,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.applyPreset(preset);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          key: const Key('mixer_bounce_btn'),
          onPressed: state.isBouncing
              ? null
              : () async {
                  HapticFeedback.heavyImpact();
                  try {
                    final result = await notifier.bounceMasterMix();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.isSimulated
                              ? 'Preview bounce created (simulated WAV). Real stems pending.'
                              : 'Master mix bounced to ${result.path}!',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to bounce mix: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            minimumSize: const Size.fromHeight(50),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.inputBorder,
            ),
          ),
          icon: const Icon(
            Icons.download_rounded,
            color: AppColors.brandContrast,
          ),
          label: Text(
            state.isBouncing ? 'Bouncing…' : 'Preview bounce',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.brandContrast,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('stem_mixer_open_mastering_btn'),
          onPressed: () {
            HapticFeedback.lightImpact();
            final isDesktop = ResponsiveUtils.isDesktop(context);
            if (isDesktop) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DesktopMasteringStudioView(
                    trackTitle: title ?? 'Active Master',
                    genre: 'Amapiano',
                  ),
                ),
              );
            } else {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.9,
                  child: MobileQuickMasterSheet(
                    trackTitle: title ?? 'Active Master',
                    genre: 'Amapiano',
                  ),
                ),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.brandPrimary),
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.inputBorder,
            ),
          ),
          icon: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.brandPrimary,
          ),
          label: Text(
            '✨ Master Track (Studio Polisher)',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('stem_mixer_list_beat_btn'),
          onPressed: () {
            HapticFeedback.lightImpact();
            final currentTrack = ref.read(playerStateProvider).currentTrack;
            final beatTitle = title ?? currentTrack?.title ?? 'Instrumental Master Mix';
            ref.read(beatsProvider.notifier).createBeat(
                  title: beatTitle,
                  genre: currentTrack?.genre ?? 'Amapiano',
                  bpm: 115,
                  musicalKey: 'F# Minor',
                  priceInCredits: 10,
                  previewAudioUrl: currentTrack?.audioUrl ?? '',
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Listed "$beatTitle" in your Beats Vault! 💰'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.coinGold),
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.inputBorder,
            ),
          ),
          icon: const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.coinGold,
          ),
          label: Text(
            '💰 List in Beatstore',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.coinGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _DspSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _DspSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, max),
            min: 0.0,
            max: max,
            activeColor: AppColors.coinGold,
            inactiveColor: AppColors.surfaceSecondary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
