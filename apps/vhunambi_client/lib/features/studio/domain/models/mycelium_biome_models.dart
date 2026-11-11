// Pure Dart Domain Layer — Zero Flutter UI Imports (REQ-P53-NFR-04)

import 'dart:math' as math;
import 'studio_form_state.dart';

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

/// The 4 toggleable ecological layers in the bottom-left Network Layers HUD (REQ-P53-HUD-05).
enum MyceliumNetworkLayer {
  coreElements,
  supportingElements,
  atmosphere,
  emotionalLayer;

  String get displayName => switch (this) {
    coreElements => 'Core Elements',
    supportingElements => 'Supporting Elements',
    atmosphere => 'Atmosphere',
    emotionalLayer => 'Emotional Layer',
  };

  int get indicatorHex => switch (this) {
    coreElements => 0xFFFF9E00,       // Orange
    supportingElements => 0xFF00B4D8, // Cyan-Blue
    atmosphere => 0xFF9D4EDD,         // Violet
    emotionalLayer => 0xFF10B981,     // Emerald Green
  };
}

/// The 5 chronological song arrangement sections in Song Journey (REQ-P53-HUD-03).
enum SongJourneySection {
  intro,
  verse,
  chorus,
  bridge,
  outro;

  String get label => switch (this) {
    intro => 'Intro',
    verse => 'Verse',
    chorus => 'Chorus',
    bridge => 'Bridge',
    outro => 'Outro',
  };

  double get normalizedPosition => switch (this) {
    intro => 0.0,
    verse => 0.25,
    chorus => 0.50,
    bridge => 0.75,
    outro => 1.0,
  };
}

/// The 5-stage biological growth phase of the ecosystem (REQ-P53-GROWTH-01..05).
enum BiomeGrowthPhase {
  nucleusSeed,         // tau in [0.00, 0.12]
  primaryNodesEmerge,  // tau in [0.12, 0.30]
  hyphaeBranching,     // tau in [0.30, 0.62]
  fruitingBodiesSprout,// tau in [0.62, 0.90]
  ecosystemMature;     // tau in [0.90, 1.00]
}

/// The 6 foundational musical clusters in the Mycelium Ecosystem (REQ-P53-CORE-01..06).
enum MyceliumClusterDomain {
  melodyCore,
  rhythmNetwork,
  vocalNetwork,
  harmonyNetwork,
  emotionNetwork,
  productionNetwork;

  String get displayName => switch (this) {
    melodyCore => 'Melody Core',
    rhythmNetwork => 'Rhythm Network',
    vocalNetwork => 'Vocal Network',
    harmonyNetwork => 'Harmony Network',
    emotionNetwork => 'Emotion Network',
    productionNetwork => 'Production Network',
  };

  String get shortLabel => switch (this) {
    melodyCore => 'Melody Core',
    rhythmNetwork => 'Rhythm',
    vocalNetwork => 'Vocals',
    harmonyNetwork => 'Harmony',
    emotionNetwork => 'Emotion',
    productionNetwork => 'Production',
  };

  String get roleSubtitle => switch (this) {
    melodyCore => "The song's heartbeat & melodic DNA",
    rhythmNetwork => 'BPM, log-drum sub & syncopated groove',
    vocalNetwork => 'Lead vocals, Bantu dialect & voice LoRA',
    harmonyNetwork => 'Chords, African scales & tonal warmth',
    emotionNetwork => 'Mood, energy surge & harmonic tension',
    productionNetwork => 'Spatial acoustics, stem-lock & mix ceiling',
  };

  int get hexColor => switch (this) {
    melodyCore => 0xFFFF9E00,        // Golden-Amber
    rhythmNetwork => 0xFF00B4D8,     // Electric Blue-Cyan
    vocalNetwork => 0xFF9D4EDD,      // Bioluminescent Violet
    harmonyNetwork => 0xFF10B981,    // Vibrant Emerald
    emotionNetwork => 0xFFF72585,    // Magenta-Rose
    productionNetwork => 0xFF06D6A0, // Teal-Aqua
  };

