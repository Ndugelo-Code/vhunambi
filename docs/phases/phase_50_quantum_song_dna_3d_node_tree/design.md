# Phase 50 Technical Design: Quantum-Entangled 3D Song DNA Node Tree & Hovering Cockpit Pill

## 1. Domain Models & State Architecture

### 1.1 `SongDnaNodeCategory` & `SongDnaNode`

```dart
enum SongDnaNodeCategory {
  beatCore,
  vocalLyrics,
  instrumentsHarmony,
  invasiveThirdParty;

  Color get color => switch (this) {
        SongDnaNodeCategory.beatCore => const Color(0xFFF97316),
        SongDnaNodeCategory.vocalLyrics => const Color(0xFF06B6D4),
        SongDnaNodeCategory.instrumentsHarmony => const Color(0xFF10B981),
        SongDnaNodeCategory.invasiveThirdParty => const Color(0xFFD946EF),
      };

  String get label => switch (this) {
        SongDnaNodeCategory.beatCore => 'Beat & Genesis Core',
        SongDnaNodeCategory.vocalLyrics => 'Vocal Timbre & Lyrics',
        SongDnaNodeCategory.instrumentsHarmony => 'Instruments & Harmony',
        SongDnaNodeCategory.invasiveThirdParty => 'Invasive 3rd-Party Audio',
      };
}

class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);
}

class SongDnaSubNode {
  final String id;
  final String name;
  final PhosphorIconData icon;
  final Color color;
  final bool isActive;

  const SongDnaSubNode({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isActive = true,
  });
}

class SongDnaNode {
  final String id;
  final SongDnaNodeCategory category;
  final String title;
  final String subtitle;
  final String cueLabel;
  final PhosphorIconData icon;
  final Color accentColor;
  final double branchUnlockProgress; // 0.0 to 1.0
  final bool isAdditive;
  final bool isInvasive;
  final bool isDetachable;
  final Vector3D localPosition;
  final List<SongDnaSubNode> subNodes;

  const SongDnaNode({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.cueLabel,
    required this.icon,
    required this.accentColor,
    required this.branchUnlockProgress,
    this.isAdditive = false,
    this.isInvasive = false,
    this.isDetachable = false,
    required this.localPosition,
    this.subNodes = const [],
  });

  bool get isFullyUnlocked => branchUnlockProgress >= 0.99;
}
```

---

### 1.2 `SongDnaGraphState` & Graph Synthesis

```dart
class SongDnaGraphState {
  final List<SongDnaNode> nodes;
  final String selectedNodeId;
  final int activeInvasiveNodesCount;
  final double overallCompleteness;
  final Color primaryGlowColor;

  const SongDnaGraphState({
    required this.nodes,
    required this.selectedNodeId,
    required this.activeInvasiveNodesCount,
    required this.overallCompleteness,
    required this.primaryGlowColor,
  });

  SongDnaNode? get selectedNode =>
      nodes.cast<SongDnaNode?>().firstWhere((n) => n?.id == selectedNodeId, orElse: () => null);
}
```

---

## 2. 3D Spatial Math & Camera System

### 2.1 Default 3D Node Topology
The nodes are spaced radially in 3D coordinate space around the central Core $(0, 0, 0)$:

| Node ID | Category | Local Coordinate $(X, Y, Z)$ | Purpose |
|---|---|---|---|
| `node_core` | `beatCore` | $(0, 0, 0)$ | Genesis Root: Song Prompt & Master Key |
| `node_genre_tempo` | `beatCore` | $(0, -140, 20)$ | Top Elevation: Genre & Tempo Pulse |
| `node_vocal_persona` | `vocalLyrics` | $(-140, 20, -30)$ | Left Elevation: Voice Timbre & Archetype |
| `node_language_lyrics` | `vocalLyrics` | $(-110, 110, 40)$ | Lower-Left: Bantu Dialect & Stanzas |
| `node_mood_energy` | `vocalLyrics` | $(-80, -90, -50)$ | Upper-Left: Mood & Vocal Dynamics |
| `node_sketchpad_groove` | `instrumentsHarmony` | $(140, 20, -30)$ | Right Elevation: 5-Channel Sketchpad |
| `node_heritage_mpc` | `instrumentsHarmony` | $(110, 110, 40)$ | Lower-Right: Heritage Crate Slices |
| `node_invasive_reference` | `invasiveThirdParty` | $(0, 160, -60)$ | Bottom Anchor: Reference Audio / Beats |
| `node_invasive_voice_clone`| `invasiveThirdParty` | $(40, 170, 60)$ | Bottom-Right Anchor: Cloned Voice VHU-SIG|
| `node_invasive_remix` | `invasiveThirdParty` | $(-40, 170, 60)$ | Bottom-Left Anchor: Parent Reel Lineage |

