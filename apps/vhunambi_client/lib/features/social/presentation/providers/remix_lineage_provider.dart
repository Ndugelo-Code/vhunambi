import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../domain/models/stem_remix_context.dart';

/// A single node in the genealogical remix tree (REQ-RMX-TREE-01 / Phase 37).
@immutable
class RemixNode {
  final String id;
  final String title;
  final String creatorId;
  final String creatorHandle;
  final String creatorDisplayName;
  final String? creatorAvatarUrl;
  final bool isVerified;
  final String genre;
  final int bpm;
  final String musicalKey;
  final RemixCreationMode? remixMode;
  final int depth;
  final String audioUrl;
  final String coverUrl;
  final int playCount;
  final int likeCount;
  final List<SplitParticipant> coCreationSplits;
  final List<RemixNode> children;

  const RemixNode({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.creatorHandle,
    required this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.isVerified = false,
    required this.genre,
    this.bpm = 112,
    this.musicalKey = 'F#m',
    this.remixMode,
    this.depth = 0,
    required this.audioUrl,
    required this.coverUrl,
    this.playCount = 0,
    this.likeCount = 0,
    this.coCreationSplits = const [],
    this.children = const [],
  });

  /// Total count of all descendant remixes beneath this node.
  int get totalDescendantsCount {
    var count = children.length;
    for (final child in children) {
      count += child.totalDescendantsCount;
    }
    return count;
  }

  /// Human-readable lineage descriptor.
  String get lineageDescriptor {
    if (depth == 0) return 'Root Original Track · Stems Open';
    return switch (remixMode) {
      RemixCreationMode.openVerseVocal => 'Open Verse Vocal',
      RemixCreationMode.beatStemFlip => 'Beat & Drum Stem-Flip',
      RemixCreationMode.aiStudioRemix || null => 'Full Studio Remix',
    };
  }

  RemixNode copyWith({
    String? id,
    String? title,
    String? creatorId,
    String? creatorHandle,
    String? creatorDisplayName,
    String? creatorAvatarUrl,
    bool? isVerified,
    String? genre,
    int? bpm,
    String? musicalKey,
    RemixCreationMode? remixMode,
    int? depth,
    String? audioUrl,
    String? coverUrl,
    int? playCount,
    int? likeCount,
    List<SplitParticipant>? coCreationSplits,
    List<RemixNode>? children,
  }) {
    return RemixNode(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorId: creatorId ?? this.creatorId,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      creatorDisplayName: creatorDisplayName ?? this.creatorDisplayName,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      isVerified: isVerified ?? this.isVerified,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      remixMode: remixMode ?? this.remixMode,
      depth: depth ?? this.depth,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      coCreationSplits: coCreationSplits ?? this.coCreationSplits,
      children: children ?? this.children,
    );
  }
}