  MyceliumNetworkLayer get networkLayer => switch (this) {
    melodyCore => MyceliumNetworkLayer.coreElements,
    rhythmNetwork => MyceliumNetworkLayer.coreElements,
    vocalNetwork => MyceliumNetworkLayer.emotionalLayer,
    harmonyNetwork => MyceliumNetworkLayer.supportingElements,
    emotionNetwork => MyceliumNetworkLayer.emotionalLayer,
    productionNetwork => MyceliumNetworkLayer.supportingElements,
  };

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

  /// Legacy root id alias for song DNA graph operations
  String get legacyBranchRootId => legacyBranchAliasKey;

  /// All associated lock keys (canonical + legacy).
  List<String> get allLockKeys => [studioBranchKey, legacyBranchAliasKey];

  /// Target 2D Studio Cockpit tab when teleporting from 3D Biome (REQ-P54-TELE-03).
  CockpitWorkspaceTab get targetCockpitTab => switch (this) {
    melodyCore => CockpitWorkspaceTab.compose,
    rhythmNetwork => CockpitWorkspaceTab.crateAndMpc,
    vocalNetwork => CockpitWorkspaceTab.voice,
    harmonyNetwork => CockpitWorkspaceTab.crateAndMpc,
    emotionNetwork => CockpitWorkspaceTab.compose,
    productionNetwork => CockpitWorkspaceTab.compose,
  };
}

