import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/design_system/theme/vhunambi_theme_extension.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/master_media_object_provider.dart';
import '../providers/player_provider.dart';

/// Pill form — minimal floating pill with cover-art reactive glow.
///
/// Displays circular cover art (32dp), track title, and play/pause orb.
/// Glow intensity is driven by simulated waveform amplitude sampling at 30fps.
/// When paused, a static breathe animation displays. Glow respects reduce-motion.
class PillForm extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;

  const PillForm({super.key, this.onExpand});

  @override
  ConsumerState<PillForm> createState() => _PillFormState();
}

class _PillFormState extends ConsumerState<PillForm>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.5;
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 33),
      vsync: this,
    );

    _startAmplitudeSampling();
    _extractDominantColor();
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

  Future<void> _extractDominantColor() async {
    final playerState = ref.read(playerStateProvider);
    final track = playerState.currentTrack;
    if (track == null || track.coverUrl == null) return;

    try {
      final provider = NetworkImage(track.coverUrl!);
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(32, 32),
      );
      if (mounted && palette.dominantColor != null) {
        setState(() => _dominantColor = palette.dominantColor!.color);
      }
    } catch (_) {
      // Fall back to genre accent color.
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

    final genre = _mapStringToGenre(track.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = _dominantColor ?? extension.genreAccent(genre);

    final glowColor = accent.withValues(alpha: 0.2 + (_currentAmplitude * 0.3));
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      onTap: widget.onExpand,
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedOf(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
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
                gradient: _genreGradient(track.genre),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: PhosphorIcon(
                  AppIcons.songs,
                  size: 16,
                  color: Colors.white,
                ),
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
                    color: Colors.white,
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

  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }

  LinearGradient _genreGradient(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
      ),
      'afro house' => const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
      ),
      'afrohouse' => const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
      ),
      'gqom' => const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      ),
      'kwaito' => const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
      ),
      'afro pop' => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      'afropop' => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      'afrobeats' => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      'afro beats' => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      'maskandi' => const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981)],
      ),
      'hip hop' => const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      ),
      'hiphop' => const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      ),
      'gospel' => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
      ),
      _ => const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
    };
  }
}
