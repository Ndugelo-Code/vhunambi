import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/song_dna_graph_models.dart' hide Vector3D;
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/song_dna_graph_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../controllers/biome_camera_controller.dart';
import '../providers/mycelium_biome_provider.dart';
import 'biome/biome_cluster_inspector_panel.dart';
import 'biome/biome_hud_decks.dart';
import 'biome/biome_top_bar.dart';
import 'biome/organic_mycelium_3d_painter.dart';
import 'biome/song_journey_timeline_scrubber.dart';
import '../../../player/presentation/providers/audio_reactive_biome_provider.dart';

/// Full-Screen Sovereign 3D Bioluminescent Song Organelle Universe (REQ-P51-WORLD-01..02,
/// REQ-P52-MACRO-01..04, REQ-P52-MUCUS-01, REQ-P52-CORE-01, REQ-P52-STEM-01..04).
/// Features macro-canopy camera perspective, 2-tier spatial hierarchy (Overview vs Branch-Dive),
/// organic mucus-membrane stem bridges with flared meniscus webbing, 3 tilted orbital atomic energy rings,
/// additive bioluminescent bloom (BlendMode.plus), and pre-generation stem-lock controls.
class SongDnaNodeTreeModal extends ConsumerStatefulWidget {
  final VoidCallback? onSynthesizeRequested;
  final MyceliumClusterDomain? initialFocusedDomain;

  const SongDnaNodeTreeModal({
    super.key,
    this.onSynthesizeRequested,
    this.initialFocusedDomain,
  });

