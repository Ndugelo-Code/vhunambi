import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/tokens/vhunambi_mood.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../core/utils/json_safe.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../player/domain/models/stem_mixer_state.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import '../../domain/models/track_detail_models.dart';

/// Track dissection record for `/track/:id` (REQ-TRK-01 … REQ-TRK-11).
final trackDetailFamilyProvider =
    StateNotifierProvider.family<
      TrackDetailNotifier,
      TrackDetailEntity,
      String
    >((ref, trackId) {
      return TrackDetailNotifier(trackId, ref: ref);
    });

/// Discussion thread for a track (REQ-TRK-11).
final trackCommentsProvider =
    StateNotifierProvider.family<
      TrackCommentsNotifier,
      List<CommentEntity>,
      String
    >((ref, trackId) {
      return TrackCommentsNotifier(trackId, ref: ref);
    });

/// Genre recommendations shown in the `More Like This` shelf (REQ-TRK-11).
final moreLikeThisProvider = Provider.family<List<TrackDetailEntity>, String>((
  ref,
  trackId,
) {
  final current = ref.watch(trackDetailFamilyProvider(trackId));
  return List.unmodifiable(
    seededTrackDetails
        .where((track) => track.genre == current.genre && track.id != trackId)
        .toList(),
  );
});

class TrackDetailNotifier extends StateNotifier<TrackDetailEntity> {
  final String trackId;
  final Ref? ref;

  TrackDetailNotifier(this.trackId, {this.ref})
    : super(_lookupInitialTrack(trackId, ref: ref));

