import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../social/presentation/providers/stem_remix_provider.dart';
import '../../domain/models/bantu_voice_profile.dart';
import '../../domain/models/song_dna_graph_models.dart';
import '../../domain/models/studio_form_state.dart';
import 'melody_sketchpad_provider.dart';
import 'studio_form_provider.dart';
import 'vocal_identity_provider.dart';

/// Notifier providing bi-directional quantum entanglement between the 3D Song DNA tree
/// and Studio Cockpit state (REQ-P50-GRAPH-05, REQ-P50-CARD-02..06).
class SongDnaGraphNotifier extends StateNotifier<SongDnaGraphState> {
  final Ref _ref;

  SongDnaGraphNotifier(this._ref)
      : super(
          const SongDnaGraphState(
            nodes: [],
            selectedNodeId: 'node_genre_tempo',
            activeInvasiveNodesCount: 0,
            overallCompleteness: 0.5,
            primaryGlowColor: Color(0xFFF97316),
          ),
        ) {
    _recomputeGraph();
  }

  void _recomputeGraph() {
    final form = _ref.read(studioFormProvider);
    final vocal = _ref.read(vocalIdentityProvider);
    final sketchpad = _ref.read(melodySketchpadProvider);
    final remix = _ref.read(stemRemixProvider);

    final nodes = <SongDnaNode>[];
    int invasiveCount = 0;

    // 1. Core Node (Song Genesis Root)
    nodes.add(
      SongDnaNode(
        id: 'node_core',
        category: SongDnaNodeCategory.beatCore,
        title: form.prompt.isNotEmpty ? form.prompt : 'Genesis Anthem',
        subtitle: form.isAutoTitle ? 'Auto-Title Active' : (form.customTitle ?? 'Song Genesis Core'),
        cueLabel: form.prompt.isNotEmpty
            ? (form.prompt.length > 18 ? '${form.prompt.substring(0, 18)}...' : form.prompt)
            : 'Core Genesis',
        icon: PhosphorIconsBold.sparkle,
        accentColor: const Color(0xFFF97316),
        branchUnlockProgress: 1.0,
        localPosition: const Vector3D(0, 0, 0),
      ),
    );

    // 2. Beat & Tempo Node
    final hasGenre = form.genre.isNotEmpty;
    nodes.add(
      SongDnaNode(
        id: 'node_genre_tempo',
        category: SongDnaNodeCategory.beatCore,
        title: '${form.genre} • ${form.tempo.label}',
        subtitle: 'BPM & Regional Drum Pulse',
        cueLabel: '${form.genre} • ${form.tempo.name.toUpperCase()}',
        icon: PhosphorIconsBold.disc,
        accentColor: const Color(0xFFF97316),
        branchUnlockProgress: hasGenre ? 1.0 : 0.5,
        localPosition: const Vector3D(0, -140, 20),
      ),
    );

    // 3. Vocal Persona Node
    final voiceProfile = form.selectedVoiceProfile;
    nodes.add(
      SongDnaNode(
        id: 'node_vocal_persona',
        category: SongDnaNodeCategory.vocalLyrics,
        title: voiceProfile.name,
        subtitle: '${voiceProfile.region.toUpperCase()} • ${voiceProfile.language}',
        cueLabel: voiceProfile.name,
        icon: PhosphorIconsBold.microphone,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: 0.95,
        localPosition: const Vector3D(-140, 20, -30),
      ),
    );

    // 4. Bantu Tongue & Lyrics Node
    final hasLyrics = form.customLyrics != null && form.customLyrics!.isNotEmpty;
    final lyricsLabel = form.lyricsMode == LyricsMode.aiWrite ? 'AI Writes' : 'My Lyrics';
    nodes.add(
      SongDnaNode(
        id: 'node_language_lyrics',
        category: SongDnaNodeCategory.vocalLyrics,
        title: '${form.language} • $lyricsLabel',
        subtitle: hasLyrics ? 'Custom Stanzas Prepared' : 'Generative Lyrics Pipeline',
        cueLabel: '${form.language} ($lyricsLabel)',
        icon: PhosphorIconsBold.translate,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: hasLyrics || form.lyricsMode == LyricsMode.aiWrite ? 1.0 : 0.6,
        localPosition: const Vector3D(-110, 110, 40),
      ),
    );

    // 5. Emotional Mood & Vocal Dynamics Node
    nodes.add(
      SongDnaNode(
        id: 'node_mood_energy',
        category: SongDnaNodeCategory.vocalLyrics,
        title: '${form.mood} • Vocal ${form.vocalEnergy.name.toUpperCase()}',
        subtitle: 'Resonance & Vocal Power Dynamics',
        cueLabel: form.mood,
        icon: PhosphorIconsBold.waveform,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: 0.9,
        localPosition: const Vector3D(-80, -90, -50),
      ),
    );

    // 6. Instrument & 5-Channel Sketchpad Node (Additive Satellites!)
    final hasSketchpadPattern = sketchpad.attachedPattern != null;
    final subNodes = <SongDnaSubNode>[];
    if (hasSketchpadPattern) {
      subNodes.addAll([
        const SongDnaSubNode(
          id: 'sub_lead',
          name: 'Rhodes Lead',
          icon: PhosphorIconsBold.pianoKeys,
          color: Color(0xFF10B981),
        ),
        const SongDnaSubNode(
          id: 'sub_chords',
          name: 'Jazz Chords',
          icon: PhosphorIconsBold.musicNotes,
          color: Color(0xFF10B981),
        ),
        const SongDnaSubNode(
          id: 'sub_bass',
          name: 'Log-Drum Bass',
          icon: PhosphorIconsBold.waveSine,
          color: Color(0xFF10B981),
        ),
        const SongDnaSubNode(
          id: 'sub_drums',
          name: 'Amapiano Kit',
          icon: PhosphorIconsBold.disc,
          color: Color(0xFF10B981),
        ),
        const SongDnaSubNode(
          id: 'sub_hats',
          name: 'Shaker Shimmer',
          icon: PhosphorIconsBold.sparkle,
          color: Color(0xFF10B981),
        ),
      ]);
    }

    nodes.add(
      SongDnaNode(
        id: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: hasSketchpadPattern
            ? '5-Channel Sketchpad Groove'
            : 'Instrumental & Harmonic Matrix',
        subtitle: hasSketchpadPattern
            ? '5 Active Channels Synthesizing'
            : 'Add Rhodes, Log Drum & Percussion',
        cueLabel: hasSketchpadPattern ? '5-Ch Groove Attached' : '+ Attach Groove',
        icon: PhosphorIconsBold.pianoKeys,
        accentColor: const Color(0xFF10B981),
        branchUnlockProgress: hasSketchpadPattern ? 1.0 : 0.4,
        isAdditive: true,
        localPosition: const Vector3D(140, 20, -30),
        subNodes: subNodes,
      ),
    );

    // 7. Heritage Crate & MPC Chops
    nodes.add(
      const SongDnaNode(
        id: 'node_heritage_mpc',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Heritage Crate & MPC Chops',
        subtitle: 'Mbira, Kora & Traditional Vinyl Slices',
        cueLabel: 'MPC Chops • Soul Slices',
        icon: PhosphorIconsBold.faders,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.6,
        localPosition: Vector3D(110, 110, 40),
      ),
    );

    // 8. Invasive Nodes: Reference Audio
    if (form.referenceAudioPath != null && form.referenceAudioPath!.isNotEmpty) {
      invasiveCount++;
      nodes.add(
        SongDnaNode(
          id: 'node_invasive_reference',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'External Reference Audio',
          subtitle: form.referenceAudioPath!,
          cueLabel: 'Invasive: Ref Beat',
          icon: PhosphorIconsBold.waveTriangle,
          accentColor: const Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          localPosition: const Vector3D(0, 160, -60),
        ),
      );
    }

    // 9. Invasive Nodes: Voice Clone (VHU-SIG)
    if (vocal.isUsingClonedVoice) {
      invasiveCount++;
      nodes.add(
        const SongDnaNode(
          id: 'node_invasive_voice_clone',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'Cloned Voice Signature (VHU-SIG)',
          subtitle: 'Zero-Shot Personal Timbre Injected',
          cueLabel: 'Invasive: VHU-SIG Voice',
          icon: PhosphorIconsBold.fingerprint,
          accentColor: Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          localPosition: Vector3D(50, 170, 50),
        ),
      );
    }

    // 10. Invasive Nodes: Parent Remix Lineage
    if (remix != null) {
      invasiveCount++;
      nodes.add(
        SongDnaNode(
          id: 'node_invasive_remix',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'Parent Reel Remix Lineage',
          subtitle: '${remix.parentTrackTitle} by ${remix.parentCreatorDisplayName}',
          cueLabel: 'Invasive: Remix Lineage',
          icon: PhosphorIconsBold.gitFork,
          accentColor: const Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          localPosition: const Vector3D(-50, 170, 50),
        ),
      );
    }

    // Determine primary multi-spectrum glow color
    Color glow;
    if (invasiveCount > 0) {
      glow = const Color(0xFFD946EF); // Electric Violet (Invasive)
    } else if (hasSketchpadPattern) {
      glow = const Color(0xFF10B981); // Emerald (Instruments)
    } else if (form.language != 'English' || hasLyrics) {
      glow = const Color(0xFF06B6D4); // Cyan (Vocal/Bantu)
    } else {
      glow = const Color(0xFFF97316); // Amber (Beat/Core)
    }

    // Calculate completeness
    double totalProgress = 0;
    for (final node in nodes) {
      totalProgress += node.branchUnlockProgress;
    }
    final completeness = (totalProgress / nodes.length).clamp(0.0, 1.0);

    state = state.copyWith(
      nodes: nodes,
      activeInvasiveNodesCount: invasiveCount,
      overallCompleteness: completeness,
      primaryGlowColor: glow,
    );
  }

