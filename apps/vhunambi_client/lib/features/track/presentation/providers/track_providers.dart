import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/track_detail_models.dart';

/// Track dissection record for `/track/:id` (REQ-TRK-01 … REQ-TRK-11).
final trackDetailFamilyProvider = StateNotifierProvider.family<
    TrackDetailNotifier, TrackDetailEntity, String>((ref, trackId) {
  return TrackDetailNotifier(trackId);
});

/// Discussion thread for a track (REQ-TRK-11).
final trackCommentsProvider = StateNotifierProvider.family<
    TrackCommentsNotifier, List<CommentEntity>, String>((ref, trackId) {
  return TrackCommentsNotifier(trackId);
});

/// Genre recommendations shown in the `More Like This` shelf (REQ-TRK-11).
final moreLikeThisProvider =
    Provider.family<List<TrackDetailEntity>, String>((ref, trackId) {
  final current = ref.watch(trackDetailFamilyProvider(trackId));
  return List.unmodifiable(
    seededTrackDetails
        .where((track) => track.genre == current.genre && track.id != trackId)
        .toList(),
  );
});

class TrackDetailNotifier extends StateNotifier<TrackDetailEntity> {
  final String trackId;

  TrackDetailNotifier(this.trackId) : super(_lookupInitialTrack(trackId));

  /// Optimistically toggles the like state and tally (REQ-TRK-04).
  void toggleLike() {
    final newLiked = !state.isLiked;
    state = state.copyWith(
      isLiked: newLiked,
      likesCount: state.likesCount + (newLiked ? 1 : -1),
    );
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

    state = state.copyWith(
      userReactions: userReactions,
      reactions: reactions,
    );
  }

  /// Runs the simulated 4-step stem isolation pipeline (REQ-TRK-09).
  Future<void> separateStems() async {
    if (state.stemState.isProcessing) return;

    /// Advances the FSM through the documented step ladder.
    Future<void> advance(
      StemSeparationStatus status,
      double progress,
    ) async {
      state = state.copyWith(
        stemState: state.stemState.copyWith(
          status: status,
          progress: progress,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    await advance(StemSeparationStatus.isolatingVocals, 0.25);
    await advance(StemSeparationStatus.isolatingDrums, 0.50);
    await advance(StemSeparationStatus.isolatingBass, 0.75);
    await advance(StemSeparationStatus.isolatingInstrumental, 0.90);

    state = state.copyWith(
      stemState: StemSeparationState(
        status: StemSeparationStatus.ready,
        progress: 1.0,
        stems: [
          StemTrackEntity(
            id: '${trackId}_vocals',
            name: 'Vocals',
            audioUrl: '',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_drums',
            name: 'Drums',
            audioUrl: '',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_bass',
            name: 'Bass & Log Drums',
            audioUrl: '',
            duration: state.duration,
          ),
          StemTrackEntity(
            id: '${trackId}_inst',
            name: 'Instrumental',
            audioUrl: '',
            duration: state.duration,
          ),
        ],
      ),
    );
  }

  void toggleMuteStem(String stemId) {
    final stems = state.stemState.stems
        .map((stem) =>
            stem.id == stemId ? stem.copyWith(isMuted: !stem.isMuted) : stem)
        .toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));
  }

  void toggleSoloStem(String stemId) {
    final stems = state.stemState.stems
        .map((stem) =>
            stem.id == stemId ? stem.copyWith(isSoloed: !stem.isSoloed) : stem)
        .toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));
  }
}

class TrackCommentsNotifier extends StateNotifier<List<CommentEntity>> {
  final String trackId;

  TrackCommentsNotifier(this.trackId)
      : super(_lookupInitialComments(trackId));

  void addComment(String content, {String authorName = 'Ndugelo', String authorHandle = '@ndugelo'}) {
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

TrackDetailEntity _lookupInitialTrack(String trackId) {
  final match = seededTrackDetails.firstWhere(
    (t) => t.id == trackId,
    orElse: () => TrackDetailEntity(
      id: trackId,
      title: 'Unknown Melody',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: const Duration(minutes: 3, seconds: 18),
      creatorId: 'creator_001',
      creatorName: 'Fifi',
      creatorHandle: '@fifi',
      prompt: 'African vocal rhythms with deep log drums',
      lyrics: '[Verse 1]\nMelodies from the north...\n[Chorus]\nVhutsila ha u imba...',
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
        content: 'That log drum drop at 1:12 is absolutely legendary! 🔥',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likesCount: 5,
        isLiked: true,
      ),
      CommentEntity(
        id: 'cmt_002',
        trackId: trackId,
        authorName: 'Lerato K',
        authorHandle: '@lerato_k',
        content: 'Tshivenḓa harmonies with amapiano piano chords hit different ❤️',
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
    reactions: {
      'fire': 0,
      'love': 1,
      'rhythm': 0,
      'hands': 0,
      'globe': 0,
    },
    userReactions: {'love'},
    prompt: 'Ndo mufuna Matibe deep amapiano with atmospheric Rhodes and heavy log drums',
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
    reactions: {
      'fire': 14,
      'love': 42,
      'rhythm': 28,
      'hands': 8,
      'globe': 19,
    },
    userReactions: {},
    prompt: 'Soulful amapiano with warm saxophone chords and uplifting choir vocals',
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
    reactions: {
      'fire': 25,
      'love': 12,
      'rhythm': 30,
      'hands': 5,
      'globe': 7,
    },
    userReactions: {},
    prompt: 'Mid-tempo Soweto kwaito groove with heavy 90s digital synths and chant vocals',
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
    reactions: {
      'fire': 40,
      'love': 8,
      'rhythm': 35,
      'hands': 12,
      'globe': 3,
    },
    userReactions: {},
    prompt: 'Dark minimalist Gqom beat with raw heavy kicks and Durban warehouse claps',
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
    reactions: {
      'fire': 8,
      'love': 15,
      'rhythm': 10,
      'hands': 18,
      'globe': 6,
    },
    userReactions: {},
    prompt: 'Intricate finger-picking acoustic guitar with traditional storytelling vocals',
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
    reactions: {
      'fire': 22,
      'love': 30,
      'rhythm': 45,
      'hands': 14,
      'globe': 20,
    },
    userReactions: {},
    prompt: 'Hypnotic 122 BPM Afro house percussion with African congas and soothing Rhodes',
    lyrics: '''[Chorus]
Langa litshonile eSoweto,
Siyavuma sonke emoyeni.''',
  ),
];