  /// Optimistically toggles the like state and tally (REQ-TRK-04).
  void toggleLike() {
    final newLiked = !state.isLiked;
    state = state.copyWith(
      isLiked: newLiked,
      likesCount: state.likesCount + (newLiked ? 1 : -1),
    );
    if (newLiked) {
      try {
        ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_track_like_${state.id}',
                title: 'Liked "${state.title}"',
                message:
                    'Hearted ${state.creatorHandle}\'s track in Track Cockpit.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'post_like',
                targetRoute: '/track/${state.id}',
                targetEntityId: state.id,
                ctaLabel: 'Open Track Cockpit',
                createdAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
  }

  /// Toggles one of the 5 cultural emoji reactions (REQ-TRK-06).
  void toggleReaction(String reactionKey) {
    final userReactions = Set<String>.from(state.userReactions);
    final reactions = Map<String, int>.from(state.reactions);

    if (userReactions.contains(reactionKey)) {
      userReactions.remove(reactionKey);
      final next = (reactions[reactionKey] ?? 1) - 1;
      reactions[reactionKey] = next < 0 ? 0 : next;
    } else {
      userReactions.add(reactionKey);
      reactions[reactionKey] = (reactions[reactionKey] ?? 0) + 1;
    }

    state = state.copyWith(userReactions: userReactions, reactions: reactions);
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

  /// Hydrates real R2 stem URLs from `GET /v1/generations/:id/manifest` (`EP-P25`).
  Future<List<StemTrackEntity>?> loadManifestFromCloud({
    http.Client? client,
    String? apiBaseUrl,
  }) async {
    if (_isTestEnv() && client == null) return null;

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final origin = AppConstants.resolveApiRootUrl(overrideOrigin: apiBaseUrl);

    try {
      final headers = <String, String>{};
      if (ref != null) {
        try {
          headers.addAll(ref!.read(authHeadersProvider));
        } catch (_) {}
      }
      final uri = Uri.parse('$origin/v1/generations/$trackId/manifest');
      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = JsonSafe.decodeMap(response.body);
      if (body == null) return null;

      final masteringMap = JsonSafe.asMap(
        body['masteringMetrics'] ?? body['mastering_metrics'],
      );
      final svcMap = JsonSafe.asMap(body['svcMetrics'] ?? body['svc_metrics']);
      final rawLufs =
          masteringMap['integratedLufs'] ?? masteringMap['integrated_lufs'];
      final integratedLufs = rawLufs is num
          ? rawLufs.toDouble()
          : double.tryParse(JsonSafe.asString(rawLufs));
      final masteringProfile = JsonSafe.asString(
        masteringMap['profileId'] ?? masteringMap['profile_id'],
      );
      final attributionTag = JsonSafe.asString(
        body['attributionTag'] ?? body['attribution_tag'],
      );
      final rawSr =
          body['sampleRateHz'] ??
          body['sample_rate_hz'] ??
          masteringMap['sampleRateHz'] ??
          masteringMap['sample_rate_hz'];
      final sampleRateHz = rawSr is num
          ? rawSr.toInt()
          : int.tryParse(JsonSafe.asString(rawSr));
      final rawCloneApplied = svcMap['applied'];
      final voiceCloneApplied = rawCloneApplied is bool
          ? rawCloneApplied
          : JsonSafe.asString(rawCloneApplied).toLowerCase() == 'true';

      final rawRepaintList = body['repaintHistory'] ?? body['repaint_history'];
      final parsedRepaintHistory = <TrackRepaintEntry>[];
      if (rawRepaintList is List) {
        for (final item in rawRepaintList) {
          final m = JsonSafe.asMap(item);
          final rpId = JsonSafe.asString(m['repaintId'] ?? m['repaint_id']);
          if (rpId.isEmpty) continue;
          final sRaw = m['startSec'] ?? m['start_sec'];
          final eRaw = m['endSec'] ?? m['end_sec'];
          parsedRepaintHistory.add(
            TrackRepaintEntry(
              repaintId: rpId,
              task: JsonSafe.asString(m['task'], 'repaint'),
              startSec: sRaw is num
                  ? sRaw.toDouble()
                  : (double.tryParse('$sRaw') ?? 0.0),
              endSec: eRaw is num
                  ? eRaw.toDouble()
                  : (double.tryParse('$eRaw') ?? 8.0),
              targetStem: JsonSafe.asString(
                m['targetStem'] ?? m['target_stem'],
                'full',
              ),
              createdAtIso: JsonSafe.asString(
                m['createdAtIso'] ?? m['created_at_iso'],
              ),
            ),
          );
        }
      }

      final loraMap = JsonSafe.asMap(
        body['loraMetrics'] ?? body['lora_metrics'],
      );
      final parsedActiveLoras = <String>[];
      final loadedList = loraMap['loadedLoras'] ?? loraMap['loaded_loras'];
      if (loadedList is List) {
        for (final entry in loadedList) {
          final m = JsonSafe.asMap(entry);
          final isLoaded = m['loaded'] is bool ? m['loaded'] as bool : false;
          final loraId = JsonSafe.asString(m['loraId'] ?? m['lora_id']);
          if (isLoaded &&
              loraId.isNotEmpty &&
              !parsedActiveLoras.contains(loraId)) {
            parsedActiveLoras.add(loraId);
          }
        }
      }
      final rawActiveLoras = body['activeLoras'] ?? body['active_loras'];
      if (rawActiveLoras is List) {
        for (final entry in rawActiveLoras) {
          final id = JsonSafe.asString(entry);
          if (id.isNotEmpty && !parsedActiveLoras.contains(id)) {
            parsedActiveLoras.add(id);
          }
        }
      }

      final rawTakesList = body['takes'];
      final parsedTakes = <TrackTakeRecord>[];
      if (rawTakesList is List) {
        for (var idx = 0; idx < rawTakesList.length; idx++) {
          final m = JsonSafe.asMap(rawTakesList[idx]);
          final tUrl = JsonSafe.asString(m['audioUrl'] ?? m['audio_url']);
          if (tUrl.isEmpty) continue;
          final rawIdx = m['takeIndex'] ?? m['take_index'];
          final rawSeed = m['seed'];
          final rawScore = m['score'];
          parsedTakes.add(
            TrackTakeRecord(
              takeIndex: rawIdx is num ? rawIdx.toInt() : idx,
              seed: rawSeed is num ? rawSeed.toInt() : (idx + 1),
              engineUsed: JsonSafe.asString(
                m['engineUsed'] ?? m['engine_used'],
                'ace_step_xl_base',
              ),
              audioUrl: AppConstants.normalizeCloudMediaUrl(
                tUrl,
                overrideOrigin: origin,
              ),
              score: rawScore is num ? rawScore.toDouble() : null,
              attribution: JsonSafe.asString(m['attribution']).isEmpty
                  ? null
                  : JsonSafe.asString(m['attribution']),
            ),
          );
        }
      }

      if (integratedLufs != null ||
          masteringProfile.isNotEmpty ||
          attributionTag.isNotEmpty ||
          sampleRateHz != null ||
          voiceCloneApplied ||
          parsedRepaintHistory.isNotEmpty ||
          parsedActiveLoras.isNotEmpty ||
          parsedTakes.isNotEmpty) {
        if (!mounted) return null;
        state = state.copyWith(
          integratedLufs: integratedLufs ?? state.integratedLufs,
          masteringProfile: masteringProfile.isNotEmpty
              ? masteringProfile
              : state.masteringProfile,
          attributionTag: attributionTag.isNotEmpty
              ? attributionTag
              : state.attributionTag,
          sampleRateHz: sampleRateHz ?? state.sampleRateHz,
          voiceCloneApplied: voiceCloneApplied || state.voiceCloneApplied,
          repaintHistory: parsedRepaintHistory.isNotEmpty
              ? parsedRepaintHistory
              : state.repaintHistory,
          activeLoras: parsedActiveLoras.isNotEmpty
              ? parsedActiveLoras
              : state.activeLoras,
          takes: parsedTakes.isNotEmpty ? parsedTakes : state.takes,
        );
      }

      final assets = JsonSafe.asMap(body['assets']);
      final stemUrls = JsonSafe.asMap(assets['stemUrls']);
      if (stemUrls.isEmpty) return null;

      String resolveStem(String rawKey, String fallbackSuffix) {
        final raw = JsonSafe.asString(rawKey);
        final mediaBase = AppConstants.resolveMediaBaseUrl(
          overrideOrigin: origin,
        );
        if (raw.isEmpty) {
          return '$mediaBase/stems/${trackId}_$fallbackSuffix.wav';
        }
        if (!raw.contains('://') && !raw.startsWith('/')) {
          return '$mediaBase/$raw';
        }
        return AppConstants.normalizeCloudMediaUrl(raw, overrideOrigin: origin);
      }

      final vUrl = resolveStem(JsonSafe.asString(stemUrls['vocals']), 'vocals');
      final dUrl = resolveStem(JsonSafe.asString(stemUrls['drums']), 'drums');
      final bUrl = resolveStem(JsonSafe.asString(stemUrls['bass']), 'bass');
      final iRaw = JsonSafe.asString(stemUrls['instrumental']).isNotEmpty
          ? JsonSafe.asString(stemUrls['instrumental'])
          : JsonSafe.asString(stemUrls['melodic']).isNotEmpty
          ? JsonSafe.asString(stemUrls['melodic'])
          : JsonSafe.asString(stemUrls['other']);
      final iUrl = resolveStem(iRaw, 'inst');

      return [
        StemTrackEntity(
          id: '${trackId}_vocals',
          name: 'Vocals',
          audioUrl: vUrl,
          duration: state.duration,
        ),
        StemTrackEntity(
          id: '${trackId}_drums',
          name: 'Drums',
          audioUrl: dUrl,
          duration: state.duration,
        ),
        StemTrackEntity(
          id: '${trackId}_bass',
          name: 'Bass & Log Drums',
          audioUrl: bUrl,
          duration: state.duration,
        ),
        StemTrackEntity(
          id: '${trackId}_inst',
          name: 'Instrumental',
          audioUrl: iUrl,
          duration: state.duration,
        ),
      ];
    } catch (err) {
      debugPrint('[TrackDetail] loadManifestFromCloud fallback: $err');
      return null;
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  /// Selects an alternate multi-take output (`EP-P81-MULTITAKE-AR-SCORER`) on Track Detail.
  void selectTake(int index) {
    if (index < 0 || index >= state.takes.length) return;
    final chosen = state.takes[index];
    state = state.copyWith(
      selectedTakeIndex: index,
      audioUrl: chosen.audioUrl,
      attributionTag: chosen.attribution ?? state.attributionTag,
    );
  }

  /// Dispatches `POST /v1/generations/:id/repaint` (`EP-P83-ACE-STEP-SECTION-REPAINT`).
  Future<String?> submitSectionRepaint({
    required double startSec,
    required double endSec,
    String task = 'repaint',
    String targetStem = 'full',
    Map<String, String>? stemLocks,
    String? editPrompt,
    String? editLyrics,
    List<Map<String, dynamic>>? loras,
    http.Client? client,
    String? apiBaseUrl,
  }) async {
    if (endSec - startSec < 2.0) {
      return 'Repaint window must be at least 2 seconds.';
    }
    if (_isTestEnv() && client == null) {
      final localId = 'gen_repaint_${DateTime.now().millisecondsSinceEpoch}';
      final entry = TrackRepaintEntry(
        repaintId: localId,
        task: task,
        startSec: startSec,
        endSec: endSec,
        targetStem: targetStem,
        createdAtIso: DateTime.now().toIso8601String(),
      );
      state = state.copyWith(
        repaintHistory: <TrackRepaintEntry>[...state.repaintHistory, entry],
      );
      return null;
    }

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final origin = AppConstants.resolveApiRootUrl(overrideOrigin: apiBaseUrl);

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (ref != null) {
        try {
          headers.addAll(ref!.read(authHeadersProvider));
        } catch (_) {}
      }
      final uri = Uri.parse('$origin/v1/generations/$trackId/repaint');
      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'startSec': startSec,
              'endSec': endSec,
              'task': task,
              'targetStem': targetStem,
              if (stemLocks != null && stemLocks.isNotEmpty)
                'stemLocks': stemLocks,
              if (editPrompt != null && editPrompt.trim().isNotEmpty)
                'editPrompt': editPrompt.trim(),
              if (editLyrics != null && editLyrics.trim().isNotEmpty)
                'editLyrics': editLyrics.trim(),
              if (loras != null && loras.isNotEmpty) 'loras': loras,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Section repaint failed (${response.statusCode}).';
      }

      final data = JsonSafe.decodeMap(response.body) ?? <String, dynamic>{};
      final rpId = JsonSafe.asString(
        data['generationId'],
        'gen_repaint_${DateTime.now().millisecondsSinceEpoch}',
      );
      final loraIds = <String>[...state.activeLoras];
      if (loras != null) {
        for (final l in loras) {
          final id = JsonSafe.asString(l['loraId']);
          if (id.isNotEmpty && !loraIds.contains(id)) {
            loraIds.add(id);
          }
        }
      }
      state = state.copyWith(
        repaintHistory: <TrackRepaintEntry>[
          ...state.repaintHistory,
          TrackRepaintEntry(
            repaintId: rpId,
            task: task,
            startSec: startSec,
            endSec: endSec,
            targetStem: targetStem,
            createdAtIso: DateTime.now().toIso8601String(),
          ),
        ],
        activeLoras: loraIds,
      );
      return null;
    } catch (err) {
      debugPrint('[TrackDetail] submitSectionRepaint error: $err');
      return 'Unable to reach section repaint engine.';
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  /// Runs the 4-step stem isolation pipeline (REQ-TRK-09 / REQ-TRK-STEM-01).
  Future<void> separateStems({http.Client? client, String? apiBaseUrl}) async {
    if (state.stemState.isProcessing) return;

    /// Advances the FSM through the documented step ladder.
    Future<void> advance(StemSeparationStatus status, double progress) async {
      state = state.copyWith(
        stemState: state.stemState.copyWith(status: status, progress: progress),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    await advance(StemSeparationStatus.isolatingVocals, 0.25);
    await advance(StemSeparationStatus.isolatingDrums, 0.50);
    await advance(StemSeparationStatus.isolatingBass, 0.75);
    final cloudStems = await loadManifestFromCloud(
      client: client,
      apiBaseUrl: apiBaseUrl,
    );
    await advance(StemSeparationStatus.isolatingInstrumental, 0.90);

    final mediaBase = AppConstants.resolveMediaBaseUrl(
      overrideOrigin: apiBaseUrl,
    );
    final resolvedStems =
        cloudStems ??
        [
          StemTrackEntity(
            id: '${trackId}_vocals',
            name: 'Vocals',
            audioUrl: '$mediaBase/stems/${trackId}_vocals.wav',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_drums',
            name: 'Drums',
            audioUrl: '$mediaBase/stems/${trackId}_drums.wav',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_bass',
            name: 'Bass & Log Drums',
            audioUrl: '$mediaBase/stems/${trackId}_bass.wav',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_inst',
            name: 'Instrumental',
            audioUrl: '$mediaBase/stems/${trackId}_inst.wav',
            duration: state.duration,
          ),
        ];

    state = state.copyWith(
      stemState: StemSeparationState(
        status: StemSeparationStatus.ready,
        progress: 1.0,
        stems: resolvedStems,
      ),
    );
  }

  void toggleMuteStem(String stemId) {
    final stems = state.stemState.stems
        .map(
          (stem) =>
              stem.id == stemId ? stem.copyWith(isMuted: !stem.isMuted) : stem,
        )
        .toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));

    if (ref != null) {
      final stemType = _mapStemIdToType(stemId);
      if (stemType != null) {
        ref!.read(stemMixerProvider.notifier).toggleMute(stemType);
      }
    }
  }

  void toggleSoloStem(String stemId) {
    final stems = state.stemState.stems
        .map(
          (stem) => stem.id == stemId
              ? stem.copyWith(isSoloed: !stem.isSoloed)
              : stem,
        )
        .toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));

    if (ref != null) {
      final stemType = _mapStemIdToType(stemId);
      if (stemType != null) {
        ref!.read(stemMixerProvider.notifier).toggleSolo(stemType);
      }
    }
  }

  static StemType? _mapStemIdToType(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('vocal')) return StemType.vocals;
    if (lower.contains('drum')) return StemType.drums;
    if (lower.contains('bass')) return StemType.bass;
    if (lower.contains('inst') || lower.contains('melody')) {
      return StemType.melody;
    }
    return null;
  }
}

class TrackCommentsNotifier extends StateNotifier<List<CommentEntity>> {
  final String trackId;
  final Ref? ref;

  TrackCommentsNotifier(this.trackId, {this.ref})
    : super(_lookupInitialComments(trackId));

  void addComment(
    String content, {
    String authorName = 'Ndugelo',
    String authorHandle = '@ndugelo',
  }) {
    if (content.trim().isEmpty) return;
    final newComment = CommentEntity(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      trackId: trackId,
      authorName: authorName,
      authorHandle: authorHandle,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    state = [newComment, ...state];
    try {
      ref
          ?.read(notificationsProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: 'notif_track_cmt_${newComment.id}',
              title: 'Commented on Track',
              message: '"${newComment.content}" added to track discussion.',
              category: NotificationCategory.social,
              priority: NotificationPriority.normal,
              subtype: 'comment',
              targetRoute: '/track/$trackId',
              targetEntityId: trackId,
              ctaLabel: 'Open Track Cockpit',
              createdAt: newComment.createdAt,
            ),
          );
    } catch (_) {}
  }

  void toggleLikeComment(String commentId) {
    state = state.map((c) {
      if (c.id == commentId) {
        final newLiked = !c.isLiked;
        return CommentEntity(
          id: c.id,
          trackId: c.trackId,
          authorName: c.authorName,
          authorHandle: c.authorHandle,
          content: c.content,
          createdAt: c.createdAt,
          likesCount: c.likesCount + (newLiked ? 1 : -1),
          isLiked: newLiked,
        );
      }
      return c;
    }).toList();
  }
}

int _defaultBpmForGenre(String genre) {
  return switch (genre.trim().toLowerCase()) {
    'gqom' => 127,
    'afro house' || 'afro-house' => 122,
    'maskandi' => 106,
    'kwaito' => 104,
    'afrobeats' || 'afro pop' || 'afro-pop' => 108,
    _ => 113,
  };
}

String _defaultKeyForGenre(String genre) {
  return switch (genre.trim().toLowerCase()) {
    'gqom' => 'Cm',
    'afro house' || 'afro-house' => 'Am',
    'maskandi' => 'G',
    'kwaito' => 'Dm',
    _ => 'F#m',
  };
}

TrackDetailEntity _lookupInitialTrack(String trackId, {Ref? ref}) {
  if (ref != null) {
    // 1. Check User Library Vault (real generated & saved tracks)
    try {
      final libraryTracks = ref.read(libraryTracksProvider);
      for (final lt in libraryTracks) {
        if (lt.id == trackId) {
          final handleSlug = lt.creatorName.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          );
          final isLegacyAiStudio =
              lt.creatorName.trim().toLowerCase() == 'ai studio' ||
              (lt.creatorId ?? '').trim().toLowerCase() == 'ai_studio' ||
              (lt.creatorId ?? '').trim().toLowerCase() ==
                  'creator_ai_studio' ||
              (lt.creatorHandle ?? '').trim().toLowerCase() == '@aistudio';
          var resolvedCreatorId = isLegacyAiStudio
              ? canonicalizeCreatorId(ref.read(currentCreatorIdProvider))
              : (lt.creatorId != null && lt.creatorId!.trim().isNotEmpty)
              ? canonicalizeCreatorId(lt.creatorId!)
              : canonicalizeCreatorId(
                  lt.creatorName,
                  fallback: 'creator_$handleSlug',
                );
          var resolvedCreatorName = lt.creatorName;
          var resolvedHandle =
              (lt.creatorHandle != null && lt.creatorHandle!.trim().isNotEmpty)
              ? lt.creatorHandle!.trim()
              : handleFromCreatorId(resolvedCreatorId);
          if (isLegacyAiStudio) {
            final activeHandle = ref.read(currentCreatorHandleProvider).trim();
            resolvedHandle = activeHandle.isNotEmpty
                ? (activeHandle.startsWith('@')
                      ? activeHandle
                      : '@$activeHandle')
                : handleFromCreatorId(resolvedCreatorId);
            resolvedCreatorName = extractRawCreatorId(resolvedCreatorId);
          }
          final canonicalMood = VhunambiMood.normalize(lt.moodId ?? lt.mood);
          return TrackDetailEntity(
            id: lt.id,
            title: lt.title,
            genre: lt.genre,
            language: lt.language,
            duration: Duration(
              seconds: lt.durationSeconds > 0 ? lt.durationSeconds : 180,
            ),
            creatorId: resolvedCreatorId,
            creatorName: resolvedCreatorName,
            creatorHandle: resolvedHandle,
            playCount: lt.playCount,
            coverUrl: lt.coverImageUrl,
            audioUrl: lt.remoteAudioUrl,
            createdAt: lt.createdAt,
            bpm: (lt.bpm != null && lt.bpm! > 0)
                ? lt.bpm!
                : _defaultBpmForGenre(lt.genre),
            musicalKey: _defaultKeyForGenre(lt.genre),
            moodId: canonicalMood.moodId,
            description:
                (lt.description != null && lt.description!.trim().isNotEmpty)
                ? lt.description!
                : 'Mastered ${lt.genre} studio composition performed in ${lt.language}.',
            allowOpenStemsRemix: lt.allowOpenStemsRemix,
            lyrics: lt.lyrics ?? '[Instrumental / AI Studio Track]',
            prompt:
                'Synthesized in Vhunambi Studio (${lt.genre} · ${lt.language})',
          );
        }
      }
    } catch (_) {}

    // 2. Check Explore Discovery Catalog
    try {
      final exploreTracks = ref.read(exploreTracksProvider);
      for (final et in exploreTracks) {
        if (et.id == trackId) {
          final resolvedCreatorId = canonicalizeCreatorId(
            et.creatorHandle ?? et.creatorName,
          );
          return TrackDetailEntity(
            id: et.id,
            title: et.title,
            genre: et.genre,
            language: et.language,
            duration: et.duration,
            creatorId: resolvedCreatorId,
            creatorName: et.creatorName,
            creatorHandle:
                et.creatorHandle ?? handleFromCreatorId(resolvedCreatorId),
            playCount: et.playCount,
            likesCount: et.likeCount,
            coverUrl: et.coverUrl,
            audioUrl: et.audioUrl,
            bpm: _defaultBpmForGenre(et.genre),
            musicalKey: _defaultKeyForGenre(et.genre),
            moodId: VhunambiMood.normalize(et.mood).moodId,
            description:
                '${et.title} by ${et.creatorName} — ${et.genre} production recorded in ${et.language}.',
            lyrics: '[${et.title} · ${et.language}]',
            prompt: 'Featured on Vhunambi Explore (${et.genre})',
          );
        }
      }
    } catch (_) {}
  }

  // 3. Check Seeded Catalog with sovereign Studio fallback (never @fifi)
  final match = seededTrackDetails.firstWhere(
    (t) => t.id == trackId,
    orElse: () => TrackDetailEntity(
      id: trackId,
      title: 'Studio Track',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: const Duration(minutes: 3, seconds: 18),
      creatorId: 'creator_cern',
      creatorName: 'Vhunambi Studio',
      creatorHandle: '@cern',
      bpm: 113,
      musicalKey: 'F#m',
      moodId: VhunambiMood.uplifting.moodId,
      description: 'Original Amapiano session crafted in Vhunambi Studio.',
      prompt: 'African vocal rhythms with deep log drums',
      lyrics:
          '[Verse 1]\nMelodies from the north...\n[Chorus]\nVhutsila ha u imba...',
    ),
  );
  return match;
}

List<CommentEntity> _lookupInitialComments(String trackId) {
  if (trackId == 'seed-01' || trackId == 'track_default_1') {
    return [
      CommentEntity(
        id: 'cmt_001',
        trackId: trackId,
        authorName: 'Sipho Beats',
        authorHandle: '@sipho_beats',
        content: 'That log drum drop at 1:12 is absolutely legendary!',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likesCount: 5,
        isLiked: true,
      ),
      CommentEntity(
        id: 'cmt_002',
        trackId: trackId,
        authorName: 'Lerato K',
        authorHandle: '@lerato_k',
        content:
            'Tshivenḓa harmonies with amapiano piano chords hit different.',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        likesCount: 2,
        isLiked: false,
      ),
    ];
  }
  return const [];
}

/// Seeded rich track details for the Phase 7 catalog (design.md §1.1).
final List<TrackDetailEntity> seededTrackDetails = [
  const TrackDetailEntity(
    id: 'seed-01',
    title: 'Ndo Mufuna Matibe',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: Duration(minutes: 3, seconds: 18),
    creatorId: 'fifi',
    creatorName: 'Fifi',
    creatorHandle: '@fifi',
    licenseType: LicenseType.personal,
    isLiked: true,
    likesCount: 1,
    playCount: 5,
    reactions: {'fire': 0, 'love': 1, 'rhythm': 0, 'hands': 0, 'globe': 0},
    userReactions: {'love'},
    prompt:
        'Ndo mufuna Matibe deep amapiano with atmospheric Rhodes and heavy log drums',
    lyrics: '''[Verse 1]
Moonlight falls on your shoulder,
Tshikona drums sound deep in the distance,
Ndi matsheloni, the dawn is breathing,
Come closer, let the rhythm tell our story.

[Pre-Chorus]
Mbilu yanga yo takala,
Don't hide your fire in the shadows,
Can you feel the pulse of the valley?

[Chorus]
Ndo mufuna Matibe, mbilu yanga yo vhuya,
Zwanda zwau zwi na mulalo,
In the warmth of the sunrise,
Ndo mufuna, ndo mufuna zwa vhukuma.

[Verse 2]
Through the dust of Thohoyandou,
The bassline guides our journey home,
Every chord a memory we wrote together,
Never letting this feeling fade away.

[Bridge]
Vhuhulu ha lufuno holu,
No storm can blow our melody down.

[Outro]
Ndo mufuna Matibe...
Mbilu yanga...
Tshikona sound...''',
  ),
  const TrackDetailEntity(
    id: 'track_default_1',
    title: 'Grateful in the Light',
    genre: 'Amapiano',
    language: 'English',
    duration: Duration(minutes: 3, seconds: 29),
    creatorId: 'sigwa_inaf',
    creatorName: 'Sigwa & Inaf',
    creatorHandle: '@sigwa',
    licenseType: LicenseType.commercial,
    isLiked: false,
    likesCount: 1002,
    playCount: 1200,
    reactions: {'fire': 14, 'love': 42, 'rhythm': 28, 'hands': 8, 'globe': 19},
    userReactions: {},
    prompt:
        'Soulful amapiano with warm saxophone chords and uplifting choir vocals',
    lyrics: '''[Verse 1]
Waking up to the morning rays,
Walking through the blessed days.

[Chorus]
Grateful in the light,
Everything is gonna be alright.''',
  ),
  const TrackDetailEntity(
    id: 'exp_track_001',
    title: 'Township Funk',
    genre: 'Kwaito',
    language: 'isiZulu',
    duration: Duration(minutes: 3, seconds: 12),
    creatorId: 'dj_vibe',
    creatorName: 'DJ Vibe',
    creatorHandle: '@djvibe',
    licenseType: LicenseType.personal,
    isLiked: false,
    likesCount: 840,
    playCount: 920,
    reactions: {'fire': 25, 'love': 12, 'rhythm': 30, 'hands': 5, 'globe': 7},
    userReactions: {},
    prompt:
        'Mid-tempo Soweto kwaito groove with heavy 90s digital synths and chant vocals',
    lyrics: '''[Chorus]
Asambeni sonke,
Kwaito sound in the street!''',
  ),
  const TrackDetailEntity(
    id: 'seed-02',
    title: 'Durban Midnight Bass',
    genre: 'Gqom',
    language: 'isiZulu',
    duration: Duration(minutes: 4, seconds: 10),
    creatorId: 'dj_vibe',
    creatorName: 'DJ Vibe',
    creatorHandle: '@djvibe',
    licenseType: LicenseType.commercial,
    isLiked: false,
    likesCount: 450,
    playCount: 1800,
    reactions: {'fire': 40, 'love': 8, 'rhythm': 35, 'hands': 12, 'globe': 3},
    userReactions: {},
    prompt:
        'Dark minimalist Gqom beat with raw heavy kicks and Durban warehouse claps',
    lyrics: '[Instrumental Track]',
  ),
  const TrackDetailEntity(
    id: 'seed-03',
    title: 'Zulu Acoustic Flow',
    genre: 'Maskandi',
    language: 'isiZulu',
    duration: Duration(minutes: 3, seconds: 45),
    creatorId: 'ndugelo',
    creatorName: 'Ndugelo',
    creatorHandle: '@ndugelo',
    licenseType: LicenseType.personal,
    isLiked: false,
    likesCount: 310,
    playCount: 780,
    reactions: {'fire': 8, 'love': 15, 'rhythm': 10, 'hands': 18, 'globe': 6},
    userReactions: {},
    prompt:
        'Intricate finger-picking acoustic guitar with traditional storytelling vocals',
    lyrics: '''[Verse 1]
Intaba zase Zululand ziya khuluma,
Indlela ende siyi hamba sonke.''',
  ),
  const TrackDetailEntity(
    id: 'seed-04',
    title: 'Soweto Sunset Groove',
    genre: 'Afro House',
    language: 'Xhosa',
    duration: Duration(minutes: 5, seconds: 12),
    creatorId: 'lerato_prod',
    creatorName: 'Lerato',
    creatorHandle: '@lerato_prod',
    licenseType: LicenseType.commercial,
    isLiked: false,
    likesCount: 620,
    playCount: 2400,
    reactions: {'fire': 22, 'love': 30, 'rhythm': 45, 'hands': 14, 'globe': 20},
    userReactions: {},
    bpm: 122,
    musicalKey: 'Am',
    moodId: 'soulful',
    allowOpenStemsRemix: false,
    description:
        'Warm twilight Afro House session layered with Conga percussion and lush Fender Rhodes chords.',
    prompt:
        'Hypnotic 122 BPM Afro house percussion with African congas and soothing Rhodes',
    lyrics: '''[Chorus]
Langa litshonile eSoweto,
Siyavuma sonke emoyeni.''',
  ),
];
