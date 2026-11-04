import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../features/creator_dna/domain/entities/creator_dna_profile.dart';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'totalCreditsTipped': totalCreditsTipped,
    'rank': rank,
  };

  factory SupporterEntity.fromJson(Map<String, dynamic> json) =>
      SupporterEntity(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        totalCreditsTipped: json['totalCreditsTipped'] as int? ?? 0,
        rank: json['rank'] as int? ?? 1,
      );
}

/// Single credit tip transaction in the creator ledger (REQ-TRK-16).
@immutable
class TipRecordEntity {
  final String id;
  final String senderName;
  final String senderHandle;
  final String recipientName;
  final int amountCredits;
  final int amountCoins;
  final double amountZar;
  final String giftEmoji;
  final String giftName;
  final String trackTitle;
  final DateTime timestamp;
  final bool isReceived;

  const TipRecordEntity({
    required this.id,
    required this.senderName,
    required this.senderHandle,
    required this.recipientName,
    required this.amountCredits,
    this.amountCoins = 0,
    this.amountZar = 0.0,
    this.giftEmoji = '🪙',
    this.giftName = 'Cultural Tip',
    required this.trackTitle,
    required this.timestamp,
    required this.isReceived,
  });

  String get amountLabel {
    if (amountCoins > 0) {
      return '$giftEmoji $amountCoins Coins (R${amountZar.toStringAsFixed(0)})';
    }
    return '⚡ $amountCredits';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'senderHandle': senderHandle,
    'recipientName': recipientName,
    'amountCredits': amountCredits,
    'amountCoins': amountCoins,
    'amountZar': amountZar,
    'giftEmoji': giftEmoji,
    'giftName': giftName,
    'trackTitle': trackTitle,
    'timestamp': timestamp.toIso8601String(),
    'isReceived': isReceived,
  };

  factory TipRecordEntity.fromJson(Map<String, dynamic> json) =>
      TipRecordEntity(
        id: json['id'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        senderHandle: json['senderHandle'] as String? ?? '',
        recipientName: json['recipientName'] as String? ?? '',
        amountCredits: json['amountCredits'] as int? ?? 0,
        amountCoins: json['amountCoins'] as int? ?? 0,
        amountZar: (json['amountZar'] as num?)?.toDouble() ?? 0.0,
        giftEmoji: json['giftEmoji'] as String? ?? '🪙',
        giftName: json['giftName'] as String? ?? 'Cultural Tip',
        trackTitle: json['trackTitle'] as String? ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        isReceived: json['isReceived'] as bool? ?? true,
      );
}

/// Discography bundle classification (REQ-TRK-15).
enum ReleaseType { single, ep, album }

/// 5-segment switcher for the Account Owner Creator Studio (Phase 33 REQ-PRF-04).
enum OwnerStudioTab {
  songs,
  reels,
  beatstore,
  voicesAndMelodies,
  releases;

  String get label => switch (this) {
    OwnerStudioTab.songs => 'Songs',
    OwnerStudioTab.reels => 'Reels',
    OwnerStudioTab.beatstore => 'Beatstore',
    OwnerStudioTab.voicesAndMelodies => 'Voices & Melodies',
    OwnerStudioTab.releases => 'Releases',
  };
}

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'releaseType': releaseType.name,
    'trackCount': trackCount,
    'releaseDate': releaseDate.toIso8601String(),
    'genre': genre,
  };

  factory MusicReleaseEntity.fromJson(Map<String, dynamic> json) =>
      MusicReleaseEntity(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        releaseType: ReleaseType.values.firstWhere(
          (e) => e.name == json['releaseType'],
          orElse: () => ReleaseType.single,
        ),
        trackCount: json['trackCount'] as int? ?? 1,
        releaseDate:
            DateTime.tryParse(json['releaseDate'] as String? ?? '') ??
            DateTime.now(),
        genre: json['genre'] as String? ?? '',
      );
}


/// Sovereign creator identity archetype defining craft specialization (Phase 39 REQ-ID-ARCH-01).
enum CreatorIdentityArchetype {
  dawProducer,
  naturalVocalist,
  liveInstrumentalist,
  kineticPerformer,
  aiSonicArchitect,
}

extension CreatorIdentityArchetypeExtension on CreatorIdentityArchetype {
  String get displayName => switch (this) {
    CreatorIdentityArchetype.dawProducer => 'DAW Producer',
    CreatorIdentityArchetype.naturalVocalist => 'Natural Vocalist',
    CreatorIdentityArchetype.liveInstrumentalist => 'Live Instrumentalist',
    CreatorIdentityArchetype.kineticPerformer => 'Kinetic Performer',
    CreatorIdentityArchetype.aiSonicArchitect => 'AI Sonic Architect',
  };

  IconData get icon => switch (this) {
    CreatorIdentityArchetype.dawProducer => PhosphorIconsRegular.slidersHorizontal,
    CreatorIdentityArchetype.naturalVocalist => PhosphorIconsRegular.microphone,
    CreatorIdentityArchetype.liveInstrumentalist => PhosphorIconsRegular.guitar,
    CreatorIdentityArchetype.kineticPerformer => PhosphorIconsRegular.personSimpleRun,
    CreatorIdentityArchetype.aiSonicArchitect => PhosphorIconsRegular.sparkle,
  };
}

