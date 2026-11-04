import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../main.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_procedural_canvas.dart';
import '../widgets/onboarding_act1_showcase.dart';
import '../widgets/interactive_identity_card_stack.dart';
import '../widgets/onboarding_act3_roots_deck.dart';
import '../widgets/creator_dna_helix_finale.dart';

/// Phase 47: 4-Act Motion Graphics Onboarding & DNA Genesis View.
/// Zero forms, 60 FPS procedural vector backdrop, 3D stacked cards, and spinning DNA helix finale.
class OnboardingView extends ConsumerStatefulWidget {
  final VoidCallback? onFinish;

  const OnboardingView({super.key, this.onFinish});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _canvasAnimController;

  int _currentPage = 0;
  double _pageOffset = 0.0;
  final List<TouchRipple> _touchRipples = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_handlePageScroll);

    _canvasAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  void _handlePageScroll() {
    if (_pageController.hasClients && _pageController.page != null) {
      setState(() {
        _pageOffset = _pageController.page!;
      });
    }
  }

  void _addTouchRipple(Offset position) {
    setState(() {
      _touchRipples.add(
        TouchRipple(position: position, createdAt: DateTime.now()),
      );
      if (_touchRipples.length > 8) {
        _touchRipples.removeAt(0);
      }
    });
  }

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    final state = ref.read(onboardingStateProvider);

    // 1. Seed Creator DNA Profile in Hive
    ref
        .read(creatorDnaProvider.notifier)
        .seedFromOnboarding(
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

    // 2. Mark onboarding state as completed
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
    if (_currentPage < 3) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _pageOffset = page.toDouble();
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _canvasAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Continuous 60 FPS Procedural Motion Graphics Backdrop Canvas (REQ-P47-CANVAS-01..05)
          OnboardingProceduralBackdropCanvas(
            animation: _canvasAnimController,
            pageOffset: _pageOffset,
            touchRipples: _touchRipples,
          ),

          // 2. Main 4-Act Content Area
          SafeArea(
            child: Column(
              children: [
                // Top App Bar Row: Back, Logo, and Skip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        IconButton(
                          icon: PhosphorIcon(
                            PhosphorIconsRegular.caretLeft,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                        )
                      else
                        const SizedBox(width: 48),

                      Text(
                        'VHUNAMBI',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _finishOnboarding();
                        },
                        child: Text(
                          'Skip',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4-Act PageView
                Expanded(
                  child: Listener(
                    onPointerDown: (event) => _addTouchRipple(event.position),
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Act 1: Living Sonic Showcase (REQ-P47-ACT1-01)
                        OnboardingAct1Showcase(
                          onInteraction: () => HapticFeedback.selectionClick(),
                        ),

                        // Act 2: 3D Stacked Identity Deck (REQ-P47-ACT2-01..03)
                        Padding(
                          key: const Key('onboarding_act_2_identity_deck'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Claim Your Craft',
                                style: AppTypography.displayLarge.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Swipe or tap to focus your creative persona',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Center(
                                  child: InteractiveIdentityCardStack(
                                    selectedRole: onboardingState.creativeRole,
                                    onRoleChanged: (role) {
                                      notifier.setCreativeRole(role);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Act 3: Tactile Roots & Vibe Playground (REQ-P47-ACT3-01..03)
                        OnboardingAct3RootsDeck(
                          onInteraction: () => HapticFeedback.lightImpact(),
                        ),

                        // Act 4: Interactive 3D Double-Helix DNA Genesis (REQ-P47-ACT4-01..04)
                        CreatorDnaHelixFinale(
                          onLaunchStudio: _finishOnboarding,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Step Dots & Navigation Control (Hidden on Act 4 as it has dedicated full-width CTA)
                if (_currentPage < 3)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 4-Act Glowing Step Indicator
                        Row(
                          children: List.generate(4, (index) {
                            final isActive = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 6),
                              width: isActive ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.brandPrimary
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white24
                                          : Colors.black12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        // Primary [ Continue → ] Button
                        ElevatedButton(
                          key: const Key('onboarding_continue_btn'),
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Continue',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const PhosphorIcon(
                                PhosphorIconsBold.arrowRight,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
