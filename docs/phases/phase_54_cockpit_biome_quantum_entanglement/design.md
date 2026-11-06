# Phase 54 Detailed Engineering Design: 2D Studio Cockpit & 3D Mycelium Biome Bi-Directional Quantum Entanglement

- **Phase Identifier**: `phase_54_cockpit_biome_quantum_entanglement`
- **Target Application**: `apps/vhunambi_client`
- **Blueprint Reference**: [`docs/phases/phase_54_cockpit_biome_quantum_entanglement/blueprint.md`](./blueprint.md)
- **Requirements Reference**: [`docs/phases/phase_54_cockpit_biome_quantum_entanglement/requirements.md`](./requirements.md)

---

## 1. Architectural Overview & System Boundaries

Phase 54 unifies Vhunambi's **2D Tactical Studio Cockpit (`StudioView`)** and **3D Organic Mycelium Biome (`SongDnaNodeTreeModal`)** into a single, bi-directionally synchronized musical organism.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│              PHASE 54 MODULE & FILE ARCHITECTURE (apps/vhunambi_client/)               │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. PURE DART DOMAIN LAYER                                                              │
│    • `lib/features/studio/domain/models/mycelium_biome_models.dart`                    │
│      - Adds `CockpitWorkspaceTab` enum (`compose`, `voice`, `crateAndMpc`)             │
│      - Adds `canonicalPrimaryKey`, `legacyAliasKey`, `targetCockpitTab` on             │
│        `MyceliumClusterDomain`                                                         │
│      - Adds `liveTelemetrySummary` on `MushroomFruitingBody`                           │
│    • `lib/features/studio/domain/models/studio_form_state.dart`                        │
│      - Unifies `branchStemLockModes` default map with both canonical & alias keys      │
│      - Adds `stemLockForDomain(MyceliumClusterDomain)` helper                          │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. BI-DIRECTIONAL RIVERPOD ENTANGLEMENT LAYER                                          │
│    • `lib/features/studio/presentation/providers/studio_form_provider.dart`            │
│      - Adds `studioCockpitTabProvider` (`StateProvider<CockpitWorkspaceTab>`)          │
│      - Adds `setClusterStemLockMode`, `cycleClusterStemLockMode`, `cycleSonicVibeDice` │
│      - Synchronizes canonical + legacy alias keys atomically on every stem-lock write  │
│    • `lib/features/studio/presentation/providers/mycelium_biome_provider.dart`         │
│      - Replaces destructive `ref.watch(studioFormProvider)` with non-destructive       │
│        `ref.listen` across `studioFormProvider`, `melodySketchpadProvider`,            │
│        `mpcSlicerProvider`, `heritageCrateProvider`, and `vocalIdentityProvider`       │
│      - Implements `reconcileWithCockpitState()` computing dynamic heights, cap radii,  │
│        `intensityPercent`, `complexityPercent`, `influencePercent`, and 29 live child  │
│        leaves while preserving `focusedDomain`, `activeSection`, and `activeLayers`    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 3. 2D COCKPIT & 3D BIOME PRESENTATION LAYER                                            │
│    • `lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart` │
│      - 6-Domain Quantum Entanglement & Stem Authority Rack on Compose Tab              │
│    • `lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`        │
│      - Inline 3-Mode Hardware Rack (Heritage Crate, 8-Pad MPC, 5-Ch Sketchpad) on Tab 2│
│    • `lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`│
│      - Wires `biome_inspector_stem_lock_btn`, live telemetry, & `onExploreDetails`     │
│    • `lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`          │
│      - Supports `initialFocusedDomain` 2D -> 3D dive & 3D -> 2D tab teleportation      │
│    • `lib/features/studio/presentation/views/studio_view.dart`                         │
│      - Binds tab bar to `studioCockpitTabProvider`, embeds Quantum Rack & Workbench    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations for 2D $\leftrightarrow$ 3D Entanglement