/// Seeded 3-node remix tree for Makhadzi's viral hit "Ndo Mufuna Matibe" (REQ-RMX-TREE-01).
final RemixNode kSeedMakhadziRemixTree = RemixNode(
  id: 'post_001',
  title: 'Ndo Mufuna Matibe',
  creatorId: 'creator_makhadzi',
  creatorHandle: '@makhadzi',
  creatorDisplayName: 'Makhadzi',
  isVerified: true,
  genre: 'Amapiano',
  bpm: 112,
  musicalKey: 'F#m',
  depth: 0,
  audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-matibe.mp3',
  coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
  playCount: 12450,
  likeCount: 1840,
  coCreationSplits: const [
    SplitParticipant(
      name: 'Makhadzi',
      role: 'Original Producer & Vocalist',
      sharePercent: 100.0,
      creatorId: 'creator_makhadzi',
      handle: '@makhadzi',
    ),
  ],
  children: [
    RemixNode(
      id: 'post_001_remix_fifi',
      title: 'Ndo Mufuna Matibe (Open Verse)',
      creatorId: 'creator_fifi',
      creatorHandle: '@fifi_vocals',
      creatorDisplayName: 'Fifi Vocals',
      isVerified: true,
      genre: 'Amapiano',
      bpm: 112,
      musicalKey: 'F#m',
      remixMode: RemixCreationMode.openVerseVocal,
      depth: 1,
      audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-verse.mp3',
      coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
      playCount: 4310,
      likeCount: 620,
      coCreationSplits: const [
        SplitParticipant(
          name: 'Fifi Vocals',
          role: 'Vocalist (Remixer)',
          sharePercent: 70.0,
          creatorId: 'creator_fifi',
          handle: '@fifi_vocals',
        ),
        SplitParticipant(
          name: 'Makhadzi',
          role: 'Original Producer',
          sharePercent: 30.0,
          creatorId: 'creator_makhadzi',
          handle: '@makhadzi',
        ),
      ],
      children: [
        RemixNode(
          id: 'node_remix_kwaito',
          title: 'Ndo Mufuna (Kwaito Rhodes Flip)',
          creatorId: 'creator_kwaito',
          creatorHandle: '@soweto_kwaito',
          creatorDisplayName: 'Soweto Kwaito',
          genre: 'Kwaito',
          bpm: 108,
          musicalKey: 'F#m',
          remixMode: RemixCreationMode.beatStemFlip,
          depth: 2,
          audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-kwaito.mp3',
          coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
          playCount: 2150,
          likeCount: 310,
          coCreationSplits: const [
            SplitParticipant(
              name: 'Soweto Kwaito',
              role: 'Remixer / Beat Maker',
              sharePercent: 50.0,
              creatorId: 'creator_kwaito',
              handle: '@soweto_kwaito',
            ),
            SplitParticipant(
              name: 'Fifi Vocals',
              role: 'Vocalist',
              sharePercent: 30.0,
              creatorId: 'creator_fifi',
              handle: '@fifi_vocals',
            ),
            SplitParticipant(
              name: 'Makhadzi',
              role: 'Original Producer',
              sharePercent: 20.0,
              creatorId: 'creator_makhadzi',
              handle: '@makhadzi',
            ),
          ],
        ),
      ],
    ),
    RemixNode(
      id: 'node_remix_bongz',
      title: 'Ndo Mufuna Matibe (Gqom 128 BPM Stem Flip)',
      creatorId: 'creator_djbongz',
      creatorHandle: '@dj_bongz',
      creatorDisplayName: 'DJ Bongz Durban',
      isVerified: true,
      genre: 'Gqom',
      bpm: 128,
      musicalKey: 'F#m',
      remixMode: RemixCreationMode.beatStemFlip,
      depth: 1,
      audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-gqom.mp3',
      coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
      playCount: 8920,
      likeCount: 1140,
      coCreationSplits: const [
        SplitParticipant(
          name: 'DJ Bongz',
          role: 'Gqom Producer (Remixer)',
          sharePercent: 70.0,
          creatorId: 'creator_djbongz',
          handle: '@dj_bongz',
        ),
        SplitParticipant(
          name: 'Makhadzi',
          role: 'Original Producer',
          sharePercent: 30.0,
          creatorId: 'creator_makhadzi',
          handle: '@makhadzi',
        ),
      ],
    ),
  ],
);

/// Provider resolving the genealogical lineage tree for any track or remix node.
final remixLineageTreeProvider =
    Provider.family<RemixNode, String>((ref, trackOrClipId) {
  // If querying for the seed root or any of its descendants, return the seed tree
  if (trackOrClipId == 'post_001' ||
      trackOrClipId == 'exp_track_002' ||
      trackOrClipId == 'post_001_remix_fifi' ||
      trackOrClipId == 'node_remix_bongz' ||
      trackOrClipId == 'node_remix_kwaito') {
    return kSeedMakhadziRemixTree;
  }

  // Fallback tree for other tracks
  return RemixNode(
    id: trackOrClipId,
    title: 'Original Track',
    creatorId: 'creator_default',
    creatorHandle: '@artist',
    creatorDisplayName: 'Artist',
    genre: 'Amapiano',
    depth: 0,
    audioUrl: '',
    coverUrl: '',
    children: const [],
  );
});

