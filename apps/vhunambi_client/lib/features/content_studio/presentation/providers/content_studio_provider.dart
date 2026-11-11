import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/sovereign_auth_session.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/sovereign_domain_repositories.dart';
import '../../domain/models/song_metadata_dna.dart';
import '../../domain/models/content_studio_preset.dart';
import '../../domain/models/lyric_word_timestamp.dart';
import '../../domain/services/i_video_export_service.dart';
import '../../data/services/cloud_video_export_service.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/domain/repositories/i_social_repository.dart';
import '../../../social/presentation/providers/social_feed_provider.dart';
import '../../../social/presentation/providers/social_repository_provider.dart';

final videoExportServiceProvider = Provider<IVideoExportService>((ref) {
  return CloudVideoExportService(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

class ContentStudioState {
  final SongMetadataDna? dna;
  final String? audioUrl;
  final String? coverArtUrl;
  final List<LyricWordTimestamp> words;
  final LyricTypographyPreset typographyPreset;
  final DurationPreset durationPreset;
  final double startSeconds;
  final double endSeconds;
  final AtmosphericEffects effects;
  final bool isPlaying;
  final double playbackPositionSec;
  final bool isExporting;
  final double exportProgress;
  final String? exportedFilePath;
  final String? errorMessage;

  /// Share URL of the most recently published clip (REQ-SOC-05 celebration).
  final String? publishedShareUrl;

  const ContentStudioState({
    this.dna,
    this.audioUrl,
    this.coverArtUrl,
    this.words = const [],
    this.typographyPreset = LyricTypographyPreset.kineticBounce,
    this.durationPreset = DurationPreset.reel30s,
    this.startSeconds = 0.0,
    this.endSeconds = 30.0,
    this.effects = const AtmosphericEffects(),
    this.isPlaying = false,
    this.playbackPositionSec = 0.0,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportedFilePath,
    this.errorMessage,
    this.publishedShareUrl,
  });

  ContentStudioState copyWith({
    SongMetadataDna? dna,
    String? audioUrl,
    String? coverArtUrl,
    List<LyricWordTimestamp>? words,
    LyricTypographyPreset? typographyPreset,
    DurationPreset? durationPreset,
    double? startSeconds,
    double? endSeconds,
    AtmosphericEffects? effects,
    bool? isPlaying,
    double? playbackPositionSec,
    bool? isExporting,
    double? exportProgress,
    String? exportedFilePath,
    String? errorMessage,
    String? publishedShareUrl,
  }) {
    return ContentStudioState(
      dna: dna ?? this.dna,
      audioUrl: audioUrl ?? this.audioUrl,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      words: words ?? this.words,
      typographyPreset: typographyPreset ?? this.typographyPreset,
      durationPreset: durationPreset ?? this.durationPreset,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      effects: effects ?? this.effects,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPositionSec: playbackPositionSec ?? this.playbackPositionSec,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      errorMessage: errorMessage,
      publishedShareUrl: publishedShareUrl ?? this.publishedShareUrl,
    );
  }
}

class ContentStudioNotifier extends StateNotifier<ContentStudioState> {
  final IVideoExportService _exportService;

  /// Injected social feed sink for optimistic in-house publishing (T2.4).
  final SocialFeedNotifier? _socialFeed;

  /// Injected social repository for backend persistence and remix propagation (Phase C & D).
  final ISocialRepository? _socialRepo;

  /// Active sovereign auth session reader for multi-tenant attribution (`Phase 61`).
  final SovereignAuthSession Function()? _readAuthSession;

  ContentStudioNotifier(
    this._exportService, [
    this._socialFeed,
    this._socialRepo,
    this._readAuthSession,
  ]) : super(_initialState());

  static ContentStudioState _initialState() {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.studioSessionBoxKey,
    )) {
      return const ContentStudioState();
    }
    final raw = SovereignPrefsRepository.loadContentStudioDraft('active');
    if (raw == null || raw.isEmpty) return const ContentStudioState();
    try {
      final rawDna = raw['dna'];
      final dna = rawDna is Map
          ? SongMetadataDna.fromJson(Map<String, dynamic>.from(rawDna))
          : null;
      final rawWords = raw['words'] as List<dynamic>?;
      final words = rawWords != null
          ? rawWords
                .whereType<Map>()
                .map(
                  (e) =>
                      LyricWordTimestamp.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const <LyricWordTimestamp>[];
      final presetName = raw['typographyPreset']?.toString();
      final typographyPreset = LyricTypographyPreset.values.firstWhere(
        (p) => p.name == presetName,
        orElse: () => LyricTypographyPreset.kineticBounce,
      );
      final durName = raw['durationPreset']?.toString();
      final durationPreset = DurationPreset.values.firstWhere(
        (p) => p.name == durName,
        orElse: () => DurationPreset.reel30s,
      );
      final rawEffects = raw['effects'];
      final effects = rawEffects is Map
          ? AtmosphericEffects.fromJson(Map<String, dynamic>.from(rawEffects))
          : const AtmosphericEffects();

      return ContentStudioState(
        dna: dna,
        audioUrl: raw['audioUrl'] as String?,
        coverArtUrl: raw['coverArtUrl'] as String?,
        words: words,
        typographyPreset: typographyPreset,
        durationPreset: durationPreset,
        startSeconds: (raw['startSeconds'] as num?)?.toDouble() ?? 0.0,
        endSeconds: (raw['endSeconds'] as num?)?.toDouble() ?? 30.0,
        effects: effects,
        publishedShareUrl: raw['publishedShareUrl'] as String?,
      );
    } catch (_) {
      return const ContentStudioState();
    }
  }

  void _persistDraft() {
    final payload = <String, dynamic>{
      if (state.dna != null) 'dna': state.dna!.toJson(),
      if (state.audioUrl != null) 'audioUrl': state.audioUrl,
      if (state.coverArtUrl != null) 'coverArtUrl': state.coverArtUrl,
      'words': state.words.map((w) => w.toJson()).toList(),
      'typographyPreset': state.typographyPreset.name,
      'durationPreset': state.durationPreset.name,
      'startSeconds': state.startSeconds,
      'endSeconds': state.endSeconds,
      'effects': state.effects.toJson(),
      if (state.publishedShareUrl != null)
        'publishedShareUrl': state.publishedShareUrl,
    };
    unawaited(
      SovereignPrefsRepository.saveContentStudioDraft('active', payload),
    );
    final dnaId = state.dna?.id;
    if (dnaId != null && dnaId.isNotEmpty) {
      unawaited(
        SovereignPrefsRepository.saveContentStudioDraft(dnaId, payload),
      );
    }
  }

  static bool _isTestEnv() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _normalizeStudioMediaUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('/mock-storage/')) {
      return AppConstants.normalizeCloudMediaUrl(trimmed);
    }
    if (!_isTestEnv() ||
        AppConstants.configuredApiBaseUrl.trim().isNotEmpty ||
        AppConstants.configuredMediaBaseUrl.trim().isNotEmpty) {
      return AppConstants.normalizeCloudMediaUrl(trimmed);
    }
    return trimmed;
  }

  void initializeWithDna({
    required SongMetadataDna dna,
    required String audioUrl,
    required String coverArtUrl,
  }) {
    final maxDuration = dna.musical.durationSec.toDouble();
    final initialEnd = maxDuration > 30.0 ? 30.0 : maxDuration;

    // Genre-Aware Smart Defaults:
    // Auto-tunes typography animation and atmospheric shaders to the acoustic identity
    final genre = dna.genre.toLowerCase();
    LyricTypographyPreset defaultPreset = LyricTypographyPreset.kineticBounce;
    AtmosphericEffects defaultEffects = const AtmosphericEffects();

    if (genre.contains('amapiano')) {
      // Amapiano: Luminous Glow + Bass-Reactive log drum pulse + Ken Burns slow drift
      defaultPreset = LyricTypographyPreset.luminousGlow;
      defaultEffects = const AtmosphericEffects(
        filmGrain: false,
        bassPulse: true,
        kenBurnsMotion: true,
      );
    } else if (genre.contains('gqom') || genre.contains('drill')) {
      // Gqom / Drill: Kinetic Bounce + 35mm gritty film grain + bass pulse
      defaultPreset = LyricTypographyPreset.kineticBounce;
      defaultEffects = const AtmosphericEffects(
        filmGrain: true,
        bassPulse: true,
        kenBurnsMotion: false,
      );
    } else if (genre.contains('maskandi') ||
        genre.contains('soul') ||
        genre.contains('venda') ||
        genre.contains('tshivenḓa') ||
        genre.contains('traditional')) {
      // African Folk / Soul / Traditional: Bantu Calligraphy + Ken Burns motion
      defaultPreset = LyricTypographyPreset.bantuCalligraphy;
      defaultEffects = const AtmosphericEffects(
        filmGrain: false,
        bassPulse: false,
        kenBurnsMotion: true,
      );
    } else if (genre.contains('afro') || genre.contains('pop')) {
      // Afro-Pop: Minimal Subtitle + Bass-Reactive pulse + Ken Burns motion
      defaultPreset = LyricTypographyPreset.minimalSubtitle;
      defaultEffects = const AtmosphericEffects(
        filmGrain: false,
        bassPulse: true,
        kenBurnsMotion: true,
      );
    }

    state = state.copyWith(
      dna: dna,
      audioUrl: _normalizeStudioMediaUrl(audioUrl),
      coverArtUrl: _normalizeStudioMediaUrl(coverArtUrl),
      words: dna.alignment,
      typographyPreset: defaultPreset,
      effects: defaultEffects,
      startSeconds: 0.0,
      endSeconds: initialEnd,
      playbackPositionSec: 0.0,
      isPlaying: false,
      exportedFilePath: null,
      errorMessage: null,
    );
    _persistDraft();
  }

  void setPreset(LyricTypographyPreset preset) {
    state = state.copyWith(typographyPreset: preset);
    _persistDraft();
  }

  void setDurationPreset(DurationPreset preset) {
    final maxSec = state.dna?.musical.durationSec.toDouble() ?? 180.0;
    final target = preset.targetSeconds.toDouble();
    final newEnd = (state.startSeconds + target) > maxSec
        ? maxSec
        : state.startSeconds + target;
    state = state.copyWith(durationPreset: preset, endSeconds: newEnd);
    _persistDraft();
  }

  void setTrimBounds(double start, double end) {
    final clampedStart = start < 0.0 ? 0.0 : start;
    final maxSec = state.dna?.musical.durationSec.toDouble() ?? 180.0;
    final clampedEnd = end > maxSec
        ? maxSec
        : (end <= clampedStart ? clampedStart + 1.0 : end);
    state = state.copyWith(startSeconds: clampedStart, endSeconds: clampedEnd);
    _persistDraft();
  }

  void toggleEffect({bool? filmGrain, bool? bassPulse, bool? kenBurnsMotion}) {
    state = state.copyWith(
      effects: state.effects.copyWith(
        filmGrain: filmGrain,
        bassPulse: bassPulse,
        kenBurnsMotion: kenBurnsMotion,
      ),
    );
    _persistDraft();
  }

  void updatePlaybackPosition(double sec) {
    final clamped = sec.clamp(state.startSeconds, state.endSeconds);
    state = state.copyWith(playbackPositionSec: clamped);
  }

  void seekTo(double sec) {
    updatePlaybackPosition(sec);
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void reRollCoverArt(String newCoverArtUrl) {
    state = state.copyWith(
      coverArtUrl: _normalizeStudioMediaUrl(newCoverArtUrl),
    );
    _persistDraft();
  }

  Future<void> exportVideo() async {
    if (state.isExporting) return;
    if (state.audioUrl == null || state.coverArtUrl == null) {
      state = state.copyWith(
        errorMessage: 'Cannot export: Audio or Cover Art is missing.',
      );
      return;
    }

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      errorMessage: null,
    );

    try {
      final path = await _exportService.exportLyricVideo(
        audioUrl: state.audioUrl!,
        coverArtUrl: state.coverArtUrl!,
        words: state.words,
        startSec: state.startSeconds,
        endSec: state.endSeconds,
        preset: state.typographyPreset,
        effects: state.effects,
        onProgress: (progress) {
          state = state.copyWith(exportProgress: progress);
        },
      );
      state = state.copyWith(
        isExporting: false,
        exportProgress: 1.0,
        exportedFilePath: path,
      );
    } catch (e) {
      state = state.copyWith(isExporting: false, errorMessage: e.toString());
    }
  }

  /// 1-tap in-house publish (REQ-SOC-01 … REQ-SOC-05): builds a [PublishedClip]
  /// from the current studio session and optimistically injects it into the
  /// social feed. Returns the created clip, or null when the session lacks a
  /// compiled DNA / audio. The clip's `dna` powers zero-video in-house
  /// playback — no MP4 is required (REQ-SOC-26).
  PublishedClip? publishClipToProfile({
    required String caption,
    required List<String> tags,
    ClipVisibility visibility = ClipVisibility.public,
    String? remixedFromClipId,
    String? remixAttribution,
  }) {
    final dna = state.dna;
    final audioUrl = state.audioUrl;
    if (dna == null || audioUrl == null) {
      state = state.copyWith(
        errorMessage: 'Cannot publish: song DNA or audio is missing.',
      );
      return null;
    }

    final session = _readAuthSession?.call();
    final creatorId = session?.canonicalCreatorId ?? 'creator_cern';
    final creatorUsername = session?.rawUsername ?? 'cern';
    final creatorDisplayName = session?.displayName ?? 'cern';

    final clipId = 'clip_pub_local_${DateTime.now().millisecondsSinceEpoch}';
    final clip = PublishedClip(
      id: clipId,
      trackId: 'track_${clipId.split('_').last}',
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorDisplayName: creatorDisplayName,
      isCreatorVerified: true,
      title: dna.title,
      caption: caption,
      tags: tags,
      genre: dna.genre,
      audioUrl: audioUrl,
      coverUrl: state.coverArtUrl ?? '',
      dna: dna,
      remixedFromClipId: remixedFromClipId,
      remixAttribution: remixAttribution,
      publishedAt: DateTime.now(),
    );

    // Optimistic local injection — the clip appears instantly in the feed and
    // on the creator profile (REQ-SOC-04).
    _socialFeed?.prependClip(clip);

    // Fire backend sync for viral remix propagation
    _socialRepo?.publishClip({
      'trackId': clip.trackId,
      'title': clip.title,
      'caption': clip.caption,
      'tags': clip.tags,
      'visibility': visibility.name,
      'dna': clip.dna.toJson(),
      'creatorId': clip.creatorId,
      'creatorUsername': clip.creatorUsername,
      'creatorDisplayName': clip.creatorDisplayName,
      'audioUrl': clip.audioUrl,
      'coverUrl': clip.coverUrl,
      'remixedFromClipId': ?remixedFromClipId,
      'remixAttribution': ?remixAttribution,
    });

    state = state.copyWith(
      publishedShareUrl: clip.shareUrl,
      errorMessage: null,
    );
    _persistDraft();
    return clip;
  }

  void reset() {
    final oldDnaId = state.dna?.id;
    state = const ContentStudioState();
    unawaited(SovereignPrefsRepository.clearContentStudioDraft('active'));
    if (oldDnaId != null && oldDnaId.isNotEmpty) {
      unawaited(SovereignPrefsRepository.clearContentStudioDraft(oldDnaId));
    }
  }
}

final contentStudioProvider =
    StateNotifierProvider<ContentStudioNotifier, ContentStudioState>((ref) {
      ref.watch(currentCreatorIdProvider);
      final exportService = ref.watch(videoExportServiceProvider);
      final socialFeed = ref.read(socialFeedProvider.notifier);
      final socialRepo = ref.watch(socialRepositoryProvider);
      return ContentStudioNotifier(
        exportService,
        socialFeed,
        socialRepo,
        () => ref.read(authSessionProvider),
      );
    });