### 2.1 Right-Handed 3D Y-Up World Space Invariant
All 6 `MushroomFruitingBody` clusters remain rooted on the contoured elevation terrain $Y_{\text{root}, k} = h(X_k, Z_k) \ge 0$ at their canonical planar coordinates $(X_k, Z_k)$:
1. **`melodyCore`**: $(X_1, Z_1) = (0.0, 0.0)$, $Y_{\text{root}, 1} = h(0, 0) \approx 32.0\text{dp}$, Base Apex $Y_{\text{base}, 1} = 140.0\text{dp}$, Base Cap Radius $R_{\text{base}, 1} = 56.0\text{dp}$.
2. **`rhythmNetwork`**: $(X_2, Z_2) = (-195.0, +95.0)$, $Y_{\text{root}, 2} = h(-195, 95) \approx 22.0\text{dp}$, Base Apex $Y_{\text{base}, 2} = 96.0\text{dp}$, Base Cap Radius $R_{\text{base}, 2} = 42.0\text{dp}$.
3. **`vocalNetwork`**: $(X_3, Z_3) = (-155.0, -90.0)$, $Y_{\text{root}, 3} = h(-155, -90) \approx 26.0\text{dp}$, Base Apex $Y_{\text{base}, 3} = 120.0\text{dp}$, Base Cap Radius $R_{\text{base}, 3} = 47.0\text{dp}$.
4. **`harmonyNetwork`**: $(X_4, Z_4) = (+165.0, -85.0)$, $Y_{\text{root}, 4} = h(165, -85) \approx 25.0\text{dp}$, Base Apex $Y_{\text{base}, 4} = 115.0\text{dp}$, Base Cap Radius $R_{\text{base}, 4} = 45.0\text{dp}$.
5. **`emotionNetwork`**: $(X_5, Z_5) = (+190.0, +75.0)$, $Y_{\text{root}, 5} = h(190, 75) \approx 21.0\text{dp}$, Base Apex $Y_{\text{base}, 5} = 96.0\text{dp}$, Base Cap Radius $R_{\text{base}, 5} = 41.0\text{dp}$.
6. **`productionNetwork`**: $(X_6, Z_6) = (-35.0, +155.0)$, $Y_{\text{root}, 6} = h(-35, 155) \approx 18.0\text{dp}$, Base Apex $Y_{\text{base}, 6} = 82.0\text{dp}$, Base Cap Radius $R_{\text{base}, 6} = 39.0\text{dp}$.

### 2.2 Continuous 2D State-to-3D Morphing Equations
Let $\mathcal{E}_k \in [0.40, 1.0]$ denote the normalized energy of cluster $k$, and $\mathcal{C}_k \in [0.40, 1.0]$ denote its normalized structural complexity computed from the 5 Studio providers:

$$\Delta_{\text{morph}}(\mathcal{E}_k) = 0.88 + 0.12 \cdot \left(\frac{\mathcal{E}_k - 0.50}{0.50}\right) \in [0.85, 1.00]$$

The dynamic stipe height $H_{\text{stipe}, k}$ and cap radius $R_{\text{cap}, k}$ are:
$$H_{\text{stipe}, k} = (Y_{\text{base}, k} - Y_{\text{root}, k}) \cdot \Delta_{\text{morph}}(\mathcal{E}_k), \quad R_{\text{cap}, k} = R_{\text{base}, k} \cdot \Delta_{\text{morph}}(\mathcal{E}_k)$$

And the 3 telemetry percentages displayed in both `BiomeClusterInspectorPanel` and `CockpitQuantumEntanglementRack` are:
$$\text{Intensity}_k = \text{clamp}_{[40, 99]}\!\left(\text{round}(100 \cdot \mathcal{E}_k)\right)$$
$$\text{Complexity}_k = \text{clamp}_{[40, 99]}\!\left(\text{round}(100 \cdot \mathcal{C}_k)\right)$$
$$\text{Influence}_k = \text{clamp}_{[45, 99]}\!\left(\text{round}(60 \cdot \mathcal{E}_k + 40 \cdot \mathcal{C}_k)\right)$$

