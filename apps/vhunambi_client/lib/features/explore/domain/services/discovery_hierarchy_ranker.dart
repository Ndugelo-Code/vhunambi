import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../shared/models/track.dart';
import '../models/social_music_post.dart';

/// 3-Stage Discovery Hierarchy Tiers (Phase 39 REQ-DISC-TIER-01).
enum DiscoveryStageTier {
  mainstage,
  risingBreakout,
  freshCrate,
}

extension DiscoveryStageTierExtension on DiscoveryStageTier {
  String get displayName => switch (this) {
    DiscoveryStageTier.mainstage => 'Mainstage',
    DiscoveryStageTier.risingBreakout => 'Rising Breakout',
    DiscoveryStageTier.freshCrate => 'Fresh Crate',
  };

  String get description => switch (this) {
    DiscoveryStageTier.mainstage =>
      'Top 10% velocity hits, viral stem remixes & verified releases',
    DiscoveryStageTier.risingBreakout =>
      'Fast-climbing grooves & high collaborative engagement',
    DiscoveryStageTier.freshCrate =>
      'Fresh vocal takes, open verse invites & community drops',
  };

  IconData get icon => switch (this) {
    DiscoveryStageTier.mainstage => PhosphorIconsRegular.flame,
    DiscoveryStageTier.risingBreakout => PhosphorIconsRegular.trendUp,
    DiscoveryStageTier.freshCrate => PhosphorIconsRegular.sparkle,
  };
}

/// Result of evaluating a post's multi-factor discovery velocity (REQ-DISC-RANK-01).
class DiscoveryRankResult {
  final SocialMusicPost post;
  final double score;
  final DiscoveryStageTier tier;

  const DiscoveryRankResult({
    required this.post,
    required this.score,
    required this.tier,
  });
}

/// Discovery Hierarchy Ranker scoring algorithm for the Explore feed.
///
/// Prevents feed degradation by separating raw uncurated drops into Fresh Crate
/// while reserving Mainstage for high-completion, co-created African music.
abstract final class DiscoveryHierarchyRanker {
  /// Evaluates and scores [post] on a 0–100 scale:
  /// - 30% Completion / Play Velocity
  /// - 25% Co-Creation Remix & Repost Pull
  /// - 20% Creator Influence / Monthly Listeners
  /// - 15% Follower Graph Boost
  /// - 10% Craft / Provenance Bonus (DAW masters & live vocals get +15 points)
  static DiscoveryRankResult rank(SocialMusicPost post) {
    // 1. Completion & Play Velocity (0–100)
    final playVelocity = (post.track.playCount * 0.5).clamp(0.0, 100.0);

    // 2. Co-Creation Remix & Repost Pull (0–100)
    final coCreationPull =
        ((post.remixCount * 12.0) + (post.repostCount * 6.0)).clamp(0.0, 100.0);

    // 3. Creator Influence / Monthly Listeners (0–100)
    final creatorInfluence =
        ((post.likeCount * 0.5) + (post.isCreatorVerified ? 20.0 : 0.0))
            .clamp(0.0, 100.0);

    // 4. Follower Graph Boost (0–100)
    final graphBoost =
        (post.isFollowingCreator ? 40.0 : 0.0) + (post.likeCount > 20 ? 30.0 : 10.0);

    // 5. Craft & Provenance Bonus (0–100)
    final craftBonus = switch (post.provenanceType) {
      AudioProvenanceType.humanDawMaster => 100.0,
      AudioProvenanceType.liveVocalRecording => 100.0,
      AudioProvenanceType.liveInstrumentStem => 90.0,
      AudioProvenanceType.hybridCoCreation => 75.0,
      AudioProvenanceType.aiGenerated => 50.0,
    };

    final cosignBonus = (post.cosignCount * 1.5).clamp(0.0, 30.0);
    final totalScore = ((playVelocity * 0.30) +
        (coCreationPull * 0.25) +
        (creatorInfluence * 0.20) +
        (graphBoost * 0.15) +
        (craftBonus * 0.10) +
        cosignBonus).clamp(0.0, 100.0);

    final baseTier = totalScore >= 45.0
        ? DiscoveryStageTier.mainstage
        : (totalScore >= 20.0
            ? DiscoveryStageTier.risingBreakout
            : DiscoveryStageTier.freshCrate);

    // Graduation loop: 25+ community co-signs automatically promote Fresh Crate to Rising Breakout
    final tier = (post.cosignCount >= 25 && baseTier == DiscoveryStageTier.freshCrate)
        ? DiscoveryStageTier.risingBreakout
        : baseTier;

    return DiscoveryRankResult(
      post: post,
      score: double.parse(totalScore.toStringAsFixed(1)),
      tier: tier,
    );
  }

  /// Filters [posts] by [tier]. If [tier] is null, all posts are returned unchanged.
  static List<SocialMusicPost> filterByTier(
    List<SocialMusicPost> posts,
    DiscoveryStageTier? tier,
  ) {
    if (tier == null) return posts;
    return posts.where((p) => rank(p).tier == tier).toList();
  }
}