  /// Presents the 3D Song DNA tree as a 100% opaque sovereign full-screen route (REQ-P51-FIX-03).
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSynthesizeRequested,
    MyceliumClusterDomain? initialFocusedDomain,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true, // 100% Opaque route: zero Studio form bleed-through
        settings: const RouteSettings(name: '/song_dna_universe'),
        pageBuilder: (ctx, anim1, anim2) => SongDnaNodeTreeModal(
          onSynthesizeRequested: onSynthesizeRequested,
          initialFocusedDomain: initialFocusedDomain,
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
  late final AnimationController _membraneWaveController;
  late final AnimationController _biomeAnimationController;
  late final AnimationController _cameraDollyController;

  // 6-DOF Camera Spherical Coordinates (Synchronized with BiomeCameraNotifier)
  double _yaw = 0.0; // Azimuth
  double _pitch = 0.0; // Polar elevation
  double _cameraDistance = 320.0; // Macro base distance (REQ-P52-MACRO-01)
  Offset _panOffset = Offset.zero;

  // Multi-touch pinch base state
  double _scaleStartZoom = 1.0;
  double _scaleStartDistance = 420.0;

  // 450ms Cubic Hermite 3D Camera Dolly endpoints
  BiomeCameraState? _dollyStartCamera;
  BiomeCameraState? _dollyEndCamera;

  // 2-Tier Spatial Hierarchy (REQ-P52-MACRO-02)
  String?
  _focusedBranchRootId; // null = Overview Mode, non-null = Branch Canopy Focus

  // Mobile Popover Tooltip Toggles (REQ-P56-BIOME-02)
  bool _isMobileControlsPopoverOpen = false;
  bool _isMobileLayersPopoverOpen = false;
  StateController<int>? _modalSheetCounter;
  bool _didIncrementModalCount = false;

  @override
  void initState() {
    super.initState();
    // Suppress MiniPlayerHost while 3D Organelle Universe is active (REQ-P51-FIX-03)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(modalSheetOpenCountProvider.notifier);
      _modalSheetCounter = counter;
      _didIncrementModalCount = true;
      counter.state++;
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

    _biomeAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addListener(() {
            if (!mounted) return;
            try {
              if (ref.read(biomeCameraProvider).isAutoRotating) {
                ref.read(biomeCameraProvider.notifier).stepAutoRotate(0.008);
              }
            } catch (_) {}
          })
          ..repeat();

    _cameraDollyController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addListener(() {
          if (!mounted ||
              _dollyStartCamera == null ||
              _dollyEndCamera == null) {
            return;
          }
          final curvedT = Curves.easeOutCubic.transform(
            _cameraDollyController.value,
          );
          final nextCam = BiomeCameraState.lerp(
            _dollyStartCamera!,
            _dollyEndCamera!,
            curvedT,
          );
          ref.read(biomeCameraProvider.notifier).setCameraState(nextCam);
        });

    if (widget.initialFocusedDomain != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusBiomeCluster(widget.initialFocusedDomain!);
        }
      });
    }
  }

  @override
  void dispose() {
    // Release MiniPlayerHost suppression safely outside dispose/unmount cycle
    final counter = _modalSheetCounter;
    if (_didIncrementModalCount && counter != null) {
      _didIncrementModalCount = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }

    _pulseController.dispose();
    _conduitFlowController.dispose();
    _membraneWaveController.dispose();
    _biomeAnimationController.dispose();
    _cameraDollyController.dispose();
    super.dispose();
  }

  void _animateBiomeCameraTo(BiomeCameraState targetCamera) {
    _dollyStartCamera = ref.read(biomeCameraProvider);
    _dollyEndCamera = targetCamera;
    ref.read(biomeCameraProvider.notifier).setCameraState(targetCamera);
    _cameraDollyController.forward(from: 0.0);
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    ref.read(biomeCameraProvider.notifier).zoomInStep();
    setState(() {
      _cameraDistance = (_cameraDistance - 35.0).clamp(160.0, 680.0);
    });
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    ref.read(biomeCameraProvider.notifier).zoomOutStep();
    setState(() {
      _cameraDistance = (_cameraDistance + 35.0).clamp(160.0, 680.0);
    });
  }

  void _resetCamera() {
    HapticFeedback.mediumImpact();
    ref.read(myceliumBiomeGraphProvider.notifier).focusCluster(null);
    ref.read(songDnaGraphProvider.notifier).selectNode(null);
    _animateBiomeCameraTo(const BiomeCameraState());
    setState(() {
      _focusedBranchRootId = null;
      _isMobileControlsPopoverOpen = false;
      _isMobileLayersPopoverOpen = false;
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

  /// Glides smoothly back to the central organelle overview (REQ-P52-MACRO-04, REQ-P56-BIOME-05).
  void _returnToOverview() {
    HapticFeedback.selectionClick();
    ref.read(myceliumBiomeGraphProvider.notifier).focusCluster(null);
    ref.read(songDnaGraphProvider.notifier).selectNode(null);
    _animateBiomeCameraTo(const BiomeCameraState());
    setState(() {
      _focusedBranchRootId = null;
      _yaw = 0.0;
      _pitch = 0.0;
      _cameraDistance = 320.0;
      _panOffset = Offset.zero;
    });
  }

  void _focusBiomeCluster(MyceliumClusterDomain domain) {
    ref.read(myceliumBiomeGraphProvider.notifier).focusCluster(domain);
    final cluster = ref.read(myceliumBiomeGraphProvider).clusters[domain];
    if (cluster != null) {
      final pos = cluster.capApexPosition;
      final targetYaw = math.atan2(pos.x, pos.z + 0.001) * 0.28;
      final currentCam = ref.read(biomeCameraProvider);
      _animateBiomeCameraTo(
        currentCam.copyWith(
          target: pos,
          yaw: targetYaw,
          pitch: 28.0 * math.pi / 180.0,
          distance: 220.0,
          zoom: 1.25,
        ),
      );
    }
    final legacyBranchId = switch (domain) {
      MyceliumClusterDomain.rhythmNetwork => 'node_beat_tempo',
      MyceliumClusterDomain.vocalNetwork => 'node_vocal_persona',
      MyceliumClusterDomain.melodyCore => 'node_sketchpad_groove',
      MyceliumClusterDomain.harmonyNetwork => 'node_sketchpad_groove',
      MyceliumClusterDomain.emotionNetwork => 'node_spatial_atmosphere',
      MyceliumClusterDomain.productionNetwork => 'node_spatial_atmosphere',
    };
    _diveIntoBranch(legacyBranchId);
  }

  void _selectNode(String nodeId) {
    HapticFeedback.selectionClick();
    final nodes = ref.read(songDnaGraphProvider).nodes;
    final target = nodes.cast<SongDnaNode?>().firstWhere(
      (n) => n?.id == nodeId,
      orElse: () => null,
    );

    // If tapping a primary branch root in Overview Mode, dive into its canopy!
    if (_focusedBranchRootId == null &&
        target != null &&
        (target.isBranchRoot || target.parentId == 'node_core')) {
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

    final musicalKey =
        formState.referenceAudioPath?.startsWith('sketchpad://') == true
            ? ref.read(melodySketchpadProvider).attachedPattern?.musicalKey ??
                formState.toSongMetadataDna().musical.key
            : formState.toSongMetadataDna().musical.key;

    ref
        .read(generationProgressProvider.notifier)
        .submitAndStartGeneration(
          trackTitle: trackTitle,
          genre: genre,
          language: language,
          lyrics: formState.customLyrics,
          isInstrumental: formState.isInstrumental,
          tempoBpm: formState.tempo.defaultBpm,
          musicalKey: musicalKey,
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
    final biomeGraph = ref.watch(myceliumBiomeGraphProvider);
    final biomeCamera = ref.watch(biomeCameraProvider);
    final formState = ref.watch(studioFormProvider);
    final audioModulation = ref.watch(audioReactiveBiomeModulationProvider);
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
            // Biome Top Bar
            BiomeTopBar(
              trackTitle: formState.prompt.isNotEmpty
                  ? formState.prompt
                  : (formState.genre.isNotEmpty
                        ? formState.genre
                        : 'African AI Genesis'),
              isPlaying: true,
              isMuted: false,
              onTogglePlay: () {
                HapticFeedback.selectionClick();
              },
              onToggleMute: () {
                HapticFeedback.selectionClick();
              },
              onClose: () => Navigator.of(context).pop(),
            ),

            // 3D Spatial Canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final isMobileCanvas = constraints.maxWidth < 680;
                  final projectedMap = _projectAllNodes(size, graph.nodes);

                  return SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Multi-Touch 3D Orbit & Pinch-Zoom Surface (REQ-P56-BIOME-05)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: (details) {
                              final cam = ref.read(biomeCameraProvider);
                              _scaleStartZoom = cam.zoom;
                              _scaleStartDistance = cam.distance;
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount >= 2) {
                                final nextZoom =
                                    (_scaleStartZoom * details.scale).clamp(
                                      BiomeCameraState.minZoom,
                                      BiomeCameraState.maxZoom,
                                    );
                                final nextDist =
                                    (_scaleStartDistance /
                                            math.pow(details.scale, 0.65))
                                        .clamp(
                                          BiomeCameraState.minDistance,
                                          BiomeCameraState.maxDistance,
                                        );
                                ref
                                    .read(biomeCameraProvider.notifier)
                                    .setZoom(nextZoom);
                                ref
                                    .read(biomeCameraProvider.notifier)
                                    .setDistance(nextDist);
                              } else {
                                final dx = details.focalPointDelta.dx;
                                final dy = details.focalPointDelta.dy;
                                setState(() {
                                  _yaw += dx * 0.0075;
                                  _pitch = (_pitch + dy * 0.0075).clamp(
                                    -0.75,
                                    0.75,
                                  );
                                });
                                ref
                                    .read(biomeCameraProvider.notifier)
                                    .addOrbitDelta(
                                      deltaYaw: dx * 0.0075,
                                      deltaPitch: dy * 0.0075,
                                    );
                              }
                            },
                            onTapUp: (details) {
                              if (_isMobileControlsPopoverOpen ||
                                  _isMobileLayersPopoverOpen) {
                                setState(() {
                                  _isMobileControlsPopoverOpen = false;
                                  _isMobileLayersPopoverOpen = false;
                                });
                              }
                              final hit = BiomeProjectionEngine.hitTest(
                                tapPosition: details.localPosition,
                                viewportSize: size,
                                graph: biomeGraph,
                                camera: biomeCamera,
                              );
                              if (hit.hitCluster != null) {
                                HapticFeedback.selectionClick();
                                _focusBiomeCluster(hit.hitCluster!);
                              }
                            },
                          ),
                        ),

                        // 2. 3D Organic Mycelium Biome Mesh CustomPainter (REQ-P53-CORE-01..06)
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _biomeAnimationController,
                            _pulseController,
                            _conduitFlowController,
                            _membraneWaveController,
                            _cameraDollyController,
                          ]),
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size.infinite,
                              painter: OrganicMycelium3DPainter(
                                graph: biomeGraph,
                                camera: ref.watch(biomeCameraProvider),
                                animationProgress:
                                    _biomeAnimationController.value,
                                focusTransitionProgress:
                                    _focusedBranchRootId != null ? 1.0 : 0.0,
                                audioModulation: audioModulation,
                              ),
                            );
                          },
                        ),

                        // 3. Decluttered Receptor Targets (Zero Legacy Pills in Overview — REQ-P56-BIOME-03)
                        for (final node in graph.nodes) ...[
                          if (node.id != 'node_core')
                            _buildDeclutteredReceptorTarget(
                              node,
                              projectedMap[node.id],
                              graph.selectedNodeId,
                            ),
                        ],

                        // 4. Semantic Mushroom Cap Badges (REQ-P53-HUD-06)
                        for (final cluster in biomeGraph.clusters.values) ...[
                          Builder(
                            builder: (context) {
                              final badgeWorld =
                                  cluster.capApexPosition +
                                  const Vector3D(0, 34, 0);
                              final badgeProj = BiomeProjectionEngine.project3D(
                                badgeWorld,
                                biomeCamera,
                                size,
                              );
                              if (badgeProj == null) {
                                return const SizedBox.shrink();
                              }

                              return Positioned(
                                left: badgeProj.screenOffset.dx - 55,
                                top: badgeProj.screenOffset.dy - 16,
                                child: GestureDetector(
                                  key: Key(
                                    'biome_cluster_badge_${cluster.domain.name}',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _focusBiomeCluster(cluster.domain);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        cluster.domain.hexColor,
                                      ).withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Color(
                                          cluster.domain.hexColor,
                                        ).withValues(alpha: 0.8),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(
                                            cluster.domain.hexColor,
                                          ).withValues(alpha: 0.25),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Color(
                                              cluster.domain.hexColor,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          cluster.domain.shortLabel,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        // 5. Floating Return to Overview Pill (REQ-P52-MACRO-04)
                        if (_focusedBranchRootId != null)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: _buildSurfaceOverviewReturnBtn(),
                          ),

                        // 6. Desktop Cluster Inspector Panel (On mobile < 680, rendered in unified bottom dock)
                        if (_focusedBranchRootId != null && !isMobileCanvas)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _buildBiomeClusterInspectorWidget(
                              biomeGraph,
                            ),
                          ),

                        // 7. Mobile Top-Left Popover Trigger Pills ([Controls] & [Layers]) (REQ-P56-BIOME-02)
                        if (_focusedBranchRootId == null && isMobileCanvas)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildMobilePopoverTogglePill(
                                      key: const Key(
                                        'biome_controls_popover_btn',
                                      ),
                                      icon: PhosphorIconsBold.compass,
                                      label: 'Controls',
                                      isActive: _isMobileControlsPopoverOpen,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _isMobileControlsPopoverOpen =
                                              !_isMobileControlsPopoverOpen;
                                          if (_isMobileControlsPopoverOpen) {
                                            _isMobileLayersPopoverOpen = false;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMobilePopoverTogglePill(
                                      key: const Key(
                                        'biome_layers_popover_btn',
                                      ),
                                      icon: PhosphorIconsBold.stack,
                                      label: 'Layers',
                                      isActive: _isMobileLayersPopoverOpen,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _isMobileLayersPopoverOpen =
                                              !_isMobileLayersPopoverOpen;
                                          if (_isMobileLayersPopoverOpen) {
                                            _isMobileControlsPopoverOpen =
                                                false;
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Offstage(
                                  offstage: !_isMobileControlsPopoverOpen,
                                  child: _buildInteractiveControlsDeck(
                                    biomeCamera,
                                    biomeGraph,
                                  ),
                                ),
                                Offstage(
                                  offstage: !_isMobileLayersPopoverOpen,
                                  child: BiomeNetworkLayersFilter(
                                    activeLayers: biomeGraph.activeLayers,
                                    onToggleLayer: (l) => ref
                                        .read(
                                          myceliumBiomeGraphProvider.notifier,
                                        )
                                        .toggleNetworkLayer(l),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 8. Desktop Bottom-Left HUD Decks (>= 680dp)
                        if (_focusedBranchRootId == null && !isMobileCanvas)
                          Positioned(
                            left: 12,
                            bottom: 74,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildInteractiveControlsDeck(
                                  biomeCamera,
                                  biomeGraph,
                                ),
                                const SizedBox(height: 8),
                                BiomeNetworkLayersFilter(
                                  activeLayers: biomeGraph.activeLayers,
                                  onToggleLayer: (l) => ref
                                      .read(myceliumBiomeGraphProvider.notifier)
                                      .toggleNetworkLayer(l),
                                ),
                              ],
                            ),
                          ),

                        // 9. Song Journey Timeline Scrubber (Non-overlapping bottom bar on mobile)
                        if (_focusedBranchRootId == null)
                          Positioned(
                            left: isMobileCanvas ? 10 : null,
                            right: 10,
                            bottom: isMobileCanvas ? 8 : 74,
                            child: Align(
                              alignment: isMobileCanvas
                                  ? Alignment.bottomCenter
                                  : Alignment.bottomRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SongJourneyTimelineScrubber(
                                  activeSection: biomeGraph.activeSection,
                                  onSelectSection: (s) => ref
                                      .read(myceliumBiomeGraphProvider.notifier)
                                      .selectSongJourneySection(s),
                                ),
                              ),
                            ),
                          ),

                        // 10. Camera HUD Controls ([+ | - | ↻])
                        if (_focusedBranchRootId == null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _buildCameraControls(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Single Unified Bottom Inspector on Mobile (< 680dp) vs Desktop QuickActionCard (REQ-P56-BIOME-04)
            Builder(
              builder: (context) {
                final isMobileViewport = MediaQuery.sizeOf(context).width < 680;
                if (isMobileViewport) {
                  if (_focusedBranchRootId == null && selectedNode == null) {
                    return const SizedBox.shrink();
                  }
                  return ConstrainedBox(
                    key: const Key('biome_mobile_unified_bottom_sheet'),
                    constraints: const BoxConstraints(maxHeight: 224),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_focusedBranchRootId != null)
                            _buildBiomeClusterInspectorWidget(biomeGraph),
                          if (_focusedBranchRootId != null &&
                              selectedNode != null)
                            const SizedBox(height: 6),
                          if (selectedNode != null)
                            _buildQuickActionCard(
                              context,
                              selectedNode,
                              formState,
                              isDark,
                            ),
                        ],
                      ),
                    ),
                  );
                }

                if (selectedNode != null) {
                  return _buildQuickActionCard(
                    context,
                    selectedNode,
                    formState,
                    isDark,
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Bottom CTA: Synthesize Song from 3D DNA (REQ-P50-CARD-07)
            _buildBottomCtaDock(),
          ],
        ),
      ),
    );
  }

  /// Floating button to return to surface overview mode (REQ-P52-MACRO-04).
  Widget _buildSurfaceOverviewReturnBtn() {
    return Container(
      key: const Key('song_dna_return_overview_btn'),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _returnToOverview,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsBold.planet,
                  size: 14,
                  color: Color(0xFF00F5D4),
                ),
                SizedBox(width: 6),
                Text(
                  '🔭 Surface Overview',
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

  Widget _buildInteractiveControlsDeck(
    BiomeCameraState biomeCamera,
    MusicalDnaGraph biomeGraph,
  ) {
    return BiomeInteractiveControlsBar(
      isAutoRotating: biomeCamera.isAutoRotating,
      isMacroZoomed: biomeCamera.zoom > 1.2,
      isCompareActive: biomeGraph.isCompareModeActive,
      isAnalyseActive: biomeGraph.isAnalyseOverlayActive,
      onToggleRotate: () =>
          ref.read(biomeCameraProvider.notifier).toggleAutoRotate(),
      onToggleZoom: () {
        final cur = biomeCamera.zoom;
        ref.read(biomeCameraProvider.notifier).setZoom(cur > 1.2 ? 1.0 : 1.6);
      },
      onFocusReset: _resetCamera,
      onToggleCompare: () =>
          ref.read(myceliumBiomeGraphProvider.notifier).toggleCompareMode(),
      onToggleAnalyse: () =>
          ref.read(myceliumBiomeGraphProvider.notifier).toggleAnalyseOverlay(),
    );
  }

  Widget _buildBiomeClusterInspectorWidget(MusicalDnaGraph biomeGraph) {
    return BiomeClusterInspectorPanel(
      cluster: biomeGraph.activeInspectorCluster,
      animationPhase: _biomeAnimationController.value,
      onClose: _returnToOverview,
      onSelectPartnerCluster: (partner) {
        _focusBiomeCluster(partner);
      },
      onExploreDetails: () {
        HapticFeedback.mediumImpact();
        final activeDomain = biomeGraph.activeInspectorCluster.domain;
        ref.read(studioCockpitTabProvider.notifier).state =
            activeDomain.targetCockpitTab;
        Navigator.of(context).pop();
      },
      onToggleStemLock: () {
        ref
            .read(myceliumBiomeGraphProvider.notifier)
            .toggleClusterStemLock(biomeGraph.activeInspectorCluster.domain);
      },
    );
  }

  Widget _buildMobilePopoverTogglePill({
    required Key key,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF9E00).withValues(alpha: 0.25)
              : const Color(0xFF0A1422).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFF9E00)
                : Colors.white.withValues(alpha: 0.18),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 13,
              color: isActive ? const Color(0xFFFF9E00) : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                color: isActive ? const Color(0xFFFF9E00) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Decluttered Billboard Cue & Receptor Touch Target (REQ-P52-MACRO-02..03, REQ-P56-BIOME-03).
  /// In Overview Mode: only the 6 circular mushroom badges appear visually; legacy nodes render as 44x44 transparent hit-targets!
  /// In Branch-Dive Mode: child leaves show sleek micro-tags at arm's reach.
  Widget _buildDeclutteredReceptorTarget(
    SongDnaNode node,
    Offset? offset,
    String? selectedNodeId,
  ) {
    if (offset == null) return const SizedBox.shrink();

    final isSelected = node.id == selectedNodeId;
    final isInsideThisBranch =
        _focusedBranchRootId != null &&
        (node.id == _focusedBranchRootId ||
            node.parentId == _focusedBranchRootId);
    final shouldShowLabelPill =
        _focusedBranchRootId != null && (isInsideThisBranch || isSelected);

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
          if (node.isBranchRoot ||
              node.parentId == 'node_core' ||
              node.stemLockMode != null) ...[
            _buildStemAuthoritySelector(node, formState),
            const SizedBox(height: 10),
          ],

          // Contextual tactile mutator controls
          _buildContextualMutator(context, node, formState),

          // Dynamic Instrument Leaf Addition on Instruments Branch (REQ-P52-LEAF-01)
          if (node.id == 'node_sketchpad_groove' ||
              node.parentId == 'node_sketchpad_groove') ...[
            const SizedBox(height: 8),
            _buildAddInstrumentLeafButton(context),
          ],
        ],
      ),
    );
  }

  /// 3-way Stem Authority Selector Pill (REQ-P52-STEM-03).
  Widget _buildStemAuthoritySelector(
    SongDnaNode node,
    StudioFormState formState,
  ) {
    final activeMode =
        formState.branchStemLockModes[node.id] ??
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
            label: '🔒 Lock Pure 44k',
            mode: StemLockMode.lockedPure44k,
            isActive: activeMode == StemLockMode.lockedPure44k,
            nodeId: node.id,
            activeColor: const Color(0xFFFFB703),
          ),
          _buildStemLockTab(
            label: '🧬 AI Inpaint',
            mode: StemLockMode.harmonicInpaint,
            isActive: activeMode == StemLockMode.harmonicInpaint,
            nodeId: node.id,
            activeColor: const Color(0xFF00F5D4),
          ),
          _buildStemLockTab(
            label: '✨ Re-Imagine',
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
    required String label,
    required StemLockMode mode,
    required bool isActive,
    required String nodeId,
    required Color activeColor,
  }) {
    return Expanded(
      child: GestureDetector(
        key: Key('song_dna_stem_lock_tab_${mode.name}'),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(songDnaGraphProvider.notifier).setStemLockMode(nodeId, mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isActive ? activeColor : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? Colors.white : Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      {
        'name': 'Private School Rhodes',
        'icon': PhosphorIconsBold.pianoKeys,
        'sub': 'Soulful Jazz Keys',
      },
      {
        'name': 'Bamboo Flute',
        'icon': PhosphorIconsBold.musicNote,
        'sub': 'Ancestral Aerophone',
      },
      {
        'name': 'Maskandi Guitar',
        'icon': PhosphorIconsBold.guitar,
        'sub': 'Zulu Fingerpicking Acoustic',
      },
      {
        'name': 'Soprano Sax',
        'icon': PhosphorIconsBold.waveform,
        'sub': 'Emotive Brass Solo',
      },
      {
        'name': 'Solo Violin',
        'icon': PhosphorIconsBold.sparkle,
        'sub': 'Strings Harmonic Lead',
      },
      {
        'name': '808 Sub-Bass',
        'icon': PhosphorIconsBold.waveSine,
        'sub': 'Deep Electronic Low-End',
      },
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const PhosphorIcon(
                        PhosphorIconsBold.x,
                        size: 18,
                        color: Colors.white70,
                      ),
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
                      child: PhosphorIcon(
                        inst['icon'] as PhosphorIconData,
                        size: 16,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    title: Text(
                      inst['name'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      inst['sub'] as String,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.white60,
                      ),
                    ),
                    trailing: const PhosphorIcon(
                      PhosphorIconsBold.caretRight,
                      size: 14,
                      color: Colors.white38,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref
                          .read(songDnaGraphProvider.notifier)
                          .addInstrumentLeaf(
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