---

## 3. Pure Dart Domain Layer Additions (`mycelium_biome_models.dart` & `studio_form_state.dart`)

### 3.1 `CockpitWorkspaceTab` & `MyceliumClusterDomain` Extensions in `lib/features/studio/domain/models/mycelium_biome_models.dart`

```dart
/// The 3 primary 2D workspace tabs in StudioView (REQ-P54-TELE-02).
enum CockpitWorkspaceTab {
  compose,
  voice,
  crateAndMpc;

  String get label => switch (this) {
    compose => 'Compose',
    voice => 'Voice',
    crateAndMpc => 'Crate & MPC',
  };
}
```

Inside `enum MyceliumClusterDomain`:
```dart
  /// Canonical primary key in StudioFormState.branchStemLockModes (REQ-P54-SYNC-02).
  String get studioBranchKey => switch (this) {
    melodyCore => 'node_sketchpad_groove',
    rhythmNetwork => 'node_beat_tempo',
    vocalNetwork => 'node_vocal_persona',
    harmonyNetwork => 'node_harmony_chords',
    emotionNetwork => 'node_emotion_mood',
    productionNetwork => 'node_spatial_atmosphere',
  };

  /// Legacy alias key kept 100% synchronized in StudioFormState.branchStemLockModes.
  String get legacyBranchAliasKey => switch (this) {
    melodyCore => 'node_branch_instruments',
    rhythmNetwork => 'node_branch_beat',
    vocalNetwork => 'node_branch_vocal',
    harmonyNetwork => 'node_branch_instruments',
    emotionNetwork => 'node_branch_vocal',
    productionNetwork => 'node_branch_sfx',
  };

  /// Target 2D Studio Cockpit tab when teleporting from 3D Biome (REQ-P54-TELE-03).
  CockpitWorkspaceTab get targetCockpitTab => switch (this) {
    melodyCore => CockpitWorkspaceTab.compose,
    rhythmNetwork => CockpitWorkspaceTab.crateAndMpc,
    vocalNetwork => CockpitWorkspaceTab.voice,
    harmonyNetwork => CockpitWorkspaceTab.crateAndMpc,
    emotionNetwork => CockpitWorkspaceTab.compose,
    productionNetwork => CockpitWorkspaceTab.compose,
  };
```

Inside `class MushroomFruitingBody`:
```dart
  final String liveTelemetrySummary;

  const MushroomFruitingBody({
    required this.domain,
    required this.rootPosition,
    required this.stipeHeight,
    required this.capRadius,
    required this.capDepth,
    this.currentLuminosity = 1.0,
    this.dynamicPulseRate = 1.0,
    required this.intensityPercent,
    required this.complexityPercent,
    required this.influencePercent,
    this.isStemLocked = false,
    this.liveTelemetrySummary = '',
    required this.connectedDomains,
    required this.childLeaves,
  });
```
*(With `liveTelemetrySummary` included in `MushroomFruitingBody.copyWith`).*

### 3.2 Canonical Stem-Lock Dictionary in `lib/features/studio/domain/models/studio_form_state.dart`

In `StudioFormState` constructor:
```dart
    Map<String, StemLockMode>? branchStemLockModes,
  })  : branchStemLockModes = branchStemLockModes ??
            const {
              'node_beat_tempo': StemLockMode.lockedPure44k,
              'node_branch_beat': StemLockMode.lockedPure44k,
              'node_sketchpad_groove': StemLockMode.lockedPure44k,
              'node_branch_instruments': StemLockMode.lockedPure44k,
              'node_harmony_chords': StemLockMode.lockedPure44k,
              'node_vocal_persona': StemLockMode.harmonicInpaint,
              'node_branch_vocal': StemLockMode.harmonicInpaint,
              'node_emotion_mood': StemLockMode.harmonicInpaint,
              'node_spatial_atmosphere': StemLockMode.harmonicInpaint,
              'node_branch_sfx': StemLockMode.harmonicInpaint,
            },
```

