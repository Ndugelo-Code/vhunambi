import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

class BiomeTopBar extends StatelessWidget {
  final String trackTitle;
  final bool isPlaying;
  final bool isMuted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;

  const BiomeTopBar({
    super.key = const Key('biome_top_bar'),
    required this.trackTitle,
    required this.isPlaying,
    required this.isMuted,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;
        final capsuleMaxWidth = isMobile ? 148.0 : 240.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Sovereign DNA Emblem
              Container(
                width: isMobile ? 32 : 38,
                height: isMobile ? 32 : 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9E00).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF9E00).withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.dna,
                    color: const Color(0xFFFF9E00),
                    size: isMobile ? 15 : 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Left Title Column — Strictly Protected from 1-Char Vertical Squash (REQ-P56-BIOME-01)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'SONG DNA QUANTUM TREE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white70,
                              fontSize: isMobile ? 9.5 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF9E00,
                            ).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(
                                0xFFFF9E00,
                              ).withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            '3D BIOME',
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFFFF9E00),
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Explore the Living DNA of Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white54,
                        fontSize: isMobile ? 9.5 : 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Now Playing Transport Capsule — Bounded Width + Ellipsis (REQ-P56-BIOME-01)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: capsuleMaxWidth),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsBold.waveform,
                        color: Color(0xFFFF9E00),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Now Playing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white54,
                                fontSize: 8.5,
                              ),
                            ),
                            Text(
                              trackTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const Key('biome_play_pause_btn'),
                        onTap: onTogglePlay,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF9E00)),
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              isPlaying
                                  ? PhosphorIconsBold.pause
                                  : PhosphorIconsBold.play,
                              color: const Color(0xFFFF9E00),
                              size: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        key: const Key('biome_mute_btn'),
                        onTap: onToggleMute,
                        child: PhosphorIcon(
                          isMuted
                              ? PhosphorIconsBold.speakerSlash
                              : PhosphorIconsBold.speakerHigh,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('biome_close_btn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.x,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: onClose,
              ),
            ],
          ),
        );
      },
    );
  }
}
