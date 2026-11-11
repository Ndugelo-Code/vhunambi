import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../../../content_studio/domain/models/master_media_object.dart';
import '../../../player/domain/models/stem_mixer_state.dart';

/// State of the Heritage Crate Digging browser.
class HeritageCrateState {
  final List<HeritageSampleEntity> allSamples;
  final HeritageCrateCategory activeCategory;
  final String searchQuery;
  final String? auditioningSampleId;

  const HeritageCrateState({
    required this.allSamples,
    this.activeCategory = HeritageCrateCategory.all,
    this.searchQuery = '',
    this.auditioningSampleId,
  });

  /// Dynamically filtered samples based on category and query.
  List<HeritageSampleEntity> get filteredSamples {
    return allSamples.where((sample) {
      final matchesCategory =
          activeCategory == HeritageCrateCategory.all ||
          _sampleMatchesCategory(sample, activeCategory);

      final matchesQuery =
          searchQuery.isEmpty ||
          sample.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          sample.instrument.toLowerCase().contains(searchQuery.toLowerCase()) ||
          sample.cultureRegion.toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          sample.tags.any(
            (t) => t.toLowerCase().contains(searchQuery.toLowerCase()),
          );

      return matchesCategory && matchesQuery;
    }).toList();
  }

  bool _sampleMatchesCategory(
    HeritageSampleEntity sample,
    HeritageCrateCategory cat,
  ) {
    switch (cat) {
      case HeritageCrateCategory.all:
        return true;
      case HeritageCrateCategory.percussion:
        return sample.tags.contains('percussion') ||
            sample.tags.contains('talking-drum');
      case HeritageCrateCategory.pluckedStrings:
        return sample.tags.contains('kora') ||
            sample.tags.contains('harp') ||
            sample.tags.contains('bow') ||
            sample.tags.contains('uhadi');
      case HeritageCrateCategory.melodicIdiophones:
        return sample.tags.contains('mbira') ||
            sample.tags.contains('marimba') ||
            sample.tags.contains('idiophone');
      case HeritageCrateCategory.traditionalPipes:
        return sample.tags.contains('pipe') ||
            sample.tags.contains('flute') ||
            sample.tags.contains('horn');
      case HeritageCrateCategory.chants:
        return sample.tags.contains('voices') ||
            sample.tags.contains('sacred') ||
            sample.tags.contains('domba');
    }
  }

  HeritageCrateState copyWith({
    List<HeritageSampleEntity>? allSamples,
    HeritageCrateCategory? activeCategory,
    String? searchQuery,
    String? auditioningSampleId,
    bool clearAudition = false,
  }) {
    return HeritageCrateState(
      allSamples: allSamples ?? this.allSamples,
      activeCategory: activeCategory ?? this.activeCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      auditioningSampleId: clearAudition
          ? null
          : (auditioningSampleId ?? this.auditioningSampleId),
    );
  }
}

/// State notifier managing sample discovery, filtering, and vinyl auditions.
class HeritageCrateNotifier extends StateNotifier<HeritageCrateState> {
  HeritageCrateNotifier([List<HeritageSampleEntity>? initialSamples])
    : super(
        HeritageCrateState(allSamples: _resolveInitialSamples(initialSamples)),
      );

  static List<HeritageSampleEntity> _resolveInitialSamples(
    List<HeritageSampleEntity>? initialSamples,
  ) {
    final base = initialSamples ?? kSeededHeritageSamples;
    if (initialSamples != null ||
        !SovereignDomainStorageMode.canHydrateFromStorage(
          AppConstants.crateMpcKitsBoxKey,
        )) {
      return base;
    }
    final favoriteIds = CrateMpcKitsRepository.loadFavoriteSampleIds();
    if (favoriteIds == null) return base;
    return base
        .map(
          (sample) =>
              sample.copyWith(isFavorite: favoriteIds.contains(sample.id)),
        )
        .toList();
  }

  void setCategory(HeritageCrateCategory category) {
    state = state.copyWith(activeCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleFavorite(String sampleId) {
    final updated = state.allSamples.map((sample) {
      if (sample.id == sampleId) {
        return sample.copyWith(isFavorite: !sample.isFavorite);
      }
      return sample;
    }).toList();
    state = state.copyWith(allSamples: updated);
    unawaited(
      CrateMpcKitsRepository.saveFavoriteSampleIds(
        updated.where((s) => s.isFavorite).map((s) => s.id).toSet(),
      ),
    );
  }

  void startAudition(String sampleId) {
    state = state.copyWith(auditioningSampleId: sampleId);
  }

  void stopAudition() {
    state = state.copyWith(clearAudition: true);
  }
}

final heritageCrateProvider =
    StateNotifierProvider<HeritageCrateNotifier, HeritageCrateState>((ref) {
      return HeritageCrateNotifier();
    });

/// State notifier driving the 8-Pad AI MPC Slicer engine.
class MpcSlicerNotifier extends StateNotifier<MpcSlicerState> {
  static const String _activeKitKey = 'active_kit';

  MpcSlicerNotifier([MpcSlicerState? initial])
    : super(_resolveInitialKit(initial));

  static MpcSlicerState _resolveInitialKit(MpcSlicerState? initial) {
    if (initial != null) return initial;
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.crateMpcKitsBoxKey,
    )) {
      final saved = CrateMpcKitsRepository.loadMpcKit(_activeKitKey);
      if (saved != null) {
        try {
          return MpcSlicerState.fromJson(saved);
        } catch (_) {}
      }
    }
    return MpcSlicerState(pads: MpcSlicerState.defaultPads);
  }