  void selectNode(String? id) {
    if (state.selectedNodeId == id) return;
    state = state.copyWith(selectedNodeId: id);
  }

  // --- Quantum Entanglement Mutators (Writes directly to Studio state) ---

  void updateGenre(String genre) {
    _ref.read(studioFormProvider.notifier).setGenre(genre);
    _recomputeGraph();
  }

  void selectGenre(String genre) => updateGenre(genre);

  void updateTempo(dynamic tempo) {
    TempoBracket bracket;
    if (tempo is TempoBracket) {
      bracket = tempo;
    } else if (tempo is int) {
      if (tempo <= 108) {
        bracket = TempoBracket.slow;
      } else if (tempo <= 115) {
        bracket = TempoBracket.medium;
      } else if (tempo <= 124) {
        bracket = TempoBracket.fast;
      } else {
        bracket = TempoBracket.veryFast;
      }
    } else {
      return;
    }
    _ref.read(studioFormProvider.notifier).setTempo(bracket);
    _recomputeGraph();
  }

  void selectTempo(dynamic tempo) => updateTempo(tempo);

  void updateVocalPersona(BantuVoiceProfile profile) {
    _ref.read(studioFormProvider.notifier).setBantuVoiceProfile(profile);
    _recomputeGraph();
  }

  void updateLanguage(String language) {
    _ref.read(studioFormProvider.notifier).setLanguage(language);
    _recomputeGraph();
  }

