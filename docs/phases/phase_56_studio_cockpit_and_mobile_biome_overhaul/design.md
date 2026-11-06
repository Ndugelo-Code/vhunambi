# Phase 56: Studio Cockpit Compaction, Ergonomic Station Unification & Mobile-First 3D Mycelium Biome Overhaul — Technical Design & Implementation Specification

**Phase Identifier**: `PHASE-56`
**Architecture Standard**: All-Gemini 4-Stage Spec-Driven Pipeline (Stage 2 Draft + Stage 3 Argon Codebase Forensic Hardening)
**Target Package**: `apps/vhunambi_client`
**Physical Device Reference**: `C:\Users\Ndugelo\Downloads\SVID_20261106_132743_1.mp4` (`360dp × 780dp`, Huawei `JNY-LX1` / `EPHUT20917014649`)
**Status**: **STAGE 3 ARGON-HARDENED — READY FOR FLASH 3.8 EXECUTION**

---

## 1. Mathematical & Ergonomic Foundations

### 1.1 Right-Handed 3D Y-Up World Space & Cubic Hermite Dolly-Zoom Interpolation
The 3D Mycelium Biome operates strictly in Right-Handed 3D Y-Up World Space:
- **$X$-axis**: Horizontal right ($+X$) / left ($-X$).
- **$Y$-axis**: Vertical elevation ($+Y = h(X, Z) \ge 0$ rises upward toward mushroom cap apexes).
- **$Z$-axis**: Depth ($+Z$ foreground closer to camera, $-Z$ background).

To eliminate the flat 2D horizontal panning bug observed at `03:35–03:56` in `SVID_20261106_132743_1.mp4`, all camera actions (`+`, `-`, `↻`, 1-finger orbit drag, 2-finger pinch-zoom, auto-rotate tick, and cluster focus dive) mutate `BiomeCameraState` inside `BiomeCameraNotifier` (`biomeCameraProvider`).

When the user taps a mushroom cap badge (`Key('biome_cluster_badge_${domain.name}')`) or 3D canvas projection, `_SongDnaNodeTreeModalState` drives a 450ms `AnimationController` (`_cameraDollyController`) with a cubic Hermite easing curve $u(t) = 1 - (1 - t)^3$ (`Curves.easeOutCubic`), interpolating between the starting camera state $\mathbf{C}_0 = (\mathbf{T}_0, \theta_0, \phi_0, R_0, Z_0)$ and the focused mushroom's 3D locus $\mathbf{C}_1 = (\mathbf{T}_1, \theta_1, \phi_1, R_1, Z_1)$:

$$\mathbf{T}(t) = \mathbf{T}_0 + u(t)\left(\mathbf{T}_1 - \mathbf{T}_0\right)$$
$$\theta(t) = \theta_0 + u(t)\left(\theta_1 - \theta_0\right), \quad \phi(t) = \operatorname{clamp}\!\left(\phi_0 + u(t)(\phi_1 - \phi_0),\; \frac{15^\circ \pi}{180^\circ},\; \frac{75^\circ \pi}{180^\circ}\right)$$
$$R(t) = \operatorname{clamp}\!\left(R_0 + u(t)(R_1 - R_0),\; 180.0,\; 650.0\right), \quad Z(t) = \operatorname{clamp}\!\left(Z_0 + u(t)(Z_1 - Z_0),\; 0.65,\; 2.20\right)$$

Where for a tapped mushroom cluster $c$ with cap apex $\mathbf{P}_c = (x_c, y_c, z_c)$:
- $\mathbf{T}_1 = \mathbf{P}_c$
- $\theta_1 = \operatorname{atan2}(x_c, z_c + 0.001) \times 0.28$
- $\phi_1 = 28^\circ \times \frac{\pi}{180^\circ}$
- $R_1 = 220.0$, $Z_1 = 1.25$

### 1.2 Multi-Touch Gesture Decomposition (`onScaleStart` / `onScaleUpdate`)
Replacing `onPanUpdate` with `onScaleStart` and `onScaleUpdate` on the 3D canvas `GestureDetector` supports simultaneous 1-finger spherical orbit and 2-finger pinch-to-zoom:
- **1-Finger Orbit (`details.pointerCount <= 1`)**:
  $$\Delta\theta = \Delta x_{\text{focal}} \times 0.0075, \quad \Delta\phi = \Delta y_{\text{focal}} \times 0.0075$$
- **2-Finger Pinch-Zoom (`details.pointerCount >= 2`)**:
  $$Z_{\text{new}} = \operatorname{clamp}\!\left(Z_{\text{base}} \times s_{\text{scale}},\; 0.65,\; 2.20\right), \quad R_{\text{new}} = \operatorname{clamp}\!\left(\frac{R_{\text{base}}}{s_{\text{scale}}^{0.65}},\; 180.0,\; 650.0\right)$$

### 1.3 Mobile Viewport Clearance & Compaction Equations
On a `360dp × 780dp` mobile portrait screen:
1. **Compose Above-the-Fold Equation**:
   $$Y_{\text{prompt}} = H_{\text{header}}(48) + H_{\text{tabs}}(40) + H_{\text{progress}}(36) + H_{\text{margins}}(24) = 148\text{dp} \ll 260\text{dp}$$
   This guarantees `PromptInputBox` (`"Describe your song"`) and `ReferenceAudioDropzone` (`"Reference Audio (optional)"`) are 100% visible immediately on screen load (`0.0s` scroll time).
2. **2×3 Stem-Lock Grid Width Equation**:
   $$W_{\text{card}} = \frac{W_{\text{rack}} - 8\text{dp}}{2} \quad (\forall W_{\text{rack}} \ge 300\text{dp})$$
3. **3-Column Wrap Chip Width Equation**:
   Each Language, Mood, and Song Structure chip uses compact padding (`horizontal: 10, vertical: 6`, `minHeight: 36dp`), allowing 3 chips per row across a `328dp` inner mobile container (`~68%` vertical scroll reduction).
4. **3D Biome Mobile Canvas Unobstructed Ratio**:
   On mobile (`constraints.maxWidth < 680`), hiding `BiomeInteractiveControlsBar` and `BiomeNetworkLayersFilter` behind top-bar popover pills (`Key('biome_controls_popover_btn')` and `Key('biome_layers_popover_btn')`) and removing legacy overview pills leaves:
   $$\text{Clearance Ratio} = \frac{780 - (54_{\text{topBar}} + 38_{\text{popoverStrip}} + 42_{\text{timeline}} + 62_{\text{ctaDock}})}{780} = \frac{584}{780} = 74.9\% \ge 70\%$$

### 1.4 Dual-Model Execution Partitioning Matrix (`Gemini 3.8 Flash` vs. `Gemini 4 Argon`)
To maximize velocity and guarantee zero architectural regression across the 2D Studio Cockpit and 3D Mycelium Biome, implementation is partitioned into two strictly bounded waves:

| Execution Wave | Assigned Agent | Design Sections & Target Files | Engineering Rationale |
| :--- | :--- | :--- | :--- |
| **Wave 1 (Tracks 1, 2, 3, 4 & §9.1)** | **`[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`** *(Suitable for a workhorse agent for quick generation advantage)* | **§3.1–§3.3**: `studio_form_provider.dart`, `studio_action_bar.dart`, `generation_pipeline_card.dart`<br>**§4.1–§4.4**: `progress_tracker.dart`, `cockpit_quantum_entanglement_rack.dart`, `reference_audio_dropzone.dart`, `studio_view.dart`<br>**§5.1–§5.2**: `multilingual_language_selector.dart`, `advanced_options_accordion.dart`<br>**§6.1**: `bantu_voice_deck.dart`<br>**§7.1–§7.2**: `crate_browser_deck.dart`, `inline_crate_mpc_workbench.dart`<br>**§8.1–§8.3**: `lyrics_review_modal.dart`, `mini_player_host.dart`, `melody_sketchpad_modal.dart`<br>**§9.1**: `biome_top_bar.dart` | Self-contained 2D widget compactions, `Wrap` chip grids, `ConstrainedBox` / `Flexible` ellipsis crash fixes, regex bracket stripping, and boolean provider guards where Flash 3.8 excels at high-speed, deterministic code replacement. |
| **Wave 2 (Track 5 Core 3D & Verification)** | **`[FOR GEMINI 4 ARGON — PRINCIPAL ARCHITECT]`** *(Complexity and advanced software engineering)* | **§2.1**: `biome_camera_controller.dart`<br>**§9.2**: `song_dna_node_tree_modal.dart` (1,323-line 3D Sovereign Biome Modal)<br>**§10.1**: `phase56_studio_cockpit_and_mobile_biome_overhaul_test.dart` + Full Regression Suite + APK Deployment | Requires 3D cubic Hermite spherical camera interpolation (`BiomeCameraState.lerp`), multi-touch `onScaleUpdate` gesture decomposition (simultaneous 1-finger 3D orbit + 2-finger pinch dolly-zoom), `TickerProviderStateMixin` 60 FPS auto-rotate stepping, `Offstage` popover orchestration, translucent hit-box preservation for Phase 51/52 tests, and cross-suite verification. |

