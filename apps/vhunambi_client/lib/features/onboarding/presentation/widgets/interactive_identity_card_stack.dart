import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';

/// Card item descriptor for the 3D identity tarot deck (REQ-P47-ACT2-01..03).
class IdentityCardItem {
  final CreativeRole role;
  final String title;
  final String subtitle;
  final String sonicTrait;
  final Color accentColor;
  final PhosphorIconData icon;
  final String testKey;

  const IdentityCardItem({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.sonicTrait,
    required this.accentColor,
    required this.icon,
    required this.testKey,
  });
}

const List<IdentityCardItem> kIdentityCards = [
  IdentityCardItem(
    role: CreativeRole.producer,
    title: 'Producer & Beatmaker',
    subtitle: 'Crafting log-drums, chords, syncopated percussions & grooves',
    sonicTrait: '4-Track Step Sequencer & MIDI Export',
    accentColor: Color(0xFFF97316),
    icon: PhosphorIconsRegular.waveform,
    testKey: 'identity_card_producer',
  ),
  IdentityCardItem(
    role: CreativeRole.vocalist,
    title: 'Natural Vocalist',
    subtitle: 'Singing hooks, traditional chants, vocal harmonies & toplines',
    sonicTrait: 'Sovereign Voice DNA & LoRA Training',
    accentColor: Color(0xFF06B6D4),
    icon: PhosphorIconsRegular.microphoneStage,
    testKey: 'identity_card_vocalist',
  ),
  IdentityCardItem(
    role: CreativeRole.multiHyphenate,
    title: 'DAW Master & Artist',
    subtitle: 'Full spectrum composition: beats, vocal production & mixing',
    sonicTrait: 'Stem Mixing & Cockpit DAW Bridge',
    accentColor: Color(0xFF10B981),
    icon: PhosphorIconsRegular.faders,
    testKey: 'identity_card_multiHyphenate',
  ),
  IdentityCardItem(
    role: CreativeRole.songwriter,
    title: 'Live Instrumentalist',
    subtitle: 'Organic guitar picking, African brass, keys & poetic lyricism',
    sonicTrait: 'Bantu Dialect Lexicon & Melodic Stems',
    accentColor: Color(0xFFF59E0B),
    icon: PhosphorIconsRegular.guitar,
    testKey: 'identity_card_songwriter',
  ),
  IdentityCardItem(
    role: CreativeRole.musicLover,
    title: 'Kinetic Creator & Curator',
    subtitle: 'Co-creating remixes, flipping open-verses & crowdsourcing A&R',
    sonicTrait: 'Co-Sign Voting & 85% ZAR Marketplace',
    accentColor: Color(0xFFEC4899),
    icon: PhosphorIconsRegular.disc,
    testKey: 'identity_card_musicLover',
  ),
];

/// 3D Stacked & Fanned Tarot Deck for Creator Identity (REQ-P47-ACT2-01..03).
/// Zero raw emojis; features programmatic vector artwork and 3D matrix spring physics.
class InteractiveIdentityCardStack extends ConsumerStatefulWidget {
  final CreativeRole selectedRole;
  final ValueChanged<CreativeRole> onRoleChanged;

