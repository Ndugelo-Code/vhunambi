import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';

const String _appTourCompletedKey = 'has_completed_app_tour';

@immutable
class AppTourCard {
  final String title;
  final String description;
  final IconData icon;
  final String illustrationLabel;

  const AppTourCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.illustrationLabel,
  });
}

class AppTourOverlay extends StatefulWidget {
  final VoidCallback onTourComplete;

  const AppTourOverlay({super.key, required this.onTourComplete});

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> {
  int _currentCard = 0;
  bool _hasCompleted = false;

  static const List<AppTourCard> _cards = [
    AppTourCard(
      title: 'Compose',
      description: 'Describe a song idea in plain language',
      icon: AppIcons.sparkle,
      illustrationLabel: 'Text prompt -> AI waveform -> Play',
    ),
    AppTourCard(
      title: 'Write Lyrics First',
      description:
          'Let AI draft lyrics in your dialect, edit them line-by-line, then generate the beat to match your words.',
      icon: AppIcons.edit,
      illustrationLabel: 'Lyric sheet -> Edit -> Beat synthesis',
    ),
    AppTourCard(
      title: 'Voice',
      description:
          'Choose from 25+ African vocal timbres and dialects to bring authentic regional flavor to your music.',
      icon: AppIcons.mic,
      illustrationLabel: 'Voice timbre & regional dialects',
    ),
    AppTourCard(
      title: 'Crate & MPC',
      description:
          'Dig through indigenous instrument samples (Mbira, Kora, Talking Drum) and slice beats on the MPC pad.',
      icon: AppIcons.songs,
      illustrationLabel: 'Indigenous crate & 8-pad slicer',
    ),
    AppTourCard(
      title: 'Credits & Library',
      description:
          'Start with 10 free credits. Every generation is yours to keep, download stems, and license commercially.',
      icon: PhosphorIconsRegular.folder,
      illustrationLabel: 'Monthly credits, stems & licenses',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkCompletion();
  }

  Future<void> _checkCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_appTourCompletedKey) ?? false;
    if (completed && mounted) {
      setState(() => _hasCompleted = true);
      widget.onTourComplete();
    }
  }

  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appTourCompletedKey, true);
    if (mounted) {
      setState(() => _hasCompleted = true);
    }
    widget.onTourComplete();
  }

  void _nextCard() {
    if (_currentCard < _cards.length - 1) {
      setState(() => _currentCard++);
    } else {
      _markCompleted();
    }
  }

  void _skipTour() {
    _markCompleted();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCompleted) return const SizedBox.shrink();

    final card = _cards[_currentCard];
    final isLast = _currentCard == _cards.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                key: const Key('app_tour_skip'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
                onPressed: _skipTour,
                child: Text(
                  'Skip Tour',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VhunambiGlassSurface(
                    key: const Key('app_tour_preview_glass'),
                    variant: VhunambiGlassVariant.card,
                    width: 164,
                    height: 152,
                    padding: const EdgeInsets.all(14),
                    borderRadius: AppRadius.cardBorder,
                    enableLiveBlur: false,
                    tintAccent: AppColors.brandPrimary,
                    borderColorOverride: AppColors.borderSubtleOf(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(
                          card.icon,
                          size: 48,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.illustrationLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    card.title,
                    style: AppTypography.displayLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      card.description,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_cards.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentCard == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentCard == index
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtleOf(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isLast)
                        TextButton(
                          key: const Key('app_tour_continue'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: _nextCard,
                          child: Text(
                            'Continue',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          key: const Key('app_tour_get_started'),
                          onPressed: _nextCard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: AppColors.brandContrast,
                            minimumSize: const Size(44, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Get Started'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