  void _persistKit() {
    unawaited(CrateMpcKitsRepository.saveMpcKit(_activeKitKey, state.toJson()));
  }

  /// Auto-slices an indigenous sample or stem into 8 transient slices.
  void sliceSample(HeritageSampleEntity sample) {
    final sliceDuration = sample.durationSec / 8.0;
    final newPads = List.generate(8, (i) {
      final start = i * sliceDuration;
      final end = (i + 1) * sliceDuration;
      return MpcPadEntity(
        id: 'pad_${sample.id}_$i',
        index: i,
        label: 'PAD ${i + 1}',
        sourceAudioUrl: sample.audioUrl,
        startSec: start,
        endSec: end,
        pitchShiftSemitones: 0,
        isReversed: false,
        volume: 1.0,
        isMuted: false,
        isTriggered: false,
      );
    });

    state = state.copyWith(
      pads: newPads,
      sourceTitle: sample.name,
      bpm: sample.bpm,
      selectedPadIndex: 0,
      timeStretchRatio: 1.0,
    );
    _persistKit();
  }

  /// Loads role-stratified slices directly from MasterMediaObjectManifest (REQ-MMO-05).
  void loadFromManifestPads(
    List<MpcPadSliceManifest> pads, {
    String sourceTitle = 'MMO Stratified Kit',
    int bpm = 112,
    Map<StemType, String>? stemUrls,
  }) {
    if (pads.isEmpty) return;

    final newPads = pads.map((p) {
      final audioUrl = stemUrls?[p.sourceStem] ?? '';
      return MpcPadEntity(
        id: 'pad_mmo_${p.padIndex}',
        index: p.padIndex,
        label: p.label,
        sourceAudioUrl: audioUrl,
        startSec: p.startSec,
        endSec: p.endSec,
        pitchShiftSemitones: p.recommendedSemitoneShift,
        isReversed: false,
        volume: p.peakIntensity.clamp(0.0, 1.5),
        isMuted: false,
        isTriggered: false,
      );
    }).toList();

    state = state.copyWith(
      pads: newPads,
      sourceTitle: sourceTitle,
      bpm: bpm,
      selectedPadIndex: 0,
      timeStretchRatio: 1.0,
    );
    _persistKit();
  }

  void selectPad(int index) {
    if (index >= 0 && index < state.pads.length) {
      state = state.copyWith(selectedPadIndex: index);
    }
  }

  /// Triggers a pad with momentary visual feedback.
  void triggerPad(int index) {
    if (index < 0 || index >= state.pads.length) return;
    final updated = List<MpcPadEntity>.from(state.pads);
    updated[index] = updated[index].copyWith(isTriggered: true);
    state = state.copyWith(pads: updated, selectedPadIndex: index);
  }

  void releasePad(int index) {
    if (index < 0 || index >= state.pads.length) return;
    final updated = List<MpcPadEntity>.from(state.pads);
    updated[index] = updated[index].copyWith(isTriggered: false);
    state = state.copyWith(pads: updated);
  }

  void setPitchShift(int index, int semitones) {
    if (index < 0 || index >= state.pads.length) return;
    final clamped = semitones.clamp(-12, 12);
    final updated = List<MpcPadEntity>.from(state.pads);
    updated[index] = updated[index].copyWith(pitchShiftSemitones: clamped);
    state = state.copyWith(pads: updated);
    _persistKit();
  }

  void toggleReverse(int index) {
    if (index < 0 || index >= state.pads.length) return;
    final updated = List<MpcPadEntity>.from(state.pads);
    updated[index] = updated[index].copyWith(
      isReversed: !updated[index].isReversed,
    );
    state = state.copyWith(pads: updated);
    _persistKit();
  }

  void setPadVolume(int index, double vol) {
    if (index < 0 || index >= state.pads.length) return;
    final clamped = vol.clamp(0.0, 1.5);
    final updated = List<MpcPadEntity>.from(state.pads);
    updated[index] = updated[index].copyWith(volume: clamped);
    state = state.copyWith(pads: updated);
    _persistKit();
  }

  void setTimeStretch(double ratio) {
    final clamped = ratio.clamp(0.5, 2.0);
    state = state.copyWith(timeStretchRatio: clamped);
    _persistKit();
  }

  void setBpm(int bpm) {
    state = state.copyWith(bpm: bpm);
    _persistKit();
  }

  /// Bounces current 8-pad chop kit to local storage.
  Future<String> bounceChops() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        '/vault/chops/mpc_kit_${state.sourceTitle.toLowerCase().replaceAll(' ', '_')}_$timestamp.wav';
    state = state.copyWith(lastBouncedChopPath: path);
    _persistKit();
    return path;
  }
}

final mpcSlicerProvider =
    StateNotifierProvider<MpcSlicerNotifier, MpcSlicerState>((ref) {
      return MpcSlicerNotifier();
    });