### 2.2 Billboard Screen-Space Hit-Testing
Each Cue Bubble is rendered at $(x_{\text{screen}, i}, y_{\text{screen}, i} - 28.0\text{dp})$. When the user taps within a 32dp radius of $(x_{\text{screen}, i}, y_{\text{screen}, i})$ or within the Cue Bubble rect, node $i$ is selected and the camera smoothly animates toward it.

---

## 3. Component Hierarchy

```
[ StudioView ]
  ├── [ ProgressTrackerWidget ]
  │     └── [ SongDnaHoverPill ] (Key: 'studio_song_dna_hover_pill')
  │           └── OnTap -> SongDnaNodeTreeModal.show(context)
  │
  └── [ Scaffold Body ]
        └── [ StudioActionBar ] (Wrapped in PlayerObstacle)

[ SongDnaNodeTreeModal ] (Key: 'song_dna_3d_tree_modal')
  ├── Header Bar (Title, Active Invasives Counter, Close Button)
  ├── 3D Spatial Canvas (GestureDetector: 1-finger orbit drag, 2-finger pinch)
  │     ├── CustomPainter (_SongDna3DPainter)
  │     │     ├── Ambient Grid & Particle Dust
  │     │     ├── Flowing Energy Conduits (0% -> 100%)
  │     │     ├── Symbiotic Violet Lightning Tethers (Invasive nodes)
  │     │     └── 3D Perspective-Scaled Node Spheres
  │     └── Billboarded Cue Bubbles (Key: 'song_dna_bubble_${node.id}')
  │
  ├── Camera HUD Controls (Key: 'song_dna_zoom_in_btn', 'song_dna_zoom_out_btn', 'song_dna_reset_camera_btn')
  │
  ├── Sleek Quick-Action Card (Key: 'song_dna_quick_action_card')
  │     ├── Category Header & Node Value
  │     ├── Mutation Pickers (Genre / Tempo / Voice / Language / Mood)
  │     ├── Additive Channel Triggers (+ Add 5-Channel Groove)
  │     └── Invasive Detach Button (Key: 'song_dna_detach_node_btn')
  │
  └── CTA Dock: [ ⚡ Synthesize Song from 3D DNA ] (Key: 'song_dna_synthesize_btn')
```

---

## 4. Deterministic Widget Keys Table

| Component | Target File | Key Value |
|---|---|---|
| Living Hover Pill | `song_dna_hover_pill.dart` | `const Key('studio_song_dna_hover_pill')` |
| Full-Screen 3D Modal | `song_dna_node_tree_modal.dart` | `const Key('song_dna_3d_tree_modal')` |
| Zoom In Button | `song_dna_node_tree_modal.dart` | `const Key('song_dna_zoom_in_btn')` |
| Zoom Out Button | `song_dna_node_tree_modal.dart` | `const Key('song_dna_zoom_out_btn')` |
| Reset Camera Button | `song_dna_node_tree_modal.dart` | `const Key('song_dna_reset_camera_btn')` |
| Floating Cue Bubble | `song_dna_node_tree_modal.dart` | `Key('song_dna_bubble_${node.id}')` |
| Quick-Action Card | `song_dna_node_tree_modal.dart` | `const Key('song_dna_quick_action_card')` |
| Detach Invasive Node Button | `song_dna_node_tree_modal.dart` | `const Key('song_dna_detach_node_btn')` |
| Synthesize from 3D DNA CTA | `song_dna_node_tree_modal.dart` | `const Key('song_dna_synthesize_btn')` |

