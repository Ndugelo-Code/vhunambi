import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_view.dart';
import '../../../../main.dart';

class SplashView extends ConsumerStatefulWidget {
  final Duration duration;
  final VoidCallback? onFinished;

  const SplashView({
    super.key,
    this.duration = const Duration(milliseconds: 1600),
    this.onFinished,
  });

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    _timer = Timer(widget.duration, _onSplashComplete);
  }

  void _onSplashComplete() {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    final hasCompleted =
        ref.read(onboardingStateProvider).hasCompletedOnboarding;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return hasCompleted ? const RootShell() : const OnboardingView();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient splash hero backdrop with subtle dark gradient vignette
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: Image.asset(
                AppAssets.splashHero,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    AppColors.surfaceCanvas.withAlpha(120),
                    AppColors.surfaceCanvas.withAlpha(245),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Emblem with Ambient Soundwave Pulse Glow Rings
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer acoustic soundwave ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final p = _pulseController.value;
                            return Container(
                              width: 88 + (44 * p),
                              height: 88 + (44 * p),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.brandPrimary
                                      .withAlpha(((1.0 - p) * 90).toInt()),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Inner acoustic soundwave ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final p = ((_pulseController.value + 0.5) % 1.0);
                            return Container(
                              width: 88 + (28 * p),
                              height: 88 + (28 * p),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.brandPrimary
                                      .withAlpha(((1.0 - p) * 70).toInt()),
                                  width: 1.2,
                                ),
                              ),
                            );
                          },
                        ),
                        // Central Brand Emblem
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.brandPrimary.withAlpha(120),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimary.withAlpha(50),
                                blurRadius: 36,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                color: AppColors.brandPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  AppAssets.vhunambiGlyph,
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.music_note_rounded,
                                    color: AppColors.brandContrast,
                                    size: 34,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Brand Wordmark
                    Text(
                      'VHUNAMBI',
                      style: AppTypography.displayLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cultural Tshivenḓa Motto
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.brandPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'The talent to sing • Tshivenḓa',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.brandPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Subtle loading indicator
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: AppRadius.pillBorder,
                        child: const LinearProgressIndicator(
                          minHeight: 2.5,
                          backgroundColor: AppColors.surfaceSecondary,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brandPrimary,
                          ),
                        ),
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
