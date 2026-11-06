import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
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
import '../providers/generation_pipeline_providers.dart';
import '../widgets/advanced_options_accordion.dart';
import '../widgets/active_remix_lineage_banner.dart';
import '../widgets/bantu_voice_deck.dart';
import '../widgets/generation_pipeline_card.dart';
import '../widgets/live_phonetic_alignment_preview.dart';
import '../widgets/multilingual_language_selector.dart';
import '../widgets/prompt_input_box.dart';
import '../widgets/reference_audio_dropzone.dart';
import '../widgets/regional_genre_selector.dart';
import '../widgets/progress_tracker.dart';
import '../widgets/studio_action_bar.dart';
import '../widgets/studio_session_recovery_banner.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../widgets/cockpit_quantum_entanglement_rack.dart';
import '../widgets/inline_crate_mpc_workbench.dart';
import '../../../creator_dna/presentation/providers/dna_studio_defaults_provider.dart';

class StudioView extends ConsumerStatefulWidget {
  const StudioView({super.key});

  @override
  ConsumerState<StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends ConsumerState<StudioView> {
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

  Widget _modeSwitcher(CockpitWorkspaceTab currentTab) {
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
              for (final tab in CockpitWorkspaceTab.values) ...[
                if (tab.index > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: InkWell(
                    key: Key('studio_tab_${tab == CockpitWorkspaceTab.crateAndMpc ? 'crate_mpc' : tab.name}'),
                    onTap: () => ref.read(studioCockpitTabProvider.notifier).state = tab,
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tab == currentTab
                            ? AppColors.brandPrimary
                            : AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: tab == currentTab
                              ? AppColors.brandPrimary
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        tab.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: tab == currentTab
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
    final activeTab = ref.watch(studioCockpitTabProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final phase = ref.watch(studioFormProvider.select((s) => s.phase));
    final generationProgress = ref.watch(generationProgressProvider);
    final hasActiveTrack =
        ref.watch(playerStateProvider.select((s) => s.hasActiveTrack));

    final isPipelineVisible = activeTab == CockpitWorkspaceTab.compose &&
        (generationProgress != null ||
            phase == GenerationPhase.queued ||
            phase == GenerationPhase.processing ||
            phase == GenerationPhase.ready);

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
          _modeSwitcher(activeTab),
          const ProgressTrackerWidget(),
          if (isPipelineVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: GenerationPipelineCard(
                    onNewSong: () {
                      ref.read(generationProgressProvider.notifier).reset();
                      ref.read(studioFormProvider.notifier).reset();
                    },
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: activeTab.index,
              children: [
                _tabScroll(isDesktop, [
                  const StudioSessionRecoveryBanner(),
                  const PromptInputBox(),
                  const ReferenceAudioDropzone(),
                  const _DnaSuggestionChip(),
                  const CockpitQuantumEntanglementRack(),
                  const ActiveRemixLineageBanner(),
                  const RegionalGenreSelector(),
                  const MultilingualLanguageSelector(),
                  const AdvancedOptionsAccordion(),
                ]),
                _tabScroll(isDesktop, const [
                  BantuVoiceDeck(),
                  LivePhoneticAlignmentPreview(),
                ]),
                _tabScroll(isDesktop, const [
                  InlineCrateMpcWorkbench(),
                ]),
              ],
            ),
          ),
          PlayerObstacle(
            id: 'studio_action_bar',
            child: Container(
              decoration: BoxDecoration(
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
    final hasDefaults = defaults.hasDnaDefaults;

    return Row(
      children: [
        if (hasDefaults)
          Expanded(
            child: Container(
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
                  PhosphorIcon(
                    PhosphorIconsBold.dna,
                    color: AppColors.brandPrimary,
                    size: 16,
                  ),
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
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message: 'Shuffle Sonic Vibe Dice',
          child: InkWell(
            key: const Key('cockpit_sonic_vibe_dice_btn'),
            onTap: () {
              ref.read(studioFormProvider.notifier).cycleSonicVibeDice();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIconsBold.diceFive,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vibe Dice',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
