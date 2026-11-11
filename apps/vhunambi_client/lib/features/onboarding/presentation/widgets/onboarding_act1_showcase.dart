import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Act 1: Living Sonic Showcase (REQ-P47-ACT1-01).
/// Features central pulsing Vhunambi emblem and 4 interactive world satellites.
class OnboardingAct1Showcase extends StatefulWidget {
  final VoidCallback? onInteraction;

  const OnboardingAct1Showcase({super.key, this.onInteraction});

  @override
  State<OnboardingAct1Showcase> createState() => _OnboardingAct1ShowcaseState();
}

class _OnboardingAct1ShowcaseState extends State<OnboardingAct1Showcase>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _entranceController;
  late final Animation<Offset> _pillSlideAnim;
  late final Animation<double> _pillFadeAnim;
  int _selectedPillarIndex = 0;

  static const List<Map<String, dynamic>> _pillars = [
    {
      'title': 'AI Studio & Stems',
      'tagline': '4-Stem Demucs Audio Engine',
      'desc':
          'Synthesize full-length Amapiano & African beats with instant vocal, drum, bass, and melodic stem separation.',
      'color': Color(0xFFF97316),
      'icon': PhosphorIconsRegular.waveform,
    },
    {
      'title': 'Voice DNA',
      'tagline': 'Sovereign Voice Synthesis',
      'desc':
          'Capture your vocal signature in your indigenous tongue. Retain 100% IP ownership on encrypted clusters.',
      'color': Color(0xFF06B6D4),
      'icon': PhosphorIconsRegular.microphoneStage,
    },
    {
      'title': '5-Channel Groove',
      'tagline': 'Log Drums & Syncopation',
      'desc':
          'Interactive live pocket mixer tailored for African rhythmic pacing, sliding sub-bass, and polyrhythms.',
      'color': Color(0xFF10B981),
      'icon': PhosphorIconsRegular.faders,
    },
    {
      'title': 'Kinetic Marketplace',
      'tagline': '85% Direct ZAR Royalties',
      'desc':
          'Publish open-verse reels, sell stems and vocal hooks, and receive instant EFT payouts to South African banks.',
      'color': Color(0xFFF59E0B),
      'icon': PhosphorIconsRegular.shoppingBagOpen,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pillSlideAnim =
        Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _pillFadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePillar = _pillars[_selectedPillarIndex];

    return SingleChildScrollView(
      key: const Key('onboarding_act_1_showcase'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Central Pulsing Emblem & Constellation Stage
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse halo ring
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 1.0 + (_pulseController.value * 0.16);
                    return Container(
                      width: 120 * scale,
                      height: 120 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (activePillar['color'] as Color).withValues(
                            alpha: 0.25,
                          ),
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),

                // Core Vhunambi Crest
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.brandPrimary.withValues(alpha: 0.35),
                        isDark ? const Color(0xFF141418) : Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      AppAssets.vhunambiGlyph,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, _, _) => const PhosphorIcon(
                        PhosphorIconsBold.waveform,
                        color: AppColors.brandPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Platform Welcome Title & Slogan with Bouncy Kinetic Typography (REQ-P49-TYPO-01..02)
          Text(
            'Welcome to Vhunambi',
            style: AppTypography.bouncyDisplayLarge.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'The African AI Audio Synthesis & Co-Creation Network',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          // 18dp clearance to prevent collision with subtitle during entrance (REQ-P51-FIX-02)
          const SizedBox(height: 18),

          // 4 Orbiting World Selector Pills with smooth easeOutCubic entrance
          FadeTransition(
            opacity: _pillFadeAnim,
            child: SlideTransition(
              position: _pillSlideAnim,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_pillars.length, (index) {
                  final p = _pillars[index];
                  final isSelected = index == _selectedPillarIndex;
                  final color = p['color'] as Color;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onInteraction?.call();
                      setState(() => _selectedPillarIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: isDark ? 0.25 : 0.14)
                            : (isDark
                                  ? const Color(0xFF141418)
                                  : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            p['icon'] as PhosphorIconData,
                            size: 15,
                            color: isSelected
                                ? color
                                : AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p['title'] as String,
                            style: AppTypography.caption.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? color
                                  : AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Active Pillar Detail Card (Interactive Expanded Benefits)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Container(
              key: ValueKey(_selectedPillarIndex),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (activePillar['color'] as Color).withValues(
                    alpha: 0.35,
                  ),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (activePillar['color'] as Color).withValues(
                      alpha: 0.12,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (activePillar['color'] as Color).withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: PhosphorIcon(
                          activePillar['icon'] as PhosphorIconData,
                          size: 18,
                          color: activePillar['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activePillar['tagline'] as String,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: activePillar['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activePillar['desc'] as String,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