  const InteractiveIdentityCardStack({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  ConsumerState<InteractiveIdentityCardStack> createState() =>
      _InteractiveIdentityCardStackState();
}

class _InteractiveIdentityCardStackState
    extends ConsumerState<InteractiveIdentityCardStack>
    with SingleTickerProviderStateMixin {
  late int _activeIndex;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _activeIndex = kIdentityCards.indexWhere(
      (c) => c.role == widget.selectedRole,
    );
    if (_activeIndex == -1) _activeIndex = 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant InteractiveIdentityCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      final newIdx = kIdentityCards.indexWhere(
        (c) => c.role == widget.selectedRole,
      );
      if (newIdx != -1 && newIdx != _activeIndex) {
        setState(() => _activeIndex = newIdx);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectIndex(int index) {
    if (index == _activeIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _activeIndex = index);
    widget.onRoleChanged(kIdentityCards[index].role);
    _animController.forward(from: 0.0);
  }

  void _swipeNext() {
    final next = (_activeIndex + 1) % kIdentityCards.length;
    _selectIndex(next);
  }

  void _swipePrev() {
    final prev =
        (_activeIndex - 1 + kIdentityCards.length) % kIdentityCards.length;
    _selectIndex(prev);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3D Card Stack Stage
        SizedBox(
          height: 330,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -200) {
                  _swipeNext();
                } else if (details.primaryVelocity! > 200) {
                  _swipePrev();
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(kIdentityCards.length, (index) {
                return _buildTransformCard(context, index, isDark);
              }),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Indicator & Quick Selector Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(kIdentityCards.length, (index) {
            final isCurrent = index == _activeIndex;
            return GestureDetector(
              onTap: () => _selectIndex(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isCurrent
                      ? kIdentityCards[index].accentColor
                      : (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTransformCard(BuildContext context, int index, bool isDark) {
    final card = kIdentityCards[index];
    final relativeDiff = (index - _activeIndex);

    // Compute 3D Card Perspective and Depth Transform
    final double zTranslate = relativeDiff == 0
        ? 0
        : -35.0 * relativeDiff.abs();
    final double yTranslate = relativeDiff == 0 ? 0 : 12.0 * relativeDiff.abs();
    final double xTranslate = relativeDiff * 28.0;
    final double rotationY = relativeDiff * -0.06;
    final double scale = (1.0 - (relativeDiff.abs() * 0.08)).clamp(0.78, 1.0);
    final double opacity = (1.0 - (relativeDiff.abs() * 0.32)).clamp(0.0, 1.0);

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // 3D perspective field
      // ignore: deprecated_member_use
      ..translate(xTranslate, yTranslate, zTranslate)
      ..rotateY(rotationY)
      // ignore: deprecated_member_use
      ..scale(scale);

    final isSelected = index == _activeIndex;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: opacity,
      child: Transform(
        transform: transform,
        alignment: Alignment.center,
        child: GestureDetector(
          key: Key(card.testKey),
          onTap: () => _selectIndex(index),
          child: Container(
            width: 280,
            height: 310,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141418).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? card.accentColor
                    : (isDark ? Colors.white12 : Colors.black12),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? card.accentColor.withValues(alpha: isDark ? 0.30 : 0.20)
                      : Colors.black.withValues(alpha: 0.15),
                  blurRadius: isSelected ? 24 : 12,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Chromatic Icon Badge & Craft Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: card.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: card.accentColor.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: PhosphorIcon(
                        card.icon,
                        color: card.accentColor,
                        size: 22,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: card.accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SELECTED',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 18),

                // Card Title
                Text(
                  card.title,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  card.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    height: 1.35,
                  ),
                ),

                const Spacer(),

                // Programmatic Vector Art Accent (Zero Raw Emojis)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.grey.shade100)
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: card.accentColor.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: CustomPaint(
                    size: const Size(double.infinity, 48),
                    painter: _CardVectorWaveformPainter(
                      color: card.accentColor,
                      isSelected: isSelected,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sonic Trait Badge
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.sparkle,
                      size: 13,
                      color: card.accentColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.sonicTrait,
                        style: AppTypography.caption.copyWith(
                          color: card.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering dynamic rhythmic soundwave patterns for each card (REQ-P47-ACT2-02).
class _CardVectorWaveformPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  const _CardVectorWaveformPainter({
    required this.color,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.85 : 0.40)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    const barCount = 20;
    final step = size.width / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final x = step * (i + 1);
      final factor = math.sin((i / barCount) * math.pi) * 0.8;
      final height = (size.height * 0.25) + (factor * size.height * 0.55);
      final yTop = (size.height - height) / 2;
      canvas.drawLine(Offset(x, yTop), Offset(x, yTop + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardVectorWaveformPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}
