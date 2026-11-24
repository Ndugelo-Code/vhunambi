import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_app_bar.dart';
import '../../../../core/widgets/vhunambi_glass_tab_bar.dart';
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
import '../widgets/song_dna_hover_pill.dart';
import '../widgets/studio_action_bar.dart';
import '../widgets/studio_lyrics_and_bake_deck.dart';
import '../widgets/studio_past_songs_remix_shelf.dart';
import '../widgets/studio_session_recovery_banner.dart';
import '../../domain/models/mycelium_biome_models.dart';
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
  final ScrollController _composeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Defer so that the ProviderContainer has initialised before we read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyDnaDefaults());
  }

  @override
  void dispose() {
    _composeScrollController.dispose();
    super.dispose();
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: VhunambiGlassTabBar(
            scrollable: false,
            selectedIndex: currentTab.index,
            onSelected: (index) {
              ref.read(studioCockpitTabProvider.notifier).state =
                  CockpitWorkspaceTab.values[index];
            },
            items: [
              for (final tab in CockpitWorkspaceTab.values)
                VhunambiGlassTabItem(
                  key: Key(
                    'studio_tab_${tab == CockpitWorkspaceTab.crateAndMpc ? 'crate_mpc' : tab.name}',
                  ),
                  label: tab.label,
                  icon: switch (tab) {
                    CockpitWorkspaceTab.compose => PhosphorIconsRegular.sparkle,
                    CockpitWorkspaceTab.voice =>
                      PhosphorIconsRegular.microphoneStage,
                    CockpitWorkspaceTab.crateAndMpc =>
                      PhosphorIconsRegular.slidersHorizontal,
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabScroll(
    bool isDesktop,
    List<Widget> children, {
    ScrollController? controller,
  }) {
    return SingleChildScrollView(
      controller: controller,
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
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: const VhunambiAppBar(),
      ),
      body: Column(
        children: [
          _modeSwitcher(activeTab),
          Expanded(
            child: IndexedStack(
              index: activeTab.index,
              children: [
                _tabScroll(
                  isDesktop,
                  [
                    if (isPipelineVisible)
                      GenerationPipelineCard(
                        onNewSong: () {
                          ref.read(generationProgressProvider.notifier).reset();
                          ref.read(studioFormProvider.notifier).reset();
                        },
                      ),
                    const StudioSessionRecoveryBanner(),
                    const PromptInputBox(),
                    const ReferenceAudioDropzone(),
                    const _DnaSuggestionChip(),
                    const ActiveRemixLineageBanner(),
                    const RegionalGenreSelector(),
                    const StudioLyricsAndBakeDeck(),
                    const MultilingualLanguageSelector(),
                    const AdvancedOptionsAccordion(),
                    StudioPastSongsRemixShelf(
                      onRemixSelected: () {
                        if (_composeScrollController.hasClients) {
                          _composeScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                    ),
                  ],
                  controller: _composeScrollController,
                ),
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
                color: AppColors.surfaceElevatedOf(context).withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderSubtleOf(context),
                    width: 1,
                  ),
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

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (hasDefaults)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIconsBold.dna,
                    color: AppColors.brandPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
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
          ),
        const SongDnaHoverPill(),
        Tooltip(
          message: 'Shuffle Sonic Vibe Dice',
          child: InkWell(
            key: const Key('cockpit_sonic_vibe_dice_btn'),
            onTap: () {
              ref.read(studioFormProvider.notifier).cycleSonicVibeDice();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
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
                      color: AppColors.textPrimaryOf(context),
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
