import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/vocal_identity_models.dart';
import '../providers/vocal_identity_provider.dart';

/// Post-Lyrics 3-Line Bantu Phonetic Voice Calibration & Zero-Shot Cloning Sheet (REQ-VOC-05..10).
///
/// Extracts the 3 most phonetically dense lines from the user's lyrics so a 15-20s
/// recording captures their exact vocal timbre and native consonant/click articulation.
class VoiceCloneRecorderSheet extends ConsumerStatefulWidget {
  const VoiceCloneRecorderSheet({
    super.key,
    this.initialLyrics,
    this.language = 'Tshivenḓa',
  });

  final String? initialLyrics;
  final String language;

  static Future<void> show(
    BuildContext context, {
    String? lyrics,
    String language = 'Tshivenḓa',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: VoiceCloneRecorderSheet(
          initialLyrics: lyrics,
          language: language,
        ),
      ),
    );
  }

  @override
  ConsumerState<VoiceCloneRecorderSheet> createState() =>
      _VoiceCloneRecorderSheetState();
}

class _VoiceCloneRecorderSheetState
    extends ConsumerState<VoiceCloneRecorderSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'My Sovereign Voice');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialLyrics != null) {
        ref.read(vocalIdentityProvider.notifier).prepareCalibrationFromLyrics(
              widget.initialLyrics!,
              language: widget.language,
            );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocalIdentityProvider);
    final notifier = ref.read(vocalIdentityProvider.notifier);
    final script = state.calibrationScript;
    final lines = script?.lines ?? const <PhoneticCalibrationLine>[];
    final activeClone = state.activeClonedProfile;

    return SafeArea(
      key: const Key('voice_clone_recorder_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.amapiano,
                    borderRadius: AppRadius.inputBorder,
                  ),
                  child: const Icon(
                    Icons.mic_external_on_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero-Shot Phonetic Voice Clone',
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Read 3 phonetically dense lines (${script?.totalEstimatedDurationSec ?? 18}s) to lock your timbre & accent',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('voice_clone_close_btn'),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (activeClone != null) ...[
              Container(
                key: const Key('voice_clone_ready_badge'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(28),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.success.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Cloned Voice Ready: ${activeClone.creatorName} • ${activeClone.cadenceWpm} WPM • ${(activeClone.clarityScore * 100).round()}% Clarity',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Profile Name Input
            TextField(
              key: const Key('voice_clone_name_input'),
              controller: _nameController,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Voice Identity Name',
                labelStyle: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.inputBorder,
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.inputBorder,
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 3 Extracted Calibration Lines
            Expanded(
              child: ListView.separated(
                itemCount: lines.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final line = lines[index];
                  return Container(
                    key: Key('calibration_line_$index'),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(
                        color: state.isRecording
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary.withAlpha(35),
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                'Line ${index + 1} • ~${line.estimatedDurationSec}s',
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Phonetic Score: ${line.phoneticScore.toStringAsFixed(1)}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.coinGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          line.text,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (line.highlightedTokens.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xxs,
                            runSpacing: AppSpacing.xxs,
                            children: line.highlightedTokens.map((token) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: AppColors.coinGold.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  token,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.coinGold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Live Microphone RMS Visualizer Bars
            Container(
              key: const Key('voice_clone_amplitude_bars'),
              height: 44,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(16, (barIdx) {
                  final baseAmp = state.isRecording ? state.liveAmplitude : 0.14;
                  final factor = 0.4 + ((barIdx * 3) % 7) * 0.1;
                  final barHeight = (28.0 * baseAmp * factor).clamp(4.0, 28.0);
                  return Container(
                    width: 6,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: state.isRecording
                          ? AppColors.brandPrimary
                          : AppColors.textTertiary,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Record Toggle & Finalize Actions
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('voice_clone_record_toggle_btn'),
                      onPressed: () async {
                        if (state.isRecording) {
                          await notifier.finalizeVoiceClone(
                            creatorName: _nameController.text,
                            nativeLanguage: widget.language,
                          );
                        } else {
                          await notifier.startCalibrationRecording();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: state.isRecording
                            ? AppColors.error
                            : AppColors.textPrimary,
                        side: BorderSide(
                          color: state.isRecording
                              ? AppColors.error
                              : AppColors.brandPrimary,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      icon: Icon(
                        state.isRecording
                            ? Icons.stop_circle_rounded
                            : Icons.fiber_manual_record_rounded,
                        color: state.isRecording
                            ? AppColors.error
                            : AppColors.brandPrimary,
                      ),
                      label: Text(
                        state.isRecording ? 'Stop Recording' : 'Record 3 Lines',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('voice_clone_finalize_btn'),
                      onPressed: () async {
                        await notifier.finalizeVoiceClone(
                          creatorName: _nameController.text,
                          nativeLanguage: widget.language,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        'Synthesize Voice DNA',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.brandContrast,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