---

## 2. Track 5A `[FOR GEMINI 4 ARGON — COMPLEXITY & ADVANCED SOFTWARE ENGINEERING]`: 3D Camera Controller & Interpolator (`biome_camera_controller.dart`)

### 2.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/controllers/biome_camera_controller.dart`
Upgrade `BiomeCameraState` with `BiomeCameraState.lerp(...)` and upgrade `BiomeCameraNotifier` with `zoomInStep()`, `zoomOutStep()`, `stepAutoRotate(double radiansDelta)`, and `setCameraState(BiomeCameraState next)`.

```dart
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
```

---

## 3. Track 4A `[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`: Non-Blocking Generation Lifecycle & `StudioFormNotifier` Guard

### 3.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`
Add `cancelLyricsReview()` to `StudioFormNotifier` so that dismissing `LyricsReviewModal` without tapping `"Approve & Generate"` returns `StudioFormState.phase` from `GenerationPhase.reviewingLyrics` to `GenerationPhase.idle` (preventing the stuck grey `"Result"` skeleton card seen at `02:04–02:48` in `SVID_20261106_132743_1.mp4`).

In `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`, add `cancelLyricsReview()` right below `openLyricsReview()`:

```dart
  /// Opens the Phase 38 Lyrics Review & Section Editor gate prior to generation.
  void openLyricsReview() {
    state = state.copyWith(phase: GenerationPhase.reviewingLyrics);
  }

  /// Cancels an unapproved Lyrics Review session and restores idle state (REQ-P56-PIPE-01)
  /// so the Studio viewport never renders a stuck empty Result skeleton card.
  void cancelLyricsReview() {
    if (state.phase == GenerationPhase.reviewingLyrics) {
      state = state.copyWith(phase: GenerationPhase.idle);
    }
  }
```

### 3.2 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart`
In `StudioActionBar._handleGenerateTap`, await `LyricsReviewModal.show(context)` and invoke `cancelLyricsReview()` if the modal closes while `ref.read(studioFormProvider).phase == GenerationPhase.reviewingLyrics`:

```dart
  Future<void> _handleGenerateTap(
    BuildContext context,
    WidgetRef ref,
    StudioFormState formState,
  ) async {
    final notifier = ref.read(studioFormProvider.notifier);

    // Vocal tracks open the Lyrics Review & Section Editor gate first
    if (!formState.isInstrumental) {
      notifier.openLyricsReview();
      await LyricsReviewModal.show(context);
      if (context.mounted &&
          ref.read(studioFormProvider).phase ==
              GenerationPhase.reviewingLyrics) {
        notifier.cancelLyricsReview();
      }
      return;
    }

    // Instrumental tracks bypass lyrics review and synthesize immediately
    notifier.triggerGeneration();
    ref
        .read(generationProgressProvider.notifier)
        .submitAndStartGeneration(
          trackTitle: formState.prompt.isNotEmpty
              ? formState.prompt
              : '${formState.genre} Instrumental',
          genre: formState.genre.isNotEmpty ? formState.genre : 'Amapiano',
          language: 'Instrumental',
          lyrics: '',
          isInstrumental: true,
        );
  }
```

### 3.3 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart`
Update `GenerationPipelineCard` so that:
1. Header `"New song"` button has `key: const Key('generation_pipeline_dismiss_btn')` and always shows when `onNewSong != null` (even during skeleton/queued state) so the user can dismiss or reset at any time.

In `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart` (lines 72–91), replace the header `Row` with:

```dart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Result',
                    style: AppTypography.titleSmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (widget.onNewSong != null)
                    TextButton.icon(
                      key: const Key('generation_pipeline_dismiss_btn'),
                      onPressed: widget.onNewSong,
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.arrowCounterClockwise,
                        size: 16,
                      ),
                      label: const Text('New song'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        textStyle: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
```

---

## 4. Track 1 & Track 2A `[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`: Prompt-First `StudioView`, Compact Header & Collapsible 2×3 Stem Rack

### 4.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/progress_tracker.dart`
Compact `ProgressTrackerWidget` into a sleek `36dp` single-line pill strip (`padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)`) so it combines cleanly with `SongDnaHoverPill` without redundant vertical height.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/glassmorphism.dart';
import '../providers/studio_form_provider.dart';
import 'song_dna_hover_pill.dart';

class ProgressTrackerWidget extends ConsumerWidget {
  final VoidCallback? onOpen3dTree;

  const ProgressTrackerWidget({super.key, this.onOpen3dTree});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedSteps = ref.watch(studioCompletedStepsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalSteps = 9;
    final progress = (completedSteps / totalSteps).clamp(0.0, 1.0);

    return GlassmorphicContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      backgroundColor: isDark
          ? AppColors.darkSurfaceElevated.withValues(alpha: 0.55)
          : AppColors.lightSurfaceElevated.withValues(alpha: 0.75),
      child: Row(
        children: [
          PhosphorIcon(
            completedSteps == totalSteps
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsRegular.SlidersHorizontal,
            color: completedSteps == totalSteps
                ? AppColors.success
                : AppColors.brandPrimary,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedSteps == totalSteps
                      ? AppColors.success
                      : AppColors.brandPrimary,
                ),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$completedSteps/$totalSteps',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          SongDnaHoverPill(onTap: onOpen3dTree),
        ],
      ),
    );
  }
}
```

### 4.2 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart`
Refactor `CockpitQuantumEntanglementRack` so that:
1. It renders a compact header bar with a collapse/expand button `Key('cockpit_rack_collapse_toggle_btn')` and a `"3D Biome"` button.
2. When expanded (`_isExpanded == true`, default `true` so all 6 `Key('cockpit_domain_card_${domain.name}')`, `Key('cockpit_stem_lock_${domain.name}')`, and `Key('cockpit_jump_3d_${domain.name}')` remain mounted for Phase 54 tests), it ALWAYS uses a **2-column × 3-row compact grid** on any screen width $\ge 300\text{dp}$ (`cardWidth = (constraints.maxWidth - 8) / 2`), reducing each card's height to `~70dp` and cutting total rack height from `564dp` down to `~258dp`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/mycelium_biome_provider.dart';
import '../providers/song_dna_graph_provider.dart';

/// Phase 54 + Phase 56: Bidirectional 2D <-> 3D Quantum Stem Authority Rack.
/// Renders a compact, collapsible 2x3 grid of the 6 Mycelium Cluster Domains
/// so mobile viewports never suffer from 6 full-width stacked cards.
class CockpitQuantumEntanglementRack extends ConsumerStatefulWidget {
  final ValueChanged<MyceliumClusterDomain> onJumpTo3DCluster;

  const CockpitQuantumEntanglementRack({
    super.key = const Key('cockpit_quantum_entanglement_rack'),
    required this.onJumpTo3DCluster,
  });

  @override
  ConsumerState<CockpitQuantumEntanglementRack> createState() =>
      _CockpitQuantumEntanglementRackState();
}

