import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/master_media_object_provider.dart';
import '../providers/player_provider.dart';
import 'player_chromatic_resolver_mixin.dart';

/// Pill form — minimal floating pill with `PostChromaticPaletteResolver` reactive glow.
class PillForm extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;

  const PillForm({super.key, this.onExpand});

  @override
  ConsumerState<PillForm> createState() => _PillFormState();
}

class _PillFormState extends ConsumerState<PillForm>
    with SingleTickerProviderStateMixin, PlayerChromaticPaletteMixin<PillForm> {
  late AnimationController _glowController;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.5;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 33),
      vsync: this,
    );

    _startAmplitudeSampling();
  }

  void _startAmplitudeSampling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final isPlaying = ref.read(playerStateProvider).isPlaying;
      if (!isPlaying) {
        if (mounted && _currentAmplitude != 0.3) {
          setState(() => _currentAmplitude = 0.3);
        }
        return;
      }
      _sampleAmplitude();
    });
  }

  void _sampleAmplitude() {
    final playerState = ref.read(playerStateProvider);

    if (!playerState.isPlaying) {
      final breathe =
          (sin(DateTime.now().millisecondsSinceEpoch / 1000) + 1) / 2;
      if (mounted) {
        setState(() => _currentAmplitude = breathe * 0.5);
      }
      return;
    }

    final track = playerState.currentTrack;
    if (track != null) {
      final dna = SongMetadataDna.fromTrackInfo(
        id: track.id,
        title: track.title,
        genre: track.genre,
        language: track.language,
        durationSec: track.duration.inSeconds,
        coverUrl: track.coverUrl,
      );
      final mmo = ref.read(masterMediaObjectProvider(dna));
      final posMs = playerState.position.inMilliseconds;
      final amplitude = mmo.modulationBus.sampleStemCurve(
        mmo.modulationBus.masterRmsBytes,
        posMs,
      );
      if (mounted) {
        setState(() => _currentAmplitude = 0.2 + (amplitude * 0.8));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _currentAmplitude = 0.3 + (Random().nextDouble() * 0.7);
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _amplitudeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final palette = resolvePlayerChromaticPalette(context, track);
    final accent = palette.accent;
    final glowColor = palette.primaryGlow.withValues(
      alpha: 0.2 + (_currentAmplitude * 0.3),
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      onTap: widget.onExpand,
      child: Container(
        key: const Key('pill_chromatic_surface'),
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedOf(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.glassBorderTint, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: reduceMotion ? 0 : 16,
              spreadRadius: reduceMotion ? 0 : 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.primaryGlow.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: VhunambiTrackArtwork(
                key: const Key('pill_track_artwork'),
                coverUrl: track.coverUrl,
                genre: track.genre,
                trackId: track.id,
                width: 32,
                height: 32,
                borderRadius: BorderRadius.circular(16),
                badgeIconSize: 16,
                showSubtleBorder: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                track.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticsService().mediumImpact();
                ref.read(playerStateProvider.notifier).togglePlayPause();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: PhosphorIcon(
                    playerState.isPlaying ? AppIcons.pause : AppIcons.play,
                    color: palette.onAccent,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
