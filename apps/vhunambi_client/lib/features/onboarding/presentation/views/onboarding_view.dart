import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../main.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../../creator_dna/presentation/widgets/creative_role_card.dart';
import '../../../creator_dna/presentation/widgets/dna_genre_badge.dart';
import '../../../creator_dna/presentation/widgets/dna_strength_meter.dart';
import '../../../creator_dna/presentation/widgets/sound_signature_picker.dart';
import '../../domain/models/onboarding_models.dart';
import '../providers/onboarding_providers.dart';

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
    // Southern Africa
    'Amapiano',
    'Kwaito',
    'Gqom',
    'Maskandi',
    'Afro House',
    'Afro Tech',
    // West Africa
    'Afrobeats',
    'Highlife',
    'Fuji',
    'Afro Fusion',
    'Palm Wine',
    'Alté',
    // East & Central Africa
    'Bongo Flava',
    'Gengetone',
    'Soukous',
    'Taarab',
    'Singeli',
    'Rumba',
  ];

  static const _availableLanguages = [
    'Tshivenḓa',
    'isiZulu',
    'isiXhosa',
    'Afrikaans',
    'English',
    'Kiswahili',
    'Sepedi',
    'Yoruba',
    'Igbo',
    'Shona',
  ];

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    final state = ref.read(onboardingStateProvider);

    // 1. Seed Creator DNA Profile in Hive
    ref.read(creatorDnaProvider.notifier).seedFromOnboarding(
          role: state.creativeRole,
          experienceLevel: state.experienceLevel,
          selectedGenres: state.selectedGenres,
          primaryLanguage: state.primaryLanguage,
          secondaryLanguages: state.selectedLanguages
              .where((l) => l != state.primaryLanguage)
              .toList(),
          tempoPreference: state.tempoPreference,
          vocalEnergyPreference: state.vocalEnergyPreference,
          selectedMoods: state.selectedMoods,
          completeness: 1.0,
        );

    // 2. Mark legacy onboarding state as completed
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
    if (_currentPage < 5) {
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
                  // Slide 0: Welcome
                  _buildWelcomeSlide(),

                  // Slide 1: Creative Identity (Role & Experience)
                  _buildIdentitySlide(onboardingState),

                  // Slide 2: Genre Heritage
                  _buildGenreSlide(onboardingState),

                  // Slide 3: Language & Dialect
                  _buildLanguageSlide(onboardingState),

                  // Slide 4: Sound Signature (Tempo, Energy, Mood)
                  _buildSoundSignatureSlide(onboardingState),

                  // Slide 5: DNA Activation & Readiness
                  _buildDnaActivationSlide(onboardingState),
                ],
              ),
            ),

            // Bottom Navigation Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  // Step Indicator Dots (6 dots)
                  Row(
                    children: List.generate(6, (index) {
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
                    key: _currentPage == 5 ? const Key('onboarding_dna_activate_cta') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      elevation: 0,
                    ),
                    onPressed: _nextPage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 5
                              ? 'Activate Creator DNA ✨'
                              : 'Continue',
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

  // ---------------------------------------------------------------------------
  // SLIDE 0: Welcome
  // ---------------------------------------------------------------------------
  Widget _buildWelcomeSlide() {
    return SingleChildScrollView(
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
                  color: AppColors.brandPrimary.withValues(alpha: 0.25),
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
              _buildFeatureBadge(Icons.fingerprint_rounded, 'Adaptive Creator DNA'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 1: Creative Identity (Role & Experience Level)
  // ---------------------------------------------------------------------------
  Widget _buildIdentitySlide(OnboardingState state) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    final roles = [
      (CreativeRole.producer, 'producer', 'Producer / Beatmaker', '🎹', 'Crafting beats, melodies, and sonic textures'),
      (CreativeRole.vocalist, 'vocalist', 'Vocalist / Singer', '🎤', 'Writing hooks, harmonies, and toplines'),
      (CreativeRole.songwriter, 'songwriter', 'Songwriter / Lyricist', '✍️', 'Poetic lyricism and storytelling in native dialects'),
      (CreativeRole.multiHyphenate, 'multi_hyphenate', 'Multi-Hyphenate Artist', '⚡', 'Doing it all: production, vocals, and engineering'),
      (CreativeRole.musicLover, 'music_lover', 'Music Enthusiast', '🎧', 'Curating, discovering, and co-creating sounds'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Creative Identity',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us how you create so Vhunambi can adapt its cockpit to your workflow.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Role cards
          ...roles.map((r) {
            final isSelected = state.creativeRole == r.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CreativeRoleCard(
                roleKey: r.$2,
                label: r.$3,
                emoji: r.$4,
                description: r.$5,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setCreativeRole(r.$1);
                },
              ),
            );
          }),

          const SizedBox(height: 20),

          // Experience Level
          Text(
            'Experience Level',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildExpChip(
                key: const Key('onboarding_experience_newbie'),
                label: 'Beginner',
                isSelected: state.experienceLevel == ExperienceLevel.newbie,
                onTap: () => notifier.setExperienceLevel(ExperienceLevel.newbie),
              ),
              const SizedBox(width: 8),
              _buildExpChip(
                key: const Key('onboarding_experience_growing'),
                label: 'Intermediate',
                isSelected: state.experienceLevel == ExperienceLevel.growing,
                onTap: () => notifier.setExperienceLevel(ExperienceLevel.growing),
              ),
              const SizedBox(width: 8),
              _buildExpChip(
                key: const Key('onboarding_experience_pro'),
                label: 'Pro',
                isSelected: state.experienceLevel == ExperienceLevel.pro,
                onTap: () => notifier.setExperienceLevel(ExperienceLevel.pro),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: AppRadius.pillBorder,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 2: Genre Heritage
  // ---------------------------------------------------------------------------
  Widget _buildGenreSlide(OnboardingState state) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genre Heritage',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick the sounds that define your artistic roots and regional taste.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableGenres.map((genre) {
              final isSelected = state.selectedGenres.contains(genre);
              return FilterChip(
                key: Key('onboarding_genre_chip_$genre'),
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
                    color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 3: Language & Dialect Selection
  // ---------------------------------------------------------------------------
  Widget _buildLanguageSlide(OnboardingState state) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Language & Dialect',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your primary vocal language and secondary languages for lyrics generation.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          Text(
            'Primary Vocal Language',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableLanguages.map((language) {
              final isPrimary = state.primaryLanguage == language;
              return ChoiceChip(
                key: Key('onboarding_primary_language_$language'),
                label: Text(language),
                selected: isPrimary,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.setPrimaryLanguage(language);
                },
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  color: isPrimary ? AppColors.brandContrast : AppColors.textPrimary,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                  side: BorderSide(
                    color: isPrimary ? AppColors.brandPrimary : AppColors.borderSubtle,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Text(
            'Additional Lyric Languages',
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
                selectedColor: AppColors.surfaceSecondary,
                backgroundColor: AppColors.surfaceElevated,
                checkmarkColor: AppColors.brandPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                  side: BorderSide(
                    color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 4: Sound Signature (Tempo, Vocal Energy, Mood)
  // ---------------------------------------------------------------------------
  Widget _buildSoundSignatureSlide(OnboardingState state) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sound Signature',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your acoustic signature so the studio pre-fills with your natural groove.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SoundSignaturePicker(
            selectedTempo: state.tempoPreference,
            onTempoChanged: notifier.setTempoPreference,
            selectedVocalEnergy: state.vocalEnergyPreference,
            onVocalEnergyChanged: notifier.setVocalEnergyPreference,
            selectedMoods: state.selectedMoods,
            onMoodToggled: notifier.toggleMood,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 5: DNA Activation & Readiness
  // ---------------------------------------------------------------------------
  Widget _buildDnaActivationSlide(OnboardingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🧬', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '10 Free Credits + Creator DNA Seeded',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Creator DNA is Ready',
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vhunambi has synthesized your initial sound profile. Your studio will open pre-configured with your signature tuning and native dialect.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // DNA Preview Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Initial Model Strength',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const Text(
                      '25%',
                      style: TextStyle(
                        color: AppColors.badgeCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const DnaStrengthMeter(strengthPercent: 25, animated: false),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: state.selectedGenres.take(3).map((g) {
                    return DnaGenreBadge(genre: g, rank: 1);
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBenefitRow(Icons.lock_outline, '100% on-device sovereignty (zero cloud tracking)'),
          const SizedBox(height: 10),
          _buildBenefitRow(Icons.tune_rounded, 'Adaptive Studio defaults (Amapiano / tempo tuned)'),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(icon, color: AppColors.brandPrimary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