class _CockpitQuantumEntanglementRackState
    extends ConsumerState<CockpitQuantumEntanglementRack> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final biomeGraph = ref.watch(myceliumBiomeGraphProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockedCount = biomeGraph.clusters.values
        .where((c) => c.stemLockMode == StemLockMode.lockedPure44k)
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.72)
            : AppColors.lightSurfaceElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const PhosphorIcon(
                  PhosphorIconsBold.atom,
                  size: 13,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  key: const Key('cockpit_rack_collapse_toggle_btn'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isExpanded = !_isExpanded);
                  },
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '2D <-> 3D Quantum Stem Authority',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$lockedCount Locked',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        _isExpanded
                            ? PhosphorIconsBold.caretUp
                            : PhosphorIconsBold.caretDown,
                        size: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 280;
                final cardWidth = isTwoCol
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final domain in MyceliumClusterDomain.values)
                      _buildDomainAuthorityTile(
                        context,
                        ref,
                        cluster: biomeGraph.clusters[domain]!,
                        width: cardWidth,
                        isDark: isDark,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDomainAuthorityTile(
    BuildContext context,
    WidgetRef ref, {
    required MushroomFruitingBody cluster,
    required double width,
    required bool isDark,
  }) {
    final domain = cluster.domain;
    final domainColor = Color(domain.hexColor);
    final mode = cluster.stemLockMode;

    return Container(
      key: Key('cockpit_domain_card_${domain.name}'),
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1422).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: domainColor.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: domainColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  domain.displayName,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(cluster.confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: domainColor,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                key: Key('cockpit_jump_3d_${domain.name}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onJumpTo3DCluster(domain);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: domainColor.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.cubeFocus,
                        size: 10,
                        color: domainColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '3D',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: domainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.lockedPure44k,
                currentMode: mode,
                label: 'Lock',
                activeColor: const Color(0xFFFFB703),
              ),
              const SizedBox(width: 3),
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.harmonicInpaint,
                currentMode: mode,
                label: 'Inpaint',
                activeColor: const Color(0xFF00F5D4),
              ),
              const SizedBox(width: 3),
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.elasticResynth,
                currentMode: mode,
                label: 'Resynth',
                activeColor: const Color(0xFFD946EF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroModeChip({
    required WidgetRef ref,
    required MyceliumClusterDomain domain,
    required StemLockMode targetMode,
    required StemLockMode currentMode,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = currentMode == targetMode;
    return Expanded(
      child: GestureDetector(
        key: Key('cockpit_stem_lock_${domain.name}_${targetMode.name}'),
        onTap: () {
          HapticFeedback.selectionClick();
          ref
              .read(songDnaGraphProvider.notifier)
              .setStemLockMode(domain.legacyBranchRootId, targetMode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white12,
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? activeColor : Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
```

### 4.3 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/reference_audio_dropzone.dart`
Eliminate the `"Refer..."` truncation (`00:22`) and giant desktop drag-and-drop box (`00:44`) by rendering a two-row compact Reference Strip:
- **Row 1**: Full-width header with icon + `'Reference Audio (optional)'` (`maxLines: 1`, zero truncation) + expand toggle chevron.
- **Row 2**: Compact 3-pill horizontal action strip:
  - `Key('dropzone_upload_audio_btn')` (`+ Upload Audio`)
  - `Key('dropzone_load_licensed_beat_btn')` (`My Beats`)
  - `Key('dropzone_open_sketchpad_btn')` (`5-Ch Sketchpad`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../marketplace/presentation/providers/beat_marketplace_providers.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

class ReferenceAudioDropzone extends ConsumerStatefulWidget {
  const ReferenceAudioDropzone({super.key});

  @override
  ConsumerState<ReferenceAudioDropzone> createState() =>
      _ReferenceAudioDropzoneState();
}

class _ReferenceAudioDropzoneState
    extends ConsumerState<ReferenceAudioDropzone> {
  bool _isExpanded = false;

  void _openPurchasedBeatsPicker(BuildContext context, bool isDark) {
    final vault = ref.read(purchasedVaultProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsFill.disc,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Load Licensed Beat from Vault',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select an acquired beat or stem pack to guide your Studio generation.',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (vault.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No licensed beats in your vault yet.',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  )
                else
                  ...vault.map(
                    (beat) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.musicNotes,
                          color: AppColors.brandPrimary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        beat.title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${beat.producerName} • ${beat.bpm} BPM • ${beat.musicalKey} • ${beat.tier.label}',
                        style: AppTypography.caption,
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          ref
                              .read(studioFormProvider.notifier)
                              .setReferenceAudio(
                                '${beat.title} (${beat.bpm} BPM • ${beat.musicalKey}) [${beat.tier.label}]',
                              );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Use Beat'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final refAudioPath = ref.watch(
      studioFormProvider.select((s) => s.referenceAudioPath),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFile = refAudioPath != null && refAudioPath.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5)
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile
              ? AppColors.brandPrimary.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Full-width Header (Zero truncation of 'Reference Audio (optional)')
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                PhosphorIcon(
                  hasFile
                      ? PhosphorIconsFill.fileAudio
                      : PhosphorIconsRegular.waveform,
                  size: 16,
                  color: hasFile
                      ? AppColors.brandPrimary
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasFile ? refAudioPath : 'Reference Audio (optional)',
                    style: AppTypography.bodySmall.copyWith(
                      color: hasFile
                          ? AppColors.brandPrimary
                          : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasFile)
                  IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.error,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(studioFormProvider.notifier)
                          .setReferenceAudio(null);
                    },
                  )
                else
                  PhosphorIcon(
                    _isExpanded
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
                    size: 15,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Compact 3-Pill Quick Action Strip (Always visible, zero desktop box bloat)
          Row(
            children: [
              Expanded(
                child: _buildQuickActionPill(
                  key: const Key('dropzone_upload_audio_btn'),
                  icon: PhosphorIconsBold.uploadSimple,
                  label: hasFile ? 'Swap Audio' : '+ Upload Audio',
                  accentColor: AppColors.brandPrimary,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(studioFormProvider.notifier)
                        .setReferenceAudio(
                          hasFile ? null : 'amapiano_logdrum_ref_01.wav',
                        );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionPill(
                  key: const Key('dropzone_load_licensed_beat_btn'),
                  icon: PhosphorIconsFill.disc,
                  label: 'My Beats',
                  accentColor: AppColors.brandPrimary,
                  isDark: isDark,
                  onTap: () => _openPurchasedBeatsPicker(context, isDark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionPill(
                  key: const Key('dropzone_open_sketchpad_btn'),
                  icon: PhosphorIconsRegular.pianoKeys,
                  label: 'Sketchpad',
                  accentColor: AppColors.brandSecondary,
                  isDark: isDark,
                  onTap: () {
                    MelodySketchpadModal.show(
                      context,
                      onMelodyExported: (summary) {
                        ref
                            .read(studioFormProvider.notifier)
                            .setReferenceAudio(summary);
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(studioFormProvider.notifier)
                    .setReferenceAudio(
                      hasFile ? null : 'amapiano_logdrum_ref_01.wav',
                    );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground.withValues(alpha: 0.45)
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFile
                        ? AppColors.brandPrimary
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(
                      hasFile
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.cloudArrowUp,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasFile
                            ? 'Attached: $refAudioPath (Tap to clear)'
                            : 'Tap to attach reference WAV/MP3 stem (Max 10MB)',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionPill({
    required Key key,
    required IconData icon,
    required String label,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 12, color: accentColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4.4 File Target: `apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`
Refactor `StudioView` so that:
1. `PromptInputBox` (`"Describe your song"`) and `ReferenceAudioDropzone` (`"Reference Audio (optional)"`) are mounted **above** `CockpitQuantumEntanglementRack` inside `_buildComposeTab` (`REQ-P56-COMP-01`), guaranteeing `"Describe your song"` is immediately visible on screen load (`0.0s`) and keeping `PromptInputBox`'s `TextField` as `find.byType(TextField).first` for `studio_view_test.dart`.
2. `GenerationPipelineCard` is ONLY mounted on Tab 0 (`Compose`) when `generationProgress != null` OR `phase == GenerationPhase.generating` OR `phase == GenerationPhase.postProcessing` OR `phase == GenerationPhase.completed` (`REQ-P56-PIPE-01..02`), and its `onNewSong` resets both `studioFormProvider` and `generationProgressProvider`.
3. Duplicate bottom buttons (`studio_daw_uploader_btn` and `studio_open_crate_btn`) are removed from `_buildCrateAndMpcTab` because they are now integrated into `InlineCrateMpcWorkbench` (`REQ-P56-CRATE-02`).

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/studio_form_provider.dart';
import '../widgets/advanced_options_accordion.dart';
import '../widgets/bantu_voice_deck.dart';
import '../widgets/cockpit_quantum_entanglement_rack.dart';
import '../widgets/genre_selector_grid.dart';
import '../widgets/inline_crate_mpc_workbench.dart';
import '../widgets/lyrics_section.dart';
import '../widgets/multilingual_language_selector.dart';
import '../widgets/progress_tracker.dart';
import '../widgets/prompt_input_box.dart';
import '../widgets/reference_audio_dropzone.dart';
import '../widgets/studio_action_bar.dart';
import '../widgets/song_dna_node_tree_modal.dart';
import '../widgets/generation_pipeline_card.dart';

class StudioView extends ConsumerStatefulWidget {
  const StudioView({super.key});

  @override
  ConsumerState<StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends ConsumerState<StudioView> {
  void _open3dDnaModal([MyceliumClusterDomain? initialDomain]) {
    SongDnaNodeTreeModal.show(context, initialFocusedDomain: initialDomain);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phase = ref.watch(studioFormProvider.select((s) => s.phase));
    final generationProgress = ref.watch(generationProgressProvider);
    final activeTab = ref.watch(studioCockpitTabProvider);

    final isPipelineVisible =
        generationProgress != null ||
        phase == GenerationPhase.generating ||
        phase == GenerationPhase.postProcessing ||
        phase == GenerationPhase.completed;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Compact Top Bar + Segmented 3-Station Cockpit Switcher
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, isDark),
                      const SizedBox(height: 6),
                      ProgressTrackerWidget(onOpen3dTree: _open3dDnaModal),
                      const SizedBox(height: 8),
                      _buildCockpitTabSwitcher(activeTab, isDark),
                    ],
                  ),
                ),

                // Active Station Viewport
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 6.0,
                      bottom: ResponsiveBreakpoints.of(context).isMobile
                          ? 148.0
                          : 96.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (activeTab == StudioCockpitTab.compose &&
                                isPipelineVisible) ...[
                              GenerationPipelineCard(
                                onNewSong: () {
                                  ref
                                      .read(
                                        generationProgressProvider.notifier,
                                      )
                                      .reset();
                                  ref
                                      .read(studioFormProvider.notifier)
                                      .resetForm();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (activeTab == StudioCockpitTab.compose)
                              _buildComposeTab(context, isDark)
                            else if (activeTab ==
                                StudioCockpitTab.voiceAndLyrics)
                              _buildVoiceAndLyricsTab(context, isDark)
                            else
                              _buildCrateAndMpcTab(context, isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Pinned Bottom Action Bar
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StudioActionBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// Station 1: Compose — Prompt First, Quick Reference Strip, Genre, Language, Compact 2x3 Stem Rack
  Widget _buildComposeTab(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PromptInputBox(),
        const SizedBox(height: 10),
        const ReferenceAudioDropzone(),
        const SizedBox(height: 12),
        CockpitQuantumEntanglementRack(
          onJumpTo3DCluster: (domain) => _open3dDnaModal(domain),
        ),
        const SizedBox(height: 14),
        const GenreSelectorGrid(),
        const SizedBox(height: 14),
        const MultilingualLanguageSelector(),
        const SizedBox(height: 14),
        const AdvancedOptionsAccordion(),
      ],
    );
  }

  /// Station 2: Voice & Bantu Lyrics — Consolidated Ensemble/Gender/Energy + Vocal LoRA + 2x2 Inflections + Lyrics
  Widget _buildVoiceAndLyricsTab(BuildContext context, bool isDark) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BantuVoiceDeck(),
        SizedBox(height: 16),
        LyricsSection(),
      ],
    );
  }

  /// Station 3: Crate & MPC — Unified 4-Mode Groove, Sample & DAW Stem Workbench (Zero Duplicate Bottom Buttons)
  Widget _buildCrateAndMpcTab(BuildContext context, bool isDark) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineCrateMpcWorkbench(),
      ],
    );
  }

  Widget _buildCockpitTabSwitcher(StudioCockpitTab activeTab, bool isDark) {
    return Container(
      key: const Key('studio_cockpit_tab_bar'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _buildTabPill(
            key: const Key('studio_tab_compose'),
            tab: StudioCockpitTab.compose,
            activeTab: activeTab,
            icon: PhosphorIconsBold.slidersHorizontal,
            label: 'Compose',
            isDark: isDark,
          ),
          _buildTabPill(
            key: const Key('studio_tab_voice'),
            tab: StudioCockpitTab.voiceAndLyrics,
            activeTab: activeTab,
            icon: PhosphorIconsBold.microphoneStage,
            label: 'Voice',
            isDark: isDark,
          ),
          _buildTabPill(
            key: const Key('studio_tab_crate_mpc'),
            tab: StudioCockpitTab.crateAndMpc,
            activeTab: activeTab,
            icon: PhosphorIconsBold.pianoKeys,
            label: 'Crate & MPC',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required Key key,
    required StudioCockpitTab tab,
    required StudioCockpitTab activeTab,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = tab == activeTab;
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(studioCockpitTabProvider.notifier).state = tab;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const PhosphorIcon(
                  PhosphorIconsFill.musicNotesPlus,
                  color: AppColors.brandPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'AI Studio',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              key: const Key('studio_header_3d_dna_btn'),
              onPressed: () => _open3dDnaModal(),
              icon: const PhosphorIcon(
                PhosphorIconsBold.planet,
                size: 14,
                color: Color(0xFF00F5D4),
              ),
              label: Text(
                '3D Biome',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFF00F5D4),
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF00F5D4).withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFF00F5D4).withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () {
                ref.read(generationProgressProvider.notifier).reset();
                ref.read(studioFormProvider.notifier).resetForm();
              },
              icon: PhosphorIcon(
                PhosphorIconsRegular.arrowCounterClockwise,
                size: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              label: Text(
                'Reset',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## 5. Track 2B: Compact Multi-Column Wrap Chips (`MultilingualLanguageSelector` & `AdvancedOptionsAccordion`)

### 5.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/multilingual_language_selector.dart`
Replace the `minHeight: 48` full-width language blocks (`00:50–01:02`) with compact 3-column `Wrap` chips (`padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`, `minHeight: 34`) while preserving every language label (`Tshivenda`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, etc.) and the `Code-Switch` toggle.

In `apps/vhunambi_client/lib/features/studio/presentation/widgets/multilingual_language_selector.dart` (lines 204–264), replace `_LanguageChip.build` with:

```dart
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label language option',
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withValues(alpha: 0.16)
                  : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurfaceElevated),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.brandPrimary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPrimary) ...[
                  const PhosphorIcon(
                    PhosphorIconsFill.star,
                    size: 11,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                ] else if (isSelected) ...[
                  const PhosphorIcon(
                    PhosphorIconsBold.check,
                    size: 11,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

### 5.2 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/advanced_options_accordion.dart`
Compact `AdvancedOptionsAccordion` so that:
1. Mood (`10` options) and Song Structure (`4` options) render as compact multi-column `Wrap` chips (`spacing: 6, runSpacing: 6`, `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`) instead of full-width 52dp bars (`01:11–01:26`).
2. Because Vocal Ensemble (`Solo/Duet/Choir`), Vocal Gender (`Male/Female/Mixed`), and Vocal Energy (`Soft/Mid/Intense`) now live at the top of the `Voice` station (`BantuVoiceDeck`), `AdvancedOptionsAccordion` replaces the redundant 3-block vocal stack with a sleek shortcut pill (`Key('advanced_jump_to_voice_station_btn')`) that jumps straight to Tab 1 (`Voice`) while keeping `Tempo`, `Mood`, `Era`, and `Song Structure` in `Compose`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';

class AdvancedOptionsAccordion extends ConsumerStatefulWidget {
  const AdvancedOptionsAccordion({super.key});

  @override
  ConsumerState<AdvancedOptionsAccordion> createState() =>
      _AdvancedOptionsAccordionState();
}

class _AdvancedOptionsAccordionState
    extends ConsumerState<AdvancedOptionsAccordion> {
  bool _isExpanded = false;

  static const List<String> _moods = [
    'Uplifting',
    'Spiritual',
    'Chill',
    'Party',
    'Romantic',
    'Melancholic',
    'Aggressive',
    'Nostalgic',
    'Triumphant',
    'Dark',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.4)
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.faders,
                        color: AppColors.brandPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Advanced Options',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.mood.isEmpty ? "Mood" : state.mood} • ${state.tempo.label.split(" ").first}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PhosphorIcon(
                        _isExpanded
                            ? PhosphorIconsRegular.caretUp
                            : PhosphorIconsRegular.caretDown,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 16),

                  // 1. Mood (Compact 3-Column Wrap Chips — REQ-P56-COMP-03)
                  _buildSectionTitle('Mood', isDark),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _moods.map((m) {
                      final isSelected = state.mood == m;
                      return _buildCompactWrapChip(
                        label: m,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => notifier.selectMood(m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 2. Tempo (Compact 4-Segment Row)
                  _buildSectionTitle('Tempo', isDark),
                  const SizedBox(height: 6),
                  _buildSegmentedRow<TempoBracket>(
                    items: TempoBracket.values,
                    selected: state.tempo,
                    labelBuilder: (t) => t.label,
                    onSelect: notifier.setTempo,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // 3. Era / Production Style
                  _buildSectionTitle('Era / Production Style', isDark),
                  const SizedBox(height: 6),
                  _buildSegmentedRow<ProductionEra>(
                    items: ProductionEra.values,
                    selected: state.era,
                    labelBuilder: (e) => e.label,
                    onSelect: notifier.setEra,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // 4. Song Structure (Compact 2x2 / 4-Chip Wrap — REQ-P56-COMP-03)
                  _buildSectionTitle('Song Structure', isDark),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SongStructureType.values.map((s) {
                      final isSelected = state.structure == s;
                      return _buildCompactWrapChip(
                        label: s.label,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => notifier.setStructure(s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 5. Shortcut Pill to Voice Station (Vocal Ensemble/Gender/Energy unified in Tab 1)
                  InkWell(
                    key: const Key('advanced_jump_to_voice_station_btn'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(studioCockpitTabProvider.notifier).state =
                          StudioCockpitTab.voiceAndLyrics;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsBold.microphoneStage,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Voice Config: ${state.vocalConfiguration.label} • ${state.vocalGender.label} • ${state.vocalIntensity.label}',
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Edit in Voice →',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: AppTypography.caption.copyWith(
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCompactWrapChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedRow<T>({
    required List<T> items,
    required T selected,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelect,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        final isSelected = item == selected;
        return _buildCompactWrapChip(
          label: labelBuilder(item),
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => onSelect(item),
        );
      }).toList(),
    );
  }
}
```

---

## 6. Track 3A: Voice Station Unification & 2×2 Dialect Grid (`bantu_voice_deck.dart`)

### 6.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/bantu_voice_deck.dart`
Unify all vocal parameters inside `BantuVoiceDeck` (Tab 1: `Voice`):
1. Mount `Key('voice_ensemble_header_card')` at the very top of `BantuVoiceDeck` with 3 compact segmented rows for:
   - `Voices`: `Solo` / `Duet` / `Choir` (`VocalConfiguration.values`)
   - `Gender`: `Male` / `Female` / `Mixed` (`VocalGender.values`)
   - `Energy`: `Soft` / `Mid` / `Intense` (`VocalIntensity.values`)
2. Compact the 4 Bantu dialect inflection sliders (`Syllable Stretch`, `Ancestral Vibrato`, `Call-and-Response`, `Cultural Ad-Libs`) into a 2×2 grid card `Key('voice_dialect_grid_card')` while preserving all 4 slider widget keys (`Key('dialect_slider_syllable_stretch')`, `Key('dialect_slider_vibrato')`, `Key('dialect_slider_call_response')`, `Key('dialect_slider_ad_libs')`).

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../voice_lab/domain/models/vocal_lora_models.dart';
import '../../../voice_lab/presentation/providers/vocal_lora_providers.dart';
import '../../../voice_lab/presentation/views/vocal_lora_lab_modal.dart';
import '../../domain/models/bantu_voice_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/bantu_voice_providers.dart';
import '../providers/studio_form_provider.dart';

class BantuVoiceDeck extends ConsumerWidget {
  const BantuVoiceDeck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personas = ref.watch(bantuVoicePersonasProvider);
    final selectedPersona = ref.watch(selectedVoicePersonaProvider);
    final inflections = ref.watch(dialectInflectionProvider);
    final loraVault = ref.watch(vocalLoraProvider);
    final activeLora = loraVault.activeStudioModel;
    final formState = ref.watch(studioFormProvider);
    final formNotifier = ref.read(studioFormProvider.notifier);

    return Container(
      key: const Key('bantu_voice_deck'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsFill.microphoneStage,
                  color: AppColors.brandPrimary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bantu Voice & Dialect Deck',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Ensemble configuration, sovereign vocal identity & dialect inflections',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selectedPersona != null)
                TextButton.icon(
                  onPressed: () {
                    ref.read(selectedVoicePersonaIdProvider.notifier).state =
                        null;
                    ref.read(dialectInflectionProvider.notifier).reset();
                  },
                  icon: const Icon(
                    PhosphorIconsRegular.arrowCounterClockwise,
                    size: 13,
                  ),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Unified Vocal Ensemble, Gender & Energy Segmented Header Card (REQ-P56-VOICE-01)
          Container(
            key: const Key('voice_ensemble_header_card'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.55)
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                _buildCompactSegmentRow<VocalConfiguration>(
                  label: 'Voices',
                  items: VocalConfiguration.values,
                  selected: formState.vocalConfiguration,
                  labelBuilder: (v) => v.label,
                  keyPrefix: 'voice_config',
                  onSelect: formNotifier.setVocalConfiguration,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildCompactSegmentRow<VocalGender>(
                  label: 'Gender',
                  items: VocalGender.values,
                  selected: formState.vocalGender,
                  labelBuilder: (g) => g.label,
                  keyPrefix: 'voice_gender',
                  onSelect: formNotifier.setVocalGender,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildCompactSegmentRow<VocalIntensity>(
                  label: 'Energy',
                  items: VocalIntensity.values,
                  selected: formState.vocalIntensity,
                  labelBuilder: (e) => e.label,
                  keyPrefix: 'voice_energy',
                  onSelect: formNotifier.setVocalIntensity,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Phase 40: Custom Trained Vocal LoRA Selector Banner
          _VocalLoraSelectorBanner(
            isDark: isDark,
            models: loraVault.models
                .where((m) => m.status == LoraTrainingStatus.ready)
                .toList(),
            activeModel: activeLora,
            onSelectModel: (id) {
              HapticFeedback.selectionClick();
              ref.read(vocalLoraProvider.notifier).selectModelForStudio(id);
            },
            onOpenLab: () => VocalLoraLabModal.show(context),
          ),
          const SizedBox(height: 12),

          // Horizontal Persona Carousel
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: personas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final persona = personas[index];
                final isSelected = selectedPersona?.id == persona.id;
                return _PersonaCard(
                  persona: persona,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedVoicePersonaIdProvider.notifier).state =
                        persona.id;
                    ref
                        .read(dialectInflectionProvider.notifier)
                        .applyPersonaDefaults(persona);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 2x2 Compact Dialect Inflection Sliders Grid (REQ-P56-VOICE-02)
          Container(
            key: const Key('voice_dialect_grid_card'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.45)
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 260;
                final cellWidth = isTwoCol
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _InflectionSliderTile(
                        sliderKey: const Key('dialect_slider_syllable_stretch'),
                        label: 'Syllable Stretch',
                        value: inflections.syllableStretch,
                        isDark: isDark,
                        onChanged: (v) => ref
                            .read(dialectInflectionProvider.notifier)
                            .setSyllableStretch(v),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _InflectionSliderTile(
                        sliderKey: const Key('dialect_slider_vibrato'),
                        label: 'Ancestral Vibrato',
                        value: inflections.vibratoDepth,
                        isDark: isDark,
                        onChanged: (v) => ref
                            .read(dialectInflectionProvider.notifier)
                            .setVibratoDepth(v),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _InflectionSliderTile(
                        sliderKey: const Key('dialect_slider_call_response'),
                        label: 'Call-and-Response',
                        value: inflections.callAndResponseEnergy,
                        isDark: isDark,
                        onChanged: (v) => ref
                            .read(dialectInflectionProvider.notifier)
                            .setCallAndResponseEnergy(v),
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _InflectionSliderTile(
                        sliderKey: const Key('dialect_slider_ad_libs'),
                        label: 'Cultural Ad-Libs',
                        value: inflections.adLibDensity,
                        isDark: isDark,
                        onChanged: (v) => ref
                            .read(dialectInflectionProvider.notifier)
                            .setAdLibDensity(v),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSegmentRow<T extends Enum>({
    required String label,
    required List<T> items,
    required T selected,
    required String Function(T) labelBuilder,
    required String keyPrefix,
    required ValueChanged<T> onSelect,
    required bool isDark,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    key: Key('${keyPrefix}_${items[i].name}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(items[i]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: items[i] == selected
                            ? AppColors.brandPrimary
                            : (isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: items[i] == selected
                              ? AppColors.brandPrimary
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          labelBuilder(items[i]),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: items[i] == selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: items[i] == selected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
```
*(Preserve `_PersonaCard`, `_InflectionSliderTile`, and `_VocalLoraSelectorBanner` in `bantu_voice_deck.dart`, compacting `_InflectionSliderTile` bottom padding from `8` to `2` so the 2×2 grid is tight and crisp).*

---

## 7. Track 3B: Crate Browser Vertical Text Crash Fix & Unified 4-Mode Workbench

### 7.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/crate_browser_deck.dart`
Fix the 1-character vertical text crash (`H-e-r-i-t-a-g-e...`) seen at `02:42–02:46` in `SVID_20261106_132743_1.mp4`:
1. Reduce `_VinylDiskWidget` from `84×84` to `52×52` (`width: 52, height: 52`).
2. Add `maxLines: 1, overflow: TextOverflow.ellipsis` on `'Heritage Crate Digging'` and `'Indigenous Sound Archive'` (`maxLines: 1, overflow: TextOverflow.ellipsis`), removing raw `💿` and `🎹` Unicode emojis.
3. Replace the unconstrained `'🎹 Open in Melody Sketchpad'` button with a compact `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 118))` button `Key('crate_open_sketchpad_btn')` labeled `'Sketchpad'` with `PhosphorIconsBold.pianoKeys`.

In `apps/vhunambi_client/lib/features/studio/presentation/widgets/crate_browser_deck.dart` (lines 25–78), replace the top `Padding` header with:

```dart
        // Top Header with Spinning Vinyl & Compact Sketchpad Bridge (REQ-P56-CRATE-01)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              _VinylDiskWidget(
                isSpinning: crateState.isPlayingPreview,
                activeSample: crateState.selectedSample,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Heritage Crate Digging',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Indigenous Sound Archive — Tap to audition & slice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenSketchpad != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 118),
                  child: TextButton.icon(
                    key: const Key('crate_open_sketchpad_btn'),
                    onPressed: onOpenSketchpad,
                    icon: const Icon(
                      PhosphorIconsBold.pianoKeys,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    label: Text(
                      'Sketchpad',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary.withValues(
                        alpha: 0.14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.brandPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
```
And in `_VinylDiskWidget.build` (lines 255–257 of `crate_browser_deck.dart`), change `width: 84, height: 84` to `width: 52, height: 52` (and inner center label `width: 30, height: 30` to `width: 20, height: 20`).

### 7.2 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`
Unify all Crate, MPC, 5-Channel Sketchpad, and DAW/Vocal Stem Upload tools inside `InlineCrateMpcWorkbench`:
1. Add `InlineWorkbenchMode.dawUpload` as the 4th mode (`Key('workbench_mode_daw_upload')`).
2. Shorten the 4 mode pill labels so zero labels truncate on a `360dp` mobile screen:
   - `Crate` (`Key('workbench_mode_crate')`)
   - `8-Pad MPC` (`Key('workbench_mode_mpc')`)
   - `5-Ch Groove` (`Key('workbench_mode_sketchpad')`)
   - `DAW Upload` (`Key('workbench_mode_daw_upload')`)
3. Include a compact full-screen modal launcher icon button `Key('studio_open_crate_btn')` in the workbench header and `Key('studio_daw_uploader_btn')` inside the DAW Upload mode so all existing test keys remain 100% intact without duplicate standalone bottom buttons under the workbench.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../marketplace/presentation/views/direct_daw_upload_modal.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../providers/heritage_crate_providers.dart';
import '../providers/melody_sketchpad_providers.dart';
import '../providers/studio_form_provider.dart';
import '../views/heritage_crate_modal.dart';
import 'melody_sketchpad_modal.dart';
import 'mpc_pad_grid.dart';

enum InlineWorkbenchMode { crate, mpc, sketchpad, dawUpload }

final inlineWorkbenchModeProvider = StateProvider<InlineWorkbenchMode>(
  (ref) => InlineWorkbenchMode.crate,
);
```
Inside `InlineCrateMpcWorkbench.build`, update the header and 4-mode switcher, and add `_InlineDawUploadView`:

```dart
          // Header Row with Full-Screen Crate Slicer Button (Key('studio_open_crate_btn'))
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const PhosphorIcon(
                  PhosphorIconsFill.vinylRecord,
                  color: AppColors.brandPrimary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Groove, Crate & DAW Workbench',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Heritage samples, 8-pad MPC, 5-Ch groove & DAW stem intake',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('studio_open_crate_btn'),
                tooltip: 'Full-Screen Heritage Crate & MPC Slicer',
                visualDensity: VisualDensity.compact,
                icon: const PhosphorIcon(
                  PhosphorIconsBold.arrowsOutSimple,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
                onPressed: () {
                  HeritageCrateModal.show(
                    context,
                    onExportSequenceToStudio: (summary) {
                      ref
                          .read(studioFormProvider.notifier)
                          .setReferenceAudio(summary);
                    },
                    onOpenSketchpad: () {
                      MelodySketchpadModal.show(
                        context,
                        onMelodyExported: (summary) {
                          ref
                              .read(studioFormProvider.notifier)
                              .setReferenceAudio(summary);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unified 4-Pill Mode Switcher (Zero Truncation on 360dp Mobile)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildModeTab(
                  key: const Key('workbench_mode_crate'),
                  label: 'Crate',
                  icon: PhosphorIconsBold.disc,
                  isSelected: activeMode == InlineWorkbenchMode.crate,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(inlineWorkbenchModeProvider.notifier).state =
                          InlineWorkbenchMode.crate,
                ),
                _buildModeTab(
                  key: const Key('workbench_mode_mpc'),
                  label: '8-Pad MPC',
                  icon: PhosphorIconsBold.squaresFour,
                  isSelected: activeMode == InlineWorkbenchMode.mpc,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(inlineWorkbenchModeProvider.notifier).state =
                          InlineWorkbenchMode.mpc,
                ),
                _buildModeTab(
                  key: const Key('workbench_mode_sketchpad'),
                  label: '5-Ch Groove',
                  icon: PhosphorIconsBold.pianoKeys,
                  isSelected: activeMode == InlineWorkbenchMode.sketchpad,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(inlineWorkbenchModeProvider.notifier).state =
                          InlineWorkbenchMode.sketchpad,
                ),
                _buildModeTab(
                  key: const Key('workbench_mode_daw_upload'),
                  label: 'DAW Upload',
                  icon: PhosphorIconsBold.uploadSimple,
                  isSelected: activeMode == InlineWorkbenchMode.dawUpload,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(inlineWorkbenchModeProvider.notifier).state =
                          InlineWorkbenchMode.dawUpload,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (activeMode == InlineWorkbenchMode.crate)
            _InlineCrateSubView(isDark: isDark)
          else if (activeMode == InlineWorkbenchMode.mpc)
            _InlineMpcSubView(isDark: isDark)
          else if (activeMode == InlineWorkbenchMode.sketchpad)
            _InlineSketchpadSubView(isDark: isDark)
          else
            _InlineDawUploadSubView(isDark: isDark),
```
Where `_InlineDawUploadSubView` renders:
```dart
class _InlineDawUploadSubView extends StatelessWidget {
  final bool isDark;
  const _InlineDawUploadSubView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.fileAudio,
                color: AppColors.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct DAW Stem Pack & Vocal Track Uploader',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload WAV/FLAC/MP3 stems or acapellas with 5-stem AI separation and cryptographic provenance.',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('studio_daw_uploader_btn'),
              onPressed: () => DirectDawUploadModal.show(context),
              icon: const PhosphorIcon(PhosphorIconsBold.uploadSimple, size: 15),
              label: const Text('Launch Direct DAW & Vocal Uploader'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 8. Track 4B & 4C: Bracket-Free Cognate Finder & Studio/Modal Mini-Player Suppression

### 8.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/lyrics_review_modal.dart`
1. Increment `modalSheetOpenCountProvider` in `initState` and decrement in `dispose` so `MiniPlayerHost` never floats over `LyricsReviewModal`.
2. In `_openCognateFinder`, strip bracketed headers (`RegExp(r'\[[^\]]*\]')`) and filter structural tags (`{'intro', 'verse', 'chorus', 'bridge', 'outro', 'hook', 'pre-chorus', 'interlude'}`) by reading `draft.allLines.join(' ')` instead of `draft.rebuildRawText()`, scanning from the end of the lyric lines to pick the most relevant content word (`REQ-P56-COG-01`).

In `apps/vhunambi_client/lib/features/studio/presentation/widgets/lyrics_review_modal.dart`, update `initState`, `dispose`, and `_openCognateFinder`:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(modalSheetOpenCountProvider.notifier).state++;
      final formState = ref.read(studioFormProvider);
      ref
          .read(lyricsReviewProvider.notifier)
          .initializeFromStudio(
            rawLyrics: formState.customLyrics,
            prompt: formState.prompt,
            genre: formState.genre,
            language: formState.language,
          );
    });
  }

  @override
  void dispose() {
    try {
      final count = ref.read(modalSheetOpenCountProvider);
      if (count > 0) {
        ref.read(modalSheetOpenCountProvider.notifier).state = count - 1;
      }
    } catch (_) {}
    _newLineController.dispose();
    super.dispose();
  }
```
And replace `_openCognateFinder` (lines 171–204 of `lyrics_review_modal.dart`) with:

```dart
  void _openCognateFinder(
    BuildContext context,
    LyricsReviewDraft draft,
    bool isDark,
  ) {
    const structuralStopwords = <String>{
      'intro',
      'verse',
      'chorus',
      'bridge',
      'outro',
      'hook',
      'pre-chorus',
      'interlude',
    };

    // Strip any bracketed tags [Intro], [Chorus], etc. and extract lyric tokens only (REQ-P56-COG-01)
    final lyricBody = draft.allLines
        .join(' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    final tokens = lyricBody
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z]'), ''))
        .where(
          (w) =>
              w.length >= 3 && !structuralStopwords.contains(w.toLowerCase()),
        )
        .toList();

    final queryWord = tokens.isNotEmpty ? tokens.last : 'uthando';
    final suggestions = BantuCognateEngine.findSuggestions(queryWord);
```

### 8.2 File Target: `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`
Suppress `MiniPlayerHost` whenever the user is on the Studio tab (`activeTab == 2`, where `0 = Home`, `1 = Explore`, `2 = Studio`, `3 = Library`, `4 = Profile`) OR when any modal sheet (`modalSheetOpenCountProvider > 0`) is open (`REQ-P56-MINI-01..02`).

In `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart` (lines 149–159), replace `_shouldHide` with:

```dart
  bool _shouldHide(WidgetRef ref) {
    final isFullScreenOpen = ref.watch(fullScreenPlayerOpenProvider);
    final modalCount = ref.watch(modalSheetOpenCountProvider);
    final isKeyboardVisible = ref.watch(keyboardVisibleProvider);
    final activeTab = ref.watch(appNavigationTabProvider);

    // Phase 56 (REQ-P56-MINI-01): Auto-hide MiniPlayerHost across Studio (tab index 2)
    // and any open Studio modal/sheet so transport controls never block the 5-Ch Sketchpad or Action Bar.
    final isStudioTabActive = activeTab == 2;

    return isFullScreenOpen ||
        modalCount > 0 ||
        isKeyboardVisible ||
        isStudioTabActive;
  }
```

### 8.3 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/melody_sketchpad_modal.dart`
Ensure `MelodySketchpadModal` increments `modalSheetOpenCountProvider` in `initState` and decrements it in `dispose` so even if launched from outside Tab 2, `MiniPlayerHost` is suppressed while the 5-Channel Note Grid is active (`REQ-P56-MINI-02`).

In `apps/vhunambi_client/lib/features/studio/presentation/widgets/melody_sketchpad_modal.dart` (lines 48–60), update `_MelodySketchpadModalState`:

```dart
class _MelodySketchpadModalState extends ConsumerState<MelodySketchpadModal> {
  final TextEditingController _humController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(modalSheetOpenCountProvider.notifier).state++;
      }
    });
  }

  @override
  void dispose() {
    try {
      final current = ref.read(modalSheetOpenCountProvider);
      if (current > 0) {
        ref.read(modalSheetOpenCountProvider.notifier).state = current - 1;
      }
    } catch (_) {}
    _humController.dispose();
    super.dispose();
  }
```
*(Add `import '../../../../core/navigation/navigation_providers.dart';` at the top of `melody_sketchpad_modal.dart`).*

---

## 9. Track 5B & 5C: Ellipsis-Guarded `BiomeTopBar` & Mobile-First `SongDnaNodeTreeModal`

### 9.1 File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_top_bar.dart`
Fix the `00:09–00:15` 1-character vertical text squash (`E-x-p-l-o-r-e...`) and `03:22` header collision by:
1. Wrapping the left `'SONG DNA QUANTUM TREE'` and `'Explore the Living DNA of Music'` text widgets in `Flexible` / `maxLines: 1, overflow: TextOverflow.ellipsis`.
2. Wrapping the `'Now Playing'` transport capsule in a `ConstrainedBox(constraints: BoxConstraints(maxWidth: isMobile ? 148 : 240))` and wrapping its inner `Column` in `Flexible` with `maxLines: 1, overflow: TextOverflow.ellipsis` on `trackTitle` (`REQ-P56-BIOME-01`).

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

class BiomeTopBar extends StatelessWidget {
  final String trackTitle;
  final bool isPlaying;
  final bool isMuted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;

  const BiomeTopBar({
    super.key = const Key('biome_top_bar'),
    required this.trackTitle,
    required this.isPlaying,
    required this.isMuted,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;
        final capsuleMaxWidth = isMobile ? 148.0 : 240.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Sovereign DNA Emblem
              Container(
                width: isMobile ? 32 : 38,
                height: isMobile ? 32 : 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9E00).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF9E00).withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.dna,
                    color: const Color(0xFFFF9E00),
                    size: isMobile ? 15 : 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Left Title Column — Strictly Protected from 1-Char Vertical Squash (REQ-P56-BIOME-01)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'SONG DNA QUANTUM TREE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white70,
                              fontSize: isMobile ? 9.5 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF9E00,
                            ).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(
                                0xFFFF9E00,
                              ).withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            '3D BIOME',
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFFFF9E00),
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Explore the Living DNA of Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white54,
                        fontSize: isMobile ? 9.5 : 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Now Playing Transport Capsule — Bounded Width + Ellipsis (REQ-P56-BIOME-01)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: capsuleMaxWidth),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsBold.waveform,
                        color: Color(0xFFFF9E00),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Now Playing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white54,
                                fontSize: 8.5,
                              ),
                            ),
                            Text(
                              trackTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const Key('biome_play_pause_btn'),
                        onTap: onTogglePlay,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF9E00)),
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              isPlaying
                                  ? PhosphorIconsBold.pause
                                  : PhosphorIconsBold.play,
                              color: const Color(0xFFFF9E00),
                              size: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        key: const Key('biome_mute_btn'),
                        onTap: onToggleMute,
                        child: PhosphorIcon(
                          isMuted
                              ? PhosphorIconsBold.speakerSlash
                              : PhosphorIconsBold.speakerHigh,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('biome_close_btn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.x,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: onClose,
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### 9.2 `[FOR GEMINI 4 ARGON — COMPLEXITY & ADVANCED SOFTWARE ENGINEERING]` File Target: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
Overhaul `SongDnaNodeTreeModal` (`_SongDnaNodeTreeModalState`) to resolve all mobile HUD pile-ups, double bottom inspectors, legacy pill overlaps, and flat 2D camera bugs (`00:09–00:15` & `03:22–03:56`):

1. **Animated 450ms 3D Camera Dolly-Zoom (`_cameraDollyController`)**:
   - Add `late final AnimationController _cameraDollyController;` (`duration: const Duration(milliseconds: 450)`), `BiomeCameraState? _dollyStartCamera;`, and `BiomeCameraState? _dollyEndCamera;`.
   - When `_animateCameraTo(BiomeCameraState targetState)` is called (on mushroom tap, `_focusBiomeCluster`, or `_returnToOverview`), `_cameraDollyController` interpolates `BiomeCameraState.lerp(_dollyStartCamera!, _dollyEndCamera!, Curves.easeOutCubic.transform(_cameraDollyController.value))` and updates `ref.read(biomeCameraProvider.notifier).setCameraState(...)`.
   - Connect `_biomeAnimationController` listener to `ref.read(biomeCameraProvider.notifier).stepAutoRotate(0.008)` when `ref.read(biomeCameraProvider).isAutoRotating` is `true`.

2. **True 3D Zoom/Reset & Multi-Touch `onScaleUpdate` (`REQ-P56-BIOME-05`)**:
   - `_zoomIn()` calls `ref.read(biomeCameraProvider.notifier).zoomInStep()`.
   - `_zoomOut()` calls `ref.read(biomeCameraProvider.notifier).zoomOutStep()`.
   - `_resetCamera()` calls `ref.read(biomeCameraProvider.notifier).resetOverview()` and `ref.read(myceliumBiomeGraphProvider.notifier).focusCluster(null)`.
   - Replace `onPanUpdate` on the 3D canvas `GestureDetector` with `onScaleStart` and `onScaleUpdate` so 1-finger drag orbits in 3D (`addOrbitDelta(deltaYaw: details.focalPointDelta.dx * 0.0075, deltaPitch: details.focalPointDelta.dy * 0.0075)`) and 2-finger pinch scales `zoom` and `distance`.

3. **Mobile Top-Bar Popover Tooltips (`Controls` & `Layers`) (`REQ-P56-BIOME-02`)**:
   - Add boolean state fields `bool _isMobileControlsPopoverOpen = false;` and `bool _isMobileLayersPopoverOpen = false;`.
   - On mobile viewports (`constraints.maxWidth < 680`), render two compact top-left popover trigger pills:
     - `Key('biome_controls_popover_btn')` (`Controls`) — toggles `_isMobileControlsPopoverOpen` (closing `_isMobileLayersPopoverOpen`).
     - `Key('biome_layers_popover_btn')` (`Layers`) — toggles `_isMobileLayersPopoverOpen` (closing `_isMobileControlsPopoverOpen`).
   - Keep `BiomeInteractiveControlsBar` and `BiomeNetworkLayersFilter` mounted inside `Offstage(offstage: !isOpen)` when closed on mobile so widget key finders can always inspect them while they occupy **zero pixels** and block **zero touch events** on the 3D mushroom canvas until toggled open.
   - On desktop viewports (`constraints.maxWidth >= 680`), keep `BiomeInteractiveControlsBar` and `BiomeNetworkLayersFilter` visible in the bottom-left corner so all existing Phase 53 desktop tests (`1280x1024`) pass without change.
   - Center `SongJourneyTimelineScrubber` horizontally along the bottom of the 3D canvas (`bottom: 8, left: 12, right: 12` on mobile) so it never collides with the bottom-left corner.

4. **Zero Legacy Rectangular Pills in Overview Mode (`REQ-P56-BIOME-03`)**:
   - In `_buildDeclutteredReceptorTarget`, set:
     ```dart
     final shouldShowLabelPill = _focusedBranchRootId != null && (isInsideThisBranch || isSelected);
     ```
     In Overview Mode (`_focusedBranchRootId == null`), all legacy `Key('song_dna_bubble_${node.id}')` nodes render as `44×44` transparent hit-targets (`Container(color: Colors.transparent)`), eliminating 100% of the rectangular Phase 51/52 text pills (`Amapiano • MEDIUM`, `Venda Folk Elder`, `+ Attach Groove`) that floated over the 6 circular mushroom badges at `03:22–03:56`, while keeping every `Key('song_dna_bubble_${node.id}')` tappable for Phase 51/52 tests!

5. **Single Unified Bottom Inspector on Mobile (`REQ-P56-BIOME-04`)**:
   - On mobile (`MediaQuery.sizeOf(context).width < 680`), do **not** render `BiomeClusterInspectorPanel` floating over the top-right of the 3D canvas while `_buildQuickActionCard` simultaneously sits at the bottom.
   - Instead, when `_focusedBranchRootId != null || selectedNode != null` on mobile (`< 680`), render a single unified compact bottom inspector sheet (`Key('biome_mobile_unified_bottom_sheet')`, `ConstrainedBox(constraints: const BoxConstraints(maxHeight: 224))`) containing a scrollable column with `BiomeClusterInspectorPanel` (when `_focusedBranchRootId != null`) and `_buildQuickActionCard` (when `selectedNode != null`), ensuring at most **1** compact bottom sheet is ever visible and $>65\%$ of the 3D canvas remains clear.

Here are the exact state additions and method replacements in `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`:

```dart
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
  String? _focusedBranchRootId; // null = Overview Mode, non-null = Branch Canopy Focus

  // Mobile Popover Tooltip Toggles (REQ-P56-BIOME-02)
  bool _isMobileControlsPopoverOpen = false;
  bool _isMobileLayersPopoverOpen = false;
```

In `initState()` and `dispose()` of `_SongDnaNodeTreeModalState`:

```dart
    _biomeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )
      ..addListener(() {
        if (mounted && ref.read(biomeCameraProvider).isAutoRotating) {
          ref.read(biomeCameraProvider.notifier).stepAutoRotate(0.008);
        }
      })
      ..repeat();

    _cameraDollyController = AnimationController(
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
```
*(Dispose `_cameraDollyController.dispose();` inside `dispose()`).*

Replace `_zoomIn()`, `_zoomOut()`, `_resetCamera()`, `_returnToOverview()`, and `_focusBiomeCluster()` in `_SongDnaNodeTreeModalState` with:

```dart
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
```

In `SongDnaNodeTreeModal.build`, update the `LayoutBuilder` and bottom inspector area so mobile (`constraints.maxWidth < 680`) uses popover pills for `Controls` and `Layers` and a single unified bottom inspector dock:

```dart
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
                              final badgeProj =
                                  BiomeProjectionEngine.project3D(
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
                final isMobileViewport =
                    MediaQuery.sizeOf(context).width < 680;
                if (isMobileViewport) {
                  if (_focusedBranchRootId == null && selectedNode == null) {
                    return const SizedBox.shrink();
                  }
                  return ConstrainedBox(
                    key: const Key('biome_mobile_unified_bottom_sheet'),
                    constraints: const BoxConstraints(maxHeight: 220),
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
```

With helper methods `_buildInteractiveControlsDeck`, `_buildBiomeClusterInspectorWidget`, and `_buildMobilePopoverTogglePill` in `_SongDnaNodeTreeModalState`:

```dart
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
```

---

## 10. `[FOR GEMINI 4 ARGON — COMPLEXITY & ADVANCED SOFTWARE ENGINEERING]` Phase 56 Verification Test Suite Specification

### 10.1 File Target: `apps/vhunambi_client/test/features/studio/phase56_studio_cockpit_and_mobile_biome_overhaul_test.dart`
Create a dedicated 8-test verification suite covering all 5 tracks on both mobile (`360×780`) and desktop viewports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/controllers/biome_camera_controller.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/views/heritage_crate_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/views/studio_view.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lyrics_review_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group(
    'Phase 56: Studio Cockpit Compaction, Ergonomic Unification & Mobile 3D Biome Overhaul',
    () {
      testWidgets(
        '1. Prompt-First Compose: PromptInputBox is above CockpitQuantumEntanglementRack and 2x3 rack collapses cleanly',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final promptTop = tester
              .getTopLeft(find.text('Describe your song'))
              .dy;
          final rackTop = tester
              .getTopLeft(
                find.byKey(const Key('cockpit_quantum_entanglement_rack')),
              )
              .dy;

          expect(promptTop, lessThan(rackTop));
          expect(find.text('Reference Audio (optional)'), findsOneWidget);
          expect(
            find.byKey(const Key('dropzone_upload_audio_btn')),
            findsOneWidget,
          );

          // Toggle rack collapse
          await tester.tap(
            find.byKey(const Key('cockpit_rack_collapse_toggle_btn')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('cockpit_domain_card_melodyCore')),
            findsNothing,
          );
        },
      );

      testWidgets(
        '2. Voice Station Unification: Ensemble/Gender/Energy header card & 2x2 dialect grid render in Voice tab',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('studio_tab_voice')));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('voice_ensemble_header_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('voice_dialect_grid_card')),
            findsOneWidget,
          );

          await tester.tap(find.byKey(const Key('voice_config_choir')));
          await tester.pumpAndSettle();
          expect(
            container.read(studioFormProvider).vocalConfiguration,
            VocalConfiguration.choir,
          );
        },
      );

      testWidgets(
        '3. Crate & MPC Unification: Zero 1-char vertical crash in HeritageCrateModal on 360dp & 4-mode workbench switcher',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('studio_tab_crate_mpc')));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('workbench_mode_daw_upload')),
            findsOneWidget,
          );

          // Open full-screen HeritageCrateModal with Sketchpad button enabled on 360dp width
          await tester.tap(find.byKey(const Key('studio_open_crate_btn')));
          await tester.pumpAndSettle();

          expect(find.byType(HeritageCrateModal), findsOneWidget);
          final titleSize = tester.getSize(
            find.text('Heritage Crate Digging'),
          );
          expect(titleSize.height, lessThan(36.0));
        },
      );

      test(
        '4. Non-Blocking Generation Lifecycle: cancelLyricsReview restores idle state and prevents stuck skeleton',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final notifier = container.read(studioFormProvider.notifier);
          notifier.openLyricsReview();
          expect(
            container.read(studioFormProvider).phase,
            GenerationPhase.reviewingLyrics,
          );

          notifier.cancelLyricsReview();
          expect(
            container.read(studioFormProvider).phase,
            GenerationPhase.idle,
          );
        },
      );

      testWidgets(
        '5. Cognate Finder Bracket Stripping: Ignores [Intro] header and matches actual Bantu lyric token',
        (tester) async {
          tester.view.physicalSize = const Size(420, 820);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          container
              .read(studioFormProvider.notifier)
              .updateLyrics('[Intro]\nKhuluma nami uthando\n[Chorus]\nAmanzi');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: LyricsReviewModal()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(container.read(modalSheetOpenCountProvider), greaterThan(0));

          final suggestions = BantuCognateEngine.findSuggestions('amanzi');
          expect(suggestions, isNotEmpty);
          expect(
            suggestions.any((s) => s.sourceWord.toLowerCase() == 'intro'),
            isFalse,
          );
        },
      );

      testWidgets(
        '6. BiomeTopBar Mobile Ellipsis Guard: Long trackTitle never crushes left title on 360dp width',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          container
              .read(studioFormProvider.notifier)
              .updatePrompt(
                'Traditional acoustic storytelling with deep Venda ancestral drums and choir harmonies',
              );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: SongDnaNodeTreeModal()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          final subtitleSize = tester.getSize(
            find.text('Explore the Living DNA of Music'),
          );
          expect(subtitleSize.height, lessThan(28.0));
        },
      );

      testWidgets(
        '7. Mobile 3D Biome Popover Tooltips: Controls and Layers cards are hidden inside popovers by default on 360dp',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: SongDnaNodeTreeModal()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          final controlsBtn = find.byKey(
            const Key('biome_controls_popover_btn'),
          );
          final layersBtn = find.byKey(const Key('biome_layers_popover_btn'));
          expect(controlsBtn, findsOneWidget);
          expect(layersBtn, findsOneWidget);

          // By default on mobile, BiomeInteractiveControlsBar is offstage
          expect(
            find.byKey(const Key('biome_interactive_controls_bar')),
            findsNothing,
          );

          // Tap Controls pill -> reveals BiomeInteractiveControlsBar
          await tester.tap(controlsBtn);
          await tester.pump();
          expect(
            find.byKey(const Key('biome_interactive_controls_bar')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '8. True 3D Camera Dolly & Zoom: Zoom buttons and mushroom cluster tap mutate BiomeCameraState',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: SongDnaNodeTreeModal()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          final initialCam = container.read(biomeCameraProvider);
          expect(initialCam.distance, 420.0);

          // Tap [+] zoom in button -> mutates BiomeCameraState
          await tester.tap(find.byKey(const Key('song_dna_zoom_in_btn')));
          await tester.pump();
          final zoomedCam = container.read(biomeCameraProvider);
          expect(zoomedCam.distance, lessThan(initialCam.distance));
          expect(zoomedCam.zoom, greaterThan(initialCam.zoom));

          // Tap Vocal Network mushroom badge -> dollies 3D camera into Vocal cluster apex
          await tester.tap(
            find.byKey(const Key('biome_cluster_badge_vocalNetwork')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final focusedCam = container.read(biomeCameraProvider);
          final vocalApex = container
              .read(myceliumBiomeGraphProvider)
              .clusters[MyceliumClusterDomain.vocalNetwork]!
              .capApexPosition;
          expect(focusedCam.target.x, closeTo(vocalApex.x, 0.1));
          expect(focusedCam.distance, closeTo(220.0, 0.1));
          expect(
            find.byKey(const Key('biome_mobile_unified_bottom_sheet')),
            findsOneWidget,
          );
        },
      );
    },
  );
}
```
