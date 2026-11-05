import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const Object _dnaSentinel = Object();

/// The 4 hierarchical node classes in the Quantum Song DNA architecture (REQ-P50-GRAPH-01).
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

  Color get defaultColor => color;

  String get label => switch (this) {
        SongDnaNodeCategory.beatCore => 'Beat & Genesis Core',
        SongDnaNodeCategory.vocalLyrics => 'Vocal Timbre & Lyrics',
        SongDnaNodeCategory.instrumentsHarmony => 'Instruments & Harmony',
        SongDnaNodeCategory.invasiveThirdParty => 'Invasive 3rd-Party Audio',
      };

  String get displayName => label;
}

/// 3D Vector for node coordinates in the spatial canvas.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  Vector3D copyWith({double? x, double? y, double? z}) =>
      Vector3D(x ?? this.x, y ?? this.y, z ?? this.z);

  Vector3D operator +(Vector3D other) =>
      Vector3D(x + other.x, y + other.y, z + other.z);

  Vector3D operator -(Vector3D other) =>
      Vector3D(x - other.x, y - other.y, z - other.z);

  Vector3D operator *(double scalar) =>
      Vector3D(x * scalar, y * scalar, z * scalar);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D get normalized {
    final len = length;
    if (len == 0) return const Vector3D(0, 0, 0);
    return Vector3D(x / len, y / len, z / len);
  }

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;
}

/// An additive satellite sub-node (e.g. for Sketchpad channels or MPC chops).
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

/// Represents an interactive 3D genomic locus in the Song DNA tree (REQ-P50-GRAPH-01..04).
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
  bool get isUnlocked => branchUnlockProgress > 0.0;
  Color get glowColor => accentColor;

  SongDnaNode copyWith({
    String? title,
    String? subtitle,
    String? cueLabel,
    double? branchUnlockProgress,
    List<SongDnaSubNode>? subNodes,
    Vector3D? localPosition,
  }) {
    return SongDnaNode(
      id: id,
      category: category,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      cueLabel: cueLabel ?? this.cueLabel,
      icon: icon,
      accentColor: accentColor,
      branchUnlockProgress: branchUnlockProgress ?? this.branchUnlockProgress,
      isAdditive: isAdditive,
      isInvasive: isInvasive,
      isDetachable: isDetachable,
      localPosition: localPosition ?? this.localPosition,
      subNodes: subNodes ?? this.subNodes,
    );
  }
}

/// Immutable state for the Quantum-Entangled 3D Song DNA graph (REQ-P50-GRAPH-05).
class SongDnaGraphState {
  final List<SongDnaNode> nodes;
  final String? selectedNodeId;
  final int activeInvasiveNodesCount;
  final double overallCompleteness;
  final Color primaryGlowColor;

  const SongDnaGraphState({
    required this.nodes,
    this.selectedNodeId,
    required this.activeInvasiveNodesCount,
    required this.overallCompleteness,
    required this.primaryGlowColor,
  });

  SongDnaNode? get selectedNode {
    for (final node in nodes) {
      if (node.id == selectedNodeId) return node;
    }
    return nodes.isNotEmpty ? nodes.first : null;
  }

  SongDnaGraphState copyWith({
    List<SongDnaNode>? nodes,
    Object? selectedNodeId = _dnaSentinel,
    int? activeInvasiveNodesCount,
    double? overallCompleteness,
    Color? primaryGlowColor,
  }) {
    return SongDnaGraphState(
      nodes: nodes ?? this.nodes,
      selectedNodeId: identical(selectedNodeId, _dnaSentinel)
          ? this.selectedNodeId
          : selectedNodeId as String?,
      activeInvasiveNodesCount:
          activeInvasiveNodesCount ?? this.activeInvasiveNodesCount,
      overallCompleteness: overallCompleteness ?? this.overallCompleteness,
      primaryGlowColor: primaryGlowColor ?? this.primaryGlowColor,
    );
  }
}
