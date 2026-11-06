import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../../domain/models/mycelium_biome_models.dart';

class SongJourneyTimelineScrubber extends StatelessWidget {
  final SongJourneySection activeSection;
  final ValueChanged<SongJourneySection> onSelectSection;

  const SongJourneyTimelineScrubber({
    super.key = const Key('biome_song_journey_scrubber'),
    required this.activeSection,
    required this.onSelectSection,
  });

  static const Map<SongJourneySection, Color> _sectionColors = {
    SongJourneySection.intro: Color(0xFF00B4D8),
    SongJourneySection.verse: Color(0xFFFF9E00),
    SongJourneySection.chorus: Color(0xFFFF9E00),
    SongJourneySection.bridge: Color(0xFF9D4EDD),
    SongJourneySection.outro: Color(0xFF10B981),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.waveform,
                color: Color(0xFFFF9E00),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Song Journey',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: SongJourneySection.values.map((section) {
              final isSelected = section == activeSection;
              final dotColor = _sectionColors[section]!;
              return GestureDetector(
                key: Key('biome_section_${section.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectSection(section);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isSelected ? 16 : 11,
                        height: isSelected ? 16 : 11,
                        decoration: BoxDecoration(
                          color: isSelected ? dotColor : AppColors.darkSurfaceCanvas,
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor, width: 2.0),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: dotColor.withValues(alpha: 0.65),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
