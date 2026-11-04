import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/onboarding_models.dart';
import '../providers/onboarding_providers.dart';

/// Act 3: Tactile Roots & Vibe Playground (REQ-P47-ACT3-01..03).
/// Combines 12 distinct African Genre Cards, Vibe Energy Slider, and Indigenous Language Orbs.
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

  static const List<Map<String, String>> kVibeTempos = [
    {'key': 'slow', 'label': 'Laid Back', 'bpm': '95-108 BPM'},
    {'key': 'medium', 'label': 'Easy Groove', 'bpm': '112-118 BPM'},
    {'key': 'fast', 'label': 'Driving Club', 'bpm': '124-128 BPM'},
    {'key': 'hyperspeed', 'label': 'Full Speed', 'bpm': '160-180 BPM'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      key: const Key('onboarding_act_3_roots_deck'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Genre Heritage Grid (12 Distinct African Genres)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'African Genre Roots',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 18,
                ),
              ),
              Text(
                '${state.selectedGenres.length} selected',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap your signature sounds to shape your studio synthesizers',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 12),

          // 12 Distinct Genre Cards (Zero Duplicate Amapiano Chips!)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAfricanOnboardingGenres.map((genre) {
              final isSelected = state.selectedGenres.contains(genre.name);
              return TactileGenreCard(
                genre: genre,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onInteraction?.call();
                  notifier.toggleGenre(genre.name);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Section 2: Tactile Vibe Energy Slider (Replaces Radio Buttons)
          Text(
            'Vibe Energy & Tempo Feel',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your baseline groove pace for session synthesis',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          _buildVibeSlider(context, notifier, state.tempoPreference, isDark),

          const SizedBox(height: 22),

          // Section 3: Indigenous Language Orbs
          Text(
            'Vocal Dialects & Tongues',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Languages used to calibrate Voice DNA and Bantu lyric engines',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAvailableLanguages.map((lang) {
              final isSelected = state.selectedLanguages.contains(lang);
              final isPrimary = state.primaryLanguage == lang;

              return GestureDetector(
                key: Key('language_orb_$lang'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onInteraction?.call();
                  notifier.toggleLanguage(lang);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isPrimary ? AppColors.brandPrimary : AppColors.badgeCyan)
                            .withValues(alpha: isDark ? 0.22 : 0.12)
                        : (isDark ? const Color(0xFF141418) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? (isPrimary ? AppColors.brandPrimary : AppColors.badgeCyan)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.translate,
                        size: 13,
                        color: isSelected
                            ? (isPrimary ? AppColors.brandPrimary : AppColors.badgeCyan)
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang,
                        style: AppTypography.caption.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isPrimary ? AppColors.brandPrimary : AppColors.badgeCyan)
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVibeSlider(
    BuildContext context,
    OnboardingNotifier notifier,
    String currentTempo,
    bool isDark,
  ) {
    return Container(
      key: const Key('onboarding_vibe_slider'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: kVibeTempos.map((opt) {
              final isCurrent = opt['key'] == currentTempo;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onInteraction?.call();
                  notifier.setTempoPreference(opt['key']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.brandPrimary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppColors.brandPrimary : Colors.transparent,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        opt['label']!,
                        style: AppTypography.caption.copyWith(
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.brandPrimary
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt['bpm']!,
                        style: TextStyle(
                          fontSize: 9,
                          color: isCurrent
                              ? AppColors.brandPrimary.withValues(alpha: 0.8)
                              : AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Tactile Genre Card with unique styling and animated dancing EQ bars (REQ-P47-ACT3-01).
class TactileGenreCard extends StatelessWidget {
  final AfricanGenreModel genre;
  final bool isSelected;
  final VoidCallback onTap;

  const TactileGenreCard({
    super.key,
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select genre ${genre.name}',
      child: InkWell(
        key: Key('genre_card_${genre.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? genre.accentColor.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF141418) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? genre.accentColor
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: genre.accentColor.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dancing Mini EQ Bars (Animated when selected)
              if (isSelected) ...[
                _DancingMiniEqualizer(color: genre.accentColor),
                const SizedBox(width: 8),
              ],
              Text(
                genre.name,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? genre.accentColor : AppColors.textPrimaryOf(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3-Band Mini Dancing Equalizer indicator
class _DancingMiniEqualizer extends StatefulWidget {
  final Color color;

  const _DancingMiniEqualizer({required this.color});

  @override
  State<_DancingMiniEqualizer> createState() => _DancingMiniEqualizerState();
}

class _DancingMiniEqualizerState extends State<_DancingMiniEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(4.0 + (val * 8.0)),
            const SizedBox(width: 2),
            _buildBar(12.0 - (val * 7.0)),
            const SizedBox(width: 2),
            _buildBar(6.0 + (val * 6.0)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.2,
      height: height.clamp(3.0, 14.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

