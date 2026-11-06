import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';

class AdvancedOptionsAccordion extends ConsumerStatefulWidget {
  const AdvancedOptionsAccordion({super.key});

  @override
  ConsumerState<AdvancedOptionsAccordion> createState() =>
      _AdvancedOptionsAccordionState();
}

class _AdvancedOptionsAccordionState
    extends ConsumerState<AdvancedOptionsAccordion> {
  bool _isExpanded = false;

  static const List<String> _moods = [
    'Uplifting',
    'Spiritual',
    'Chill',
    'Party',
    'Romantic',
    'Melancholic',
    'Aggressive',
    'Nostalgic',
    'Triumphant',
    'Dark',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.4)
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsRegular.faders,
                          color: AppColors.brandPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Advanced Options',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${state.mood.isEmpty ? "Mood" : state.mood} • ${state.tempo.label.split(" ").first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PhosphorIcon(
                          _isExpanded
                              ? PhosphorIconsRegular.caretUp
                              : PhosphorIconsRegular.caretDown,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 16),

                  // 1. Mood (Compact 3-Column Wrap Chips — REQ-P56-COMP-03)
                  _buildSectionTitle('Mood', isDark),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _moods.map((m) {
                      final isSelected = state.mood == m;
                      return _buildCompactWrapChip(
                        label: m,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => notifier.selectMood(m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 2. Tempo (Compact 4-Segment Row)
                  _buildSectionTitle('Tempo', isDark),
                  const SizedBox(height: 6),
                  _buildSegmentedRow<TempoBracket>(
                    items: TempoBracket.values,
                    selected: state.tempo,
                    labelBuilder: (t) => t.label,
                    onSelect: notifier.setTempo,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // 3. Era / Production Style
                  _buildSectionTitle('Era / Production Style', isDark),
                  const SizedBox(height: 6),
                  _buildSegmentedRow<ProductionEra>(
                    items: ProductionEra.values,
                    selected: state.era,
                    labelBuilder: (e) => e.label,
                    onSelect: notifier.setEra,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // 4. Song Structure (Compact 2x2 / 4-Chip Wrap — REQ-P56-COMP-03)
                  _buildSectionTitle('Song Structure', isDark),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SongStructureType.values.map((s) {
                      final isSelected = state.structure == s;
                      return _buildCompactWrapChip(
                        label: s.label,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => notifier.setStructure(s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 5. Shortcut Pill to Voice Station (Vocal Ensemble/Gender/Energy unified in Tab 1)
                  InkWell(
                    key: const Key('advanced_jump_to_voice_station_btn'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(studioCockpitTabProvider.notifier).state =
                          CockpitWorkspaceTab.voice;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsBold.microphoneStage,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Voice Config: ${state.vocalConfiguration.label} • ${state.vocalGender.label} • ${state.vocalIntensity.label}',
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Edit in Voice →',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: AppTypography.caption.copyWith(
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCompactWrapChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedRow<T>({
    required List<T> items,
    required T selected,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelect,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        final isSelected = item == selected;
        return _buildCompactWrapChip(
          label: labelBuilder(item),
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => onSelect(item),
        );
      }).toList(),
    );
  }
}
