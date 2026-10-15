import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';
import 'guided_lyrics_composer.dart';

class AdvancedOptionsAccordion extends ConsumerStatefulWidget {
  const AdvancedOptionsAccordion({super.key});

  @override
  ConsumerState<AdvancedOptionsAccordion> createState() =>
      _AdvancedOptionsAccordionState();
}

class _AdvancedOptionsAccordionState
    extends ConsumerState<AdvancedOptionsAccordion> {
  bool _isExpanded = false;
  final TextEditingController _customLyricsController =
      TextEditingController();
  final TextEditingController _customTitleController =
      TextEditingController();

  static const List<int> _durationSteps = [15, 30, 60, 120, 240, 360, 480];

  static const List<String> _moods = [
    '😊 Uplifting',
    '🌧️ Melancholic',
    '💕 Romantic',
    '⚡ Energetic',
    '🕊️ Peaceful',
    '🔥 Angry',
    '📻 Nostalgic',
    '🌙 Mysterious',
    '✨ Hopeful',
    '🖤 Dark',
  ];

  @override
  void dispose() {
    _customLyricsController.dispose();
    _customTitleController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final mins = seconds ~/ 60;
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Accordion Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Advanced Options',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(color: AppColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Instrumental Only Switch
                  Row(
                    children: [
                      const Icon(
                        Icons.music_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instrumental only',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Skip lyrics — generate music only',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.isInstrumental,
                        onChanged: notifier.toggleInstrumental,
                        activeThumbColor: AppColors.brandPrimary,
                        activeTrackColor:
                            AppColors.brandPrimary.withAlpha(80),
                        inactiveThumbColor: AppColors.textSecondary,
                        inactiveTrackColor: AppColors.surfaceSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Song Length Stepped Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Song length',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          _formatDuration(state.durationSeconds),
                          style: AppTypography.badge.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.brandPrimary,
                      inactiveTrackColor: AppColors.surfaceSecondary,
                      thumbColor: AppColors.brandPrimary,
                      overlayColor: AppColors.brandPrimary.withAlpha(40),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: _durationSteps
                          .indexOf(state.durationSeconds)
                          .clamp(0, _durationSteps.length - 1)
                          .toDouble(),
                      min: 0,
                      max: (_durationSteps.length - 1).toDouble(),
                      divisions: _durationSteps.length - 1,
                      onChanged: (val) {
                        final idx = val.round();
                        notifier.setDurationSeconds(_durationSteps[idx]);
                      },
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('15s', style: AppTypography.caption),
                        Text('1 min', style: AppTypography.caption),
                        Text('4 min', style: AppTypography.caption),
                        Text('8 min', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Lyrics Mode Switcher (if not instrumental)
                  if (!state.isInstrumental) ...[
                    Text(
                      'Lyrics',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildLyricsModeTab(
                            title: '✨ AI writes lyrics',
                            mode: LyricsMode.aiWrite,
                            activeMode: state.lyricsMode,
                            onTap: () =>
                                notifier.setLyricsMode(LyricsMode.aiWrite),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _buildLyricsModeTab(
                            title: '✍️ My own lyrics',
                            mode: LyricsMode.myOwn,
                            activeMode: state.lyricsMode,
                            onTap: () =>
                                notifier.setLyricsMode(LyricsMode.myOwn),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _buildLyricsModeTab(
                            title: '📷 From photo',
                            mode: LyricsMode.fromPhoto,
                            activeMode: state.lyricsMode,
                            onTap: () =>
                                notifier.setLyricsMode(LyricsMode.fromPhoto),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Helper banner or Custom Lyrics Input
                    if (state.lyricsMode == LyricsMode.aiWrite)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadius.inputBorder,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.badgeCyan,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'AI will generate lyrics and show them to you to review and edit before producing the beat.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (state.lyricsMode == LyricsMode.myOwn)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Custom Lyrics',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                key: const Key('write_with_guide_btn'),
                                onPressed: () {
                                  GuidedLyricsComposer.show(
                                    context,
                                    onDone: () {
                                      _customLyricsController.text =
                                          ref.read(studioFormProvider).customLyrics ?? '';
                                    },
                                  );
                                },
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: AppColors.brandPrimary,
                                ),
                                label: Text(
                                  'Write with Guide',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: AppSpacing.xxs),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadius.inputBorder,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: TextField(
                              controller: _customLyricsController,
                              onChanged: notifier.setCustomLyrics,
                              maxLines: 4,
                              style: AppTypography.bodySmall,
                              cursorColor: AppColors.brandPrimary,
                              decoration: InputDecoration(
                                hintText:
                                    'Paste or write your lyrics here (Verses, Chorus, Outro)...',
                                hintStyle: AppTypography.caption,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.all(AppSpacing.sm),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 4. Mood Selection
                  Text(
                    'Mood',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _moods.map((m) {
                      final cleanName = m.split(' ').last;
                      final isSelected = state.mood == cleanName;
                      return InkWell(
                        onTap: () => notifier.setMood(cleanName),
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.surfaceSecondary,
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            m,
                            style: AppTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.brandContrast
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. Tempo Bracket Cards
                  Text(
                    'Tempo',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _buildTempoCard('Slow', '< 70', TempoBracket.slow,
                          state.tempo, notifier),
                      const SizedBox(width: AppSpacing.xs),
                      _buildTempoCard('Medium', '70-110', TempoBracket.medium,
                          state.tempo, notifier),
                      const SizedBox(width: AppSpacing.xs),
                      _buildTempoCard('Fast', '110-150', TempoBracket.fast,
                          state.tempo, notifier),
                      const SizedBox(width: AppSpacing.xs),
                      _buildTempoCard('Very Fast', '150+',
                          TempoBracket.veryFast, state.tempo, notifier),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. Vocal Arrangement Controls (Voices, Gender, Mode, Energy)
                  if (!state.isInstrumental) ...[
                    Text(
                      'Voices',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        _buildChoiceChip<VocalVoices>(
                          label: 'Solo',
                          value: VocalVoices.solo,
                          current: state.vocalVoices,
                          onSelected: notifier.setVocalVoices,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalVoices>(
                          label: 'Duet',
                          value: VocalVoices.duet,
                          current: state.vocalVoices,
                          onSelected: notifier.setVocalVoices,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalVoices>(
                          label: 'Choir',
                          value: VocalVoices.choir,
                          current: state.vocalVoices,
                          onSelected: notifier.setVocalVoices,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Vocal Gender',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        _buildChoiceChip<VocalGender>(
                          label: 'Male',
                          value: VocalGender.male,
                          current: state.vocalGender,
                          onSelected: notifier.setVocalGender,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalGender>(
                          label: 'Female',
                          value: VocalGender.female,
                          current: state.vocalGender,
                          onSelected: notifier.setVocalGender,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalGender>(
                          label: 'Mixed',
                          value: VocalGender.mixed,
                          current: state.vocalGender,
                          onSelected: notifier.setVocalGender,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Vocal Energy',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        _buildChoiceChip<VocalEnergy>(
                          label: '🌙 Soft',
                          value: VocalEnergy.soft,
                          current: state.vocalEnergy,
                          onSelected: notifier.setVocalEnergy,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalEnergy>(
                          label: '☀️ Mid',
                          value: VocalEnergy.mid,
                          current: state.vocalEnergy,
                          onSelected: notifier.setVocalEnergy,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildChoiceChip<VocalEnergy>(
                          label: '🔥 Intense',
                          value: VocalEnergy.intense,
                          current: state.vocalEnergy,
                          onSelected: notifier.setVocalEnergy,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 7. Song Structure
                  Text(
                    'Song Structure',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _buildChoiceChip<SongStructure>(
                        label: 'Standard',
                        value: SongStructure.standard,
                        current: state.songStructure,
                        onSelected: notifier.setSongStructure,
                      ),
                      _buildChoiceChip<SongStructure>(
                        label: 'Extended (DJ)',
                        value: SongStructure.extended,
                        current: state.songStructure,
                        onSelected: notifier.setSongStructure,
                      ),
                      _buildChoiceChip<SongStructure>(
                        label: 'Freestyle',
                        value: SongStructure.freestyle,
                        current: state.songStructure,
                        onSelected: notifier.setSongStructure,
                      ),
                      _buildChoiceChip<SongStructure>(
                        label: 'Loop',
                        value: SongStructure.loop,
                        current: state.songStructure,
                        onSelected: notifier.setSongStructure,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 8. Song Title Mode
                  Text(
                    'Song Title',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => notifier.toggleAutoTitle(true),
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: state.isAutoTitle
                                ? AppColors.brandPrimary
                                : AppColors.surfaceSecondary,
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: state.isAutoTitle
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            '✨ AI picks title',
                            style: AppTypography.bodySmall.copyWith(
                              color: state.isAutoTitle
                                  ? AppColors.brandContrast
                                  : AppColors.textSecondary,
                              fontWeight: state.isAutoTitle
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InkWell(
                        onTap: () => notifier.toggleAutoTitle(false),
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: !state.isAutoTitle
                                ? AppColors.brandPrimary
                                : AppColors.surfaceSecondary,
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: !state.isAutoTitle
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            "✍️ I'll name it",
                            style: AppTypography.bodySmall.copyWith(
                              color: !state.isAutoTitle
                                  ? AppColors.brandContrast
                                  : AppColors.textSecondary,
                              fontWeight: !state.isAutoTitle
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!state.isAutoTitle)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.inputBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: TextField(
                        controller: _customTitleController,
                        onChanged: notifier.setCustomTitle,
                        style: AppTypography.bodySmall,
                        cursorColor: AppColors.brandPrimary,
                        decoration: InputDecoration(
                          hintText: 'Enter custom song title...',
                          hintStyle: AppTypography.caption,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLyricsModeTab({
    required String title,
    required LyricsMode mode,
    required LyricsMode activeMode,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == activeMode;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          title,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected
                ? AppColors.brandContrast
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTempoCard(
    String label,
    String bpm,
    TempoBracket bracket,
    TempoBracket current,
    StudioFormNotifier notifier,
  ) {
    final isSelected = bracket == current;
    return Expanded(
      child: InkWell(
        onTap: () => notifier.setTempo(bracket),
        borderRadius: AppRadius.cardBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brandPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bpm,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip<T>({
    required String label,
    required T value,
    required T current,
    required void Function(T) onSelected,
  }) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: AppRadius.pillBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected
                ? AppColors.brandContrast
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
