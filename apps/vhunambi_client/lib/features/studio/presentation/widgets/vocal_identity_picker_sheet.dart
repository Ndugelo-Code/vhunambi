import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/vocal_identity_models.dart';
import '../providers/vocal_identity_provider.dart';
import 'voice_clone_recorder_sheet.dart';

/// 24-Archetype Sovereign African Voice Catalog & Cloned Voices Picker Sheet (REQ-VOC-01..03, REQ-VOC-10).
class VocalIdentityPickerSheet extends ConsumerStatefulWidget {
  const VocalIdentityPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.90,
        child: VocalIdentityPickerSheet(),
      ),
    );
  }

  @override
  ConsumerState<VocalIdentityPickerSheet> createState() =>
      _VocalIdentityPickerSheetState();
}

class _VocalIdentityPickerSheetState
    extends ConsumerState<VocalIdentityPickerSheet> {
  bool _showClonedTab = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocalIdentityProvider);
    final notifier = ref.read(vocalIdentityProvider.notifier);

    return SafeArea(
      key: const Key('vocal_identity_picker_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.coinGold,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'African Vocal Identity Library',
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Active: ${state.activeVoiceDisplayLabel}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.coinGold,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('vocal_picker_close_btn'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Mode Tabs: Catalog (24) vs My Cloned Voices
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('vocal_tab_catalog'),
                    onTap: () => setState(() => _showClonedTab = false),
                    borderRadius: AppRadius.buttonBorder,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_showClonedTab
                            ? AppColors.brandPrimary
                            : AppColors.surfaceElevated,
                        borderRadius: AppRadius.buttonBorder,
                        border: Border.all(
                          color: !_showClonedTab
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'Regional Catalog (${state.catalog.length})',
                        style: AppTypography.bodySmall.copyWith(
                          color: !_showClonedTab
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: InkWell(
                    key: const Key('vocal_tab_cloned'),
                    onTap: () => setState(() => _showClonedTab = true),
                    borderRadius: AppRadius.buttonBorder,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _showClonedTab
                            ? AppColors.brandPrimary
                            : AppColors.surfaceElevated,
                        borderRadius: AppRadius.buttonBorder,
                        border: Border.all(
                          color: _showClonedTab
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'My Cloned Voices (${state.clonedProfiles.length})',
                        style: AppTypography.bodySmall.copyWith(
                          color: _showClonedTab
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (!_showClonedTab) ...[
              // Search input
              TextField(
                key: const Key('vocal_catalog_search_input'),
                onChanged: notifier.setSearchQuery,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search language, city, or accent (e.g. Tshivenḓa, Soweto, Lagos)...',
                  hintStyle: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorder,
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorder,
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Region Filter Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AfricanVoiceRegion.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final region = AfricanVoiceRegion.values[index];
                    final isSelected = state.selectedRegion == region;
                    return FilterChip(
                      key: Key('vocal_region_filter_${region.name}'),
                      selected: isSelected,
                      label: Text(
                        region.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selectedColor: AppColors.brandPrimary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                      onSelected: (_) => notifier.setRegionFilter(region),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // Gender Filter Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: VocalGender.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final gender = VocalGender.values[index];
                    final isSelected = state.selectedGender == gender;
                    return FilterChip(
                      key: Key('vocal_gender_filter_${gender.name}'),
                      selected: isSelected,
                      label: Text(
                        gender.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selectedColor: AppColors.coinGold,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.coinGold
                            : AppColors.borderSubtle,
                      ),
                      onSelected: (_) => notifier.setGenderFilter(gender),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Filtered Archetype List
              Expanded(
                child: ListView.separated(
                  itemCount: state.filteredCatalog.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final arch = state.filteredCatalog[index];
                    final isSelected =
                        !state.isUsingClonedVoice &&
                        state.activeArchetype.id == arch.id;
                    final isPreviewing = state.previewingArchetypeId == arch.id;

                    return InkWell(
                      key: Key('vocal_archetype_card_${arch.id}'),
                      onTap: () => notifier.selectArchetype(arch),
                      borderRadius: AppRadius.cardBorder,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceSecondary
                              : AppColors.surfaceElevated,
                          borderRadius: AppRadius.cardBorder,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.coinGold
                                : AppColors.borderSubtle,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    arch.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.coinGold.withAlpha(32),
                                    borderRadius: AppRadius.pillBorder,
                                  ),
                                  child: Text(
                                    '${arch.nativeLanguage} • ${arch.vocalRange}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.coinGold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  key: Key('preview_voice_btn_${arch.id}'),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  onPressed: () =>
                                      notifier.togglePreviewArchetype(arch.id),
                                  icon: Icon(
                                    isPreviewing
                                        ? Icons.stop_circle_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: isPreviewing
                                        ? AppColors.brandPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              arch.accentDescription,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${arch.region.label} • ${arch.deliveryStyle.label} • Master Cleanse: ${arch.recommendedCleanseFlavor.label}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Cloned Voices Tab
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('vocal_cloned_tab_new_btn'),
                  onPressed: () => VoiceCloneRecorderSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: Text(
                    'Record New 3-Line Voice Clone',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: state.clonedProfiles.isEmpty
                    ? Center(
                        child: Text(
                          'No cloned voices recorded yet.\nTap above or record directly after reviewing lyrics.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.clonedProfiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final profile = state.clonedProfiles[index];
                          final isActive =
                              state.activeClonedProfile?.id == profile.id;
                          return InkWell(
                            key: Key('cloned_voice_card_${profile.id}'),
                            onTap: () => notifier.selectClonedProfile(profile),
                            borderRadius: AppRadius.cardBorder,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.surfaceSecondary
                                    : AppColors.surfaceElevated,
                                borderRadius: AppRadius.cardBorder,
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.brandPrimary
                                      : AppColors.borderSubtle,
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: AppColors.brandPrimary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.creatorName,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${profile.nativeLanguage} • ${profile.cadenceWpm} WPM • ${(profile.clarityScore * 100).round()}% Clarity',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    key: Key(
                                      'delete_cloned_voice_${profile.id}',
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    onPressed: () => notifier
                                        .deleteClonedProfile(profile.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
