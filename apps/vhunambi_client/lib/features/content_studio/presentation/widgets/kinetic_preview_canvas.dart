import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';
import '../../domain/models/lyric_word_timestamp.dart';
import '../providers/master_media_object_provider.dart';

/// 60 FPS real-time kinetic canvas rendering 9:16 vertical cover art,
/// synchronized karaoke typography, atmospheric shaders, and audio-reactive waveforms.
class KineticPreviewCanvas extends StatefulWidget {
  final String? coverArtUrl;
  final List<LyricWordTimestamp> words;
  final LyricTypographyPreset preset;
  final AtmosphericEffects effects;
  final double playbackPositionSec;
  final bool isPlaying;
  final VoidCallback? onPlayPauseToggle;
  final FrameModulationSnapshot? modulationSnapshot;

  /// When `true` (used inside `KineticReelsModal`), expands edge-to-edge
  /// without a rounded card frame and elevates the lyrics/waveform above the
  /// social caption & action rail.
  final bool fullScreen;

  /// Whether to render the internal tap-to-play InkWell overlay.
  /// Set to `false` inside `KineticReelsModal` where the parent gesture detector
  /// handles both single-tap play/pause and double-tap love bursts.
  final bool showInternalPlayOverlay;

  const KineticPreviewCanvas({
    super.key,
    required this.coverArtUrl,
    required this.words,
    required this.preset,
    required this.effects,
    required this.playbackPositionSec,
    required this.isPlaying,
    this.onPlayPauseToggle,
    this.modulationSnapshot,
    this.fullScreen = false,
    this.showInternalPlayOverlay = true,
  });

  @override
  State<KineticPreviewCanvas> createState() => _KineticPreviewCanvasState();
}