---

## 4. Bi-Directional Riverpod Providers (`studio_form_provider.dart` & `mycelium_biome_provider.dart`)

### 4.1 `studioCockpitTabProvider` & Atomic Stem-Lock Synchronization in `lib/features/studio/presentation/providers/studio_form_provider.dart`

```dart
import '../../domain/models/mycelium_biome_models.dart';

/// Tracks the active 2D Studio Cockpit workspace tab (REQ-P54-TELE-02).
final studioCockpitTabProvider =
    StateProvider<CockpitWorkspaceTab>((ref) => CockpitWorkspaceTab.compose);
```

Inside `StudioFormNotifier`:
```dart
  int _sonicVibePresetIndex = 0;

  /// Atomically sets a stem lock mode and synchronizes all canonical & legacy alias keys (REQ-P54-SYNC-02).
  void setBranchStemLockMode(String branchId, StemLockMode mode) {
    final updated = Map<String, StemLockMode>.from(state.branchStemLockModes);
    updated[branchId] = mode;

    // Synchronize canonical <-> legacy alias pairs
    switch (branchId) {
      case 'node_beat_tempo':
      case 'node_branch_beat':
        updated['node_beat_tempo'] = mode;
        updated['node_branch_beat'] = mode;
      case 'node_sketchpad_groove':
      case 'node_branch_instruments':
      case 'node_harmony_chords':
        updated['node_sketchpad_groove'] = mode;
        updated['node_branch_instruments'] = mode;
        updated['node_harmony_chords'] = mode;
      case 'node_vocal_persona':
      case 'node_branch_vocal':
      case 'node_emotion_mood':
        updated['node_vocal_persona'] = mode;
        updated['node_branch_vocal'] = mode;
        updated['node_emotion_mood'] = mode;
      case 'node_spatial_atmosphere':
      case 'node_branch_sfx':
        updated['node_spatial_atmosphere'] = mode;
        updated['node_branch_sfx'] = mode;
    }

    state = state.copyWith(branchStemLockModes: updated);
  }

  /// Sets the StemLockMode for a specific 3D MyceliumClusterDomain (REQ-P54-SYNC-02).
  void setClusterStemLockMode(MyceliumClusterDomain domain, StemLockMode mode) {
    setBranchStemLockMode(domain.studioBranchKey, mode);
  }

  /// Cycles StemLockMode (lockedPure44k -> harmonicInpaint -> elasticResynth) for a domain (REQ-P54-RACK-02).
  StemLockMode cycleClusterStemLockMode(MyceliumClusterDomain domain) {
    final current = state.branchStemLockModes[domain.studioBranchKey] ??
        state.branchStemLockModes[domain.legacyBranchAliasKey] ??
        StemLockMode.harmonicInpaint;
    final next = switch (current) {
      StemLockMode.lockedPure44k => StemLockMode.harmonicInpaint,
      StemLockMode.harmonicInpaint => StemLockMode.elasticResynth,
      StemLockMode.elasticResynth => StemLockMode.lockedPure44k,
    };
    setClusterStemLockMode(domain, next);
    return next;
  }

  /// Cycles through the 4 curated African Sonic Vibe DNA presets (REQ-P54-RACK-03).
  void cycleSonicVibeDice() {
    _sonicVibePresetIndex = (_sonicVibePresetIndex + 1) % 4;
    switch (_sonicVibePresetIndex) {
      case 0:
        applyDnaPresetPrivateSchoolPiano();
      case 1:
        applyDnaPresetDurbanDarkGqom();
      case 2:
        applyDnaPresetVendaTraditionalSoul();
      case 3:
        applyDnaPresetLagosAfroPop();
    }
  }
```

### 4.2 Non-Destructive 5-Provider `MyceliumBiomeGraphNotifier` (`lib/features/studio/presentation/providers/mycelium_biome_provider.dart`)

