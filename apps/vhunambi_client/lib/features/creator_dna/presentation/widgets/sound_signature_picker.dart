import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../../onboarding/presentation/widgets/mood_color_chip.dart';

/// Interactive sound signature selection component covering tempo feel, vocal energy, and mood.
///
/// Uses natural language descriptors with African genre references instead of
/// technical BPM jargon (REQ-VH009-01 through REQ-VH009-06). Internal enum
/// values remain unchanged for backward compatibility.
class SoundSignaturePicker extends ConsumerWidget {
  final String selectedTempo;
  final ValueChanged<String> onTempoChanged;

  final String selectedVocalEnergy;
  final ValueChanged<String> onVocalEnergyChanged;

  final List<String> selectedMoods;
  final ValueChanged<String> onMoodToggled;

  const SoundSignaturePicker({
    super.key,
    required this.selectedTempo,
    required this.onTempoChanged,
    required this.selectedVocalEnergy,
    required this.onVocalEnergyChanged,
    required this.selectedMoods,
    required this.onMoodToggled,
  });

  /// Natural language tempo options. Internal keys preserved for backward compat.
  static const List<Map<String, String>> tempoOptions = [
    {
      'key': 'slow',
      'label': 'Laid back',
      'hint': 'Feels like Deep House and Kizomba: slow, smooth, swaying',
    },
    {
      'key': 'medium',
      'label': 'Easy groove',
      'hint': 'Feels like Amapiano and Afro Pop: relaxed but danceable',
    },
    {
      'key': 'fast',
      'label': 'Driving',
      'hint': 'Feels like Afro Tech and Gqom: heads nod, floor fills',
    },
    {
      'key': 'hyperspeed',
      'label': 'Full speed',
      'hint': 'Feels like Singeli and Shangaan: fast, frantic, high energy',
    },
  ];

  /// Natural language vocal energy options. Internal keys preserved for backward compat.
  static const List<Map<String, String>> energyOptions = [
    {
      'key': 'soft',
      'label': 'Smooth and tender',
      'hint': 'Like a love song: soft, close, warm voice',
    },
    {
      'key': 'balanced',
      'label': 'Easy and melodic',
      'hint': 'Like Afro Pop and R&B: natural, singable',
    },
    {
      'key': 'intense',
      'label': 'Raw and aggressive',
      'hint': 'Like Rap and Drill: punchy, hard-hitting delivery',
    },
    {
      'key': 'loud',
      'label': 'Loud and gritty',
      'hint': 'Like Rock: raw, strained, big voice',
    },
  ];

  static const List<String> moodOptions = [
    'Energetic',
    'Chill',
    'Melancholic',
    'Celebratory',
    'Spiritual',
    'Gritty',
  ];

  /// Maps a mood string to its [Mood] enum value.
  Mood _moodStringToEnum(String moodName) {
    return Mood.values.firstWhere(
      (m) => m.displayName.toLowerCase() == moodName.toLowerCase(),
      orElse: () => Mood.energetic,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tempo Section
        Text(
          'Tempo Feel',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select your primary rhythmic pace',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Column(
          key: const Key('tempo_picker'),
          children: tempoOptions.map((opt) {
            final isSelected = selectedTempo == opt['key'];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildOptionTile(
                key: Key('onboarding_tempo_${opt['key']}'),
                label: opt['label']!,
                hint: opt['hint']!,
                isSelected: isSelected,
                onTap: () => onTempoChanged(opt['key']!),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 2. Vocal Energy Section
        Text(
          'Vocal Energy',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Default energy level for vocal synthesis',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Column(
          key: const Key('energy_picker'),
          children: energyOptions.map((opt) {
            final isSelected = selectedVocalEnergy == opt['key'];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildOptionTile(
                key: Key('onboarding_energy_${opt['key']}'),
                label: opt['label']!,
                hint: opt['hint']!,
                isSelected: isSelected,
                onTap: () => onVocalEnergyChanged(opt['key']!),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 3. Mood Palette Section
        Text(
          'Mood Palette',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Emotional tones that inspire your sound',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          key: const Key('mood_picker'),
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: moodOptions.map((mood) {
            final isSelected = selectedMoods.contains(mood);
            return MoodColorChip(
              key: Key('onboarding_mood_chip_$mood'),
              mood: _moodStringToEnum(mood),
              isSelected: isSelected,
              onTap: () => onMoodToggled(mood),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required Key key,
    required String label,
    required String hint,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, $hint',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        hint,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.brandPrimary : AppColors.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