class _KineticPreviewCanvasState extends State<KineticPreviewCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    final isHeadlessTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isHeadlessTest) {
      _animController.value = 0.25;
    } else {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCoverUrl =
        widget.coverArtUrl != null && widget.coverArtUrl!.trim().isNotEmpty;

    final stackContent = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius:
            widget.fullScreen ? BorderRadius.zero : BorderRadius.circular(16),
        boxShadow: widget.fullScreen
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ken Burns Visual Cover Art Layer with Log Drum Snap-Zoom
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final snapZoom = widget.modulationSnapshot?.logDrumSnapZoom ?? 0.0;
              final bassEnergy =
                  widget.modulationSnapshot?.effectiveBassEnergy ?? 0.0;
              final kenBurnsScale = widget.effects.kenBurnsMotion
                  ? 1.0 + (0.06 * sin(_animController.value * 2 * pi))
                  : 1.0;
              // Exponential camera snap-zoom on log drum drop + subtle bass pump
              final scale = kenBurnsScale *
                  (1.0 + (0.12 * snapZoom) + (0.03 * bassEnergy));

              final dx = widget.effects.kenBurnsMotion
                  ? 8.0 * cos(_animController.value * 2 * pi)
                  : 0.0;

              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: scale,
                  child: hasCoverUrl
                      ? Image.network(
                          widget.coverArtUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackVisual(),
                        )
                      : _buildFallbackVisual(),
                ),
              );
            },
          ),

          // 2. Atmospheric Vignette, Film Grain & Bass Spark Particle Overlay
          CustomPaint(
            painter: _AtmosphereOverlayPainter(
              filmGrain: widget.effects.filmGrain,
              bassPulse: widget.effects.bassPulse,
              bassEnergy: widget.modulationSnapshot?.effectiveBassEnergy ?? 0.0,
              logDrumZoom: widget.modulationSnapshot?.logDrumSnapZoom ?? 0.0,
              animValue: _animController.value,
            ),
          ),

          // 3. Synced Karaoke Lyrics Layer with Bantu Bloom
          Positioned(
            left: 20,
            right: widget.fullScreen ? 84 : 20,
            bottom: widget.fullScreen ? 195 : 120,
            child: _buildLyricsOverlay(),
          ),

          // 4. Audio-Reactive Waveform Equalizer
          Positioned(
            left: widget.fullScreen ? 20 : 24,
            right: widget.fullScreen ? 84 : 24,
            bottom: widget.fullScreen ? 148 : 32,
            height: widget.fullScreen ? 36 : 48,
            child: _buildWaveformVisualizer(),
          ),

          // 5. Play/Pause Overlay Hit Zone (when enabled)
          if (widget.showInternalPlayOverlay)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPlayPauseToggle,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: widget.isPlaying ? 0.0 : 0.85,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brandPrimary.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 48,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.fullScreen) {
      return SizedBox.expand(child: stackContent);
    }

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: stackContent,
    );
  }

  Widget _buildFallbackVisual() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C1810),
            Color(0xFF0D0A08),
            Color(0xFF1A1208),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 64,
              color: AppColors.brandPrimary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'VHUNAMBI 9:16 COVER',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsOverlay() {
    if (widget.words.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '♪ Instrumental Rhythms & Harmonies ♪',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final currentPos = widget.playbackPositionSec;
    final activeWordIndex = widget.words.indexWhere(
      (w) => currentPos >= w.start && currentPos <= w.end,
    );

    final startIndex = activeWordIndex >= 0
        ? max(0, activeWordIndex - 2)
        : max(0, widget.words.indexWhere((w) => w.start > currentPos) - 2);
    final endIndex = min(widget.words.length, startIndex + 5);
    final displayedWords = widget.words.sublist(
      max(0, startIndex),
      max(0, endIndex),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: displayedWords.map((word) {
          final isActive = currentPos >= word.start && currentPos <= word.end;
          return _buildWordWidget(word, isActive);
        }).toList(),
      ),
    );
  }

  Widget _buildWordWidget(LyricWordTimestamp word, bool isActive) {
    final wordText = word.word;
    final vocalGlow = widget.modulationSnapshot?.effectiveVocalGlow ?? 0.8;
    final bloomRadius =
        (14.0 + (18.0 * vocalGlow * word.phoneticStress)).clamp(8.0, 32.0);
    final isIdiom = word.isCulturalIdiom;

    switch (widget.preset) {
      case LyricTypographyPreset.kineticBounce:
        return AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: isActive ? (isIdiom ? 1.3 : 1.2) : 1.0,
          child: Text(
            wordText.toUpperCase(),
            style: AppTypography.displayMedium.copyWith(
              color: isActive
                  ? (isIdiom ? AppColors.brandPrimary : const Color(0xFFFFA726))
                  : Colors.white70,
              fontWeight: FontWeight.w900,
              shadows: isActive
                  ? [
                      Shadow(
                        color: isIdiom
                            ? AppColors.brandPrimary.withValues(alpha: 0.95)
                            : AppColors.brandPrimary.withValues(alpha: 0.8),
                        blurRadius: bloomRadius,
                      ),
                    ]
                  : null,
            ),
          ),
        );

      case LyricTypographyPreset.luminousGlow:
        return Text(
          wordText,
          style: AppTypography.displayMedium.copyWith(
            color: isActive
                ? (isIdiom ? AppColors.brandPrimary : const Color(0xFFFFD54F))
                : Colors.white70,
            fontWeight: FontWeight.w700,
            shadows: isActive
                ? [
                    Shadow(
                      color: isIdiom
                          ? AppColors.brandPrimary.withValues(alpha: 0.95)
                          : const Color(0xFFFFC107),
                      blurRadius: bloomRadius,
                    ),
                    const Shadow(
                      color: Colors.white,
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );

      case LyricTypographyPreset.minimalSubtitle:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: isActive
              ? BoxDecoration(
                  color: isIdiom
                      ? AppColors.brandPrimary.withValues(alpha: 0.45)
                      : AppColors.brandPrimary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            wordText,
            style: AppTypography.bodyLarge.copyWith(
              color: isActive
                  ? (isIdiom ? AppColors.brandPrimary : Colors.white)
                  : Colors.white60,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );

      case LyricTypographyPreset.bantuCalligraphy:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              wordText,
              style: AppTypography.displayMedium.copyWith(
                color: isActive ? AppColors.brandPrimary : Colors.white70,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                shadows: isActive && isIdiom
                    ? [
                        Shadow(
                          color: AppColors.brandPrimary.withValues(alpha: 0.9),
                          blurRadius: bloomRadius,
                        ),
                      ]
                    : null,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: isIdiom ? 3 : 2,
                width: isIdiom ? 32 : 24,
                color: AppColors.brandPrimary,
              ),
          ],
        );
    }
  }

  Widget _buildWaveformVisualizer() {
    final drumsEnergy = widget.modulationSnapshot?.effectiveDrumsEnergy ?? 0.5;
    final bassEnergy = widget.modulationSnapshot?.effectiveBassEnergy ?? 0.5;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (index) {
            final wave = sin((_animController.value * 2 * pi) + (index * 0.4));
            final dynamicBoost = (index < 8) ? bassEnergy : drumsEnergy;
            final height = widget.isPlaying
                ? (12 + (24 * wave.abs() * (0.6 + 0.4 * dynamicBoost)))
                : (8.0 + (index % 4) * 3);

            return Container(
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(
                  alpha: widget.isPlaying ? 0.85 : 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// CustomPainter for procedural film grain, bass vignette, and transient spark particles
class _AtmosphereOverlayPainter extends CustomPainter {
  final bool filmGrain;
  final bool bassPulse;
  final double bassEnergy;
  final double logDrumZoom;
  final double animValue;

  _AtmosphereOverlayPainter({
    required this.filmGrain,
    required this.bassPulse,
    this.bassEnergy = 0.0,
    this.logDrumZoom = 0.0,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Radial Vignette with Bass Pumping
    final pulseFactor = bassPulse || bassEnergy > 0.25;
    final vignetteAlpha =
        pulseFactor ? (0.55 + 0.25 * bassEnergy).clamp(0.0, 0.85) : 0.45;

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: vignetteAlpha),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    final random = Random((animValue * 1000).toInt());

    // 2. Procedural Film Grain
    if (filmGrain) {
      final grainPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1.0;

      for (int i = 0; i < 180; i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;
        canvas.drawCircle(Offset(x, y), 0.75, grainPaint);
      }
    }

    // 3. Transient Spark Particles on heavy log drum and bass transients (REQ-MMO-12)
    final sparkEnergy = max(bassEnergy, logDrumZoom);
    if (sparkEnergy > 0.35) {
      final sparkCount = (sparkEnergy * 24).toInt();
      final sparkPaint = Paint()
        ..color = AppColors.brandPrimary
            .withValues(alpha: (sparkEnergy * 0.7).clamp(0.1, 0.75));

      for (int i = 0; i < sparkCount; i++) {
        final sx = random.nextDouble() * size.width;
        final sy =
            (size.height * 0.4) + (random.nextDouble() * size.height * 0.6);
        final radius =
            (1.0 + (random.nextDouble() * 2.0 * sparkEnergy)).clamp(0.5, 3.5);
        canvas.drawCircle(Offset(sx, sy), radius, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphereOverlayPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.filmGrain != filmGrain ||
        oldDelegate.bassPulse != bassPulse ||
        oldDelegate.bassEnergy != bassEnergy ||
        oldDelegate.logDrumZoom != logDrumZoom;
  }
}
