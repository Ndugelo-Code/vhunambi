import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/models/mycelium_biome_models.dart';
import '../../controllers/biome_camera_controller.dart';

/// Depth-sortable 3D cluster or sprout item for back-to-front painter ordering.
class _DepthSortableEntity {
  final double eyeDepth;
  final VoidCallback drawCallback;

  const _DepthSortableEntity({
    required this.eyeDepth,
    required this.drawCallback,
  });
}

/// 6-Layer Production 3D Mesh CustomPainter for the Organic Mycelium Biome.
class OrganicMycelium3DPainter extends CustomPainter {
  final MusicalDnaGraph graph;
  final BiomeCameraState camera;
  final double animationProgress; // 0.0 -> 1.0 continuously cycling (60 FPS)
  final double focusTransitionProgress; // 0.0 (Overview) -> 1.0 (Canopy Dive)
  final AudioBiomeModulationState? audioModulation;

  /// Effective camera state taking into account log-drum transient snap zoom (REQ-P55-DSP-02).
  BiomeCameraState get activeCamera =>
      (audioModulation != null && audioModulation!.logDrumSnapZoom > 0.01)
          ? camera.copyWith(
              zoom: (camera.zoom * audioModulation!.cameraSnapZoomMultiplier)
                  .clamp(BiomeCameraState.minZoom, BiomeCameraState.maxZoom),
            )
          : camera;

  // Pre-allocated Paint instances (Zero Garbage Collection allocation rule)
  static final Paint _bgPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _gridPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _tendrilPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _hyphaGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  static final Paint _hyphaCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  static final Paint _photonPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  static final Paint _stipeFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _stipeRibPaint = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  static final Paint _gillPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  static final Paint _coreBloomPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  static final Paint _meshPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  static final Paint _ringWirePaint = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  static final Paint _badgePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _badgeBorderPaint = Paint()..style = PaintingStyle.stroke;

  // Reusable scratch paths
  static final Path _scratchPath = Path();
  static final Path _gillPath = Path();

  OrganicMycelium3DPainter({
    required this.graph,
    required this.camera,
    required this.animationProgress,
    this.focusTransitionProgress = 0.0,
    this.audioModulation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final growth = graph.growthProgress.clamp(0.05, 1.0);
    final phaseTime = animationProgress * 2.0 * math.pi;

    // =========================================================================
    // LAYER 1: Abyssal Bio-Space Skybox & Atmospheric Floating Spores
    // =========================================================================
    _bgPaint.shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.48),
      math.max(size.width, size.height) * 0.78,
      const [
        Color(0xFF0A1124),
        Color(0xFF040812),
        Color(0xFF020409),
      ],
      const [0.0, 0.58, 1.0],
    );
    canvas.drawRect(Offset.zero & size, _bgPaint);
    _bgPaint.shader = null;

    if (graph.activeLayers.contains(MyceliumNetworkLayer.atmosphere)) {
      _drawAtmosphericSpores(canvas, size, phaseTime);
    }

    // =========================================================================
    // LAYER 2: 3D Contoured Terrain Grid Y = h(X, Z) & Mycelium Root Web
    // =========================================================================
    _draw3DContouredTerrain(canvas, size, phaseTime);

    if (growth >= 0.15) {
      final webScale = ((growth - 0.15) / 0.47).clamp(0.0, 1.0);
      _draw3DMyceliumRootWeb(canvas, size, phaseTime, webScale);
    }

    // =========================================================================
    // LAYER 3, 4 & 5: Depth-Sorted 3D Sprout Mushrooms & 6 Fruiting Bodies
    // =========================================================================
    final depthQueue = <_DepthSortableEntity>[];

    // Enqueue 16 miniature 3D Sprout/Pinhead Mushrooms
    if (growth >= 0.35 &&
        graph.activeLayers.contains(MyceliumNetworkLayer.atmosphere)) {
      final sproutScale = ((growth - 0.35) / 0.45).clamp(0.0, 1.0);
      for (final sprout in graph.sproutNodes) {
        final proj = BiomeProjectionEngine.project3D(
          sprout.rootPosition,
          activeCamera,
          size,
        );
        if (proj != null) {
          depthQueue.add(
            _DepthSortableEntity(
              eyeDepth: proj.eyeDepth,
              drawCallback: () => _draw3DSproutMushroom(
                canvas,
                size,
                sprout,
                phaseTime,
                sproutScale,
              ),
            ),
          );
        }
      }
    }