  void updateLyricsMode(LyricsMode mode) {
    _ref.read(studioFormProvider.notifier).setLyricsMode(mode);
    _recomputeGraph();
  }

  void updateCustomLyrics(String lyrics) {
    _ref.read(studioFormProvider.notifier).setCustomLyrics(lyrics);
    _recomputeGraph();
  }

  void updateMood(String mood) {
    _ref.read(studioFormProvider.notifier).setMood(mood);
    _recomputeGraph();
  }

  void updateVocalEnergy(VocalEnergy energy) {
    _ref.read(studioFormProvider.notifier).setVocalEnergy(energy);
    _recomputeGraph();
  }

  void detachInvasiveNode(String nodeId) {
    if (nodeId == 'node_invasive_reference') {
      _ref.read(studioFormProvider.notifier).setReferenceAudio(null);
    } else if (nodeId == 'node_invasive_remix') {
      _ref.read(stemRemixProvider.notifier).clearRemix();
    } else if (nodeId == 'node_invasive_voice_clone') {
      final vocalState = _ref.read(vocalIdentityProvider);
      _ref.read(vocalIdentityProvider.notifier).selectArchetype(vocalState.activeArchetype);
    }
    _recomputeGraph();
  }

  void attachSketchpadPreset(String presetTitle) {
    final notifier = _ref.read(melodySketchpadProvider.notifier);
    notifier.applyEuclideanGroove();
    _recomputeGraph();
  }
}

/// Global provider for the Quantum-Entangled 3D Song DNA graph (REQ-P50-GRAPH-05).
final songDnaGraphProvider =
    StateNotifierProvider<SongDnaGraphNotifier, SongDnaGraphState>((ref) {
  final notifier = SongDnaGraphNotifier(ref);

  // Subscribe to changes in underlying Studio providers
  ref.listen(studioFormProvider, (_, _) => notifier._recomputeGraph());
  ref.listen(vocalIdentityProvider, (_, _) => notifier._recomputeGraph());
  ref.listen(melodySketchpadProvider, (_, _) => notifier._recomputeGraph());
  ref.listen(stemRemixProvider, (_, _) => notifier._recomputeGraph());

  return notifier;
});