/// Artist / creator identity used by both profile routes (design.md §1.3).
@immutable
class ArtistProfileEntity {
  final String id;
  final String username;
  final String displayName;
  final String monogram;
  final String? avatarUrl;
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
  final String? vocalArchetypeTitle;
  final String? vocalArchetypeLanguage;
  final String? vocalSampleUrl;
  final CreatorDnaProfile? creatorDna;
  final String? pinnedTrackId;
  final CreatorIdentityArchetype archetype;
  final int monthlyListenersCount;

  const ArtistProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.monogram,
    this.avatarUrl,
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
    this.vocalArchetypeTitle,
    this.vocalArchetypeLanguage,
    this.vocalSampleUrl,
    this.creatorDna,
    this.pinnedTrackId,
    this.archetype = CreatorIdentityArchetype.aiSonicArchitect,
    this.monthlyListenersCount = 14200,
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
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool clearAvatar = false,
    bool? isFollowing,
    bool? tipsEnabled,
    int? songCount,
    int? likeCount,
    int? playCount,
    int? followerCount,
    int? dayStreak,
    List<String>? topGenres,
    List<SupporterEntity>? topSupporters,
    List<MusicReleaseEntity>? releases,
    List<TipRecordEntity>? tipHistory,
    String? vocalArchetypeTitle,
    String? vocalArchetypeLanguage,
    String? vocalSampleUrl,
    CreatorDnaProfile? creatorDna,
    String? pinnedTrackId,
    CreatorIdentityArchetype? archetype,
    int? monthlyListenersCount,
    bool clearPinnedTrack = false,
  }) {
    return ArtistProfileEntity(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      monogram: displayName != null && displayName.isNotEmpty
          ? (displayName.length >= 2
                ? displayName.substring(0, 2).toUpperCase()
                : displayName.toUpperCase())
          : monogram,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      bio: bio ?? this.bio,
      isVerified: isVerified,
      songCount: songCount ?? this.songCount,
      likeCount: likeCount ?? this.likeCount,
      playCount: playCount ?? this.playCount,
      followerCount: followerCount ?? this.followerCount,
      dayStreak: dayStreak ?? this.dayStreak,
      isFollowing: isFollowing ?? this.isFollowing,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      topGenres: topGenres ?? this.topGenres,
      topSupporters: topSupporters ?? this.topSupporters,
      releases: releases ?? this.releases,
      tipHistory: tipHistory ?? this.tipHistory,
      vocalArchetypeTitle: vocalArchetypeTitle ?? this.vocalArchetypeTitle,
      vocalArchetypeLanguage:
          vocalArchetypeLanguage ?? this.vocalArchetypeLanguage,
      vocalSampleUrl: vocalSampleUrl ?? this.vocalSampleUrl,
      creatorDna: creatorDna ?? this.creatorDna,
      archetype: archetype ?? this.archetype,
      monthlyListenersCount: monthlyListenersCount ?? this.monthlyListenersCount,
      pinnedTrackId: clearPinnedTrack
          ? null
          : (pinnedTrackId ?? this.pinnedTrackId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'monogram': monogram,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'isVerified': isVerified,
    'songCount': songCount,
    'likeCount': likeCount,
    'playCount': playCount,
    'followerCount': followerCount,
    'dayStreak': dayStreak,
    'isFollowing': isFollowing,
    'tipsEnabled': tipsEnabled,
    'topGenres': topGenres,
    'topSupporters': topSupporters.map((s) => s.toJson()).toList(),
    'releases': releases.map((r) => r.toJson()).toList(),
    'tipHistory': tipHistory.map((t) => t.toJson()).toList(),
    'vocalArchetypeTitle': vocalArchetypeTitle,
    'vocalArchetypeLanguage': vocalArchetypeLanguage,
    'vocalSampleUrl': vocalSampleUrl,
    'pinnedTrackId': pinnedTrackId,
    'archetype': archetype.name,
    'monthlyListenersCount': monthlyListenersCount,
  };

  factory ArtistProfileEntity.fromJson(
    Map<String, dynamic> json,
  ) => ArtistProfileEntity(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    monogram: json['monogram'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    bio: json['bio'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? true,
    songCount: json['songCount'] as int? ?? 0,
    likeCount: json['likeCount'] as int? ?? 0,
    playCount: json['playCount'] as int? ?? 0,
    followerCount: json['followerCount'] as int? ?? 0,
    dayStreak: json['dayStreak'] as int? ?? 1,
    isFollowing: json['isFollowing'] as bool? ?? false,
    tipsEnabled: json['tipsEnabled'] as bool? ?? true,
    topGenres:
        (json['topGenres'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    pinnedTrackId: json['pinnedTrackId'] as String?,
    archetype: json['archetype'] != null ? CreatorIdentityArchetype.values.firstWhere((e) => e.name == json['archetype'], orElse: () => CreatorIdentityArchetype.aiSonicArchitect) : CreatorIdentityArchetype.aiSonicArchitect,
    monthlyListenersCount: json['monthlyListenersCount'] as int? ?? 14200,
    vocalArchetypeTitle: json['vocalArchetypeTitle'] as String?,
    vocalArchetypeLanguage: json['vocalArchetypeLanguage'] as String?,
    vocalSampleUrl: json['vocalSampleUrl'] as String?,
    topSupporters:
        (json['topSupporters'] as List<dynamic>?)
            ?.map(
              (e) =>
                  SupporterEntity.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    releases:
        (json['releases'] as List<dynamic>?)
            ?.map(
              (e) => MusicReleaseEntity.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        const [],
    tipHistory:
        (json['tipHistory'] as List<dynamic>?)
            ?.map(
              (e) =>
                  TipRecordEntity.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
  );
}
