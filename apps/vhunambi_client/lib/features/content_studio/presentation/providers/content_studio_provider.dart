import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/song_metadata_dna.dart';
import '../../domain/models/content_studio_preset.dart';
import '../../domain/models/lyric_word_timestamp.dart';
import '../../domain/services/i_video_export_service.dart';
import '../../data/services/local_video_export_service.dart';

final videoExportServiceProvider = Provider<IVideoExportService>((ref) {
  return LocalVideoExportService();
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
    );
  }
}

class ContentStudioNotifier extends StateNotifier<ContentStudioState> {
  final IVideoExportService _exportService;

  ContentStudioNotifier(this._exportService) : super(const ContentStudioState());

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
      audioUrl: audioUrl,
      coverArtUrl: coverArtUrl,
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
  }

  void setPreset(LyricTypographyPreset preset) {
    state = state.copyWith(typographyPreset: preset);
  }

  void setDurationPreset(DurationPreset preset) {
    final maxSec = state.dna?.musical.durationSec.toDouble() ?? 180.0;
    final target = preset.targetSeconds.toDouble();
    final newEnd = (state.startSeconds + target) > maxSec ? maxSec : state.startSeconds + target;
    state = state.copyWith(durationPreset: preset, endSeconds: newEnd);
  }

  void setTrimBounds(double start, double end) {
    final clampedStart = start < 0.0 ? 0.0 : start;
    final maxSec = state.dna?.musical.durationSec.toDouble() ?? 180.0;
    final clampedEnd = end > maxSec ? maxSec : (end <= clampedStart ? clampedStart + 1.0 : end);
    state = state.copyWith(startSeconds: clampedStart, endSeconds: clampedEnd);
  }

  void toggleEffect({bool? filmGrain, bool? bassPulse, bool? kenBurnsMotion}) {
    state = state.copyWith(
      effects: state.effects.copyWith(
        filmGrain: filmGrain,
        bassPulse: bassPulse,
        kenBurnsMotion: kenBurnsMotion,
      ),
    );
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
    state = state.copyWith(coverArtUrl: newCoverArtUrl);
  }

  Future<void> exportVideo() async {
    if (state.isExporting) return;
    if (state.audioUrl == null || state.coverArtUrl == null) {
      state = state.copyWith(errorMessage: 'Cannot export: Audio or Cover Art is missing.');
      return;
    }

    state = state.copyWith(isExporting: true, exportProgress: 0.0, errorMessage: null);

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
      state = state.copyWith(isExporting: false, exportProgress: 1.0, exportedFilePath: path);
    } catch (e) {
      state = state.copyWith(isExporting: false, errorMessage: e.toString());
    }
  }

  void reset() {
    state = const ContentStudioState();
  }
}

final contentStudioProvider =
    StateNotifierProvider<ContentStudioNotifier, ContentStudioState>((ref) {
  final exportService = ref.watch(videoExportServiceProvider);
  return ContentStudioNotifier(exportService);
});