```dart
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../controllers/biome_camera_controller.dart';
import 'heritage_crate_provider.dart';
import 'melody_sketchpad_provider.dart';
import 'studio_form_provider.dart';
import 'vocal_identity_provider.dart';

/// Provides the active 3D Mycelium Biome Graph, non-destructively entangled
/// with all 5 Studio Cockpit providers (REQ-P54-SYNC-01..04).
final myceliumBiomeGraphProvider =
    StateNotifierProvider<MyceliumBiomeGraphNotifier, MusicalDnaGraph>((ref) {
  final notifier = MyceliumBiomeGraphNotifier(ref);

  ref.listen<StudioFormState>(
    studioFormProvider,
    (_, _) => notifier.reconcileWithCockpitState(),
  );
  ref.listen<MelodySketchpadState>(
    melodySketchpadProvider,
    (_, _) => notifier.reconcileWithCockpitState(),
  );
  ref.listen<MpcSlicerState>(
    mpcSlicerProvider,
    (_, _) => notifier.reconcileWithCockpitState(),
  );
  ref.listen<HeritageCrateState>(
    heritageCrateProvider,
    (_, _) => notifier.reconcileWithCockpitState(),
  );
  ref.listen<VocalIdentityState>(
    vocalIdentityProvider,
    (_, _) => notifier.reconcileWithCockpitState(),
  );

  return notifier;
});
```

Inside `MyceliumBiomeGraphNotifier`:
- Maintains `final List<MyceliumChildNode> _customHarmonyLeaves = [];` so user-spawned leaves (`addInstrumentLeaf`) survive every 2D state reconciliation!
- Implements `void reconcileWithCockpitState()`:
  1. Reads current `form = _ref.read(studioFormProvider)`, `sketchpad = _ref.read(melodySketchpadProvider)`, `mpc = _ref.read(mpcSlicerProvider)`, `vocal = _ref.read(vocalIdentityProvider)`.
  2. Recomputes the 6 `MushroomFruitingBody` clusters with live `stipeHeight`, `capRadius`, `intensityPercent`, `complexityPercent`, `influencePercent`, `isStemLocked`, `liveTelemetrySummary`, and dynamic `childLeaves` (appending `_customHarmonyLeaves` to `harmonyNetwork`).
  3. Applies the active `SongJourneySection` luminosity multipliers (`state.activeSection`) to the updated clusters.
  4. Recomputes `hyphaeEdges` (setting `isStemLocked: cSrc.isStemLocked && cTgt.isStemLocked`), `rootTendrils`, and `sproutNodes`.
  5. Updates `state = state.copyWith(...)` **without clearing** `focusedDomain`, `selectedChildNodeId`, `activeSection`, `activeLayers`, `isCompareModeActive`, or `isAnalyseOverlayActive`!

---

## 5. Complete Production Implementation: `CockpitQuantumEntanglementRack`

**Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/mycelium_biome_provider.dart';
import '../providers/studio_form_provider.dart';
import 'song_dna_node_tree_modal.dart';

