import 'package:flutter/foundation.dart';

/// Top tipping fan on the supporter leaderboard (REQ-TRK-14).
@immutable
class SupporterEntity {
  final String id;
  final String name;
  final String handle;
  final int totalCreditsTipped;
  final int rank;

  const SupporterEntity({
    required this.id,
    required this.name,
    required this.handle,
    required this.totalCreditsTipped,
    required this.rank,
  });

  String get rankBadge {
    return switch (rank) {
      1 => '🥇 Gold',
      2 => '🥈 Silver',
      3 => '🥉 Bronze',
      _ => 'Fan',
    };
  }
}

/// Single credit tip transaction in the creator ledger (REQ-TRK-16).
@immutable
class TipRecordEntity {
  final String id;
  final String senderName;
  final String senderHandle;
  final String recipientName;
  final int amountCredits;
  final String trackTitle;
  final DateTime timestamp;
  final bool isReceived;

  const TipRecordEntity({
    required this.id,
    required this.senderName,
    required this.senderHandle,
    required this.recipientName,
    required this.amountCredits,
    required this.trackTitle,
    required this.timestamp,
    required this.isReceived,
  });
}

/// Discography bundle classification (REQ-TRK-15).
enum ReleaseType { single, ep, album }

@immutable
class MusicReleaseEntity {
  final String id;
  final String title;
  final ReleaseType releaseType;
  final int trackCount;
  final DateTime releaseDate;
  final String genre;

  const MusicReleaseEntity({
    required this.id,
    required this.title,
    required this.releaseType,
    required this.trackCount,
    required this.releaseDate,
    required this.genre,
  });

  String get typeLabel {
    return switch (releaseType) {
      ReleaseType.single => 'Single',
      ReleaseType.ep => 'EP',
      ReleaseType.album => 'Album',
    };
  }

  String get releaseYear => '${releaseDate.year}';
}

/// Artist / creator identity used by both profile routes (design.md §1.3).
@immutable
class ArtistProfileEntity {
  final String id;
  final String username;
  final String displayName;
  final String monogram;
  final String bio;
  final bool isVerified;
  final int songCount;
  final int likeCount;
  final int playCount;
  final int followerCount;
  final int dayStreak;
  final bool isFollowing;
  final bool tipsEnabled;
  final List<String> topGenres;
  final List<SupporterEntity> topSupporters;
  final List<MusicReleaseEntity> releases;
  final List<TipRecordEntity> tipHistory;

  const ArtistProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.monogram,
    this.bio = '',
    this.isVerified = true,
    this.songCount = 0,
    this.likeCount = 0,
    this.playCount = 0,
    this.followerCount = 0,
    this.dayStreak = 1,
    this.isFollowing = false,
    this.tipsEnabled = true,
    this.topGenres = const [],
    this.topSupporters = const [],
    this.releases = const [],
    this.tipHistory = const [],
  });

  String get handle => '@$username';

  /// Public referral URL copied by the referral card (REQ-TRK-16).
  String get profileUrl => 'https://vhunambi.com/profile/$username';

  String get streakLabel => '🔥 $dayStreak';

  List<TipRecordEntity> get receivedTips =>
      tipHistory.where((tip) => tip.isReceived).toList();

  List<TipRecordEntity> get sentTips =>
      tipHistory.where((tip) => !tip.isReceived).toList();

  ArtistProfileEntity copyWith({
    bool? isFollowing,
    bool? tipsEnabled,
    int? followerCount,
    List<MusicReleaseEntity>? releases,
    List<TipRecordEntity>? tipHistory,
  }) {
    return ArtistProfileEntity(
      id: id,
      username: username,
      displayName: displayName,
      monogram: monogram,
      bio: bio,
      isVerified: isVerified,
      songCount: songCount,
      likeCount: likeCount,
      playCount: playCount,
      followerCount: followerCount ?? this.followerCount,
      dayStreak: dayStreak,
      isFollowing: isFollowing ?? this.isFollowing,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      topGenres: topGenres,
      topSupporters: topSupporters,
      releases: releases ?? this.releases,
      tipHistory: tipHistory ?? this.tipHistory,
    );
  }
}
