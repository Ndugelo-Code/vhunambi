import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/studio_form_provider.dart';

class PromptInputBox extends ConsumerStatefulWidget {
  const PromptInputBox({super.key});

  @override
  ConsumerState<PromptInputBox> createState() => _PromptInputBoxState();
}

class _PromptInputBoxState extends ConsumerState<PromptInputBox> {
  late final TextEditingController _controller;

  static const List<_PromptPreset> _presets = [
    _PromptPreset(
      shortLabel: 'A heartbreak track...',
      fullPrompt:
          'A heartbreak track about leaving the village for the city lights, with mournful log drums and deep emotion.',
    ),
    _PromptPreset(
      shortLabel: 'Late-night log drum...',
      fullPrompt:
          'Late-night log drum session, dark heavy basslines with hypnotic jazz chords and energetic township chants.',
    ),
    _PromptPreset(
      shortLabel: 'Township love story...',
      fullPrompt:
          'Township love story — two people meeting at a street festival on a warm sunny afternoon in Soweto.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(studioFormProvider).prompt,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Synchronize controller text when changed externally (e.g. inspire me or presets)
    ref.listen(studioFormProvider.select((s) => s.prompt), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Describe your song',
              style: AppTypography.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Multiline Input Box
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.inputBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: TextField(
            controller: _controller,
            onChanged: (val) =>
                ref.read(studioFormProvider.notifier).updatePrompt(val),
            maxLines: 5,
            minLines: 3,
            style: AppTypography.bodyLarge,
            cursorColor: AppColors.brandPrimary,
            decoration: InputDecoration(
              hintText:
                  'A powerful anthem about rising from hardship, full of hope and energy...',
              hintStyle: AppTypography.bodyMuted.copyWith(
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: const BorderSide(
                  color: AppColors.brandPrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Quick Preset Chips and Inspire Me Row
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._presets.map(
              (p) => InkWell(
                onTap: () {
                  ref
                      .read(studioFormProvider.notifier)
                      .applyPromptPreset(p.fullPrompt);
                },
                borderRadius: AppRadius.pillBorder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    p.shortLabel,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            // Inspire Me Button
            InkWell(
              onTap: () {
                ref.read(studioFormProvider.notifier).inspireMe();
              },
              borderRadius: AppRadius.pillBorder,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.brandPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Inspire Me',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromptPreset {
  final String shortLabel;
  final String fullPrompt;

  const _PromptPreset({
    required this.shortLabel,
    required this.fullPrompt,
  });
}
