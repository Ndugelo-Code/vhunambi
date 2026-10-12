import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../player/presentation/providers/player_provider.dart';
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
import '../widgets/studio_action_bar.dart';

class StudioView extends ConsumerStatefulWidget {
  const StudioView({super.key});

  @override
  ConsumerState<StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends ConsumerState<StudioView> {
  int _mode = 0;

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
        child: const _StudioAppBar(),
      ),
      body: Column(
        children: [
          _modeSwitcher(),
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
                _tabScroll(isDesktop, const [
                  PromptInputBox(),
                  ReferenceAudioDropzone(),
                  RegionalGenreSelector(),
                  MultilingualLanguageSelector(),
                  AdvancedOptionsAccordion(),
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
          Container(
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
                constraints: BoxConstraints(maxWidth: 840),
                child: StudioActionBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAppBar extends StatelessWidget {
  const _StudioAppBar();

  @override
  Widget build(BuildContext context) {
    return VhunambiTopBarSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            // Brand Emblem
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.music_note_rounded,
                size: 20,
                color: AppColors.brandContrast,
              ),
            ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'VHUNAMBI',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),

              // Studio Route Title
              Text(
                'Studio',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),

              // Token Balance Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '10 left',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Live Alert Centre (Phase 11)
              const NotificationBellButton(),
            ],
          ),
        ),
    );
  }
}

/// Opens the Heritage Crate Digging browser & 8-Pad MPC Slicer sheet.
void _openHeritageStudio(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCanvas,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalBorder),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _HeritageStudioSheet(),
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
      child: _showSlicer
          ? Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showSlicer = false),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Crate'),
                  ),
                ),
                const Expanded(child: MpcSlicerDeck()),
              ],
            )
          : CrateBrowserDeck(
              onChop: (_) => setState(() => _showSlicer = true),
            ),
    );
  }
}
