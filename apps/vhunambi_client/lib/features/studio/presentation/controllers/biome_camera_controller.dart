import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/mycelium_biome_models.dart';

/// Immutable 3D Camera State in Right-Handed Y-Up World Space.
class BiomeCameraState {
  static const double minZoom = 0.65;
  static const double maxZoom = 2.2;
  static const double minDistance = 180.0;
  static const double maxDistance = 650.0;

  final Vector3D target; // Focal target (T_x, T_y, T_z)
  final double yaw; // Azimuth theta in radians
  final double pitch; // Elevation phi in radians, clamped to [15 deg, 75 deg]
  final double distance; // Camera distance R in [180, 650]
  final double zoom; // Additional FOV zoom multiplier (default 1.0)
  final bool isAutoRotating;

  const BiomeCameraState({
    this.target = const Vector3D(0.0, 55.0, 0.0),
    this.yaw = 0.0,
    this.pitch = 32.0 * math.pi / 180.0,
    this.distance = 420.0,
    this.zoom = 1.0,
    this.isAutoRotating = false,
  });

  BiomeCameraState copyWith({
    Vector3D? target,
    double? yaw,
    double? pitch,
    double? distance,
    double? zoom,
    bool? isAutoRotating,
  }) {
    return BiomeCameraState(
      target: target ?? this.target,
      yaw: yaw ?? this.yaw,
      pitch: (pitch ?? this.pitch).clamp(
        15.0 * math.pi / 180.0,
        75.0 * math.pi / 180.0,
      ),
      distance: (distance ?? this.distance).clamp(minDistance, maxDistance),
      zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
      isAutoRotating: isAutoRotating ?? this.isAutoRotating,
    );
  }

  /// Smoothly interpolates between two 3D camera states [a] and [b] by [t] in [0, 1].
  static BiomeCameraState lerp(
    BiomeCameraState a,
    BiomeCameraState b,
    double t,
  ) {
    final clampedT = t.clamp(0.0, 1.0);
    return BiomeCameraState(
      target: Vector3D.lerp(a.target, b.target, clampedT),
      yaw: a.yaw + (b.yaw - a.yaw) * clampedT,
      pitch: (a.pitch + (b.pitch - a.pitch) * clampedT).clamp(
        15.0 * math.pi / 180.0,
        75.0 * math.pi / 180.0,
      ),
      distance: (a.distance + (b.distance - a.distance) * clampedT).clamp(
        minDistance,
        maxDistance,
      ),
      zoom: (a.zoom + (b.zoom - a.zoom) * clampedT).clamp(minZoom, maxZoom),
      isAutoRotating: b.isAutoRotating,
    );
  }
}

/// Projected 2D screen point with eye-space depth and perspective scale.
class ProjectedPoint2D {
  final Offset screenOffset;
  final double eyeDepth;
  final double scale;

  const ProjectedPoint2D({
    required this.screenOffset,
    required this.eyeDepth,
    required this.scale,
  });
}

/// Strongly-typed result of a 2D tap hit-test against the 3D Mycelium Biome.
class BiomeHitTestResult {
  final MyceliumClusterDomain? hitCluster;
  final MyceliumChildNode? hitChildLeaf;

  const BiomeHitTestResult({this.hitCluster, this.hitChildLeaf});
  bool get hasHit => hitCluster != null || hitChildLeaf != null;
}

/// Pure mathematical 3D->2D projection & hit-testing engine.
abstract final class BiomeProjectionEngine {
  static ProjectedPoint2D? project3D(
    Vector3D worldPt,
    BiomeCameraState camera,
    Size viewportSize,
  ) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return null;

    final dx = worldPt.x - camera.target.x;
    final dy = worldPt.y - camera.target.y;
    final dz = worldPt.z - camera.target.z;

    final cosYaw = math.cos(camera.yaw);
    final sinYaw = math.sin(camera.yaw);
    final cosPitch = math.cos(camera.pitch);
    final sinPitch = math.sin(camera.pitch);

    // 1. Yaw rotation around +Y axis
    final x1 = dx * cosYaw - dz * sinYaw;
    final y1 = dy;
    final z1 = dx * sinYaw + dz * cosYaw;

    // 2. Pitch elevation rotation
    final xEye = x1;
    final yEye = y1 * cosPitch - z1 * sinPitch;
    final zEye = y1 * sinPitch + z1 * cosPitch;

    // 3. Eye depth (foreground +Z is closer -> smaller eyeDepth)
    final eyeDepth = camera.distance - zEye;
    if (eyeDepth <= 15.0) return null;

    final fov =
        math.min(viewportSize.width, viewportSize.height) * 0.92 * camera.zoom;
    final scale = fov / eyeDepth;

