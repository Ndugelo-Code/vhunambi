import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/progress_tracker_provider.dart';
import '../providers/studio_form_provider.dart';
import 'song_dna_hover_pill.dart';

/// Progress tracker widget (VH-005).
///
/// Collapsed state: slim segmented bar (~8-12dp tall) showing the
/// filled/total ratio plus the living [SongDnaHoverPill] (REQ-P50-PILL-01).
/// Expanded state: scrollable list of all 9 slots with slot name, current
/// value, and state indicator (Empty / Set / Auto).
///
/// Derives all state from [StudioFormState] via [ProgressTracker] — no
/// duplicate state is cached (REQ-STM-01).
///
/// Uses genre accent tokens from [VhunambiThemeExtension] for the progress
/// bar fill, replacing legacy `AppColors.brandPrimary`.
class ProgressTrackerWidget extends ConsumerWidget {
  final bool expanded;

  const ProgressTrackerWidget({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(progressTrackerProvider);
    final genreString = ref.watch(studioFormProvider.select((s) => s.genre));
    final genre = _mapStringToGenre(genreString);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    if (expanded) {
      return _buildExpanded(tracker, accent);
    }

    return _buildCollapsed(tracker, accent);
  }

  /// Slim collapsed bar pinned under the mode tabs with living SongDnaHoverPill.
  Widget _buildCollapsed(ProgressTracker tracker, Color accent) {
    final filledCount = tracker.slots.where((s) => s.isSet).length;
    final total = tracker.slots.length;
    final ratio = tracker.completenessRatio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: AppRadius.pillBorder,
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Container(color: AppColors.surfaceSecondary),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(color: accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$filledCount / $total',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            // Living 3D Hovering Song DNA Pill (REQ-P50-PILL-01)
            const SongDnaHoverPill(),
          ],
        ),
      ],
    );
  }

  /// Expanded state: scrollable list of all slots.
  Widget _buildExpanded(ProgressTracker tracker, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generation Completeness',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: tracker.slots.length,
            itemBuilder: (context, index) {
              final slot = tracker.slots[index];
              final isEmpty = slot.stateLabel == 'Empty';
              return _buildSlotRow(slot, isEmpty, accent);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlotRow(ProgressSlot slot, bool isEmpty, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Semantics(
            label: '${slot.label}: ${slot.stateLabel}',
            child: SizedBox(
              width: 110,
              child: Text(
                slot.label,
                style: AppTypography.bodySmall.copyWith(
                  color: isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: isEmpty ? AppColors.surfaceSecondary : accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _stateColor(slot.stateLabel, accent).withAlpha(30),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: _stateColor(slot.stateLabel, accent)),
            ),
            child: Text(
              slot.stateLabel,
              style: AppTypography.caption.copyWith(
                color: _stateColor(slot.stateLabel, accent),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _stateColor(String stateLabel, Color accent) {
    switch (stateLabel) {
      case 'Empty':
        return AppColors.textTertiary;
      case 'Set':
        return accent;
      case 'Auto':
        return AppColors.badgeCyan;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Maps a free-form [genre] string from [StudioFormState] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
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
}
