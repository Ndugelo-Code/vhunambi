import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/bantu_voice_profile.dart';
import '../../domain/models/song_dna_graph_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/song_dna_graph_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

/// Full-Screen 3D Navigable Song DNA Node Tree Modal (REQ-P50-TREE-01..06, REQ-P50-CARD-01..07).
/// Allows 3D pitch/yaw navigation, pinch zoom, depth-sorted energy conduits,
/// billboarded cue bubbles, and real-time quantum entanglement with Studio state.
class SongDnaNodeTreeModal extends ConsumerStatefulWidget {
  final VoidCallback? onSynthesizeRequested;

  const SongDnaNodeTreeModal({
    super.key,
    this.onSynthesizeRequested,
  });

  /// Presents the 3D Song DNA tree as a full-screen transparent modal.
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSynthesizeRequested,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (ctx, anim1, anim2) => SongDnaNodeTreeModal(
          onSynthesizeRequested: onSynthesizeRequested,
        ),
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

  // 3D Camera Spherical Coordinates
  double _yaw = 0.0; // Azimuth
  double _pitch = 0.0; // Polar elevation
  double _cameraDistance = 420.0; // Zoom distance

  final Map<String, Offset> _projectedScreenCoordinates = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _conduitFlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _conduitFlowController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraDistance = (_cameraDistance - 60.0).clamp(240.0, 680.0);
    });
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraDistance = (_cameraDistance + 60.0).clamp(240.0, 680.0);
    });
  }

  void _resetCamera() {
    HapticFeedback.selectionClick();
    setState(() {
      _yaw = 0.0;
      _pitch = 0.0;
      _cameraDistance = 420.0;
    });
  }

  void _selectNode(String nodeId) {
    HapticFeedback.selectionClick();
    ref.read(songDnaGraphProvider.notifier).selectNode(nodeId);
    setState(() {});
  }

  void _synthesizeFromDna() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
    if (widget.onSynthesizeRequested != null) {
      widget.onSynthesizeRequested!();
    } else {
      ref.read(studioFormProvider.notifier).triggerGeneration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(songDnaGraphProvider);
    final formState = ref.watch(studioFormProvider);
    final selectedNode = graph.selectedNode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('song_dna_3d_tree_modal'),
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, graph),

            // 3D Spatial Canvas with Billboarded Cue Bubbles
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _yaw += details.delta.dx * 0.008;
                        _pitch = (_pitch + details.delta.dy * 0.008)
                            .clamp(-0.75, 0.75);
                      });
                    },
                    child: Stack(
                      children: [
                        // 3D CustomPainter
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _pulseController,
                            _conduitFlowController,
                          ]),
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size.infinite,
                              painter: _SongDna3DPainter(
                                yaw: _yaw,
                                pitch: _pitch,
                                cameraDistance: _cameraDistance,
                                nodes: graph.nodes,
                                selectedNodeId: graph.selectedNodeId,
                                pulseValue: _pulseController.value,
                                flowProgress: _conduitFlowController.value,
                                onScreenProjected: (id, offset) {
                                  _projectedScreenCoordinates[id] = offset;
                                },
                              ),
                            );
                          },
                        ),

                        // Billboarded Floating Cue Bubbles (REQ-P50-TREE-05)
                        for (final node in graph.nodes) ...[
                          _buildBillboardCueBubble(node),
                        ],

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
                  'SONG DNA ARCHITECTURE',
                  style: AppTypography.bouncyTitleLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Quantum-Entangled 3D Genomic Tree • ${(graph.overallCompleteness * 100).round()}% Complete',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (graph.activeInvasiveNodesCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD946EF).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD946EF).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(
                    PhosphorIconsBold.waveTriangle,
                    size: 12,
                    color: Color(0xFFD946EF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${graph.activeInvasiveNodesCount} Invasive',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD946EF),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161622).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('song_dna_zoom_in_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.magnifyingGlassPlus,
              size: 16,
              color: Colors.white,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _zoomIn,
          ),
          IconButton(
            key: const Key('song_dna_zoom_out_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.magnifyingGlassMinus,
              size: 16,
              color: Colors.white,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _zoomOut,
          ),
          IconButton(
            key: const Key('song_dna_reset_camera_btn'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.arrowsClockwise,
              size: 16,
              color: AppColors.brandPrimary,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _resetCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildBillboardCueBubble(SongDnaNode node) {
    final offset = _projectedScreenCoordinates[node.id];
    if (offset == null) return const SizedBox.shrink();

    final isSelected = node.id == ref.read(songDnaGraphProvider).selectedNodeId;

    // Anchor bubble ~36dp above node center
    return Positioned(
      left: offset.dx - 65.0,
      top: offset.dy - 40.0,
      child: GestureDetector(
        key: Key('song_dna_bubble_${node.id}'),
        onTap: () => _selectNode(node.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(maxWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? node.accentColor.withValues(alpha: 0.28)
                : const Color(0xFF151520).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? node.accentColor
                  : node.accentColor.withValues(alpha: 0.45),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: node.accentColor.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(node.icon, size: 12, color: node.accentColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  node.cueLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    SongDnaNode node,
    StudioFormState form,
    bool isDark,
  ) {
    final notifier = ref.read(songDnaGraphProvider.notifier);

    return Container(
      key: const Key('song_dna_quick_action_card'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: node.accentColor.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: node.accentColor.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Category label + Detach button if invasive
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  PhosphorIcon(node.icon, size: 16, color: node.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    node.category.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: node.accentColor,
                    ),
                  ),
                ],
              ),
              if (node.isDetachable)
                TextButton.icon(
                  key: const Key('song_dna_detach_node_btn'),
                  onPressed: () => notifier.detachInvasiveNode(node.id),
                  icon: const PhosphorIcon(
                    PhosphorIconsBold.trash,
                    size: 13,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Detach Node',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          // Title & Subtitle
          Text(
            node.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          Text(
            node.subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 10),

          // Dynamic Mutator Pickers based on active node
          _buildNodeMutatorControls(context, node, form, notifier),
        ],
      ),
    );
  }

  Widget _buildNodeMutatorControls(
    BuildContext context,
    SongDnaNode node,
    StudioFormState form,
    SongDnaGraphNotifier notifier,
  ) {
    if (node.id == 'node_genre_tempo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genre Row
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final g in [
                  'Amapiano',
                  'Gqom',
                  'Maskandi',
                  'Afro House',
                  'Kwaito',
                  'Afrobeats',
                ]) ...[
                  _buildMutatorPill(
                    label: g,
                    isSelected: form.genre.toLowerCase() == g.toLowerCase(),
                    onTap: () => notifier.updateGenre(g),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tempo Row
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in TempoBracket.values) ...[
                  _buildMutatorPill(
                    label: t.label,
                    isSelected: form.tempo == t,
                    onTap: () => notifier.updateTempo(t),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (node.id == 'node_vocal_persona') {
      return SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final v in kBantuVoiceProfiles) ...[
              _buildMutatorPill(
                label: v.name,
                isSelected: form.selectedVoiceProfile.id == v.id,
                onTap: () => notifier.updateVocalPersona(v),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );
    }

    if (node.id == 'node_language_lyrics') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language Pills
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in [
                  'Tshivenḓa',
                  'isiZulu',
                  'isiXhosa',
                  'Sepedi',
                  'Sesotho',
                  'English',
                ]) ...[
                  _buildMutatorPill(
                    label: l,
                    isSelected: form.language == l,
                    onTap: () => notifier.updateLanguage(l),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Lyrics Mode Toggle
          Row(
            children: [
              _buildMutatorPill(
                label: 'AI Writes Lyrics',
                isSelected: form.lyricsMode == LyricsMode.aiWrite,
                onTap: () => notifier.updateLyricsMode(LyricsMode.aiWrite),
              ),
              const SizedBox(width: 6),
              _buildMutatorPill(
                label: 'My Custom Lyrics',
                isSelected: form.lyricsMode == LyricsMode.myOwn,
                onTap: () => notifier.updateLyricsMode(LyricsMode.myOwn),
              ),
            ],
          ),
        ],
      );
    }

    if (node.id == 'node_mood_energy') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood Pills
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in [
                  'Uplifting',
                  'Soulful & Nostalgic',
                  'Dark Hypnotic',
                  'Energetic Club',
                ]) ...[
                  _buildMutatorPill(
                    label: m,
                    isSelected: form.mood == m,
                    onTap: () => notifier.updateMood(m),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Vocal Energy
          Row(
            children: [
              for (final e in VocalEnergy.values) ...[
                _buildMutatorPill(
                  label: '${e.name.toUpperCase()} Energy',
                  isSelected: form.vocalEnergy == e,
                  onTap: () => notifier.updateVocalEnergy(e),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      );
    }

    if (node.id == 'node_sketchpad_groove') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node.subNodes.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final sub in node.subNodes)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sub.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sub.color),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(sub.icon, size: 10, color: sub.color),
                        const SizedBox(width: 4),
                        Text(
                          sub.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: sub.color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  notifier.attachSketchpadPreset('Soweto Log-Drum Knock');
                },
                icon: const PhosphorIcon(
                  PhosphorIconsBold.waveSine,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
                label: const Text(
                  '+ Attach Log-Drum Groove',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => MelodySketchpadModal.show(context),
                child: const Text(
                  'Launch Sketchpad →',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
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

  Widget _buildBottomCtaDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          key: const Key('song_dna_synthesize_btn'),
          onPressed: _synthesizeFromDna,
          icon: const PhosphorIcon(
            PhosphorIconsBold.sparkle,
            size: 20,
            color: Colors.black,
          ),
          label: Text(
            'Synthesize Song from 3D DNA',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.6,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 8,
            shadowColor: AppColors.brandPrimary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 3D CustomPainter projecting Song DNA topology into 2D screen space (REQ-P50-TREE-01..04).
class _SongDna3DPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double cameraDistance;
  final List<SongDnaNode> nodes;
  final String? selectedNodeId;
  final double pulseValue;
  final double flowProgress;
  final void Function(String id, Offset screenOffset) onScreenProjected;

  final Paint _conduitPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _nodePaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  _SongDna3DPainter({
    required this.yaw,
    required this.pitch,
    required this.cameraDistance,
    required this.nodes,
    this.selectedNodeId,
    required this.pulseValue,
    required this.flowProgress,
    required this.onScreenProjected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || nodes.isEmpty) return;

    final cx = size.width * 0.5;
    final cy = size.height * 0.44;
    const focalLength = 380.0;

    // Draw ambient cosmic grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 3D Rotation transform matrix
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    // Project Core (0, 0, 0)
    final coreScreen = Offset(cx, cy);

    // Project each node into 3D view space
    final projectedItems = <_Projected3DItem>[];

    for (final node in nodes) {
      final pos = node.localPosition;

      // Rotate around Y (yaw)
      final x1 = pos.x * cosY - pos.z * sinY;
      final z1 = pos.x * sinY + pos.z * cosY;

      // Rotate around X (pitch)
      final y2 = pos.y * cosP - z1 * sinP;
      final z2 = pos.y * sinP + z1 * cosP;

      final scale = focalLength / (focalLength + z2 + cameraDistance);
      final screenX = cx + x1 * scale;
      final screenY = cy + y2 * scale;
      final screenOffset = Offset(screenX, screenY);

      onScreenProjected(node.id, screenOffset);

      projectedItems.add(
        _Projected3DItem(
          node: node,
          screenOffset: screenOffset,
          depth: z2,
          scale: scale,
        ),
      );
    }

    // Painter's algorithm: sort farthest to nearest
    projectedItems.sort((a, b) => a.depth.compareTo(b.depth));

    // 1. Draw Energy Conduits from Core to Nodes
    for (final item in projectedItems) {
      if (item.node.id == 'node_core') continue;

      final progress = item.node.branchUnlockProgress;
      final color = item.node.accentColor;

      // Conduit line
      _conduitPaint
        ..color = color.withValues(
          alpha: item.node.isInvasive
              ? 0.75
              : (0.15 + (progress * 0.55)),
        )
        ..strokeWidth = (item.node.isInvasive ? 2.4 : 1.8) * item.scale;

      canvas.drawLine(coreScreen, item.screenOffset, _conduitPaint);

      // Flowing energy particles along conduit (REQ-P50-GRAPH-02)
      if (progress > 0.1) {
        const particleCount = 4;
        for (int p = 0; p < particleCount; p++) {
          final t = (flowProgress + (p / particleCount)) % 1.0;
          final px = (1.0 - t) * coreScreen.dx + t * item.screenOffset.dx;
          final py = (1.0 - t) * coreScreen.dy + t * item.screenOffset.dy;

          _particlePaint.color = color.withValues(
            alpha: (math.sin(t * math.pi) * progress * 0.9).clamp(0.0, 1.0),
          );
          canvas.drawCircle(Offset(px, py), 2.5 * item.scale, _particlePaint);
        }
      }

      // Invasive symbiotic lightning tethers
      if (item.node.isInvasive) {
        final lightningPaint = Paint()
          ..color = const Color(0xFFD946EF).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        final mid = (coreScreen + item.screenOffset) * 0.5;
        final jitter = Offset(
          math.sin(flowProgress * 20.0) * 8.0,
          math.cos(flowProgress * 20.0) * 8.0,
        );
        canvas.drawLine(coreScreen, mid + jitter, lightningPaint);
        canvas.drawLine(mid + jitter, item.screenOffset, lightningPaint);
      }
    }

    // 2. Draw 3D Spheres & Target Reticles
    for (final item in projectedItems) {
      final color = item.node.accentColor;
      final baseRadius = item.node.id == 'node_core'
          ? 18.0
          : (item.node.isInvasive ? 14.0 : 12.0);
      final radius = baseRadius * item.scale;

      // Soft glow
      _glowPaint.color = color.withValues(alpha: 0.22 * item.scale);
      canvas.drawCircle(item.screenOffset, radius * 2.2, _glowPaint);

      // Solid sphere
      _nodePaint.color = color.withValues(alpha: 0.90);
      canvas.drawCircle(item.screenOffset, radius, _nodePaint);

      // Specular core dot
      _nodePaint.color = Colors.white.withValues(alpha: 0.7);
      canvas.drawCircle(
        item.screenOffset - Offset(radius * 0.3, radius * 0.3),
        radius * 0.28,
        _nodePaint,
      );

      // Counter-rotating double ring on invasive nodes (REQ-P50-GRAPH-04)
      if (item.node.isInvasive) {
        final ringPaint = Paint()
          ..color = const Color(0xFFD946EF).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;

        final ringRadius = radius * 1.7;
        canvas.drawCircle(item.screenOffset, ringRadius, ringPaint);
      }

      // Active target halo
      if (item.node.id == selectedNodeId) {
        final haloPaint = Paint()
          ..color = color.withValues(alpha: 0.8 - (pulseValue * 0.35))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final haloRadius = radius * 1.8 + (pulseValue * 6.0);
        canvas.drawCircle(item.screenOffset, haloRadius, haloPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SongDna3DPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.cameraDistance != cameraDistance ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.flowProgress != flowProgress ||
        oldDelegate.nodes != nodes;
  }
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

