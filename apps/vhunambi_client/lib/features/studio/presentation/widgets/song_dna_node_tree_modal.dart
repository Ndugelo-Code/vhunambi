import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/song_dna_graph_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/song_dna_graph_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

/// Full-Screen Sovereign 3D Bioluminescent Song Organelle Universe (REQ-P51-WORLD-01..02,
/// REQ-P52-MACRO-01..04, REQ-P52-MUCUS-01, REQ-P52-CORE-01, REQ-P52-STEM-01..04).
/// Features macro-canopy camera perspective, 2-tier spatial hierarchy (Overview vs Branch-Dive),
/// organic mucus-membrane stem bridges with flared meniscus webbing, 3 tilted orbital atomic energy rings,
/// additive bioluminescent bloom (BlendMode.plus), and pre-generation stem-lock controls.
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
  double _cameraDistance = 320.0; // Macro base distance (REQ-P52-MACRO-01)
  Offset _panOffset = Offset.zero;

  // 2-Tier Spatial Hierarchy (REQ-P52-MACRO-02)
  String? _focusedBranchRootId; // null = Overview Mode, non-null = Branch Canopy Focus

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
      _cameraDistance = (_cameraDistance - 35.0).clamp(160.0, 680.0);
    });
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraDistance = (_cameraDistance + 35.0).clamp(160.0, 680.0);
    });
  }

  void _resetCamera() {
    HapticFeedback.mediumImpact();
    setState(() {
      _focusedBranchRootId = null;
      _yaw = 0.0;
      _pitch = 0.0;
      _cameraDistance = 320.0;
      _panOffset = Offset.zero;
    });
  }

  /// Dives directly into a primary branch canopy (REQ-P52-MACRO-02).
  void _diveIntoBranch(String branchRootId) {
    HapticFeedback.mediumImpact();
    final nodes = ref.read(songDnaGraphProvider).nodes;
    final target = nodes.cast<SongDnaNode?>().firstWhere(
      (n) => n?.id == branchRootId,
      orElse: () => null,
    );

    setState(() {
      _focusedBranchRootId = branchRootId;
      _cameraDistance = 210.0; // Close canopy zoom
      if (target != null) {
        final pos = target.localPosition;
        _panOffset = Offset(-pos.x * 0.42, -pos.y * 0.42);
        _yaw = math.atan2(pos.x, pos.z + 0.001) * 0.35;
        _pitch = (-pos.y / (pos.length + 0.001)).clamp(-0.45, 0.45) * 0.35;
      }
    });
    ref.read(songDnaGraphProvider.notifier).selectNode(branchRootId);
  }

  /// Glides smoothly back to the central organelle overview (REQ-P52-MACRO-04).
  void _returnToOverview() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedBranchRootId = null;
      _yaw = 0.0;
      _pitch = 0.0;
      _cameraDistance = 320.0;
      _panOffset = Offset.zero;
    });
  }

  void _selectNode(String nodeId) {
    HapticFeedback.selectionClick();
    final nodes = ref.read(songDnaGraphProvider).nodes;
    final target = nodes.cast<SongDnaNode?>().firstWhere(
      (n) => n?.id == nodeId,
      orElse: () => null,
    );

    // If tapping a primary branch root in Overview Mode, dive into its canopy!
    if (_focusedBranchRootId == null && target != null && (target.isBranchRoot || target.parentId == 'node_core')) {
      _diveIntoBranch(nodeId);
      return;
    }

    ref.read(songDnaGraphProvider.notifier).selectNode(nodeId);

    // Subtle camera tilt towards selected leaf
    if (target != null && target.id != 'node_core') {
      final pos = target.localPosition;
      final targetYaw = math.atan2(pos.x, pos.z + 0.001);
      final targetPitch = (-pos.y / (pos.length + 0.001)).clamp(-0.55, 0.55);
      setState(() {
        _yaw = (_yaw * 0.7) + (targetYaw * 0.3);
        _pitch = (_pitch * 0.7) + (targetPitch * 0.3);
      });
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
    const focalLength = 420.0;

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

            // 3D Spatial Canvas with Macro-Canopy Bioluminescent Organelle Universe
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final projectedMap = _projectAllNodes(size, graph.nodes);

                  return SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Pan/Rotation Surface behind interactive HUD (REQ-P52-MACRO-01)
                        Positioned.fill(
                          child: GestureDetector(
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
                          ),
                        ),

                        // 3D Organelle CustomPainter (Membrane, Nucleus, Orbital Rings, Mucus-Membrane Bridges)
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
                                  focusedBranchRootId: _focusedBranchRootId,
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

                          // Decluttered Billboard Cues & Receptor Hit Targets (REQ-P52-MACRO-02..03)
                          for (final node in graph.nodes) ...[
                            if (node.id != 'node_core')
                              _buildDeclutteredReceptorTarget(
                                node,
                                projectedMap[node.id],
                                graph.selectedNodeId,
                              ),
                          ],

                          // Floating Return to Overview Pill (REQ-P52-MACRO-04)
                          if (_focusedBranchRootId != null)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _buildSurfaceOverviewReturnBtn(),
                            ),

                          // Camera HUD Controls (REQ-P50-TREE-03)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _buildCameraControls(),
                          ),
                        ],
                      ),
                  );
                },
              ),
            ),

            // Sleek Floating Quick-Action Card with Stem Authority Selector (REQ-P52-STEM-03)
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
                  _focusedBranchRootId != null
                      ? 'Inside Branch Canopy • 2.25x Macro Dive'
                      : '${(graph.overallCompleteness * 100).toInt()}% Genetic Completeness • ${graph.nodes.length} Nodes Wired',
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

  /// Floating button to return to surface overview mode (REQ-P52-MACRO-04).
  Widget _buildSurfaceOverviewReturnBtn() {
    return GestureDetector(
      key: const Key('song_dna_return_overview_btn'),
      behavior: HitTestBehavior.opaque,
      onTap: _returnToOverview,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00F5D4).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5D4).withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsBold.compass,
              size: 14,
              color: Color(0xFF00F5D4),
            ),
            SizedBox(width: 6),
            Text(
              'Surface Overview',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
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

  /// Decluttered Billboard Cue & Receptor Touch Target (REQ-P52-MACRO-02..03).
  /// In Overview Mode: only the 4 primary branch roots show text pills so zero pills overlap!
  /// In Branch-Dive Mode: child leaves show sleek micro-tags at arm's reach.
  Widget _buildDeclutteredReceptorTarget(
    SongDnaNode node,
    Offset? offset,
    String? selectedNodeId,
  ) {
    if (offset == null) return const SizedBox.shrink();

    final isSelected = node.id == selectedNodeId;
    final isBranchRoot = node.isBranchRoot ||
        node.parentId == 'node_core' ||
        node.id == 'node_beat_tempo' ||
        node.id == 'node_vocal_persona' ||
        node.id == 'node_sketchpad_groove' ||
        node.id == 'node_spatial_atmosphere' ||
        node.id == 'node_invasive_reference';

    // Show full label pill if in overview and branch root, or if inside this branch's canopy
    final isInsideThisBranch = _focusedBranchRootId != null &&
        (node.id == _focusedBranchRootId || node.parentId == _focusedBranchRootId);
    final shouldShowLabelPill = (_focusedBranchRootId == null && (isBranchRoot || isSelected)) ||
        isInsideThisBranch ||
        isSelected;

    return Positioned(
      left: offset.dx - (shouldShowLabelPill ? 64.0 : 22.0),
      top: offset.dy - (shouldShowLabelPill ? 28.0 : 22.0),
      width: shouldShowLabelPill ? 128.0 : 44.0,
      height: shouldShowLabelPill ? 30.0 : 44.0,
      child: GestureDetector(
        key: Key('song_dna_bubble_${node.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectNode(node.id),
        child: shouldShowLabelPill
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

          // Stem Authority Mode Selector (REQ-P52-STEM-01..03)
          if (node.isBranchRoot || node.parentId == 'node_core' || node.stemLockMode != null) ...[
            _buildStemAuthoritySelector(node, formState),
            const SizedBox(height: 10),
          ],

          // Contextual tactile mutator controls
          _buildContextualMutator(context, node, formState),

          // Dynamic Instrument Leaf Addition on Instruments Branch (REQ-P52-LEAF-01)
          if (node.id == 'node_sketchpad_groove' || node.parentId == 'node_sketchpad_groove') ...[
            const SizedBox(height: 8),
            _buildAddInstrumentLeafButton(context),
          ],
        ],
      ),
    );
  }

  /// 3-way Stem Authority Selector Pill (REQ-P52-STEM-03).
  Widget _buildStemAuthoritySelector(SongDnaNode node, StudioFormState formState) {
    final activeMode = formState.branchStemLockModes[node.id] ??
        node.stemLockMode ??
        StemLockMode.harmonicInpaint;

    return Container(
      key: const Key('song_dna_stem_lock_selector'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildStemLockTab(
            icon: PhosphorIconsBold.lockKey,
            label: 'Lock Pure 44k',
            mode: StemLockMode.lockedPure44k,
            isActive: activeMode == StemLockMode.lockedPure44k,
            nodeId: node.id,
            activeColor: const Color(0xFFFFB703),
          ),
          _buildStemLockTab(
            icon: PhosphorIconsBold.dna,
            label: 'AI Inpaint',
            mode: StemLockMode.harmonicInpaint,
            isActive: activeMode == StemLockMode.harmonicInpaint,
            nodeId: node.id,
            activeColor: const Color(0xFF00F5D4),
          ),
          _buildStemLockTab(
            icon: PhosphorIconsBold.sparkle,
            label: 'Re-Imagine',
            mode: StemLockMode.elasticResynth,
            isActive: activeMode == StemLockMode.elasticResynth,
            nodeId: node.id,
            activeColor: const Color(0xFFD946EF),
          ),
        ],
      ),
    );
  }

  Widget _buildStemLockTab({
    required PhosphorIconData icon,
    required String label,
    required StemLockMode mode,
    required bool isActive,
    required String nodeId,
    required Color activeColor,
  }) {
    return Expanded(
      child: GestureDetector(
        key: Key('song_dna_stem_lock_tab_${mode.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(songDnaGraphProvider.notifier).setStemLockMode(nodeId, mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isActive ? activeColor : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 11,
                color: isActive ? activeColor : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? Colors.white : Colors.white60,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddInstrumentLeafButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('song_dna_add_instrument_leaf_btn'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: const Color(0xFF10B981).withValues(alpha: 0.6),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        icon: const PhosphorIcon(
          PhosphorIconsBold.plus,
          size: 13,
          color: Color(0xFF10B981),
        ),
        label: const Text(
          '+ Add Instrument Leaf to Canopy',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10B981),
          ),
        ),
        onPressed: () => _showAddInstrumentLeafSheet(context),
      ),
    );
  }

  void _showAddInstrumentLeafSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final instruments = [
      {'name': 'Private School Rhodes', 'icon': PhosphorIconsBold.pianoKeys, 'sub': 'Soulful Jazz Keys'},
      {'name': 'Bamboo Flute', 'icon': PhosphorIconsBold.musicNote, 'sub': 'Ancestral Aerophone'},
      {'name': 'Maskandi Guitar', 'icon': PhosphorIconsBold.guitar, 'sub': 'Zulu Fingerpicking Acoustic'},
      {'name': 'Soprano Sax', 'icon': PhosphorIconsBold.waveform, 'sub': 'Emotive Brass Solo'},
      {'name': 'Solo Violin', 'icon': PhosphorIconsBold.sparkle, 'sub': 'Strings Harmonic Lead'},
      {'name': '808 Sub-Bass', 'icon': PhosphorIconsBold.waveSine, 'sub': 'Deep Electronic Low-End'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sprout Instrument Leaf',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    IconButton(
                      icon: const PhosphorIcon(PhosphorIconsBold.x, size: 18, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final inst in instruments) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: PhosphorIcon(inst['icon'] as PhosphorIconData, size: 16, color: const Color(0xFF10B981)),
                    ),
                    title: Text(
                      inst['name'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    subtitle: Text(
                      inst['sub'] as String,
                      style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                    ),
                    trailing: const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: Colors.white38),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(songDnaGraphProvider.notifier).addInstrumentLeaf(
                        name: inst['name'] as String,
                        icon: inst['icon'] as PhosphorIconData,
                        subtitle: inst['sub'] as String,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
        node.id == 'node_heritage_mpc' ||
        node.id.startsWith('node_leaf_')) {
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

/// 3D Bioluminescent Organelle CustomPainter (REQ-P51-WORLD-01..02, REQ-P52-MUCUS-01, REQ-P52-CORE-01).
/// Paints the 100% opaque deep bio-space, depth-of-field bokeh satellite organelles,
/// 3D harmonic deformed geodesic cyan membrane, 3 tilted orbital atomic energy rings,
/// inner blazing additive amber nucleus, and organic mucus-membrane stem bridges.
class _BioluminescentOrganelle3DPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double cameraDistance;
  final Offset panOffset;
  final List<SongDnaNode> nodes;
  final String? selectedNodeId;
  final String? focusedBranchRootId;
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
    this.focusedBranchRootId,
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
    const focalLength = 420.0;

    // =========================================================================
    // LAYER 1: ABYSSAL MICROSCOPIC VOID & BOKEH SATELLITE ORGANELLES
    // =========================================================================
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

    // Subtle holographic bio-telemetry HUD lines
    _drawBioTelemetryHud(canvas, size, cx, cy);

    // =========================================================================
    // LAYER 2: 3D PROJECTION & TRANSFORMATION MATRICES
    // =========================================================================
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

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
    // LAYER 3: ORGANIC MUCUS-MEMBRANE STEM BRIDGES & ADDITIVE GLOW (REQ-P52-MUCUS-01)
    // =========================================================================
    for (final item in projectedNodes) {
      if (item.node.id == 'node_core') continue;

      Offset parentScreen = coreScreen;
      if (item.node.parentId != null && nodeMap.containsKey(item.node.parentId)) {
        parentScreen = nodeMap[item.node.parentId!]!.screenOffset;
      }

      final isSelected = item.node.id == selectedNodeId;
      final isFocused = focusedBranchRootId == item.node.id ||
          item.node.parentId == focusedBranchRootId ||
          (focusedBranchRootId == null && item.node.parentId == 'node_core');
      final isStemLocked = item.node.stemLockMode == StemLockMode.lockedPure44k;

      _paintMucusMembraneBridge(
        canvas: canvas,
        start: parentScreen,
        end: item.screenOffset,
        color: item.node.accentColor,
        isSelected: isSelected,
        isFocused: isFocused,
        isStemLocked: isStemLocked,
        scale: item.scale,
        flowProgress: flowProgress,
        seed: item.node.id.hashCode.abs(),
      );
    }

    // =========================================================================
    // LAYER 4: CENTRAL BREATHING ORGANELLE & 3 TILTED ATOMIC RINGS (REQ-P52-CORE-01)
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
      if (item.node.id == 'node_core') continue;

      final node = item.node;
      final isSelected = node.id == selectedNodeId;
      final isTerminal = node.isTerminalReceptor;
      final baseRadius = (isTerminal ? 9.0 : 15.0) * item.scale;
      final currentRadius =
          baseRadius * (isSelected ? (1.0 + pulseValue * 0.15) : 1.0);

      // 1. Soft corona glow with BlendMode.plus
      final glowPaint = Paint()
        ..color = node.accentColor.withValues(alpha: isSelected ? 0.75 : 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 12 : 6)
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus;
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
          currentRadius * 0.28,
          innerDotPaint,
        );
      } else {
        // PRIMARY OR JOINT SPHERE
        final spherePaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [
              Colors.white,
              node.accentColor,
              node.accentColor.withValues(alpha: 0.35),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(
            Rect.fromCircle(center: item.screenOffset, radius: currentRadius),
          )
          ..style = PaintingStyle.fill;
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

  /// Paints an organic biological mucus-membrane stem bridge (REQ-P52-MUCUS-01).
  void _paintMucusMembraneBridge({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Color color,
    required bool isSelected,
    required bool isFocused,
    required bool isStemLocked,
    required double scale,
    required double flowProgress,
    required int seed,
  }) {
    final d = end - start;
    final length = d.distance;
    if (length < 2.0) return;

    final unit = Offset(d.dx / length, d.dy / length);
    final normal = Offset(-unit.dy, unit.dx);

    final waveOffset = math.sin(flowProgress * 2 * math.pi + seed) * (length * 0.08).clamp(3.0, 14.0);

    final cp1 = Offset(
      start.dx + d.dx * 0.35 + normal.dx * waveOffset,
      start.dy + d.dy * 0.35 + normal.dy * waveOffset,
    );
    final cp2 = Offset(
      start.dx + d.dx * 0.65 - normal.dx * waveOffset * 0.6,
      start.dy + d.dy * 0.65 - normal.dy * waveOffset * 0.6,
    );

    // Flared Smooth-Min Meniscus Webbing widths
    final startR = (isFocused ? 13.0 : 7.0) * scale;
    final endR = (isFocused ? 9.5 : 5.5) * scale;
    final waistR = (isFocused ? 4.0 : 2.2) * scale;

    final path = Path();
    path.moveTo(start.dx + normal.dx * startR, start.dy + normal.dy * startR);
    path.cubicTo(
      cp1.dx + normal.dx * waistR,
      cp1.dy + normal.dy * waistR,
      cp2.dx + normal.dx * waistR,
      cp2.dy + normal.dy * waistR,
      end.dx + normal.dx * endR,
      end.dy + normal.dy * endR,
    );
    path.lineTo(end.dx - normal.dx * endR, end.dy - normal.dy * endR);
    path.cubicTo(
      cp2.dx - normal.dx * waistR,
      cp2.dy - normal.dy * waistR,
      cp1.dx - normal.dx * waistR,
      cp1.dy - normal.dy * waistR,
      start.dx - normal.dx * startR,
      start.dy - normal.dy * startR,
    );
    path.close();

    // 1. Translucent Mucus-Membrane Sheath Fill
    final sheathPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: isFocused ? 0.30 : 0.10),
          color.withValues(alpha: isFocused ? 0.12 : 0.03),
        ],
      ).createShader(path.getBounds())
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, sheathPaint);

    // 2. Specular Rim Highlight on Outer Boundaries
    final rimPaint = Paint()
      ..color = color.withValues(alpha: isFocused ? 0.75 : 0.30)
      ..strokeWidth = (isFocused ? 1.6 : 0.9) * scale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, rimPaint);

    // 3. Crystalline Golden-Cyan Double-Sheath for StemLockMode.lockedPure44k (REQ-P52-STEM-04)
    if (isStemLocked) {
      final lockGlowPaint = Paint()
        ..color = const Color(0xFFFFB703).withValues(alpha: 0.85)
        ..strokeWidth = 1.8 * scale
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, lockGlowPaint);

      final lockAura = Paint()
        ..color = const Color(0xFF00F5D4).withValues(alpha: 0.40)
        ..strokeWidth = 3.5 * scale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, lockAura);
    }

    // 4. Intertwined Sinusoidal Internal Neural Fibers (BlendMode.plus)
    for (int k = 0; k < 3; k++) {
      final fiberPath = Path();
      fiberPath.moveTo(start.dx, start.dy);
      final phaseK = (k * 2 * math.pi / 3) + (flowProgress * 2 * math.pi);
      const steps = 12;
      for (int s = 1; s <= steps; s++) {
        final t = s / steps.toDouble();
        final bx = (1 - t) * (1 - t) * (1 - t) * start.dx +
            3 * (1 - t) * (1 - t) * t * cp1.dx +
            3 * (1 - t) * t * t * cp2.dx +
            t * t * t * end.dx;
        final by = (1 - t) * (1 - t) * (1 - t) * start.dy +
            3 * (1 - t) * (1 - t) * t * cp1.dy +
            3 * (1 - t) * t * t * cp2.dy +
            t * t * t * end.dy;
        final fiberOffset = math.sin(t * 3 * math.pi + phaseK) * waistR * 0.7;
        fiberPath.lineTo(bx + normal.dx * fiberOffset, by + normal.dy * fiberOffset);
      }
      final fiberPaint = Paint()
        ..color = (k == 1 ? Colors.white : color).withValues(alpha: isFocused ? 0.90 : 0.45)
        ..strokeWidth = (isFocused ? 1.4 : 0.8) * scale
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.plus;
      canvas.drawPath(fiberPath, fiberPaint);
    }

    // 5. Synaptic Bioluminescent Photon Packets
    final packetT = (flowProgress * 1.6 + (seed % 100) / 100.0) % 1.0;
    final px = (1 - packetT) * (1 - packetT) * (1 - packetT) * start.dx +
        3 * (1 - packetT) * (1 - packetT) * packetT * cp1.dx +
        3 * (1 - packetT) * packetT * packetT * cp2.dx +
        packetT * packetT * packetT * end.dx;
    final py = (1 - packetT) * (1 - packetT) * (1 - packetT) * start.dy +
        3 * (1 - packetT) * (1 - packetT) * packetT * cp1.dy +
        3 * (1 - packetT) * packetT * packetT * cp2.dy +
        packetT * packetT * packetT * end.dy;
    final packetCenter = Offset(px, py);

    final packetPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(packetCenter, 3.2 * scale, packetPaint);

    final packetHalo = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(packetCenter, 6.5 * scale, packetHalo);
  }

  /// Draws 3D Geodesic Deformable Filamentous Membrane, Blazing Amber Nucleus, and 3 Tilted Orbital Rings.
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
    // --- 1. Inner Blazing Amber Nucleus with Multi-Layer Additive Light (BlendMode.plus) ---
    final nucleusRadius = 38.0 * scale * (1.0 + pulseValue * 0.08);

    // Multi-layered additive plasma core
    final whiteHotCore = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFFFFF176).withValues(alpha: 0.95),
          const Color(0xFFFFB703).withValues(alpha: 0.85),
          const Color(0xFFFF6B00).withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: nucleusRadius * 2.4))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, nucleusRadius * 2.4, whiteHotCore);

    final amberCorona = Paint()
      ..color = const Color(0xFFFF8500).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, nucleusRadius, amberCorona);

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
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(vesiclePos, 4.5 * scale, vPaint);

      final filamentPaint = Paint()
        ..color = const Color(0xFFFF6B00).withValues(alpha: 0.55)
        ..strokeWidth = 1.2 * scale
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.plus;
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
    const double baseRadius = 110.0;
    final t = waveProgress * 2 * math.pi;

    final gridPoints = List.generate(latSteps + 1, (j) {
      final phi = -math.pi / 2 + (j * math.pi / latSteps);
      return List.generate(lonSteps, (i) {
        final theta = i * 2 * math.pi / lonSteps;

        final r = baseRadius *
            (1.0 +
                0.07 * math.sin(3 * theta + 1.6 * t) * math.cos(2 * phi - 1.2 * t) +
                0.04 * math.cos(4 * phi + 2.2 * t));

        final x = r * math.cos(phi) * math.cos(theta);
        final y = r * math.sin(phi);
        final z = r * math.cos(phi) * math.sin(theta);

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
      ..strokeWidth = 1.1 * scale
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.40);

    for (int i = 0; i < lonSteps; i++) {
      final path = Path()..moveTo(gridPoints[0][i].dx, gridPoints[0][i].dy);
      for (int j = 1; j <= latSteps; j++) {
        path.lineTo(gridPoints[j][i].dx, gridPoints[j][i].dy);
      }
      canvas.drawPath(path, filamentPaint);
    }

    for (int j = 1; j < latSteps; j++) {
      final path = Path()..moveTo(gridPoints[j][0].dx, gridPoints[j][0].dy);
      for (int i = 1; i < lonSteps; i++) {
        path.lineTo(gridPoints[j][i].dx, gridPoints[j][i].dy);
      }
      path.close();
      canvas.drawPath(path, filamentPaint);
    }

    // Outer Fresnel Rim Glow
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * scale
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, baseRadius * scale * 1.05, rimPaint);

    // --- 3. 3 Tilted Elliptical Orbital Energy Rings with Rotating Beads (REQ-P52-CORE-01) ---
    _drawOrbitalEnergyRings(
      canvas: canvas,
      center: center,
      baseRadius: baseRadius,
      scale: scale,
      flowProgress: flowProgress,
    );
  }

  /// Draws 3 tilted elliptical atomic orbital rings with traveling energy beads (REQ-P52-CORE-01).
  void _drawOrbitalEnergyRings({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double scale,
    required double flowProgress,
  }) {
    final ringConfigs = [
      {'tilt': 0.48, 'r': baseRadius * 1.35, 'color': const Color(0xFFFFB703), 'speed': 1.0},
      {'tilt': -0.62, 'r': baseRadius * 1.55, 'color': const Color(0xFF00F5D4), 'speed': -0.75},
      {'tilt': 0.22, 'r': baseRadius * 1.80, 'color': const Color(0xFFD946EF), 'speed': 0.50},
    ];

    for (int idx = 0; idx < ringConfigs.length; idx++) {
      final cfg = ringConfigs[idx];
      final tilt = cfg['tilt'] as double;
      final r = (cfg['r'] as double) * scale;
      final col = cfg['color'] as Color;
      final spd = cfg['speed'] as double;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilt);

      final ringRect = Rect.fromCenter(center: Offset.zero, width: r * 2.0, height: r * 0.72);
      final ringPaint = Paint()
        ..color = col.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..blendMode = BlendMode.plus;
      canvas.drawOval(ringRect, ringPaint);

      // Rotating glowing satellite energy bead on the ring
      final beadAngle = (flowProgress * spd * 2 * math.pi) % (2 * math.pi);
      final beadX = math.cos(beadAngle) * r;
      final beadY = math.sin(beadAngle) * (r * 0.36);

      final beadGlow = Paint()
        ..color = col.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(beadX, beadY), 3.8 * scale, beadGlow);

      final beadCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(beadX, beadY), 1.9 * scale, beadCore);

      canvas.restore();
    }
  }

  /// Draws out-of-focus background bokeh satellite organelle clusters.
  void _drawBokehSatellite(
    Canvas canvas,
    Offset position, {
    required double radius,
    required Color color,
    required int subCount,
  }) {
    final auraPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.55);
    canvas.drawCircle(position, radius, auraPaint);

    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.25);
    canvas.drawCircle(position, radius * 0.45, corePaint);

    for (int i = 0; i < subCount; i++) {
      final angle = (i * 2 * math.pi / subCount) + (waveProgress * math.pi);
      final dist = radius * 0.65;
      final subPos = Offset(
        position.dx + math.cos(angle) * dist,
        position.dy + math.sin(angle) * dist,
      );
      final subPaint = Paint()
        ..color = color.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(subPos, radius * 0.2, subPaint);
    }
  }

  /// Draws subtle holographic bio-telemetry HUD lines on the horizons.
  void _drawBioTelemetryHud(Canvas canvas, Size size, double cx, double cy) {
    final hudPaint = Paint()
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.15)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final hudLeft = Path()
      ..moveTo(24, cy - 60)
      ..lineTo(70, cy - 60)
      ..lineTo(85, cy - 35)
      ..lineTo(85, cy + 35)
      ..lineTo(70, cy + 60)
      ..lineTo(24, cy + 60);
    canvas.drawPath(hudLeft, hudPaint);

    final hudRight = Path()
      ..moveTo(size.width - 24, cy - 60)
      ..lineTo(size.width - 70, cy - 60)
      ..lineTo(size.width - 85, cy - 35)
      ..lineTo(size.width - 85, cy + 35)
      ..lineTo(size.width - 70, cy + 60)
      ..lineTo(size.width - 24, cy + 60);
    canvas.drawPath(hudRight, hudPaint);
  }

  @override
  bool shouldRepaint(covariant _BioluminescentOrganelle3DPainter old) {
    return old.yaw != yaw ||
        old.pitch != pitch ||
        old.cameraDistance != cameraDistance ||
        old.panOffset != panOffset ||
        old.nodes != nodes ||
        old.selectedNodeId != selectedNodeId ||
        old.focusedBranchRootId != focusedBranchRootId ||
        old.pulseValue != pulseValue ||
        old.flowProgress != flowProgress ||
        old.waveProgress != waveProgress;
  }
}

class _Projected3DItem {
  final SongDnaNode node;
  final Offset screenOffset;
  final double depth;
  final double scale;

  _Projected3DItem({
    required this.node,
    required this.screenOffset,
    required this.depth,
    required this.scale,
  });
}