    // +Y in 3D world space maps UP on screen (subtract yEye * scale)
    final sx = viewportSize.width * 0.5 + xEye * scale;
    final sy = viewportSize.height * 0.5 - yEye * scale;

    return ProjectedPoint2D(
      screenOffset: Offset(sx, sy),
      eyeDepth: eyeDepth,
      scale: scale,
    );
  }

  /// Resolves a 2D screen tap against unfurled child leaves first, then parent mushroom caps/badges.
  static BiomeHitTestResult hitTest({
    required Offset tapPosition,
    required Size viewportSize,
    required MusicalDnaGraph graph,
    required BiomeCameraState camera,
  }) {
    // 1. If a cluster is focused, test its unfurled child leaf nodes first
    final focused = graph.focusedCluster;
    if (focused != null) {
      for (final leaf in focused.childLeaves) {
        final worldPos = focused.capApexPosition + leaf.localOffset;
        final proj = project3D(worldPos, camera, viewportSize);
        if (proj != null) {
          final hitRect = Rect.fromCenter(
            center: proj.screenOffset,
            width: 118.0 * proj.scale.clamp(0.7, 1.3),
            height: 36.0 * proj.scale.clamp(0.7, 1.3),
          );
          if (hitRect.inflate(8.0).contains(tapPosition)) {
            return BiomeHitTestResult(
              hitCluster: focused.domain,
              hitChildLeaf: leaf,
            );
          }
        }
      }
    }

    // 2. Sort parent clusters front-to-back (smallest eyeDepth first) and test cap + badge
    final candidates =
        <(MushroomFruitingBody, ProjectedPoint2D, ProjectedPoint2D)>[];
    for (final cluster in graph.clusters.values) {
      final capProj = project3D(cluster.capApexPosition, camera, viewportSize);
      final badgeWorld = cluster.capApexPosition + const Vector3D(0, 34, 0);
      final badgeProj = project3D(badgeWorld, camera, viewportSize);
      if (capProj != null && badgeProj != null) {
        candidates.add((cluster, capProj, badgeProj));
      }
    }
    candidates.sort((a, b) => a.$2.eyeDepth.compareTo(b.$2.eyeDepth));

    for (final (cluster, capProj, badgeProj) in candidates) {
      final capHitRadius = math.max(
        32.0,
        cluster.capRadius * capProj.scale * 1.15,
      );
      final badgeHitRadius = math.max(28.0, 26.0 * badgeProj.scale);
      if ((tapPosition - badgeProj.screenOffset).distance <= badgeHitRadius ||
          (tapPosition - capProj.screenOffset).distance <= capHitRadius) {
        return BiomeHitTestResult(hitCluster: cluster.domain);
      }
    }

    return const BiomeHitTestResult();
  }
}

/// Riverpod StateNotifier controlling 3D orbital camera movements.
class BiomeCameraNotifier extends StateNotifier<BiomeCameraState> {
  BiomeCameraNotifier() : super(const BiomeCameraState());

  void setCameraState(BiomeCameraState next) {
    state = next;
  }

  void setOrbit({required double yaw, required double pitch}) {
    state = state.copyWith(yaw: yaw, pitch: pitch);
  }

  void addOrbitDelta({required double deltaYaw, required double deltaPitch}) {
    state = state.copyWith(
      yaw: state.yaw + deltaYaw,
      pitch: state.pitch + deltaPitch,
    );
  }

  void setDistance(double distance) {
    state = state.copyWith(distance: distance);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
  }

  /// Incremental 3D dolly-in + FOV zoom step for the [+] HUD button (REQ-P56-BIOME-05).
  void zoomInStep() {
    state = state.copyWith(
      distance: state.distance - 42.0,
      zoom: state.zoom + 0.16,
    );
  }

  /// Incremental 3D dolly-out + FOV zoom step for the [-] HUD button (REQ-P56-BIOME-05).
  void zoomOutStep() {
    state = state.copyWith(
      distance: state.distance + 42.0,
      zoom: state.zoom - 0.16,
    );
  }

  void toggleAutoRotate() {
    state = state.copyWith(isAutoRotating: !state.isAutoRotating);
  }

  /// Advances camera azimuth when [isAutoRotating] is active.
  void stepAutoRotate([double radiansDelta = 0.008]) {
    if (!state.isAutoRotating) return;
    state = state.copyWith(yaw: state.yaw + radiansDelta);
  }

  void glideToTarget(
    Vector3D target, {
    double? distance,
    double? zoom,
    double? yaw,
    double? pitch,
  }) {
    state = state.copyWith(
      target: target,
      distance: distance ?? state.distance,
      zoom: zoom ?? state.zoom,
      yaw: yaw ?? state.yaw,
      pitch: pitch ?? state.pitch,
    );
  }

  void resetOverview() {
    state = const BiomeCameraState();
  }
}
