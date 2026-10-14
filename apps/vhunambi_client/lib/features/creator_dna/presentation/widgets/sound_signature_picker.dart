import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Interactive sound signature selection component covering tempo feel, vocal energy, and mood.
class SoundSignaturePicker extends StatelessWidget {
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

  static const List<Map<String, String>> tempoOptions = [
    {'key': 'slow', 'label': 'Slow (70-95 BPM)', 'hint': 'Deep House / Kizomba'},
    {'key': 'medium', 'label': 'Medium (100-118 BPM)', 'hint': 'Amapiano / Afro Pop'},
    {'key': 'fast', 'label': 'Fast (120-135 BPM)', 'hint': 'Afro Tech / Gqom'},
    {'key': 'hyperspeed', 'label': 'Hyperspeed (140+ BPM)', 'hint': 'Singeli / Shangaan'},
  ];

  static const List<Map<String, String>> energyOptions = [
    {'key': 'soft', 'label': 'Soft & Intimate', 'hint': 'Smooth / Acoustic'},
    {'key': 'balanced', 'label': 'Balanced & Melodic', 'hint': 'Natural Resonance'},
    {'key': 'intense', 'label': 'Raw & Intense', 'hint': 'High Octane / Chants'},
  ];

  static const List<String> moodOptions = [
    'Energetic',
    'Chill',
    'Melancholic',
    'Celebratory',
    'Spiritual',
    'Gritty',
  ];

  @override
  Widget build(BuildContext context) {
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
            return Semantics(
              button: true,
              selected: isSelected,
              label: '$mood mood${isSelected ? ", selected" : ""}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('onboarding_mood_${mood.toLowerCase()}'),
                  onTap: () => onMoodToggled(mood),
                  borderRadius: AppRadius.pillBorder,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      mood,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
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
