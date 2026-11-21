import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../main.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_view.dart';

/// Tracks whether the application is currently presenting the splash sequence (REQ-P47-BUG-01).
final isSplashActiveProvider = StateProvider<bool>((ref) => true);

/// Phase 68.5 Cinema Splash Screen showcasing the full-bleed `Vhunambi` sunset
/// artwork backdrop, blended central `V` emblem, `Music • Create • Socialize`
/// motto, animated progress sweep, and compact `Madoni Software` attribution.
class SplashView extends ConsumerStatefulWidget {
  final Duration duration;
  final VoidCallback? onFinished;

  const SplashView({
    super.key,
    this.duration = const Duration(milliseconds: 2000),
    this.onFinished,
  });

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with TickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _animController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _footerFadeAnimation;
  late final Animation<double> _backdropScaleAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _footerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
      ),
    );

    _backdropScaleAnimation = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
    );

    _progressAnimation = Tween<double>(begin: 0.06, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _animController.forward();
    _progressController.forward();

    _timer = Timer(widget.duration, _onSplashComplete);
  }

  void _onSplashComplete() {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    if (widget.onFinished != null) {
      ref.read(isSplashActiveProvider.notifier).state = false;
      widget.onFinished!();
      return;
    }

    final hasCompleted = ref
        .read(onboardingStateProvider)
        .hasCompletedOnboarding;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
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
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurfaceCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Vivid Ambient Hero Backdrop preserving top "Vhunambi" script
          Positioned.fill(
            child: ScaleTransition(
              scale: _backdropScaleAnimation,
              child: Opacity(
                opacity: 0.72,
                child: Image.asset(
                  AppAssets.splashHero,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // 2. Cinema Scrim Vignette: keeps top "Vhunambi" luminous, blends
          // center sky behind emblem, and anchors bottom motto + attribution.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0.0, 0.24, 0.56, 0.80, 1.0],
                  colors: <Color>[
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.14),
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.24),
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.44),
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.82),
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),

          // 3. Soft Center Ember Halo fusing the V medallion into the sky
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.08),
                  radius: 0.62,
                  colors: <Color>[
                    AppColors.brandPrimary.withValues(alpha: 0.18),
                    AppColors.darkSurfaceCanvas.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. Foreground Composition (Zero duplicate VHUNAMBI text)
          SafeArea(
            child: Column(
              children: <Widget>[
                // Breathing room at top so "Vhunambi" script in splash_hero stays unobstructed
                const Spacer(flex: 5),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Centered V Emblem with Dual Acoustic Pulse Glow Rings
                        SizedBox(
                          key: const Key('splash_brand_emblem'),
                          width: 156,
                          height: 156,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final eased = Curves.easeOut.transform(
                                    _pulseController.value,
                                  );
                                  final size = 88 + (64 * eased);
                                  return Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.brandPrimary
                                            .withValues(
                                              alpha: (1.0 - eased) * 0.42,
                                            ),
                                        width: 1.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final raw =
                                      (_pulseController.value + 0.5) % 1.0;
                                  final eased = Curves.easeOut.transform(raw);
                                  final size = 88 + (38 * eased);
                                  return Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.brandPrimary
                                            .withValues(
                                              alpha: (1.0 - eased) * 0.34,
                                            ),
                                        width: 1.2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: AppColors.darkSurfaceElevated
                                      .withValues(alpha: 0.78),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.brandPrimary.withValues(
                                      alpha: 0.60,
                                    ),
                                    width: 1.8,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.brandPrimary.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 34,
                                      spreadRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
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
                                        errorBuilder: (_, _, _) => const Center(
                                          child: PhosphorIcon(
                                            PhosphorIconsFill.musicNotes,
                                            color: AppColors.brandContrast,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Simple 3-Word Motto
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const _MottoEmberDot(),
                            const SizedBox(width: 10),
                            Text(
                              'Music • Create • Socialize',
                              key: const Key('splash_motto_text'),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const _MottoEmberDot(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Upgraded Animated Shimmer Progress Sweep
                        SizedBox(
                          key: const Key('splash_progress_bar'),
                          width: 156,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: AppRadius.pillBorder,
                            child: AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _progressController,
                                _pulseController,
                              ]),
                              builder: (context, _) {
                                final progress = _progressAnimation.value;
                                final sweep = _pulseController.value;
                                return Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.brandPrimary,
                                          ),
                                    ),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.05, 1.0),
                                      child: ShaderMask(
                                        blendMode: BlendMode.srcATop,
                                        shaderCallback: (rect) {
                                          return LinearGradient(
                                            begin: Alignment(
                                              -1.5 + (sweep * 3.0),
                                              0,
                                            ),
                                            end: Alignment(
                                              -0.5 + (sweep * 3.0),
                                              0,
                                            ),
                                            colors: <Color>[
                                              Colors.transparent,
                                              Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ).createShader(rect);
                                        },
                                        child: Container(
                                          color: Colors.white.withValues(
                                            alpha: 0.25,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // 5. Tasteful Compact Parent Attribution (Madoni Software)
                FadeTransition(
                  opacity: _footerFadeAnimation,
                  child: Padding(
                    key: const Key('splash_madoni_attribution'),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'A PRODUCT OF',
                          style: AppTypography.badge.copyWith(
                            fontSize: 9.5,
                            color: Colors.white.withValues(alpha: 0.56),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Image.asset(
                          AppAssets.madoniSoftwareLogo,
                          key: const Key('splash_madoni_logo'),
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Text(
                            'MADONI SOFTWARE',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
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
}

class _MottoEmberDot extends StatelessWidget {
  const _MottoEmberDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.55),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