    // Enqueue 6 Giant Mushroom Fruiting Bodies (Stipe + 32 Gills + 3D Cap Mesh)
    if (growth >= 0.20) {
      final stipeGrowth = ((growth - 0.20) / 0.65).clamp(0.0, 1.0);
      final capGrowth = ((growth - 0.45) / 0.55).clamp(0.08, 1.0);

      for (final cluster in graph.clusters.values) {
        final proj = BiomeProjectionEngine.project3D(
          cluster.capApexPosition,
          activeCamera,
          size,
        );
        if (proj != null) {
          depthQueue.add(
            _DepthSortableEntity(
              eyeDepth: proj.eyeDepth,
              drawCallback: () => _draw3DFruitingBody(
                canvas,
                size,
                cluster,
                phaseTime,
                stipeGrowth,
                capGrowth,
              ),
            ),
          );
        }
      }
    }

    // Painter's Algorithm: Sort back-to-front (largest eyeDepth drawn first)
    depthQueue.sort((a, b) => b.eyeDepth.compareTo(a.eyeDepth));
    for (final item in depthQueue) {
      item.drawCallback();
    }

    // =========================================================================
    // LAYER 6: Focused Canopy Child Leaf Nodes (Unfurled at Arm's Reach)
    // =========================================================================
    if (graph.focusedCluster != null && focusTransitionProgress > 0.05) {
      _drawFocusedCanopyLeaves(
        canvas,
        size,
        graph.focusedCluster!,
        phaseTime,
      );
    }
  }

  /// Renders Layer 1 atmospheric bokeh spores drifting upward in +Y space.
  void _drawAtmosphericSpores(Canvas canvas, Size size, double phaseTime) {
    const int sporeCount = 42;
    for (int i = 0; i < sporeCount; i++) {
      final seed = (graph.songFingerprintSeed + i * 7919) & 0x7FFFFFFF;
      final sx = ((seed % 600) - 300).toDouble();
      final sz = (((seed ~/ 600) % 480) - 240).toDouble();
      final baseY = ((seed ~/ 288000) % 180).toDouble() + 12.0;
      final floatY = baseY + 12.0 * math.sin(phaseTime + i * 0.45);

      final proj = BiomeProjectionEngine.project3D(
        Vector3D(sx, floatY, sz),
        activeCamera,
        size,
      );
      if (proj == null) continue;

      final colorHex = MyceliumClusterDomain
          .values[i % MyceliumClusterDomain.values.length].hexColor;
      final radius = (1.6 + (i % 3) * 0.9) * proj.scale.clamp(0.4, 1.8);
      final sporeAlpha = audioModulation?.sporeCloudAlpha ?? 1.0;
      _photonPaint.color = Color(colorHex).withValues(alpha: (0.32 * sporeAlpha).clamp(0.05, 0.90));
      canvas.drawCircle(proj.screenOffset, radius * 2.2, _photonPaint);
      _photonPaint.color = Colors.white.withValues(alpha: (0.55 * sporeAlpha).clamp(0.1, 0.95));
      canvas.drawCircle(proj.screenOffset, radius * 0.7, _photonPaint);
    }
  }

  /// Renders the 20x20 contoured 3D Y-Up terrain grid Y = h(X, Z).
  void _draw3DContouredTerrain(Canvas canvas, Size size, double phaseTime) {
    const int steps = 18;
    const double minX = -300.0, maxX = 300.0;
    const double minZ = -240.0, maxZ = 240.0;
    const double dx = (maxX - minX) / steps;
    const double dz = (maxZ - minZ) / steps;

    _gridPaint
      ..color = const Color(0xFF00B4D8).withValues(alpha: 0.11)
      ..strokeWidth = 0.9;

    // Longitudinal X-lines
    for (int i = 0; i <= steps; i++) {
      final x = minX + i * dx;
      _scratchPath.reset();
      bool started = false;
      for (int j = 0; j <= steps; j++) {
        final z = minZ + j * dz;
        final y = BiomeTerrainMath.heightAt(x, z);
        final proj = BiomeProjectionEngine.project3D(
          Vector3D(x, y, z),
          activeCamera,
          size,
        );
        if (proj != null) {
          if (!started) {
            _scratchPath.moveTo(proj.screenOffset.dx, proj.screenOffset.dy);
            started = true;
          } else {
            _scratchPath.lineTo(proj.screenOffset.dx, proj.screenOffset.dy);
          }
        }
      }
      if (started) canvas.drawPath(_scratchPath, _gridPaint);
    }

    // Latitudinal Z-lines
    for (int j = 0; j <= steps; j++) {
      final z = minZ + j * dz;
      _scratchPath.reset();
      bool started = false;
      for (int i = 0; i <= steps; i++) {
        final x = minX + i * dx;
        final y = BiomeTerrainMath.heightAt(x, z);
        final proj = BiomeProjectionEngine.project3D(
          Vector3D(x, y, z),
          activeCamera,
          size,
        );
        if (proj != null) {
          if (!started) {
            _scratchPath.moveTo(proj.screenOffset.dx, proj.screenOffset.dy);
            started = true;
          } else {
            _scratchPath.lineTo(proj.screenOffset.dx, proj.screenOffset.dy);
          }
        }
      }
      if (started) canvas.drawPath(_scratchPath, _gridPaint);
    }
  }

  /// Renders the 72 branching rootlet tendrils, 15 arterial hyphae, and synaptic photons.
  void _draw3DMyceliumRootWeb(
    Canvas canvas,
    Size size,
    double phaseTime,
    double webScale,
  ) {
    // 1. Render 72 Secondary/Tertiary Branching Rootlet Tendrils
    for (final tendril in graph.rootTendrils) {
      final layerVisible = graph.isClusterLayerVisible(tendril.originDomain);
      final alpha = (layerVisible ? 0.38 : 0.06) * tendril.luminosity * webScale;
      if (alpha <= 0.01) continue;

      _scratchPath.reset();
      bool started = false;
      for (final wp in tendril.waypoints) {
        final proj = BiomeProjectionEngine.project3D(wp, activeCamera, size);
        if (proj != null) {
          if (!started) {
            _scratchPath.moveTo(proj.screenOffset.dx, proj.screenOffset.dy);
            started = true;
          } else {
            _scratchPath.lineTo(proj.screenOffset.dx, proj.screenOffset.dy);
          }
        }
      }
      if (started) {
        _tendrilPaint
          ..color = Color(tendril.originDomain.hexColor).withValues(alpha: alpha)
          ..strokeWidth = tendril.thickness;
        canvas.drawPath(_scratchPath, _tendrilPaint);
      }
    }

    // 2. Render 15 Cross-Cluster Arterial Hyphal Conduits & Synaptic Photons
    for (final edge in graph.hyphaeEdges) {
      final srcVisible = graph.isClusterLayerVisible(edge.sourceDomain);
      final tgtVisible = graph.isClusterLayerVisible(edge.targetDomain);
      final isFocusedEdge = graph.focusedDomain == edge.sourceDomain ||
          graph.focusedDomain == edge.targetDomain;

      double visibilityFactor = (srcVisible || tgtVisible) ? 1.0 : 0.14;
      if (isFocusedEdge) visibilityFactor = 1.25;

      final pts = <Offset>[];
      for (final wp in edge.splineWaypoints) {
        final proj = BiomeProjectionEngine.project3D(wp, activeCamera, size);
        if (proj != null) pts.add(proj.screenOffset);
      }
      if (pts.length < 2) continue;

      _scratchPath.reset();
      _scratchPath.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) * 0.5,
          (pts[i].dy + pts[i + 1].dy) * 0.5,
        );
        _scratchPath.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      _scratchPath.lineTo(pts.last.dx, pts.last.dy);

      final srcColor = Color(edge.sourceDomain.hexColor);
      final tgtColor = Color(edge.targetDomain.hexColor);

      // Outer bioluminescent aura pass
      _hyphaGlowPaint
        ..shader = ui.Gradient.linear(pts.first, pts.last, [
          srcColor.withValues(alpha: (0.28 * visibilityFactor).clamp(0.0, 1.0)),
          tgtColor.withValues(alpha: (0.28 * visibilityFactor).clamp(0.0, 1.0)),
        ])
        ..strokeWidth = (edge.isPrimaryArterial ? 5.5 : 3.0) * edge.conductivityWeight;
      canvas.drawPath(_scratchPath, _hyphaGlowPaint);

      // Inner high-intensity core filament pass (or crystalline gold-cyan sheath if Stem-Locked)
      _hyphaCorePaint
        ..shader = ui.Gradient.linear(pts.first, pts.last, [
          edge.isStemLocked
              ? const Color(0xFF00F5D4).withValues(alpha: 0.92)
              : srcColor.withValues(alpha: (0.78 * visibilityFactor).clamp(0.0, 1.0)),
          edge.isStemLocked
              ? const Color(0xFFFFD166).withValues(alpha: 0.92)
              : tgtColor.withValues(alpha: (0.78 * visibilityFactor).clamp(0.0, 1.0)),
        ])
        ..strokeWidth = edge.isPrimaryArterial ? 2.1 : 1.1;
      canvas.drawPath(_scratchPath, _hyphaCorePaint);

      // Layer 3: Traveling Synaptic Nutrient Photons along the 3D spline
      if (visibilityFactor > 0.3) {
        final baseSpeed =
            graph.activeSection == SongJourneySection.chorus ? 1.45 : 1.0;
        final dspSpeed = audioModulation?.photonSpeedMultiplier ?? 1.0;
        final speedMultiplier = baseSpeed * dspSpeed;
        for (int p = 0; p < edge.photonCount; p++) {
          final t = ((animationProgress * speedMultiplier) +
                  (p / edge.photonCount) +
                  edge.conductivityWeight * 0.37) %
              1.0;
          final worldPos = edge.sampleAt(t);
          final proj = BiomeProjectionEngine.project3D(worldPos, activeCamera, size);
          if (proj == null) continue;

          final r = (edge.isPrimaryArterial ? 3.6 : 2.4) * proj.scale.clamp(0.6, 1.8);
          _photonPaint.color = Color.lerp(srcColor, tgtColor, t)!
              .withValues(alpha: 0.85);
          canvas.drawCircle(proj.screenOffset, r * 1.9, _photonPaint);
          _photonPaint.color = Colors.white.withValues(alpha: 0.95);
          canvas.drawCircle(proj.screenOffset, r * 0.75, _photonPaint);
        }
      }
    }
    _hyphaGlowPaint.shader = null;
    _hyphaCorePaint.shader = null;
  }

  /// Renders a miniature 3D bioluminescent Sprout/Pinhead Mushroom at a hyphal junction.
  void _draw3DSproutMushroom(
    Canvas canvas,
    Size size,
    MyceliumSproutNode sprout,
    double phaseTime,
    double sproutScale,
  ) {
    final bob = 1.2 * math.sin(phaseTime + sprout.pulsePhase);
    final rootProj = BiomeProjectionEngine.project3D(
      sprout.rootPosition,
      activeCamera,
      size,
    );
    final apexWorld = Vector3D(
      sprout.rootPosition.x,
      sprout.rootPosition.y + sprout.height * sproutScale + bob,
      sprout.rootPosition.z,
    );
    final apexProj = BiomeProjectionEngine.project3D(apexWorld, activeCamera, size);
    if (rootProj == null || apexProj == null) return;

    final color = Color(sprout.hexColor);
    final s = apexProj.scale.clamp(0.45, 2.0);

    // 1. Miniature Stalk
    _tendrilPaint
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 2.6 * s;
    canvas.drawLine(rootProj.screenOffset, apexProj.screenOffset, _tendrilPaint);

    // 2. Miniature 3D Domed Cap (8-segment 3D polygon)
    final capR = sprout.capRadius * sproutScale;
    _scratchPath.reset();
    for (int i = 0; i <= 10; i++) {
      final angle = (2.0 * math.pi * i) / 10;
      final rimWorld = Vector3D(
        apexWorld.x + capR * math.cos(angle),
        apexWorld.y - capR * 0.55,
        apexWorld.z + capR * math.sin(angle),
      );
      final p = BiomeProjectionEngine.project3D(rimWorld, activeCamera, size);
      if (p != null) {
        if (i == 0) {
          _scratchPath.moveTo(p.screenOffset.dx, p.screenOffset.dy);
        } else {
          _scratchPath.lineTo(p.screenOffset.dx, p.screenOffset.dy);
        }
      }
    }
    _scratchPath.close();

    _photonPaint.color = color.withValues(alpha: 0.55);
    canvas.drawPath(_scratchPath, _photonPaint);
    canvas.drawCircle(apexProj.screenOffset, capR * s * 0.9, _photonPaint);
  }

  /// Renders a complete 3D Mushroom Fruiting Body:
  /// (1) 8-Ring Curved Hyperboloid Stipe, (2) 32 3D Radial Gills + Core Bloom,
  /// (3) 5-Ring x 24-Seg Fluted 3D Umbrella Cap (`ui.Vertices`).
  void _draw3DFruitingBody(
    Canvas canvas,
    Size size,
    MushroomFruitingBody cluster,
    double phaseTime,
    double stipeGrowth,
    double capGrowth,
  ) {
    final isLayerActive = graph.isClusterLayerVisible(cluster.domain);
    final opacityMult = isLayerActive ? 1.0 : 0.15;
    final mod = audioModulation;
    final capAudioScale = mod?.capScaleMultiplierFor(cluster.domain) ?? 1.0;
    final lumAudioMult = mod?.luminosityMultiplierFor(cluster.domain) ?? 1.0;
    final acousticHeaveY = mod?.stipeHeaveFor(cluster.domain) ?? 0.0;
    final isSoloSpotlight = mod?.isDomainSoloed(cluster.domain) ?? false;

    final breathY = 2.5 *
        math.sin(phaseTime * cluster.dynamicPulseRate + cluster.domain.index);

    final x0 = cluster.rootPosition.x;
    final yRoot = cluster.rootPosition.y;
    final z0 = cluster.rootPosition.z;
    final hStipe = cluster.stipeHeight * stipeGrowth;
    final yApex = yRoot + hStipe + breathY + acousticHeaveY;
    final rCap = cluster.capRadius * capGrowth * capAudioScale;
    final hCap = cluster.capDepth * capGrowth * capAudioScale;
    final yCollar = yApex - 0.45 * hCap;

    final baseColor = Color(cluster.domain.hexColor);
    final lum = (cluster.currentLuminosity * opacityMult * lumAudioMult)
        .clamp(0.12, 1.35);

    // =========================================================================
    // STEP 1: Root Mound Bioluminescent Corona
    // =========================================================================
    final rootProj = BiomeProjectionEngine.project3D(
      cluster.rootPosition,
      activeCamera,
      size,
    );
    if (rootProj != null) {
      _coreBloomPaint
        ..color = baseColor.withValues(alpha: 0.26 * lum)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(
        rootProj.screenOffset,
        rCap * 0.65 * rootProj.scale.clamp(0.5, 2.0),
        _coreBloomPaint,
      );
      _coreBloomPaint.maskFilter = null;
    }

    // =========================================================================
    // STEP 2: 8-Ring 3D Curved Hyperboloid Stipe (Stalk)
    // =========================================================================
    const int stipeRings = 7;
    final rBase = 0.28 * rCap;
    final rWaist = 0.12 * rCap;
    final rApex = 0.22 * rCap;
    final bendAngle = cluster.domain.index * 1.1;

    final leftContour = <Offset>[];
    final rightContour = <Offset>[];

    for (int sIdx = 0; sIdx <= stipeRings; sIdx++) {
      final s = sIdx / stipeRings;
      final omt = 1.0 - s;
      final rS = rBase * omt * omt + rWaist * 2.0 * s * omt + rApex * s * s;
      final yS = yRoot + s * (yCollar - yRoot);
      final bendOffset = 4.2 * math.sin(math.pi * s);
      final cx = x0 + bendOffset * math.cos(bendAngle);
      final cz = z0 + bendOffset * math.sin(bendAngle);

      // Camera-perpendicular horizontal tangent in XZ plane
      final perpX = math.cos(activeCamera.yaw);
      final perpZ = -math.sin(activeCamera.yaw);

      final leftPt = BiomeProjectionEngine.project3D(
        Vector3D(cx - rS * perpX, yS, cz - rS * perpZ),
        activeCamera,
        size,
      );
      final rightPt = BiomeProjectionEngine.project3D(
        Vector3D(cx + rS * perpX, yS, cz + rS * perpZ),
        activeCamera,
        size,
      );
      if (leftPt != null && rightPt != null) {
        leftContour.add(leftPt.screenOffset);
        rightContour.add(rightPt.screenOffset);
      }
    }

    if (leftContour.length >= 2 && rightContour.length >= 2) {
      _scratchPath.reset();
      _scratchPath.moveTo(leftContour.first.dx, leftContour.first.dy);
      for (int i = 1; i < leftContour.length; i++) {
        _scratchPath.lineTo(leftContour[i].dx, leftContour[i].dy);
      }
      for (int i = rightContour.length - 1; i >= 0; i--) {
        _scratchPath.lineTo(rightContour[i].dx, rightContour[i].dy);
      }
      _scratchPath.close();

      _stipeFillPaint.shader = ui.Gradient.linear(
        leftContour.first,
        rightContour.last,
        [
          baseColor.withValues(alpha: 0.22 * lum),
          baseColor.withValues(alpha: 0.72 * lum),
          Colors.white.withValues(alpha: 0.85 * lum),
        ],
        const [0.0, 0.70, 1.0],
      );
      canvas.drawPath(_scratchPath, _stipeFillPaint);
      _stipeFillPaint.shader = null;

      // Longitudinal fibrous stipe striations (6 3D vertical ribs)
      _stipeRibPaint
        ..color = Colors.white.withValues(alpha: 0.35 * lum)
        ..strokeWidth = 1.1;
      for (int rib = 0; rib < 6; rib++) {
        final frac = (rib + 1) / 7.0;
        _scratchPath.reset();
        for (int i = 0; i < leftContour.length; i++) {
          final pt = Offset.lerp(leftContour[i], rightContour[i], frac)!;
          if (i == 0) {
            _scratchPath.moveTo(pt.dx, pt.dy);
          } else {
            _scratchPath.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(_scratchPath, _stipeRibPaint);
      }
    }

    // =========================================================================
    // STEP 3: Sub-Cap Core Bioluminescent Heart & 32 3D Radial Lamellae Gills
    // =========================================================================
    final heartWorld = Vector3D(x0, yApex - 0.36 * hCap, z0);
    final heartProj = BiomeProjectionEngine.project3D(heartWorld, activeCamera, size);
    if (heartProj != null) {
      if (isSoloSpotlight) {
        _ringWirePaint
          ..color = const Color(0xFFFFD166).withValues(alpha: 0.90)
          ..strokeWidth = 2.5;
        canvas.drawCircle(
          heartProj.screenOffset,
          rCap * 0.92 * heartProj.scale.clamp(0.4, 2.2),
          _ringWirePaint,
        );
      }
      _coreBloomPaint
        ..color = baseColor.withValues(alpha: 0.65 * lum)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(
        heartProj.screenOffset,
        rCap * 0.55 * heartProj.scale.clamp(0.4, 2.2),
        _coreBloomPaint,
      );
      _coreBloomPaint
        ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.82 * lum)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        heartProj.screenOffset,
        rCap * 0.25 * heartProj.scale.clamp(0.4, 2.2),
        _coreBloomPaint,
      );
      _coreBloomPaint.maskFilter = null;
    }

    // 32 3D Arched Radial Lamellae Gills
    const int gillCount = 32;
    for (int k = 0; k < gillCount; k++) {
      final v = (2.0 * math.pi * k) / gillCount;
      final fluteFactor = 1.0 + 0.085 * math.sin(12.0 * v);
      final rRim = rCap * fluteFactor;
      final yRim = yApex - hCap + 2.2 * math.cos(12.0 * v);

      final pStart = BiomeProjectionEngine.project3D(
        Vector3D(
          x0 + rApex * math.cos(v),
          yCollar,
          z0 + rApex * math.sin(v),
        ),
        activeCamera,
        size,
      );
      final pMid = BiomeProjectionEngine.project3D(
        Vector3D(
          x0 + 0.56 * rRim * math.cos(v),
          yApex - 0.30 * hCap,
          z0 + 0.56 * rRim * math.sin(v),
        ),
        activeCamera,
        size,
      );
      final pEnd = BiomeProjectionEngine.project3D(
        Vector3D(
          x0 + rRim * math.cos(v),
          yRim,
          z0 + rRim * math.sin(v),
        ),
        activeCamera,
        size,
      );

      if (pStart != null && pMid != null && pEnd != null) {
        _gillPath.reset();
        _gillPath.moveTo(pStart.screenOffset.dx, pStart.screenOffset.dy);
        _gillPath.quadraticBezierTo(
          pMid.screenOffset.dx,
          pMid.screenOffset.dy,
          pEnd.screenOffset.dx,
          pEnd.screenOffset.dy,
        );
        _gillPaint
          ..color = (k.isEven ? Colors.white : baseColor)
              .withValues(alpha: (k.isEven ? 0.52 : 0.68) * lum)
          ..strokeWidth = (k % 4 == 0 ? 1.45 : 0.85) * pEnd.scale.clamp(0.5, 1.8);
        canvas.drawPath(_gillPath, _gillPaint);
      }
    }

    // =========================================================================
    // STEP 4: 5-Ring x 24-Seg 3D Fluted Umbrella Cap Mesh (`ui.Vertices`)
    // =========================================================================
    const int uRings = 5; // u in {0.0, 0.25, 0.5, 0.75, 1.0}
    const int vSegs = 24;
    const int vertexCount = uRings * vSegs;

    final positions = Float32List(vertexCount * 2);
    final colors = Int32List(vertexCount);
    final ringScreenPoints = List<List<Offset>>.generate(
      uRings,
      (_) => <Offset>[],
    );

    bool meshValid = true;
    for (int i = 0; i < uRings; i++) {
      final u = i / (uRings - 1);
      final uGamma = math.pow(u, 0.85).toDouble();

      for (int j = 0; j < vSegs; j++) {
        final v = (2.0 * math.pi * j) / vSegs;
        final flute = 0.085 * math.sin(12.0 * v) * u * u;
        final rUV = rCap * (uGamma + flute);
        final yUV =
            yApex - hCap * u * u + 2.2 * u * (1.0 - u) * math.cos(12.0 * v);
        final xUV = x0 + rUV * math.cos(v);
        final zUV = z0 + rUV * math.sin(v);

        final proj = BiomeProjectionEngine.project3D(
          Vector3D(xUV, yUV, zUV),
          activeCamera,
          size,
        );
        final vIdx = i * vSegs + j;
        if (proj == null) {
          meshValid = false;
          break;
        }
        positions[vIdx * 2] = proj.screenOffset.dx;
        positions[vIdx * 2 + 1] = proj.screenOffset.dy;
        ringScreenPoints[i].add(proj.screenOffset);

        // Per-vertex translucent bioluminescence (brighter at apex & fluted rim)
        final vertexAlpha =
            ((1.0 - 0.55 * u + 0.30 * math.pow(u, 3)) * 0.52 * lum)
                .clamp(0.05, 0.85);
        final vertexColor = i == 0
            ? Color.lerp(baseColor, Colors.white, 0.65)!
                .withValues(alpha: vertexAlpha)
            : baseColor.withValues(alpha: vertexAlpha);
        colors[vIdx] = vertexColor.toARGB32();
      }
      if (!meshValid) break;
    }

    if (meshValid) {
      const int quadCount = (uRings - 1) * vSegs;
      final indices = Uint16List(quadCount * 6);
      int k = 0;
      for (int i = 0; i < uRings - 1; i++) {
        for (int j = 0; j < vSegs; j++) {
          final nextJ = (j + 1) % vSegs;
          final v00 = i * vSegs + j;
          final v01 = i * vSegs + nextJ;
          final v10 = (i + 1) * vSegs + j;
          final v11 = (i + 1) * vSegs + nextJ;

          indices[k++] = v00;
          indices[k++] = v10;
          indices[k++] = v11;
          indices[k++] = v00;
          indices[k++] = v11;
          indices[k++] = v01;
        }
      }

      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      );
      _meshPaint.color = Colors.white;
      canvas.drawVertices(vertices, BlendMode.plus, _meshPaint);

      // Draw 3D Concentric Dome Contour Rings & Fluted Margin Rim
      for (int i = 1; i < uRings; i++) {
        final ring = ringScreenPoints[i];
        if (ring.isEmpty) continue;
        _scratchPath.reset();
        _scratchPath.moveTo(ring.first.dx, ring.first.dy);
        for (int j = 1; j < ring.length; j++) {
          _scratchPath.lineTo(ring[j].dx, ring[j].dy);
        }
        _scratchPath.close();

        final isOuterRim = i == uRings - 1;
        _ringWirePaint
          ..color = (isOuterRim
                  ? Color.lerp(baseColor, Colors.white, 0.45)!
                  : baseColor)
              .withValues(alpha: (isOuterRim ? 0.88 : 0.34) * lum)
          ..strokeWidth = isOuterRim ? 2.0 : 0.9;
        canvas.drawPath(_scratchPath, _ringWirePaint);
      }

      // Bioluminescent Surface Specks on the Cap Dome (Rings 2 and 3)
      for (int j = 0; j < vSegs; j += 2) {
        final speckPt = ringScreenPoints[2][j];
        _photonPaint.color = Colors.white.withValues(alpha: 0.65 * lum);
        canvas.drawCircle(speckPt, 1.6, _photonPaint);
      }
    }
  }

  /// Renders focused cluster's child leaf nodes unfurled radially in 3D space.
  void _drawFocusedCanopyLeaves(
    Canvas canvas,
    Size size,
    MushroomFruitingBody cluster,
    double phaseTime,
  ) {
    final capProj = BiomeProjectionEngine.project3D(
      cluster.capApexPosition,
      activeCamera,
      size,
    );
    if (capProj == null) return;

    final baseColor = Color(cluster.domain.hexColor);

    for (final leaf in cluster.childLeaves) {
      final leafWorld =
          cluster.capApexPosition + (leaf.localOffset * focusTransitionProgress);
      final leafProj = BiomeProjectionEngine.project3D(leafWorld, activeCamera, size);
      if (leafProj == null) continue;

      // Glowing neural tether from cap apex to child leaf
      _gillPaint
        ..color = baseColor.withValues(alpha: 0.72 * focusTransitionProgress)
        ..strokeWidth = 1.6 * leafProj.scale.clamp(0.6, 1.5);
      canvas.drawLine(capProj.screenOffset, leafProj.screenOffset, _gillPaint);

      // Child Leaf Pill
      final s = (leafProj.scale * focusTransitionProgress).clamp(0.55, 1.25);
      final pillW = 116.0 * s;
      final pillH = 28.0 * s;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: leafProj.screenOffset,
          width: pillW,
          height: pillH,
        ),
        Radius.circular(14.0 * s),
      );

      _badgePaint.color = const Color(0xFF101420).withValues(alpha: 0.92);
      canvas.drawRRect(rrect, _badgePaint);

      final isSelected = graph.selectedChildNodeId == leaf.id;
      _badgeBorderPaint
        ..color = isSelected
            ? Colors.white
            : baseColor.withValues(alpha: 0.85 * focusTransitionProgress)
        ..strokeWidth = isSelected ? 2.0 : 1.2;
      canvas.drawRRect(rrect, _badgeBorderPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: leaf.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: (10.0 * s).clamp(8.5, 12.0),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: pillW - 14.0);

      tp.paint(
        canvas,
        Offset(
          leafProj.screenOffset.dx - tp.width * 0.5,
          leafProj.screenOffset.dy - tp.height * 0.5,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrganicMycelium3DPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.camera != camera ||
        oldDelegate.focusTransitionProgress != focusTransitionProgress ||
        oldDelegate.graph != graph ||
        oldDelegate.audioModulation != audioModulation;
  }
}