/// 2D Studio Cockpit Quantum Entanglement & Stem Authority Rack (REQ-P54-RACK-01..02).
///
/// Displays all 6 entangled 3D Mycelium domains directly inside the 2D Compose tab,
/// surfacing real-time 2D->3D telemetry, 1-tap StemLockMode cycling, and 1-tap
/// deep-link dives into specific 3D mushroom fruiting bodies.
class CockpitQuantumEntanglementRack extends ConsumerWidget {
  const CockpitQuantumEntanglementRack({
    super.key = const Key('cockpit_quantum_entanglement_rack'),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biomeGraph = ref.watch(myceliumBiomeGraphProvider);
    final formState = ref.watch(studioFormProvider);
    final lockedCount = biomeGraph.clusters.values
        .where((c) => c.isStemLocked)
        .length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.dna,
                color: AppColors.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2D <-> 3D Quantum Stem Authority',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$lockedCount of 6 Ecosystem Clusters Locked Pure 44.1 kHz',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: const Key('cockpit_rack_open_3d_biome_btn'),
                borderRadius: AppRadius.pillBorder,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  SongDnaNodeTreeModal.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.14),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: AppColors.brandPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsBold.cubeFocus,
                        size: 13,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '3D Biome',
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
          const SizedBox(height: AppSpacing.sm),

          // 6 Domain Entanglement Cards (Responsive 2-Column Wrap/Grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final cardWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: MyceliumClusterDomain.values.map((domain) {
                  final cluster = biomeGraph.clusters[domain]!;
                  final lockMode =
                      formState.branchStemLockModes[domain.studioBranchKey] ??
                      formState.branchStemLockModes[
                          domain.legacyBranchAliasKey] ??
                      StemLockMode.harmonicInpaint;

                  return SizedBox(
                    width: cardWidth,
                    child: _DomainEntanglementCard(
                      cluster: cluster,
                      lockMode: lockMode,
                      onCycleLock: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(studioFormProvider.notifier)
                            .cycleClusterStemLockMode(domain);
                      },
                      onDive3D: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(myceliumBiomeGraphProvider.notifier)
                            .focusCluster(domain);
                        SongDnaNodeTreeModal.show(
                          context,
                          initialFocusedDomain: domain,
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DomainEntanglementCard extends StatelessWidget {
  final MushroomFruitingBody cluster;
  final StemLockMode lockMode;
  final VoidCallback onCycleLock;
  final VoidCallback onDive3D;

  const _DomainEntanglementCard({
    required this.cluster,
    required this.lockMode,
    required this.onCycleLock,
    required this.onDive3D,
  });

  @override
  Widget build(BuildContext context) {
    final domain = cluster.domain;
    final accent = Color(domain.hexColor);
    final isLocked = lockMode == StemLockMode.lockedPure44k;

    return Container(
      key: Key('cockpit_domain_card_${domain.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked
              ? accent.withValues(alpha: 0.75)
              : AppColors.borderSubtleOf(context),
          width: isLocked ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  domain.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${cluster.intensityPercent}%',
                style: AppTypography.badge.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            cluster.liveTelemetrySummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: Key('cockpit_stem_lock_${domain.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onCycleLock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? accent.withValues(alpha: 0.18)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLocked
                            ? accent.withValues(alpha: 0.65)
                            : AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          isLocked
                              ? PhosphorIconsBold.lockKey
                              : PhosphorIconsBold.sparkle,
                          size: 11,
                          color: isLocked
                              ? accent
                              : AppColors.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            lockMode.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isLocked
                                  ? accent
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                key: Key('cockpit_jump_3d_${domain.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: onDive3D,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.cube,
                        size: 11,
                        color: accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '3D',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Complete Production Implementation: `InlineCrateMpcWorkbench`

**Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/heritage_crate_provider.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

/// Inline 3-Mode Groove, Crate & 8-Pad MPC Workbench on Tab 2 (REQ-P54-WORK-01..02).
class InlineCrateMpcWorkbench extends ConsumerStatefulWidget {
  const InlineCrateMpcWorkbench({
    super.key = const Key('cockpit_inline_crate_mpc_workbench'),
  });

  @override
  ConsumerState<InlineCrateMpcWorkbench> createState() =>
      _InlineCrateMpcWorkbenchState();
}

class _InlineCrateMpcWorkbenchState
    extends ConsumerState<InlineCrateMpcWorkbench> {
  int _activeSegment = 1; // 0: Crate, 1: 8-Pad MPC, 2: 5-Ch Sketchpad

  @override
  Widget build(BuildContext context) {
    final mpcState = ref.watch(mpcSlicerProvider);
    final crateState = ref.watch(heritageCrateProvider);
    final sketchState = ref.watch(melodySketchpadProvider);
    final formState = ref.watch(studioFormProvider);
    final beatLocked =
        formState.branchStemLockModes['node_beat_tempo'] ==
        StemLockMode.lockedPure44k;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Beat Stem Lock Toggle
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.faders,
                color: AppColors.coinGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inline Groove & Sample Workbench',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('workbench_lock_beat_btn'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(studioFormProvider.notifier)
                      .cycleClusterStemLockMode(
                        MyceliumClusterDomain.rhythmNetwork,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: beatLocked
                        ? const Color(0xFF00B4D8).withValues(alpha: 0.18)
                        : AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: beatLocked
                          ? const Color(0xFF00B4D8)
                          : AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        beatLocked
                            ? PhosphorIconsBold.lockKey
                            : PhosphorIconsBold.lockKeyOpen,
                        size: 12,
                        color: beatLocked
                            ? const Color(0xFF00B4D8)
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        beatLocked ? 'Beat Locked 44.1k' : 'Beat Guided',
                        style: AppTypography.caption.copyWith(
                          color: beatLocked
                              ? const Color(0xFF00B4D8)
                              : AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3-Mode Segmented Rack Selector
          Row(
            children: [
              _buildSegmentTab(
                index: 0,
                keyName: 'workbench_mode_crate',
                label: 'Heritage Crate',
                icon: PhosphorIconsBold.vinylRecord,
              ),
              const SizedBox(width: 6),
              _buildSegmentTab(
                index: 1,
                keyName: 'workbench_mode_mpc',
                label: '8-Pad MPC',
                icon: PhosphorIconsBold.squaresFour,
              ),
              const SizedBox(width: 6),
              _buildSegmentTab(
                index: 2,
                keyName: 'workbench_mode_sketchpad',
                label: '5-Ch Sketchpad',
                icon: PhosphorIconsBold.pianoKeys,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Active Mode Surface
          if (_activeSegment == 0)
            _buildInlineCrateSurface(context, crateState)
          else if (_activeSegment == 1)
            _buildInlineMpcSurface(context, mpcState)
          else
            _buildInlineSketchpadSurface(context, sketchState),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required String keyName,
    required String label,
    required PhosphorIconData icon,
  }) {
    final isSelected = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        key: Key(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeSegment = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPrimary.withValues(alpha: 0.16)
                : AppColors.surfaceSecondaryOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.brandPrimary
                  : AppColors.borderSubtleOf(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 13,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondaryOf(context),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineCrateSurface(
    BuildContext context,
    HeritageCrateState crateState,
  ) {
    final samples = crateState.filteredSamples.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sample in samples)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtleOf(context)),
            ),
            child: Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsBold.musicNotes,
                  size: 15,
                  color: AppColors.coinGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.name,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${sample.cultureRegion} • ${sample.bpm} BPM',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: Key('workbench_chop_sample_${sample.id}'),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(mpcSlicerProvider.notifier).sliceSample(sample);
                    setState(() => _activeSegment = 1);
                  },
                  child: Text(
                    'Chop to MPC',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInlineMpcSurface(BuildContext context, MpcSlicerState mpcState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${mpcState.sourceTitle} • ${mpcState.bpm} BPM',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Stretch: ${mpcState.timeStretchRatio.toStringAsFixed(1)}x',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(mpcState.pads.length, (i) {
            final pad = mpcState.pads[i];
            final isSelected = mpcState.selectedPadIndex == i;
            return GestureDetector(
              key: Key('workbench_mpc_pad_$i'),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(mpcSlicerProvider.notifier).selectPad(i);
                ref.read(mpcSlicerProvider.notifier).triggerPad(i);
              },
              child: Container(
                width: 72,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary.withValues(alpha: 0.22)
                      : AppColors.surfaceSecondaryOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtleOf(context),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pad.label,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      '${pad.startSec.toStringAsFixed(1)}s',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInlineSketchpadSurface(
    BuildContext context,
    MelodySketchpadState sketchState,
  ) {
    final pat = sketchState.activePattern;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.pianoKeys,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pat.instrument.label} • ${pat.rootKey} ${pat.scale.label}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '5 Channels (Lead, Chords, Bass, Drums, Hats) • ${pat.bpm} BPM',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          key: const Key('workbench_open_sketchpad_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => MelodySketchpadModal.show(context),
          icon: const PhosphorIcon(
            PhosphorIconsBold.waveSine,
            size: 16,
            color: Colors.black,
          ),
          label: Text(
            'Open 5-Channel Master Sketchpad',
            style: AppTypography.caption.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
```
*(Note: Use `PhosphorIconsBold.waveSine` in camelCase).*

---

## 7. Updated `BiomeClusterInspectorPanel` with Active Stem-Lock Button & Telemetry

**Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`

Inside `BiomeClusterInspectorPanel.build(...)`, between the 3-Metrics Row and the `Related Nodes` section, render the live 2D Telemetry summary and the interactive Stem-Lock control button (`Key('biome_inspector_stem_lock_btn')`):

```dart
          // Live 2D Telemetry Summary & Stem Authority Control (REQ-P54-TELE-01)
          if (cluster.liveTelemetrySummary.isNotEmpty) ...[
            Text(
              cluster.liveTelemetrySummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            key: const Key('biome_inspector_stem_lock_btn'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleStemLock();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: cluster.isStemLocked
                    ? clusterColor.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cluster.isStemLocked
                      ? clusterColor
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    cluster.isStemLocked
                        ? PhosphorIconsBold.lockKey
                        : PhosphorIconsBold.sparkle,
                    size: 13,
                    color: cluster.isStemLocked ? clusterColor : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cluster.isStemLocked
                          ? 'Stem-Locked (Pure 44.1 kHz)'
                          : 'Guided AI Inpaint Active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
```

---

## 8. Updated `SongDnaNodeTreeModal` Deep-Link Router & Initial Focus

**Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`

1. Add optional `final MyceliumClusterDomain? initialFocusedDomain;` parameter to `SongDnaNodeTreeModal` and `SongDnaNodeTreeModal.show(BuildContext context, {VoidCallback? onSynthesizeRequested, MyceliumClusterDomain? initialFocusedDomain})`.
2. In `initState()`, if `widget.initialFocusedDomain != null`, invoke `_focusBiomeCluster(widget.initialFocusedDomain!)` inside `addPostFrameCallback`.
3. In `BiomeClusterInspectorPanel` wiring (lines 487–495), wire `onExploreDetails` (`REQ-P54-TELE-03`) to:
   ```dart
   onExploreDetails: () {
     HapticFeedback.mediumImpact();
     final activeDomain = biomeGraph.activeInspectorCluster.domain;
     ref.read(studioCockpitTabProvider.notifier).state =
         activeDomain.targetCockpitTab;
     Navigator.of(context).pop();
   },
   ```

---

## 9. Formal Proof of Non-Destructive Entanglement & Key Parity

1. **Theorem 1 (Focus Retention Under 2D Mutation)**:
   Because `myceliumBiomeGraphProvider` is constructed once per `ProviderContainer` lifetime and uses `ref.listen` rather than `ref.watch`, mutating `studioFormProvider`, `melodySketchpadProvider`, `mpcSlicerProvider`, `heritageCrateProvider`, or `vocalIdentityProvider` invokes `reconcileWithCockpitState()` on the existing `MyceliumBiomeGraphNotifier` instance. Since `reconcileWithCockpitState()` calls `state.copyWith(clusters: ..., hyphaeEdges: ...)` without passing `clearFocusedDomain: true`, `state.focusedDomain` is invariant across all 2D mutations. $\blacksquare$
2. **Theorem 2 (Canonical-Legacy Stem Lock Isomorphism)**:
   For every domain $d \in \text{MyceliumClusterDomain}$, `setBranchStemLockMode` writes identical `StemLockMode` values to both $d.\text{studioBranchKey}$ and $d.\text{legacyBranchAliasKey}$ in `StudioFormState.branchStemLockModes`. Therefore, `songDnaGraphProvider` and `myceliumBiomeGraphProvider` read identical lock states at all times $t \ge 0$. $\blacksquare$
