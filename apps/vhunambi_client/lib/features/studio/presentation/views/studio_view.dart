import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_app_bar.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/player_obstacle.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';
import '../widgets/advanced_options_accordion.dart';
import '../widgets/bantu_voice_deck.dart';
import '../widgets/crate_browser_deck.dart';
import '../widgets/generation_pipeline_card.dart';
import '../widgets/live_phonetic_alignment_preview.dart';
import '../widgets/mpc_slicer_deck.dart';
import '../widgets/multilingual_language_selector.dart';
import '../widgets/prompt_input_box.dart';
import '../widgets/reference_audio_dropzone.dart';
import '../widgets/regional_genre_selector.dart';
import '../widgets/progress_tracker.dart';
import '../widgets/studio_action_bar.dart';
import '../widgets/studio_session_recovery_banner.dart';
import '../../../creator_dna/presentation/providers/dna_studio_defaults_provider.dart';

class StudioView extends ConsumerStatefulWidget {
  const StudioView({super.key});

  @override
  ConsumerState<StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends ConsumerState<StudioView> {
  int _mode = 0;

  /// Guards DNA pre-fill so it only applies once per session (T6.10).
  bool _dnaApplied = false;

  @override
  void initState() {
    super.initState();
    // Defer so that the ProviderContainer has initialised before we read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyDnaDefaults());
  }

  /// Applies Creator DNA defaults to the Studio form on first mount when the
  /// user has not already interacted with the form (T6.10 — REQ-DNA-STU-01/02).
  void _applyDnaDefaults() {
    if (_dnaApplied || !mounted) return;
    final defaults = ref.read(dnaStudioDefaultsProvider);
    if (!defaults.hasDnaDefaults) return;
    _dnaApplied = true;
    final notifier = ref.read(studioFormProvider.notifier);
    // Only pre-fill when the form is still at its untouched default values so
    // we never override deliberate user edits from a prior session.
    final form = ref.read(studioFormProvider);
    if (form.prompt.isEmpty) notifier.setGenre(defaults.genre);
    if (form.language == 'English') notifier.setLanguage(defaults.language);
    if (form.tempo == TempoBracket.medium) notifier.setTempo(defaults.tempo);
    if (form.vocalEnergy == VocalEnergy.mid) notifier.setVocalEnergy(defaults.vocalEnergy);
    if (form.mood == 'Uplifting') notifier.setMood(defaults.mood);
  }

  static const List<String> _modeLabels = ['Compose', 'Voice', 'Crate & MPC'];

  Widget _modeSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Row(
            children: [
              for (var i = 0; i < _modeLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mode = i),
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: i == _mode
                            ? AppColors.brandPrimary
                            : AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: i == _mode
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        _modeLabels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: i == _mode
                              ? AppColors.brandContrast
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabScroll(bool isDesktop, List<Widget> children) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? AppSpacing.xl : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  children[i],
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final phase = ref.watch(studioFormProvider.select((s) => s.phase));
    final hasActiveTrack =
        ref.watch(playerStateProvider.select((s) => s.hasActiveTrack));

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: const VhunambiAppBar(),
      ),
      body: Column(
        children: [
          _modeSwitcher(),
          const ProgressTrackerWidget(),
          if (phase != GenerationPhase.idle)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 840),
                  child: GenerationPipelineCard(),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: [
                _tabScroll(isDesktop, [
                  const StudioSessionRecoveryBanner(),
                  // T6.10: DNA suggestion banner (REQ-DNA-STU-03)
                  _DnaSuggestionChip(),
                  const PromptInputBox(),
                  const ReferenceAudioDropzone(),
                  const RegionalGenreSelector(),
                  const MultilingualLanguageSelector(),
                  const AdvancedOptionsAccordion(),
                ]),
                _tabScroll(isDesktop, const [
                  BantuVoiceDeck(),
                  LivePhoneticAlignmentPreview(),
                ]),
                _tabScroll(isDesktop, [
                  OutlinedButton.icon(
                    key: const Key('studio_open_crate_btn'),
                    onPressed: () => _openHeritageStudio(context),
                    icon: const Icon(
                      Icons.album_rounded,
                      color: AppColors.coinGold,
                    ),
                    label: Text(
                      'Heritage Crate & MPC Slicer',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.inputBorder,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          PlayerObstacle(
            id: 'studio_action_bar',
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                AppSpacing.sm,
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                VhunambiBottomDockMetrics.scrollInset(
                  hasActiveTrack: hasActiveTrack,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: const StudioActionBar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// DNA suggestion banner rendered at the top of the Compose tab (T6.10 \u2014 REQ-DNA-STU-03).
///
/// Shows the user's top DNA genre pre-fill hint. Renders nothing when DNA is
/// uninitialized so the compose tab stays clean for new users.
class _DnaSuggestionChip extends ConsumerWidget {
  const _DnaSuggestionChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaults = ref.watch(dnaStudioDefaultsProvider);
    if (!defaults.hasDnaDefaults) return const SizedBox.shrink();

    return Container(
      key: const Key('dna_studio_suggestion_chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withAlpha(20),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.brandPrimary.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Text('🧬', style: TextStyle(fontSize: 14)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'DNA suggests: ${defaults.genre} • ${defaults.language}',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the Heritage Crate Digging browser & 8-Pad MPC Slicer sheet.
void _openHeritageStudio(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceModal,
          borderRadius: AppRadius.modalBorder,
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.modalBorder,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(child: _HeritageStudioSheet()),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Toggles between the crate browser and the MPC slicer once a sample is
/// chopped (Phase 22).
class _HeritageStudioSheet extends StatefulWidget {
  const _HeritageStudioSheet();

  @override
  State<_HeritageStudioSheet> createState() => _HeritageStudioSheetState();
}

class _HeritageStudioSheetState extends State<_HeritageStudioSheet> {
  bool _showSlicer = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showSlicer
            ? Column(
                key: const ValueKey('heritage_slicer_view'),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Row(
                      children: [
                        VhunambiBackButton(
                          onPressed: () => setState(() => _showSlicer = false),
                          tooltip: 'Back to Crate',
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Back to Crate',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: MpcSlicerDeck()),
                ],
              )
            : CrateBrowserDeck(
                key: const ValueKey('heritage_crate_view'),
                onChop: (_) => setState(() => _showSlicer = true),
              ),
      ),
    );
  }
}
