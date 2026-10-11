import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/onboarding_models.dart';
import '../providers/onboarding_providers.dart';
import '../../../../main.dart';

class OnboardingView extends ConsumerStatefulWidget {
  final VoidCallback? onFinish;

  const OnboardingView({super.key, this.onFinish});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _availableGenres = [
    'Amapiano',
    'Kwaito',
    'Gqom',
    'Maskandi',
    'Afro House',
    'Afrobeats',
  ];

  static const _availableLanguages = [
    'Tshivenḓa',
    'isiZulu',
    'isiXhosa',
    'Afrikaans',
    'English',
    'Kiswahili',
    'Sepedi',
  ];

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    ref.read(onboardingStateProvider.notifier).completeOnboarding();
    if (widget.onFinish != null) {
      widget.onFinish!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RootShell(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingStateProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                  );
                },
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _finishOnboarding();
            },
            child: Text(
              'Skip',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Slide 0: Welcome & Heritage Audio Vision
                  _buildWelcomeSlide(),

                  // Slide 1: Genre & Language Preferences
                  _buildPreferencesSlide(onboardingState),

                  // Slide 2: Credits & Ownership Ready
                  _buildReadySlide(),
                ],
              ),
            ),

            // Bottom Navigation Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  // Step Indicator Dots
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.brandPrimary
                              : AppColors.surfaceSecondary,
                          borderRadius: AppRadius.pillBorder,
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Primary Action CTA
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      elevation: 0,
                    ),
                    onPressed: _nextPage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 2 ? 'Start Creating ✨' : 'Continue',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.brandContrast,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre('Amapiano'),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withAlpha(50),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Create Authentic African Music',
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Generate studio-grade productions tailored to African musical heritage—from Amapiano log drums to Maskandi acoustic guitar.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureBadge(Icons.translate_rounded, '25+ African Languages'),
              _buildFeatureBadge(Icons.graphic_eq_rounded, 'Native Rhythms'),
              _buildFeatureBadge(Icons.speed_rounded, 'Ready in 60s'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSlide(OnboardingState state) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalize Your Sound',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the rhythms and languages you want featured on your creator dashboard.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Genres Section
          Text(
            'Favorite Genres',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableGenres.map((genre) {
              final isSelected = state.selectedGenres.contains(genre);
              return FilterChip(
                label: Text(genre),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.toggleGenre(genre);
                },
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surfaceElevated,
                checkmarkColor: AppColors.brandContrast,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.brandContrast : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtle,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Languages Section
          Text(
            'Indigenous Languages',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableLanguages.map((language) {
              final isSelected = state.selectedLanguages.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.toggleLanguage(language);
                },
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surfaceElevated,
                checkmarkColor: AppColors.brandContrast,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.brandContrast : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtle,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadySlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Credit Gift Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withAlpha(25),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.brandPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '10 Free Song Credits Loaded',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'You’re Ready to Create',
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your studio is pre-configured with authentic African tuning and vocal models. You own 100% of what you create.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          _buildBenefitRow(Icons.music_note_rounded, 'Full song generation with verse, chorus & log drums'),
          const SizedBox(height: 14),
          _buildBenefitRow(Icons.layers_outlined, '4-Stem isolation (Vocals, Bass, Drums, Instruments)'),
          const SizedBox(height: 14),
          _buildBenefitRow(Icons.verified_rounded, 'Commercial license & instant export rights'),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.brandPrimary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(icon, color: AppColors.brandPrimary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
