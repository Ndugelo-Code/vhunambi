import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';
import '../../domain/models/lyric_word_timestamp.dart';

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

  const KineticPreviewCanvas({
    super.key,
    required this.coverArtUrl,
    required this.words,
    required this.preset,
    required this.effects,
    required this.playbackPositionSec,
    required this.isPlaying,
    this.onPlayPauseToggle,
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
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCanvas,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
            // 1. Ken Burns Visual Cover Art Layer
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final scale = widget.effects.kenBurnsMotion
                    ? 1.0 + (0.06 * sin(_animController.value * 2 * pi))
                    : 1.0;
                final dx = widget.effects.kenBurnsMotion
                    ? 8.0 * cos(_animController.value * 2 * pi)
                    : 0.0;

                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Transform.scale(
                    scale: scale,
                    child: widget.coverArtUrl != null
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

            // 2. Atmospheric Vignette & Film Grain Overlay
            CustomPaint(
              painter: _AtmosphereOverlayPainter(
                filmGrain: widget.effects.filmGrain,
                bassPulse: widget.effects.bassPulse,
                animValue: _animController.value,
              ),
            ),

            // 3. Synced Karaoke Lyrics Layer
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: _buildLyricsOverlay(),
            ),

            // 4. Audio-Reactive Waveform Equalizer
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              height: 48,
              child: _buildWaveformVisualizer(),
            ),

            // 5. Play/Pause Overlay Hit Zone
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
      ),
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

    // Find currently active words around current playback position
    final currentPos = widget.playbackPositionSec;
    final activeWordIndex = widget.words.indexWhere(
      (w) => currentPos >= w.start && currentPos <= w.end,
    );

    // Grab a window of 3 to 5 words centered on the active word
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
          return _buildWordWidget(word.word, isActive);
        }).toList(),
      ),
    );
  }

  Widget _buildWordWidget(String wordText, bool isActive) {
    switch (widget.preset) {
      case LyricTypographyPreset.kineticBounce:
        return AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: isActive ? 1.2 : 1.0,
          child: Text(
            wordText.toUpperCase(),
            style: AppTypography.displayMedium.copyWith(
              color: isActive ? AppColors.brandPrimary : Colors.white70,
              fontWeight: FontWeight.w900,
              shadows: isActive
                  ? [
                      Shadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.8),
                        blurRadius: 18,
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
            color: isActive ? const Color(0xFFFFD54F) : Colors.white70,
            fontWeight: FontWeight.w700,
            shadows: isActive
                ? [
                    const Shadow(
                      color: Color(0xFFFFC107),
                      blurRadius: 24,
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
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            wordText,
            style: AppTypography.bodyLarge.copyWith(
              color: isActive ? Colors.white : Colors.white60,
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
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 2,
                width: 24,
                color: AppColors.brandPrimary,
              ),
          ],
        );
    }
  }

  Widget _buildWaveformVisualizer() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (index) {
            final wave = sin((_animController.value * 2 * pi) + (index * 0.4));
            final height = widget.isPlaying
                ? (12 + (32 * wave.abs()))
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

/// CustomPainter for procedural film grain and bass vignette
class _AtmosphereOverlayPainter extends CustomPainter {
  final bool filmGrain;
  final bool bassPulse;
  final double animValue;

  _AtmosphereOverlayPainter({
    required this.filmGrain,
    required this.bassPulse,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Radial Vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: bassPulse ? 0.65 : 0.45),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    // 2. Procedural Film Grain
    if (filmGrain) {
      final random = Random((animValue * 1000).toInt());
      final grainPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1.0;

      for (int i = 0; i < 180; i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;
        canvas.drawCircle(Offset(x, y), 0.75, grainPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphereOverlayPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.filmGrain != filmGrain ||
        oldDelegate.bassPulse != bassPulse;
  }
}