/// Immutable 3D Vector in Right-Handed Y-Up World Space (X right, +Y up, +Z foreground).
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D get normalized {
    final len = length;
    return len > 1e-5 ? this * (1.0 / len) : const Vector3D(0, 1, 0);
  }

  double distanceTo(Vector3D o) => (this - o).length;

  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  static Vector3D lerp(Vector3D a, Vector3D b, double t) => Vector3D(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3D &&
          (x - other.x).abs() < 1e-4 &&
          (y - other.y).abs() < 1e-4 &&
          (z - other.z).abs() < 1e-4;

  @override
  int get hashCode => Object.hash(x.round(), y.round(), z.round());

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, ${z.toStringAsFixed(1)})';

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};

  factory Vector3D.fromJson(Map<String, dynamic> json) => Vector3D(
    (json['x'] as num?)?.toDouble() ?? 0.0,
    (json['y'] as num?)?.toDouble() ?? 0.0,
    (json['z'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Evaluates the continuous 3D Y-Up terrain elevation Y = h(X, Z) >= 0.
class BiomeTerrainMath {
  static const List<(double x, double z, double amp, double sigma)> mounds = [
    (0.0, 0.0, 30.0, 68.0),      // 1. melodyCore central mound
    (-195.0, 95.0, 20.0, 56.0),  // 2. rhythmNetwork FG-Left mound
    (-155.0, -90.0, 24.0, 58.0), // 3. vocalNetwork BG-Left mound
    (165.0, -85.0, 23.0, 58.0),  // 4. harmonyNetwork BG-Right mound
    (190.0, 75.0, 19.0, 54.0),   // 5. emotionNetwork MG-Right mound
    (-35.0, 155.0, 16.0, 52.0),  // 6. productionNetwork FG-Center mound
  ];

  /// Returns vertical elevation Y = h(X, Z) >= 0 in Y-Up world space.
  static double heightAt(double x, double z) {
    double sum = 0.0;
    for (final m in mounds) {
      final dx = x - m.$1;
      final dz = z - m.$2;
      final d2 = dx * dx + dz * dz;
      sum += m.$3 * math.exp(-d2 / (2.0 * m.$4 * m.$4));
    }
    final micro = 2.0 * (1.0 + math.sin(0.015 * x) * math.cos(0.018 * z));
    return sum + micro;
  }

  /// Evaluates upward unit surface normal vector in Y-Up world space.
  static Vector3D normalAt(double x, double z) {
    double dhDx = 0.0;
    double dhDz = 0.0;
    for (final m in mounds) {
      final dx = x - m.$1;
      final dz = z - m.$2;
      final d2 = dx * dx + dz * dz;
      final g = m.$3 * math.exp(-d2 / (2.0 * m.$4 * m.$4));
      dhDx -= (dx / (m.$4 * m.$4)) * g;
      dhDz -= (dz / (m.$4 * m.$4)) * g;
    }
    dhDx += 2.0 * 0.015 * math.cos(0.015 * x) * math.cos(0.018 * z);
    dhDz -= 2.0 * 0.018 * math.sin(0.015 * x) * math.sin(0.018 * z);

    // Normal = (-dh/dx, 1, -dh/dz) normalized
    return Vector3D(-dhDx, 1.0, -dhDz).normalized;
  }
}

/// Attached child leaf node inside a mushroom cluster canopy (REQ-P53-CORE-01..06).
class MyceliumChildNode {
  final String id;
  final MyceliumClusterDomain parentDomain;
  final String title;
  final String subtitle;
  final String iconIdentifier;
  final double intensityWeight; // 0.0 to 1.0
  final Vector3D localOffset;   // 3D offset relative to parent capApexPosition
  final bool isStemLocked;
  final String? studioMutatorKey;

  const MyceliumChildNode({
    required this.id,
    required this.parentDomain,
    required this.title,
    required this.subtitle,
    required this.iconIdentifier,
    required this.intensityWeight,
    required this.localOffset,
    this.isStemLocked = false,
    this.studioMutatorKey,
  });

  MyceliumChildNode copyWith({
    String? title,
    String? subtitle,
    double? intensityWeight,
    bool? isStemLocked,
  }) {
    return MyceliumChildNode(
      id: id,
      parentDomain: parentDomain,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconIdentifier: iconIdentifier,
      intensityWeight: intensityWeight ?? this.intensityWeight,
      localOffset: localOffset,
      isStemLocked: isStemLocked ?? this.isStemLocked,
      studioMutatorKey: studioMutatorKey,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'parentDomain': parentDomain.name,
    'title': title,
    'subtitle': subtitle,
    'iconIdentifier': iconIdentifier,
    'intensityWeight': intensityWeight,
    'localOffset': localOffset.toJson(),
    'isStemLocked': isStemLocked,
    if (studioMutatorKey != null) 'studioMutatorKey': studioMutatorKey,
  };

  factory MyceliumChildNode.fromJson(Map<String, dynamic> json) {
    final domainName = json['parentDomain']?.toString();
    final offsetRaw = json['localOffset'];
    return MyceliumChildNode(
      id: json['id']?.toString() ?? 'node_leaf_custom',
      parentDomain: MyceliumClusterDomain.values.firstWhere(
        (d) => d.name == domainName,
        orElse: () => MyceliumClusterDomain.harmonyNetwork,
      ),
      title: json['title']?.toString() ?? 'Instrument Leaf',
      subtitle: json['subtitle']?.toString() ?? 'Dynamic Instrument Leaf',
      iconIdentifier: json['iconIdentifier']?.toString() ?? 'musicNotes',
      intensityWeight:
          ((json['intensityWeight'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0),
      localOffset: offsetRaw is Map
          ? Vector3D.fromJson(Map<String, dynamic>.from(offsetRaw))
          : const Vector3D(34.0, 14.0, 0.0),
      isStemLocked: json['isStemLocked'] as bool? ?? false,
      studioMutatorKey: json['studioMutatorKey']?.toString(),
    );
  }
}

/// Represents one of the 6 Giant Mushroom Fruiting Bodies (Parent Cluster).
class MushroomFruitingBody {
  final MyceliumClusterDomain domain;
  final Vector3D rootPosition; // (X_k, h(X_k, Z_k), Z_k) in Y-Up space
  final double stipeHeight;    // H_stipe along +Y
  final double capRadius;      // R_cap
  final double capDepth;       // H_cap
  final double currentLuminosity; // 0.0 to 1.0
  final double dynamicPulseRate;  // Modulated by BPM
  final List<MyceliumChildNode> childLeaves;
  final List<MyceliumClusterDomain> connectedDomains;
  final int intensityPercent;  // 0..100
  final int complexityPercent; // 0..100
  final int influencePercent;  // 0..100
  final bool isStemLocked;
  final String liveTelemetrySummary;

  const MushroomFruitingBody({
    required this.domain,
    required this.rootPosition,
    required this.stipeHeight,
    required this.capRadius,
    required this.capDepth,
    required this.currentLuminosity,
    required this.dynamicPulseRate,
    required this.childLeaves,
    required this.connectedDomains,
    required this.intensityPercent,
    required this.complexityPercent,
    required this.influencePercent,
    this.isStemLocked = false,
    this.liveTelemetrySummary = '',
  });

  /// 3D Cap Apex position strictly in Y-Up World Space: Y_apex = Y_root + H_stipe.
  Vector3D get capApexPosition =>
      Vector3D(rootPosition.x, rootPosition.y + stipeHeight, rootPosition.z);

  StemLockMode get stemLockMode =>
      isStemLocked ? StemLockMode.lockedPure44k : StemLockMode.harmonicInpaint;

  double get confidence => intensityPercent / 100.0;

  MushroomFruitingBody copyWith({
    double? stipeHeight,
    double? capRadius,
    double? capDepth,
    double? currentLuminosity,
    double? dynamicPulseRate,
    List<MyceliumChildNode>? childLeaves,
    List<MyceliumClusterDomain>? connectedDomains,
    int? intensityPercent,
    int? complexityPercent,
    int? influencePercent,
    bool? isStemLocked,
    String? liveTelemetrySummary,
  }) {
    return MushroomFruitingBody(
      domain: domain,
      rootPosition: rootPosition,
      stipeHeight: stipeHeight ?? this.stipeHeight,
      capRadius: capRadius ?? this.capRadius,
      capDepth: capDepth ?? this.capDepth,
      currentLuminosity: currentLuminosity ?? this.currentLuminosity,
      dynamicPulseRate: dynamicPulseRate ?? this.dynamicPulseRate,
      childLeaves: childLeaves ?? this.childLeaves,
      connectedDomains: connectedDomains ?? this.connectedDomains,
      intensityPercent: intensityPercent ?? this.intensityPercent,
      complexityPercent: complexityPercent ?? this.complexityPercent,
      influencePercent: influencePercent ?? this.influencePercent,
      isStemLocked: isStemLocked ?? this.isStemLocked,
      liveTelemetrySummary: liveTelemetrySummary ?? this.liveTelemetrySummary,
    );
  }
}

/// Primary cross-cluster arterial mycelium filament (REQ-P53-MYCEL-01..03).
class MyceliumHyphaEdge {
  final String id;
  final MyceliumClusterDomain sourceDomain;
  final MyceliumClusterDomain targetDomain;
  final List<Vector3D> splineWaypoints; // 9 waypoints hugging Y = h(X, Z) + 1.5
  final double conductivityWeight;      // 0.45..1.0
  final bool isPrimaryArterial;
  final bool isStemLocked;
  final int photonCount;

  const MyceliumHyphaEdge({
    required this.id,
    required this.sourceDomain,
    required this.targetDomain,
    required this.splineWaypoints,
    required this.conductivityWeight,
    this.isPrimaryArterial = true,
    this.isStemLocked = false,
    this.photonCount = 4,
  });

  /// Evaluates piecewise linear / Catmull-Rom position along the 3D spline for t in [0, 1].
  Vector3D sampleAt(double t) {
    if (splineWaypoints.isEmpty) return const Vector3D(0, 0, 0);
    if (splineWaypoints.length == 1) return splineWaypoints.first;
    final clamped = t.clamp(0.0, 0.9999);
    final scaled = clamped * (splineWaypoints.length - 1);
    final idx = scaled.floor();
    final frac = scaled - idx;
    return Vector3D.lerp(splineWaypoints[idx], splineWaypoints[idx + 1], frac);
  }
}

/// Secondary/tertiary space-colonization branching rootlet tendril on the terrain floor.
class MyceliumRootTendril {
  final String id;
  final MyceliumClusterDomain originDomain;
  final List<Vector3D> waypoints; // 5 waypoints along Y = h(X, Z) + 0.8
  final double thickness;
  final double luminosity;

  const MyceliumRootTendril({
    required this.id,
    required this.originDomain,
    required this.waypoints,
    required this.thickness,
    required this.luminosity,
  });
}

/// Miniature 3D bioluminescent sprout/pinhead mushroom at hyphal junctions (REQ-P53-MYCEL-04).
class MyceliumSproutNode {
  final String id;
  final Vector3D rootPosition; // (X_s, h(X_s, Z_s), Z_s)
  final double height;         // 9.0..18.0 dp
  final double capRadius;      // 5.0..11.0 dp
  final int hexColor;
  final double pulsePhase;

  const MyceliumSproutNode({
    required this.id,
    required this.rootPosition,
    required this.height,
    required this.capRadius,
    required this.hexColor,
    required this.pulsePhase,
  });

  Vector3D get apexPosition =>
      Vector3D(rootPosition.x, rootPosition.y + height, rootPosition.z);
}

/// Complete immutable state of the 3D Musical Mycelium Biome Graph.
class MusicalDnaGraph {
  final Map<MyceliumClusterDomain, MushroomFruitingBody> clusters;
  final List<MyceliumHyphaEdge> hyphaeEdges;
  final List<MyceliumRootTendril> rootTendrils;
  final List<MyceliumSproutNode> sproutNodes;
  final MyceliumClusterDomain? focusedDomain;
  final String? selectedChildNodeId;
  final Set<MyceliumNetworkLayer> activeLayers;
  final SongJourneySection activeSection;
  final BiomeGrowthPhase growthPhase;
  final double growthProgress; // 0.0 to 1.0
  final bool isCompareModeActive;
  final bool isAnalyseOverlayActive;
  final int songFingerprintSeed;

  const MusicalDnaGraph({
    required this.clusters,
    required this.hyphaeEdges,
    required this.rootTendrils,
    required this.sproutNodes,
    this.focusedDomain,
    this.selectedChildNodeId,
    this.activeLayers = const {
      MyceliumNetworkLayer.coreElements,
      MyceliumNetworkLayer.supportingElements,
      MyceliumNetworkLayer.atmosphere,
      MyceliumNetworkLayer.emotionalLayer,
    },
    this.activeSection = SongJourneySection.chorus,
    this.growthPhase = BiomeGrowthPhase.ecosystemMature,
    this.growthProgress = 1.0,
    this.isCompareModeActive = false,
    this.isAnalyseOverlayActive = false,
    required this.songFingerprintSeed,
  });

  MushroomFruitingBody? get focusedCluster =>
      focusedDomain != null ? clusters[focusedDomain!] : null;

  /// Returns the currently inspected cluster (defaults to melodyCore when in overview).
  MushroomFruitingBody get activeInspectorCluster =>
      clusters[focusedDomain ?? MyceliumClusterDomain.melodyCore]!;

  bool isClusterLayerVisible(MyceliumClusterDomain domain) =>
      activeLayers.contains(domain.networkLayer);

  MusicalDnaGraph copyWith({
    Map<MyceliumClusterDomain, MushroomFruitingBody>? clusters,
    List<MyceliumHyphaEdge>? hyphaeEdges,
    List<MyceliumRootTendril>? rootTendrils,
    List<MyceliumSproutNode>? sproutNodes,
    MyceliumClusterDomain? focusedDomain,
    bool clearFocusedDomain = false,
    String? selectedChildNodeId,
    bool clearSelectedChildNode = false,
    Set<MyceliumNetworkLayer>? activeLayers,
    SongJourneySection? activeSection,
    BiomeGrowthPhase? growthPhase,
    double? growthProgress,
    bool? isCompareModeActive,
    bool? isAnalyseOverlayActive,
  }) {
    return MusicalDnaGraph(
      clusters: clusters ?? this.clusters,
      hyphaeEdges: hyphaeEdges ?? this.hyphaeEdges,
      rootTendrils: rootTendrils ?? this.rootTendrils,
      sproutNodes: sproutNodes ?? this.sproutNodes,
      focusedDomain:
          clearFocusedDomain ? null : (focusedDomain ?? this.focusedDomain),
      selectedChildNodeId: clearSelectedChildNode
          ? null
          : (selectedChildNodeId ?? this.selectedChildNodeId),
      activeLayers: activeLayers ?? this.activeLayers,
      activeSection: activeSection ?? this.activeSection,
      growthPhase: growthPhase ?? this.growthPhase,
      growthProgress: growthProgress ?? this.growthProgress,
      isCompareModeActive: isCompareModeActive ?? this.isCompareModeActive,
      isAnalyseOverlayActive:
          isAnalyseOverlayActive ?? this.isAnalyseOverlayActive,
      songFingerprintSeed: songFingerprintSeed,
    );
  }
}

/// The 3 hero visual surfaces in ExpandedCockpitModal (REQ-P55-HERO-01).
enum PlayerHeroMode {
  artwork,
  biome3d,
  lyrics;

  String get label => switch (this) {
    artwork => 'Artwork',
    biome3d => '3D Biome',
    lyrics => 'Lyrics',
  };
}

/// Pure Dart 60 FPS audio-reactive modulation state driving the 3D Mycelium Biome (REQ-P55-DSP-01..03).
class AudioBiomeModulationState {
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final double bassEnergy;
  final double drumsEnergy;
  final double melodicEnergy;
  final double vocalGlow;
  final double logDrumSnapZoom;
  final Map<MyceliumClusterDomain, double> clusterAudibleGains;
  final Set<MyceliumClusterDomain> soloedDomains;
  final Set<MyceliumClusterDomain> mutedDomains;

  const AudioBiomeModulationState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 1,
    this.bassEnergy = 0.0,
    this.drumsEnergy = 0.0,
    this.melodicEnergy = 0.0,
    this.vocalGlow = 0.0,
    this.logDrumSnapZoom = 0.0,
    this.clusterAudibleGains = const {},
    this.soloedDomains = const {},
    this.mutedDomains = const {},
  });

  static const AudioBiomeModulationState idle = AudioBiomeModulationState();

  /// Normalized playback progress ratio in [0.0, 1.0].
  double get progressRatio {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// Deterministically maps playback progress to the 5 SongJourneySection stages (REQ-P55-DSP-03).
  SongJourneySection get synchronizedJourneySection {
    final r = progressRatio;
    if (r < 0.15) return SongJourneySection.intro;
    if (r < 0.40) return SongJourneySection.verse;
    if (r < 0.70) return SongJourneySection.chorus;
    if (r < 0.85) return SongJourneySection.bridge;
    return SongJourneySection.outro;
  }

  /// True when a cluster is muted or non-soloed while another cluster is soloed (REQ-P55-DSP-02).
  bool isDomainDormant(MyceliumClusterDomain domain) {
    if (mutedDomains.contains(domain)) return true;
    if (soloedDomains.isNotEmpty && !soloedDomains.contains(domain)) {
      return true;
    }
    return false;
  }

  /// True when a cluster's mapped stem channel is explicitly soloed.
  bool isDomainSoloed(MyceliumClusterDomain domain) =>
      soloedDomains.contains(domain) && !mutedDomains.contains(domain);

  /// Evaluates real-time normalized acoustic energy in [0.0, 1.0] for [domain] (REQ-P55-DSP-01).
  double domainEnergyFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.0;
    final raw = switch (domain) {
      MyceliumClusterDomain.melodyCore => melodicEnergy,
      MyceliumClusterDomain.rhythmNetwork =>
        0.60 * bassEnergy + 0.40 * drumsEnergy,
      MyceliumClusterDomain.vocalNetwork => vocalGlow,
      MyceliumClusterDomain.harmonyNetwork =>
        0.50 * melodicEnergy + 0.50 * bassEnergy,
      MyceliumClusterDomain.productionNetwork =>
        0.50 * drumsEnergy + 0.50 * melodicEnergy,
      MyceliumClusterDomain.emotionNetwork =>
        1.40 * melodicEnergy * vocalGlow,
    };
    return raw.clamp(0.0, 1.0);
  }

  /// Evaluates radial cap dilation multiplier in [0.85, 1.32] for [domain] (REQ-P55-DSP-02).
  double capScaleMultiplierFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.86;
    final energy = domainEnergyFor(domain);
    final gain = (clusterAudibleGains[domain] ?? 1.0).clamp(0.0, 1.5);
    final soloBoost = isDomainSoloed(domain) ? 0.08 : 0.0;
    return (1.0 + 0.18 * energy * gain + soloBoost).clamp(0.85, 1.32);
  }

  /// Evaluates bioluminescent luminosity multiplier in [0.20, 1.35] for [domain] (REQ-P55-DSP-02).
  double luminosityMultiplierFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.20;
    final energy = domainEnergyFor(domain);
    if (isDomainSoloed(domain)) {
      return (1.15 + 0.20 * energy).clamp(1.00, 1.35);
    }
    return (0.85 + 0.30 * energy).clamp(0.50, 1.25);
  }

  /// Vertical stipe acoustic heave in world dp along +Y (REQ-P55-DSP-02).
  double stipeHeaveFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.0;
    return 6.5 * domainEnergyFor(domain);
  }

  /// Synaptic photon speed multiplier along arterial hyphae in [1.0, 5.0] (REQ-P55-DSP-02).
  double get photonSpeedMultiplier =>
      (1.0 + 2.5 * melodicEnergy + 1.5 * drumsEnergy).clamp(1.0, 5.0);

  /// Camera snap-zoom multiplier on log-drum transients in [1.0, 1.065] (REQ-P55-DSP-02).
  double get cameraSnapZoomMultiplier =>
      (1.0 + 0.065 * logDrumSnapZoom).clamp(1.0, 1.065);

  /// Floating spore cloud alpha in [0.35, 0.90].
  double get sporeCloudAlpha =>
      (0.35 + 0.55 * vocalGlow).clamp(0.35, 0.90);

  AudioBiomeModulationState copyWith({
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    double? bassEnergy,
    double? drumsEnergy,
    double? melodicEnergy,
    double? vocalGlow,
    double? logDrumSnapZoom,
    Map<MyceliumClusterDomain, double>? clusterAudibleGains,
    Set<MyceliumClusterDomain>? soloedDomains,
    Set<MyceliumClusterDomain>? mutedDomains,
  }) {
    return AudioBiomeModulationState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      bassEnergy: bassEnergy ?? this.bassEnergy,
      drumsEnergy: drumsEnergy ?? this.drumsEnergy,
      melodicEnergy: melodicEnergy ?? this.melodicEnergy,
      vocalGlow: vocalGlow ?? this.vocalGlow,
      logDrumSnapZoom: logDrumSnapZoom ?? this.logDrumSnapZoom,
      clusterAudibleGains: clusterAudibleGains ?? this.clusterAudibleGains,
      soloedDomains: soloedDomains ?? this.soloedDomains,
      mutedDomains: mutedDomains ?? this.mutedDomains,
    );
  }
}

