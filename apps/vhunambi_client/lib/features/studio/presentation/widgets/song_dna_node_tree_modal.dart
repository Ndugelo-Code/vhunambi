import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/bantu_voice_profile.dart';
import '../../domain/models/song_dna_graph_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/song_dna_graph_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

/// Full-Screen Sovereign 3D Bioluminescent Song Organelle Universe (REQ-P51-WORLD-01..02,
/// REQ-P51-MEMB-01, REQ-P51-CORE-01, REQ-P51-DENDR-01..04).
/// Features deep abyssal bio-fluid space, 4 depth-of-field bokeh satellite organelles,
/// 3D geodesic cyan filamentous membrane, inner blazing amber nucleus, 4 multi-jointed
/// molecular dendrite chains (24+ interactive sub-nodes), and decluttered holographic HUD.
class SongDnaNodeTreeModal extends ConsumerStatefulWidget {
  final VoidCallback? onSynthesizeRequested;

  const SongDnaNodeTreeModal({super.key, this.onSynthesizeRequested});

  /// Presents the 3D Song DNA tree as a 100% opaque sovereign full-screen route (REQ-P51-FIX-03).
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSynthesizeRequested,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true, // 100% Opaque route: zero Studio form bleed-through
        settings: const RouteSettings(name: '/song_dna_universe'),
        pageBuilder: (ctx, anim1, anim2) =>
            SongDnaNodeTreeModal(onSynthesizeRequested: onSynthesizeRequested),
        transitionsBuilder: (ctx, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<SongDnaNodeTreeModal> createState() =>
      _SongDnaNodeTreeModalState();
}

class _SongDnaNodeTreeModalState extends ConsumerState<SongDnaNodeTreeModal>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _conduitFlowController;
  late final AnimationController _membraneWaveController;

  // 6-DOF Camera Spherical Coordinates
  double _yaw = 0.0; // Azimuth
  double _pitch = 0.0; // Polar elevation
  double _cameraDistance = 420.0; // Zoom distance
  Offset _panOffset = Offset.zero;

  final Map<String, Offset> _projectedScreenCoordinates = {};

