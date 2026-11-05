import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/onboarding_models.dart';
import '../providers/onboarding_providers.dart';

/// Act 3: Generation-Aware Roots & Cultural Intelligence Deck (REQ-P49-ROOTS-01..06).
/// Features a non-scrolling 3-Tier layout:
/// Tier 1: Interactive Birth Year & Generation Era Dial
/// Tier 2: Cultural Tongues & Linguistic Roots Orbs
/// Tier 3: Era-Recommended African Genre Cards (✨ Era Match)
class OnboardingAct3RootsDeck extends ConsumerWidget {
  final VoidCallback? onInteraction;

  const OnboardingAct3RootsDeck({
    super.key,
    this.onInteraction,
  });

  static const List<String> kAvailableLanguages = [
    'Tshivenḓa',
    'isiZulu',
    'isiXhosa',
    'Afrikaans',
    'Sepedi',
    'Sesotho',
    'Setswana',
    'Xitsonga',
    'Kiswahili',
    'Yorùbá',
    'English',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      key: const Key('onboarding_act_3_roots_deck'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'African Genre Roots',
                style: AppTypography.bouncyTitleLarge.copyWith(
                  fontSize: 18,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${state.selectedGenres.length} active',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Calibrate your generational sound signature & cultural DNA',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 12),

          // Tier 1: Interactive Birth Year & Generation Era Dial (REQ-P49-ROOTS-01..03)
          _buildBirthYearTier(context, notifier, state, isDark),

          const SizedBox(height: 12),

          // Tier 2: Cultural Tongues & Linguistic Roots Orbs
          _buildCultureLanguageTier(context, notifier, state, isDark),

          const SizedBox(height: 12),

          // Tier 3: Era-Recommended African Genre Cards (REQ-P49-ROOTS-04..06)
          _buildEraGenreDeck(context, notifier, state, isDark),
        ],
      ),
    );
  }

  Widget _buildBirthYearTier(
    BuildContext context,
    OnboardingNotifier notifier,
    OnboardingState state,
    bool isDark,
  ) {
    final era = state.generationEra;
    final currentYear = state.birthYear;

    return Container(
      key: const Key('onboarding_birth_year_selector'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.badgeCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Birth Year & Generation Era',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.badgeCyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.badgeCyan.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  era.label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.badgeCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Year Drum Dial (1970 to 2018)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 49, // 1970 to 2018
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final year = 1970 + idx;
                final isSelected = year == currentYear;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onInteraction?.call();
                    notifier.setBirthYear(year);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  era.description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                key: const Key('onboarding_autotune_era_btn'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onInteraction?.call();
                  notifier.autotuneEraGenres();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.magicWand,
                        size: 13,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-Tune Era',
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
        ],
      ),
    );
  }

  Widget _buildCultureLanguageTier(
    BuildContext context,
    OnboardingNotifier notifier,
    OnboardingState state,
    bool isDark,
  ) {
    return Container(
      key: const Key('onboarding_culture_language_orbs'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white12 : Colors.black12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cultural & Linguistic Roots',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                '${state.selectedLanguages.length} tongues',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kAvailableLanguages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final lang = kAvailableLanguages[idx];
                final isSelected = state.selectedLanguages.contains(lang);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onInteraction?.call();
                    notifier.toggleLanguage(lang);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary.withValues(alpha: 0.18)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.translate,
                          size: 13,
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          lang,
                          style: AppTypography.caption.copyWith(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.textPrimaryOf(context),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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
      ),
    );
  }

  Widget _buildEraGenreDeck(
    BuildContext context,
    OnboardingNotifier notifier,
    OnboardingState state,
    bool isDark,
  ) {
    final eraRecs = state.generationEra.recommendedGenres;

    return Container(
      key: const Key('onboarding_era_genre_deck'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white12 : Colors.black12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Signature African Genres',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                'Auto-Era Highlighted',
                style: AppTypography.caption.copyWith(
                  color: AppColors.badgeCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2-row horizontal grid of 12 distinct genres
          SizedBox(
            height: 98,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                mainAxisExtent: 140,
              ),
              itemCount: kAfricanOnboardingGenres.length,
              itemBuilder: (context, idx) {
                final genre = kAfricanOnboardingGenres[idx];
                final isSelected = state.selectedGenres.contains(genre.name);
                final isEraMatch = eraRecs.contains(genre.name);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onInteraction?.call();
                    notifier.toggleGenre(genre.name);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? genre.accentColor.withValues(alpha: isDark ? 0.22 : 0.14)
                          : (isDark ? const Color(0xFF1C1C24) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? genre.accentColor
                            : (isEraMatch
                                ? AppColors.brandPrimary.withValues(alpha: 0.5)
                                : Colors.transparent),
                        width: isSelected ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: genre.accentColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                genre.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected
                                      ? genre.accentColor
                                      : AppColors.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isEraMatch)
                                const Text(
                                  '✨ Era Match',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                            ],
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
      ),
    );
  }
}