  @override
  void initState() {
    super.initState();
    // Suppress MiniPlayerHost while 3D Organelle Universe is active (REQ-P51-FIX-03)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(modalSheetOpenCountProvider.notifier).state++;
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _conduitFlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _membraneWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    // Release MiniPlayerHost suppression
    try {
      final current = ref.read(modalSheetOpenCountProvider);
      if (current > 0) {
        ref.read(modalSheetOpenCountProvider.notifier).state = current - 1;
      }
    } catch (_) {}

    _pulseController.dispose();
    _conduitFlowController.dispose();
    _membraneWaveController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraDistance = (_cameraDistance - 40.0).clamp(240.0, 750.0);
    });
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraDistance = (_cameraDistance + 40.0).clamp(240.0, 750.0);
    });
  }

  void _resetCamera() {
    HapticFeedback.mediumImpact();
    setState(() {
      _yaw = 0.0;
      _pitch = 0.0;
      _cameraDistance = 420.0;
      _panOffset = Offset.zero;
    });
  }

  void _selectNode(String nodeId) {
    HapticFeedback.selectionClick();
    ref.read(songDnaGraphProvider.notifier).selectNode(nodeId);

    // Smooth camera dive towards selected node's 3D angle (REQ-P51-CAM-01)
    final nodes = ref.read(songDnaGraphProvider).nodes;
    final target = nodes.cast<SongDnaNode?>().firstWhere(
      (n) => n?.id == nodeId,
      orElse: () => null,
    );

    if (target != null && target.id != 'node_core') {
      final pos = target.localPosition;
      final targetYaw = math.atan2(pos.x, pos.z + 0.001);
      final targetPitch = (-pos.y / (pos.length + 0.001)).clamp(-0.55, 0.55);
      setState(() {
        _yaw = targetYaw * 0.5;
        _pitch = targetPitch * 0.5;
        _cameraDistance = 380.0;
      });
    } else {
      setState(() {});
    }
  }

  /// Triggers live synthesis pipeline and closes modal (REQ-P51-FIX-04).
  void _synthesizeFromDna() {
    HapticFeedback.heavyImpact();
    final formState = ref.read(studioFormProvider);

    Navigator.of(context).pop();

    if (widget.onSynthesizeRequested != null) {
      widget.onSynthesizeRequested!();
      return;
    }

    // 1. Advance studio form state to queued
    ref.read(studioFormProvider.notifier).triggerGeneration();

    // 2. Start live generation progress FSM in GenerationPipelineNotifier
    final trackTitle = formState.prompt.isNotEmpty
        ? formState.prompt
        : (formState.genre.isNotEmpty
              ? '${formState.genre} Synthesis'
              : 'African AI Genesis');
    final genre = formState.genre.isNotEmpty ? formState.genre : 'Amapiano';
    final language = formState.language.isNotEmpty
        ? formState.language
        : 'isiZulu';

    ref
        .read(generationProgressProvider.notifier)
        .submitAndStartGeneration(
          trackTitle: trackTitle,
          genre: genre,
          language: language,
          lyrics: formState.customLyrics,
          isInstrumental: formState.isInstrumental,
        );
  }

  Map<String, Offset> _projectAllNodes(Size size, List<SongDnaNode> nodes) {
    if (size.width <= 0 || size.height <= 0 || nodes.isEmpty) return {};

    final cx = size.width * 0.5 + _panOffset.dx;
    final cy = size.height * 0.44 + _panOffset.dy;
    const focalLength = 380.0;

    final cosY = math.cos(_yaw);
    final sinY = math.sin(_yaw);
    final cosP = math.cos(_pitch);
    final sinP = math.sin(_pitch);

    final result = <String, Offset>{};
    for (final node in nodes) {
      final pos = node.localPosition;
      final x1 = pos.x * cosY - pos.z * sinY;
      final z1 = pos.x * sinY + pos.z * cosY;
      final y2 = pos.y * cosP - z1 * sinP;
      final z2 = pos.y * sinP + z1 * cosP;

      final depth = focalLength + _cameraDistance + z2;
      final scale = depth > 10.0 ? (focalLength / depth) : 0.1;
      final screenOffset = Offset(cx + x1 * scale, cy + y2 * scale);
      result[node.id] = screenOffset;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(songDnaGraphProvider);
    final formState = ref.watch(studioFormProvider);
    final selectedNode = graph.selectedNode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('song_dna_3d_tree_modal'),
      // 100% OPAQUE Abyssal Void Background — zero Studio form bleed-through (REQ-P51-FIX-03)
      backgroundColor: const Color(0xFF020710),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            _buildTopBar(context, graph),

            // 3D Spatial Canvas with Bioluminescent Organelle Universe
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final projectedMap = _projectAllNodes(size, graph.nodes);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _yaw += details.delta.dx * 0.007;
                        _pitch = (_pitch + details.delta.dy * 0.007).clamp(
                          -0.75,
                          0.75,
                        );
                      });
                    },
                    child: SizedBox.expand(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 3D Organelle CustomPainter (Membrane, Nucleus, Filaments, Dendrites)
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _pulseController,
                              _conduitFlowController,
                              _membraneWaveController,
                            ]),
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size.infinite,
                                painter: _BioluminescentOrganelle3DPainter(
                                  yaw: _yaw,
                                  pitch: _pitch,
                                  cameraDistance: _cameraDistance,
                                  panOffset: _panOffset,
                                  nodes: graph.nodes,
                                  selectedNodeId: graph.selectedNodeId,
                                  pulseValue: _pulseController.value,
                                  flowProgress: _conduitFlowController.value,
                                  waveProgress: _membraneWaveController.value,
                                  onScreenProjected: (id, offset) {
                                    _projectedScreenCoordinates[id] = offset;
                                  },
                                ),
                              );
                            },
                          ),

                          // Decluttered Billboard Cues & Receptor Hit Targets (REQ-P51-HUD-01)
                          for (final node in graph.nodes) ...[
                            if (node.id != 'node_core')
                              _buildDeclutteredReceptorTarget(
                                node,
                                projectedMap[node.id],
                                graph.selectedNodeId,
                              ),
                          ],

                          // Camera HUD Controls (REQ-P50-TREE-03)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _buildCameraControls(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Sleek Floating Quick-Action Card (REQ-P50-CARD-01..06)
            if (selectedNode != null)
              _buildQuickActionCard(context, selectedNode, formState, isDark),

            // Bottom CTA: Synthesize Song from 3D DNA (REQ-P50-CARD-07)
            _buildBottomCtaDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SongDnaGraphState graph) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: graph.primaryGlowColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(
              PhosphorIconsBold.dna,
              size: 18,
              color: graph.primaryGlowColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SONG DNA QUANTUM TREE',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${(graph.overallCompleteness * 100).toInt()}% Genetic Completeness • ${graph.nodes.length} Nodes Wired',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsBold.x,
              size: 20,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('song_dna_zoom_in_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.plus,
              size: 14,
              color: Colors.white,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _zoomIn,
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          IconButton(
            key: const Key('song_dna_zoom_out_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.minus,
              size: 14,
              color: Colors.white,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _zoomOut,
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          IconButton(
            key: const Key('song_dna_reset_camera_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.arrowsCounterClockwise,
              size: 14,
              color: AppColors.brandPrimary,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _resetCamera,
          ),
        ],
      ),
    );
  }

  /// Decluttered Billboard Cue & Receptor Touch Target (REQ-P51-HUD-01).
  /// Replaces giant rectangular card pile-up with sleek holographic micro-callouts
  /// while keeping all Key('song_dna_bubble_${node.id}') hit-targets accessible!
  Widget _buildDeclutteredReceptorTarget(
    SongDnaNode node,
    Offset? offset,
    String? selectedNodeId,
  ) {
    if (offset == null) return const SizedBox.shrink();

    final isSelected = node.id == selectedNodeId;
    final isPrimaryOrFocused =
        isSelected ||
        node.parentId == 'node_core' ||
        node.id == 'node_beat_tempo' ||
        node.id == 'node_vocal_persona' ||
        node.id == 'node_sketchpad_groove';

    return Positioned(
      left: offset.dx - (isPrimaryOrFocused ? 64.0 : 22.0),
      top: offset.dy - (isPrimaryOrFocused ? 28.0 : 22.0),
      width: isPrimaryOrFocused ? 128.0 : 44.0,
      height: isPrimaryOrFocused ? 30.0 : 44.0,
      child: GestureDetector(
        key: Key('song_dna_bubble_${node.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectNode(node.id),
        child: isPrimaryOrFocused
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? node.accentColor.withValues(alpha: 0.35)
                      : const Color(0xFF071220).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? node.accentColor
                        : node.accentColor.withValues(alpha: 0.45),
                    width: isSelected ? 1.6 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: node.accentColor.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(node.icon, size: 11, color: node.accentColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        node.cueLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.white70,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                // Invisible padded hit target for secondary receptor nodes
                color: Colors.transparent,
              ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    SongDnaNode node,
    StudioFormState formState,
    bool isDark,
  ) {
    return Container(
      key: const Key('song_dna_quick_action_card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF081422).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: node.accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: node.accentColor.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon, category badge, and close/detach
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: node.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  node.icon,
                  size: 16,
                  color: node.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      node.category.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: node.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (node.isDetachable)
                TextButton.icon(
                  key: const Key('song_dna_detach_node_btn'),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(songDnaGraphProvider.notifier)
                        .detachInvasiveNode(node.id);
                  },
                  icon: const PhosphorIcon(
                    PhosphorIconsBold.trash,
                    size: 13,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'Detach from Graph',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const PhosphorIcon(
                  PhosphorIconsBold.x,
                  size: 14,
                  color: Colors.white54,
                ),
                onPressed: () {
                  ref.read(songDnaGraphProvider.notifier).selectNode(null);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Contextual tactile mutator controls
          _buildContextualMutator(context, node, formState),
        ],
      ),
    );
  }

  Widget _buildContextualMutator(
    BuildContext context,
    SongDnaNode node,
    StudioFormState formState,
  ) {
    final notifier = ref.read(songDnaGraphProvider.notifier);

    // 1. Beat & Tempo mutators
    if (node.id == 'node_beat_tempo' ||
        node.id == 'node_beat_tempo_feel' ||
        node.id == 'node_beat_rhythm_pocket') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tempo (BPM)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final bpm in [112, 115, 118, 122, 128]) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildMutatorPill(
                      label: '$bpm',
                      isSelected:
                          formState.tempo.label.contains('$bpm') ||
                          (bpm == 118 &&
                              formState.tempo == TempoBracket.medium),
                      onTap: () => notifier.updateTempo(bpm),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    // 2. Vocal Persona & Bantu Language
    if (node.id == 'node_vocal_persona' ||
        node.id == 'node_language_lyrics' ||
        node.id == 'node_vocal_lora' ||
        node.id == 'node_vocal_dialects') {
      final bantuLangs = ['isiZulu', 'Xitsonga', 'Tshivenda', 'Sesotho'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linguistic Attunement:',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final lang in bantuLangs) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildMutatorPill(
                      label: lang,
                      isSelected: formState.language == lang,
                      onTap: () => notifier.updateLanguage(lang),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // 3. Instrument & 5-Channel Groove Matrix
    if (node.id == 'node_sketchpad_groove' ||
        node.id.startsWith('node_inst_') ||
        node.id == 'node_heritage_mpc') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              '5-Channel Groove Sequencer Attached',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const PhosphorIcon(PhosphorIconsBold.faders, size: 14),
            label: const Text(
              'Open Sketchpad',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const MelodySketchpadModal(),
              );
            },
          ),
        ],
      );
    }

    // Default Node info
    return Text(
      node.subtitle,
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }

  Widget _buildMutatorPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : Colors.white12,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom CTA: Synthesize Song from 3D DNA (REQ-P50-CARD-07, REQ-P51-FIX-04).
  /// Uses FittedBox to guarantee single-line button rendering across all mobile screen widths.
  Widget _buildBottomCtaDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          key: const Key('song_dna_synthesize_btn'),
          onPressed: _synthesizeFromDna,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 8,
            shadowColor: AppColors.brandPrimary.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(
                  PhosphorIconsBold.sparkle,
                  size: 20,
                  color: Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  '⚡ Synthesize Song from 3D DNA',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D Bioluminescent Organelle CustomPainter (REQ-P51-WORLD-01..02, REQ-P51-MEMB-01, REQ-P51-CORE-01, REQ-P51-DENDR-01..04).
/// Paints the 100% opaque deep bio-space, depth-of-field bokeh satellite organelles,
/// 3D harmonic deformed geodesic cyan membrane, inner blazing amber nucleus with curved neural filaments,
/// and articulated multi-jointed molecular dendrite chains.
class _BioluminescentOrganelle3DPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double cameraDistance;
  final Offset panOffset;
  final List<SongDnaNode> nodes;
  final String? selectedNodeId;
  final double pulseValue;
  final double flowProgress;
  final double waveProgress;
  final void Function(String id, Offset screenOffset) onScreenProjected;

  _BioluminescentOrganelle3DPainter({
    required this.yaw,
    required this.pitch,
    required this.cameraDistance,
    required this.panOffset,
    required this.nodes,
    this.selectedNodeId,
    required this.pulseValue,
    required this.flowProgress,
    required this.waveProgress,
    required this.onScreenProjected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || nodes.isEmpty) return;

    final cx = size.width * 0.5 + panOffset.dx;
    final cy = size.height * 0.44 + panOffset.dy;
    const focalLength = 380.0;

    // =========================================================================
    // LAYER 1: ABYSSAL MICROSCOPIC VOID & BOKEH SATELLITE ORGANELLES
    // =========================================================================
    // Deep radial bio-fluid gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          ((cx / size.width) - 0.5) * 1.2,
          ((cy / size.height) - 0.5) * 1.2,
        ),
        radius: 1.1,
        colors: const [Color(0xFF04162B), Color(0xFF020914), Color(0xFF01040A)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle horizontal anamorphic cyan lens flare beam
    final flarePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFF00F5D4).withValues(alpha: 0.08),
          const Color(0xFF00F5D4).withValues(alpha: 0.18),
          const Color(0xFF00F5D4).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, cy - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, cy - 1.5, size.width, 3), flarePaint);

    // 4 Blurred Depth-of-Field Satellite Bokeh Organelles (REQ-P51-WORLD-02)
    final parallaxX = math.sin(yaw) * 22.0;
    final parallaxY = math.sin(pitch) * 22.0;
    _drawBokehSatellite(
      canvas,
      Offset(size.width * 0.14 + parallaxX, size.height * 0.16 + parallaxY),
      radius: 42.0,
      color: const Color(0xFF00F5D4),
      subCount: 3,
    );
    _drawBokehSatellite(
      canvas,
      Offset(size.width * 0.86 - parallaxX, size.height * 0.14 - parallaxY),
      radius: 48.0,
      color: const Color(0xFF06B6D4),
      subCount: 4,
    );
    _drawBokehSatellite(
      canvas,
      Offset(size.width * 0.84 - parallaxX, size.height * 0.82 - parallaxY),
      radius: 52.0,
      color: const Color(0xFFFF6B00),
      subCount: 4,
    );
    _drawBokehSatellite(
      canvas,
      Offset(size.width * 0.16 + parallaxX, size.height * 0.80 + parallaxY),
      radius: 38.0,
      color: const Color(0xFF10B981),
      subCount: 3,
    );

    // Subtle holographic bio-telemetry HUD lines on far left and right horizons
    _drawBioTelemetryHud(canvas, size, cx, cy);

    // =========================================================================
    // LAYER 2: 3D PROJECTION & TRANSFORMATION MATRICES
    // =========================================================================
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    Offset project(Vector3D pos) {
      final x1 = pos.x * cosY - pos.z * sinY;
      final z1 = pos.x * sinY + pos.z * cosY;
      final y2 = pos.y * cosP - z1 * sinP;
      final z2 = pos.y * sinP + z1 * cosP;
      final depth = focalLength + cameraDistance + z2;
      final scale = depth > 10.0 ? (focalLength / depth) : 0.1;
      return Offset(cx + x1 * scale, cy + y2 * scale);
    }

    _Projected3DItem projectItem(SongDnaNode node) {
      final pos = node.localPosition;
      final x1 = pos.x * cosY - pos.z * sinY;
      final z1 = pos.x * sinY + pos.z * cosY;
      final y2 = pos.y * cosP - z1 * sinP;
      final z2 = pos.y * sinP + z1 * cosP;
      final depth = focalLength + cameraDistance + z2;
      final scale = depth > 10.0 ? (focalLength / depth) : 0.1;
      final offset = Offset(cx + x1 * scale, cy + y2 * scale);
      onScreenProjected(node.id, offset);
      return _Projected3DItem(
        node: node,
        screenOffset: offset,
        depth: z2,
        scale: scale,
      );
    }

    final projectedNodes = nodes.map(projectItem).toList();
    final nodeMap = {for (final item in projectedNodes) item.node.id: item};
    final coreScreen = Offset(cx, cy);

    // Sort items for painter's algorithm (deepest first)
    projectedNodes.sort((a, b) => a.depth.compareTo(b.depth));

    // =========================================================================
    // LAYER 3: MOLECULAR BOND DENDRITE CONDUITS & PHOTON PACKETS
    // =========================================================================
    for (final item in projectedNodes) {
      if (item.node.id == 'node_core') continue;

      // Determine parent screen coordinate
      Offset parentScreen = coreScreen;
      if (item.node.parentId != null &&
          nodeMap.containsKey(item.node.parentId)) {
        parentScreen = nodeMap[item.node.parentId!]!.screenOffset;
      }

      final color = item.node.accentColor;
      final isSelected = item.node.id == selectedNodeId;
      final lineWidth = (item.scale * (isSelected ? 2.6 : 1.4)).clamp(0.8, 3.5);

      // Outer glowing aura of bond tube
      final auraPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.45 : 0.20)
        ..strokeWidth = lineWidth * 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(parentScreen, item.screenOffset, auraPaint);

      // Core molecular bond line
      final bondPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.95 : 0.70)
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(parentScreen, item.screenOffset, bondPaint);

      // Traveling bioluminescent photon packet with light trail
      final packetT =
          (flowProgress * 1.4 + (item.node.id.hashCode.abs() % 100) / 100.0) %
          1.0;
      final packetPos = Offset.lerp(parentScreen, item.screenOffset, packetT)!;
      final packetPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(packetPos, 2.2 * item.scale, packetPaint);

      final packetGlow = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(packetPos, 4.5 * item.scale, packetGlow);
    }

    // =========================================================================
    // LAYER 4: THE CENTRAL BREATHING 3D CELLULAR ORGANELLE (REQ-P51-MEMB-01)
    // =========================================================================
    _drawCentralBreathingOrganelle(
      canvas: canvas,
      center: coreScreen,
      scale: focalLength / (focalLength + cameraDistance),
      cosY: cosY,
      sinY: sinY,
      cosP: cosP,
      sinP: sinP,
      focalLength: focalLength,
      cameraDistance: cameraDistance,
      cx: cx,
      cy: cy,
    );

    // =========================================================================
    // LAYER 5: STIPPLED 3D SPHERES & DOUBLE-RING RECEPTORS (◎) (REQ-P51-NODE-01)
    // =========================================================================
    for (final item in projectedNodes) {
      if (item.node.id == 'node_core') continue; // Handled by Central Organelle

      final node = item.node;
      final isSelected = node.id == selectedNodeId;
      final isTerminal = node.isTerminalReceptor;
      final baseRadius = (isTerminal ? 8.0 : 13.0) * item.scale;
      final currentRadius =
          baseRadius * (isSelected ? (1.0 + pulseValue * 0.15) : 1.0);

      // 1. Soft corona glow
      final glowPaint = Paint()
        ..color = node.accentColor.withValues(alpha: isSelected ? 0.75 : 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 12 : 6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(item.screenOffset, currentRadius * 1.8, glowPaint);

      if (isTerminal) {
        // DOUBLE-RING TERMINAL RECEPTOR (◎)
        final outerRingPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelected ? 2.0 : 1.2) * item.scale
          ..color = node.accentColor.withValues(alpha: isSelected ? 1.0 : 0.75);
        canvas.drawCircle(
          item.screenOffset,
          currentRadius * 1.3,
          outerRingPaint,
        );

        final innerCorePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = isSelected ? node.accentColor : const Color(0xFF071220);
        canvas.drawCircle(
          item.screenOffset,
          currentRadius * 0.7,
          innerCorePaint,
        );

        final innerDotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white;
        canvas.drawCircle(
          item.screenOffset,
          currentRadius * 0.35,
          innerDotPaint,
        );
      } else {
        // PRIMARY JUNCTION SPHERE (Stippled 3D shading)
        final sphereShader =
            RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.9,
              colors: [Colors.white, node.accentColor, const Color(0xFF071220)],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromCircle(center: item.screenOffset, radius: currentRadius),
            );

        final spherePaint = Paint()..shader = sphereShader;
        canvas.drawCircle(item.screenOffset, currentRadius, spherePaint);

        // Precision outer bounding ring
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelected ? 2.2 : 1.4) * item.scale
          ..color = node.accentColor;
        canvas.drawCircle(item.screenOffset, currentRadius * 1.25, ringPaint);
      }
    }
  }

  /// Draws 3D Geodesic Deformable Filamentous Membrane & Blazing Amber Nucleus.
  void _drawCentralBreathingOrganelle({
    required Canvas canvas,
    required Offset center,
    required double scale,
    required double cosY,
    required double sinY,
    required double cosP,
    required double sinP,
    required double focalLength,
    required double cameraDistance,
    required double cx,
    required double cy,
  }) {
    // --- 1. Inner Blazing Amber Nucleus (REQ-P51-CORE-01) ---
    final nucleusRadius = 24.0 * scale * (1.0 + pulseValue * 0.08);

    // Blazing amber corona glow
    final amberCorona = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(
                0xFFFFF176,
              ).withValues(alpha: 0.95), // White-yellow core
              const Color(0xFFFFB703).withValues(alpha: 0.85),
              const Color(0xFFFF6B00).withValues(alpha: 0.65),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.75, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: nucleusRadius * 2.2),
          );
    canvas.drawCircle(center, nucleusRadius * 2.2, amberCorona);

    // Solid nucleus core
    final nucleusCore = Paint()
      ..color = const Color(0xFFFF8500)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, nucleusRadius, nucleusCore);

    // 4 Internal Orange Sub-Organelle Vesicles (Key, BPM, Energy, Mastery)
    for (int i = 0; i < 4; i++) {
      final vAngle = (i * math.pi * 0.5) + (waveProgress * 2 * math.pi);
      final vDist = nucleusRadius * 1.25;
      final vesiclePos = Offset(
        center.dx + math.cos(vAngle) * vDist,
        center.dy + math.sin(vAngle) * vDist * 0.6,
      );

      final vPaint = Paint()
        ..color = const Color(0xFFFFB703).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(vesiclePos, 3.8 * scale, vPaint);

      // Curved internal neural filament connecting vesicle to core
      final filamentPaint = Paint()
        ..color = const Color(0xFFFF6B00).withValues(alpha: 0.55)
        ..strokeWidth = 1.0 * scale
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + vesiclePos.dx) * 0.5 + 4,
          (center.dy + vesiclePos.dy) * 0.5 - 4,
          vesiclePos.dx,
          vesiclePos.dy,
        );
      canvas.drawPath(path, filamentPaint);
    }

    // --- 2. Outer Cyan Geodesic Filamentous Membrane Mesh (REQ-P51-MEMB-01) ---
    const int latSteps = 8;
    const int lonSteps = 14;
    const double baseRadius = 76.0;
    final t = waveProgress * 2 * math.pi;

    final gridPoints = List.generate(latSteps + 1, (j) {
      final phi = -math.pi / 2 + (j * math.pi / latSteps);
      return List.generate(lonSteps, (i) {
        final theta = i * 2 * math.pi / lonSteps;

        // 3D Harmonic Wave Deformation Equation:
        // r(θ, φ, t) = R * (1 + 0.07*sin(3θ + 1.6t)*cos(2φ - 1.2t) + 0.04*cos(4φ + 2.2t))
        final r =
            baseRadius *
            (1.0 +
                0.07 *
                    math.sin(3 * theta + 1.6 * t) *
                    math.cos(2 * phi - 1.2 * t) +
                0.04 * math.cos(4 * phi + 2.2 * t));

        final x = r * math.cos(phi) * math.cos(theta);
        final y = r * math.sin(phi);
        final z = r * math.cos(phi) * math.sin(theta);

        // 3D Camera Rotation (yaw then pitch)
        final x1 = x * cosY - z * sinY;
        final z1 = x * sinY + z * cosY;
        final y2 = y * cosP - z1 * sinP;
        final z2 = y * sinP + z1 * cosP;

        final depth = focalLength + cameraDistance + z2;
        final s = depth > 10.0 ? (focalLength / depth) : 0.1;
        return Offset(cx + x1 * s, cy + y2 * s);
      });
    });

    final filamentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.35);

    // Draw longitudinal strands
    for (int i = 0; i < lonSteps; i++) {
      final path = Path()..moveTo(gridPoints[0][i].dx, gridPoints[0][i].dy);
      for (int j = 1; j <= latSteps; j++) {
        path.lineTo(gridPoints[j][i].dx, gridPoints[j][i].dy);
      }
      canvas.drawPath(path, filamentPaint);
    }

    // Draw latitudinal rings
    for (int j = 1; j < latSteps; j++) {
      final path = Path()..moveTo(gridPoints[j][0].dx, gridPoints[j][0].dy);
      for (int i = 1; i < lonSteps; i++) {
        path.lineTo(gridPoints[j][i].dx, gridPoints[j][i].dy);
      }
      path.close();
      canvas.drawPath(path, filamentPaint);
    }

    // Outer Fresnel Rim Glow (Glowing silhouette ring)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(center, baseRadius * scale * 1.05, rimPaint);
  }

  /// Draws out-of-focus background bokeh satellite organelle clusters.
  void _drawBokehSatellite(
    Canvas canvas,
    Offset position, {
    required double radius,
    required Color color,
    required int subCount,
  }) {
    final blurPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius, blurPaint);

    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius * 0.45, innerPaint);

    for (int i = 0; i < subCount; i++) {
      final angle = i * 2 * math.pi / subCount;
      final dist = radius * 0.7;
      final subPos = Offset(
        position.dx + math.cos(angle) * dist,
        position.dy + math.sin(angle) * dist * 0.7,
      );
      canvas.drawCircle(subPos, radius * 0.25, innerPaint);
    }
  }

  /// Draws subtle holographic bio-telemetry HUD lines and ticks on horizons.
  void _drawBioTelemetryHud(Canvas canvas, Size size, double cx, double cy) {
    final hudLinePaint = Paint()
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    // Left horizon bracket
    canvas.drawLine(
      Offset(16, size.height * 0.35),
      Offset(16, size.height * 0.65),
      hudLinePaint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.35),
      Offset(32, size.height * 0.35),
      hudLinePaint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.65),
      Offset(32, size.height * 0.65),
      hudLinePaint,
    );

    // Right horizon bracket
    canvas.drawLine(
      Offset(size.width - 16, size.height * 0.35),
      Offset(size.width - 16, size.height * 0.65),
      hudLinePaint,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height * 0.35),
      Offset(size.width - 32, size.height * 0.35),
      hudLinePaint,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height * 0.65),
      Offset(size.width - 32, size.height * 0.65),
      hudLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BioluminescentOrganelle3DPainter oldDelegate) =>
      true;
}

class _Projected3DItem {
  final SongDnaNode node;
  final Offset screenOffset;
  final double depth;
  final double scale;

  const _Projected3DItem({
    required this.node,
    required this.screenOffset,
    required this.depth,
    required this.scale,
  });
}
