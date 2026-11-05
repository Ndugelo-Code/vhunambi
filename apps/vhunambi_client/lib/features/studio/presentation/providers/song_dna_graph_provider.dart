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
  final List<SongDnaNode> _dynamicInstrumentLeaves = [];

  SongDnaGraphNotifier(this._ref)
    : super(
        const SongDnaGraphState(
          nodes: [],
          selectedNodeId: null,
          activeInvasiveNodesCount: 0,
          overallCompleteness: 0.5,
          primaryGlowColor: Color(0xFFF59E0B),
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
        subtitle: form.isAutoTitle
            ? 'Auto-Title Active'
            : (form.customTitle ?? 'Song Genesis Core'),
        cueLabel: form.prompt.isNotEmpty
            ? (form.prompt.length > 18
                  ? '${form.prompt.substring(0, 18)}...'
                  : form.prompt)
            : 'Core Genesis',
        icon: PhosphorIconsBold.sparkle,
        accentColor: const Color(0xFFF59E0B),
        branchUnlockProgress: 1.0,
        localPosition: Vector3D(0, 0, 0),
      ),
    );

    // =========================================================================
    // ARM 1: BEAT & RHYTHM DENDRITE (Blazing Amber/Coral #F59E0B)
    // =========================================================================
    final hasGenre = form.genre.isNotEmpty;
    final beatLockMode =
        form.branchStemLockModes['node_beat_tempo'] ??
        StemLockMode.lockedPure44k;
    nodes.add(
      SongDnaNode(
        id: 'node_beat_tempo',
        parentId: 'node_core',
        category: SongDnaNodeCategory.beatCore,
        title: '${form.genre} • ${form.tempo.label}',
        subtitle: 'BPM & Regional Drum Pulse',
        cueLabel: '${form.genre} • ${form.tempo.name.toUpperCase()}',
        icon: PhosphorIconsBold.disc,
        accentColor: const Color(0xFFF59E0B),
        branchUnlockProgress: hasGenre ? 1.0 : 0.5,
        localPosition: Vector3D(0, -180, 20),
        isBranchRoot: true,
        stemLockMode: beatLockMode,
      ),
    );

    nodes.add(
      SongDnaNode(
        id: 'node_beat_rhythm_pocket',
        parentId: 'node_beat_tempo',
        category: SongDnaNodeCategory.beatCore,
        title: 'Rhythm Pocket',
        subtitle: 'African Syncopated Grid',
        cueLabel: 'Syncopated Grid',
        icon: PhosphorIconsBold.metronome,
        accentColor: const Color(0xFFF59E0B),
        branchUnlockProgress: 0.85,
        isTerminalReceptor: true,
        localPosition: Vector3D(-45, -235, 55),
      ),
    );

    nodes.add(
      SongDnaNode(
        id: 'node_beat_tempo_feel',
        parentId: 'node_beat_tempo',
        category: SongDnaNodeCategory.beatCore,
        title: 'Tempo Feel (${form.tempo.label})',
        subtitle: 'Groove Velocity & Pacing',
        cueLabel: form.tempo.name.toUpperCase(),
        icon: PhosphorIconsBold.gauge,
        accentColor: const Color(0xFFF59E0B),
        branchUnlockProgress: 0.9,
        isTerminalReceptor: true,
        localPosition: Vector3D(45, -240, 25),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_beat_era',
        parentId: 'node_beat_tempo',
        category: SongDnaNodeCategory.beatCore,
        title: 'Era Signature',
        subtitle: 'Generational Harmonic Tuning',
        cueLabel: 'Era Tuning',
        icon: PhosphorIconsBold.calendarBlank,
        accentColor: Color(0xFFF59E0B),
        branchUnlockProgress: 0.8,
        isTerminalReceptor: true,
        localPosition: Vector3D(-20, -285, 80),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_beat_structure',
        parentId: 'node_beat_tempo',
        category: SongDnaNodeCategory.beatCore,
        title: 'Song Structure',
        subtitle: 'Intro • Verse • Log-Drop • Outro',
        cueLabel: 'Arrangement',
        icon: PhosphorIconsBold.rows,
        accentColor: Color(0xFFF59E0B),
        branchUnlockProgress: 0.75,
        isTerminalReceptor: true,
        localPosition: Vector3D(35, -290, 40),
      ),
    );

    // =========================================================================
    // ARM 2: VOCAL & LINGUISTIC DENDRITE (Bioluminescent Cyan #06B6D4)
    // =========================================================================
    final voiceProfile = form.selectedVoiceProfile;
    final vocalLockMode =
        form.branchStemLockModes['node_vocal_persona'] ??
        StemLockMode.harmonicInpaint;
    nodes.add(
      SongDnaNode(
        id: 'node_vocal_persona',
        parentId: 'node_core',
        category: SongDnaNodeCategory.vocalLyrics,
        title: voiceProfile.name,
        subtitle:
            '${voiceProfile.region.toUpperCase()} • ${voiceProfile.language}',
        cueLabel: voiceProfile.name,
        icon: PhosphorIconsBold.microphone,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: 0.95,
        localPosition: Vector3D(-160, 40, -30),
        isBranchRoot: true,
        stemLockMode: vocalLockMode,
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_vocal_lora',
        parentId: 'node_vocal_persona',
        category: SongDnaNodeCategory.vocalLyrics,
        title: 'LoRA Voice Weight',
        subtitle: '0.85 Vocal Timbre Fidelity Bias',
        cueLabel: 'LoRA 85%',
        icon: PhosphorIconsBold.slidersHorizontal,
        accentColor: Color(0xFF06B6D4),
        branchUnlockProgress: 0.85,
        isTerminalReceptor: true,
        localPosition: Vector3D(-225, -25, -50),
      ),
    );

    final hasLyrics =
        form.customLyrics != null && form.customLyrics!.isNotEmpty;
    final lyricsLabel = form.lyricsMode == LyricsMode.aiWrite
        ? 'AI Writes'
        : 'My Lyrics';
    nodes.add(
      SongDnaNode(
        id: 'node_language_lyrics',
        parentId: 'node_vocal_persona',
        category: SongDnaNodeCategory.vocalLyrics,
        title: '${form.language} • $lyricsLabel',
        subtitle: hasLyrics
            ? 'Custom Stanzas Prepared'
            : 'Generative Lyrics Pipeline',
        cueLabel: '${form.language} ($lyricsLabel)',
        icon: PhosphorIconsBold.translate,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: hasLyrics || form.lyricsMode == LyricsMode.aiWrite
            ? 1.0
            : 0.6,
        localPosition: Vector3D(-210, 80, 20),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_vocal_dialects',
        parentId: 'node_language_lyrics',
        category: SongDnaNodeCategory.vocalLyrics,
        title: 'Dialect Roots & Cadence',
        subtitle: 'Indigenous Phonetic Pronunciation',
        cueLabel: 'Phonetic Roots',
        icon: PhosphorIconsBold.chatsTeardrop,
        accentColor: Color(0xFF06B6D4),
        branchUnlockProgress: 0.8,
        isTerminalReceptor: true,
        localPosition: Vector3D(-265, 120, 40),
      ),
    );

    nodes.add(
      SongDnaNode(
        id: 'node_mood_energy',
        parentId: 'node_vocal_persona',
        category: SongDnaNodeCategory.vocalLyrics,
        title: '${form.mood} • Vocal ${form.vocalEnergy.name.toUpperCase()}',
        subtitle: 'Resonance & Vocal Power Dynamics',
        cueLabel: form.mood,
        icon: PhosphorIconsBold.waveform,
        accentColor: const Color(0xFF06B6D4),
        branchUnlockProgress: 0.9,
        localPosition: Vector3D(-215, -75, -70),
      ),
    );

    // =========================================================================
    // ARM 3: HARMONIC & INSTRUMENT DENDRITE (Vibrant Emerald #10B981)
    // =========================================================================
    final hasSketchpadPattern = sketchpad.attachedPattern != null;
    final instLockMode =
        form.branchStemLockModes['node_sketchpad_groove'] ??
        (hasSketchpadPattern
            ? StemLockMode.lockedPure44k
            : StemLockMode.harmonicInpaint);
    final subNodes = <SongDnaSubNode>[
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
    ];

    nodes.add(
      SongDnaNode(
        id: 'node_sketchpad_groove',
        parentId: 'node_core',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: hasSketchpadPattern
            ? '5-Channel Sketchpad Groove'
            : 'Instrumental & Harmonic Matrix',
        subtitle: hasSketchpadPattern
            ? '5 Active Channels Synthesizing'
            : 'Add Rhodes, Log Drum & Percussion',
        cueLabel: hasSketchpadPattern
            ? '5-Ch Groove Attached'
            : '+ Attach Groove',
        icon: PhosphorIconsBold.pianoKeys,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: hasSketchpadPattern ? 1.0 : 0.4,
        isAdditive: true,
        localPosition: Vector3D(170, 30, -20),
        subNodes: subNodes,
        isBranchRoot: true,
        stemLockMode: instLockMode,
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_inst_lead',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Lead Melody',
        subtitle: 'Rhodes & Synth Solo Line',
        cueLabel: 'Lead Synth',
        icon: PhosphorIconsBold.pianoKeys,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.9,
        isTerminalReceptor: true,
        localPosition: Vector3D(225, -20, 30),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_inst_chords',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Chords & Harmonic Layers',
        subtitle: 'Jazz & Gospel voicings',
        cueLabel: 'Jazz Chords',
        icon: PhosphorIconsBold.musicNotes,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.85,
        isTerminalReceptor: true,
        localPosition: Vector3D(240, 40, -40),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_inst_logdrum',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Log-Drum Sub Bass',
        subtitle: 'Sliding Bassline Pacing',
        cueLabel: 'Log Drum',
        icon: PhosphorIconsBold.waveSine,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.95,
        isTerminalReceptor: true,
        localPosition: Vector3D(260, 95, 10),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_inst_drums',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Amapiano Percussion Kit',
        subtitle: 'Congas, Shakers & Claps',
        cueLabel: 'Drum Kit',
        icon: PhosphorIconsBold.disc,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.8,
        isTerminalReceptor: true,
        localPosition: Vector3D(220, 140, -30),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_inst_hats',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Shaker & High-Hat Shimmer',
        subtitle: '16th-note Polyrhythmic Swing',
        cueLabel: 'Shakers',
        icon: PhosphorIconsBold.sparkle,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.8,
        isTerminalReceptor: true,
        localPosition: Vector3D(275, 160, -10),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_heritage_mpc',
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Heritage Crate & MPC Chops',
        subtitle: 'Mbira, Kora & Traditional Vinyl Slices',
        cueLabel: 'MPC Chops • Soul Slices',
        icon: PhosphorIconsBold.faders,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 0.6,
        localPosition: Vector3D(160, 180, 50),
      ),
    );

    // Append dynamic user-spawned instrument leaves (REQ-P52-LEAF-01)
    nodes.addAll(_dynamicInstrumentLeaves);

    // =========================================================================
    // ARM 4: SPATIAL ATMOSPHERE & ACOUSTIC DENDRITE (Bioluminescent Violet #8B5CF6)
    // =========================================================================
    final spatialLockMode =
        form.branchStemLockModes['node_spatial_atmosphere'] ??
        StemLockMode.harmonicInpaint;
    nodes.add(
      SongDnaNode(
        id: 'node_spatial_atmosphere',
        parentId: 'node_core',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Spatial Atmosphere & Room',
        subtitle: 'Bioluminescent Acoustic Field',
        cueLabel: 'Spatial Room',
        icon: PhosphorIconsBold.speakerHifi,
        accentColor: const Color(0xFF8B5CF6),
        branchUnlockProgress: 0.85,
        localPosition: Vector3D(20, 160, -40),
        isBranchRoot: true,
        stemLockMode: spatialLockMode,
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_spatial_reverb',
        parentId: 'node_spatial_atmosphere',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Vocal Plate Reverb',
        subtitle: '3D Spatial Decay & Warmth',
        cueLabel: 'Plate Reverb',
        icon: PhosphorIconsBold.waveform,
        accentColor: Color(0xFF8B5CF6),
        branchUnlockProgress: 0.8,
        isTerminalReceptor: true,
        localPosition: Vector3D(55, 220, -60),
      ),
    );

    nodes.add(
      const SongDnaNode(
        id: 'node_spatial_stereo_width',
        parentId: 'node_spatial_atmosphere',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: 'Stereo Field Spread',
        subtitle: 'African Poly-Spatial Spread',
        cueLabel: 'Stereo Field',
        icon: PhosphorIconsBold.arrowsOutLineHorizontal,
        accentColor: Color(0xFF8B5CF6),
        branchUnlockProgress: 0.75,
        isTerminalReceptor: true,
        localPosition: Vector3D(-15, 235, -30),
      ),
    );

    // =========================================================================
    // SYMBIOTIC / INVASIVE INTAKE DENDRITE (Electric Magenta #D946EF)
    // =========================================================================
    final hasRefAudio =
        form.referenceAudioPath != null && form.referenceAudioPath!.isNotEmpty;
    if (hasRefAudio) {
      invasiveCount++;
      final refLockMode =
          form.branchStemLockModes['node_invasive_reference'] ??
          StemLockMode.elasticResynth;
      nodes.add(
        SongDnaNode(
          id: 'node_invasive_reference',
          parentId: 'node_core',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'External Reference Audio',
          subtitle: form.referenceAudioPath!,
          cueLabel: 'Invasive: Ref Beat',
          icon: PhosphorIconsBold.waveTriangle,
          accentColor: const Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          localPosition: Vector3D(60, 160, -60),
          isBranchRoot: true,
          stemLockMode: refLockMode,
        ),
      );

      nodes.add(
        const SongDnaNode(
          id: 'node_invasive_ref_beat',
          parentId: 'node_invasive_reference',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'Reference Beat Ingestion',
          subtitle: 'Stem Acoustic Conditioning',
          cueLabel: 'Ref Ingestion',
          icon: PhosphorIconsBold.musicNote,
          accentColor: Color(0xFFD946EF),
          branchUnlockProgress: 0.7,
          isInvasive: true,
          isTerminalReceptor: true,
          localPosition: Vector3D(90, 240, -60),
        ),
      );
    }

    if (vocal.isUsingClonedVoice) {
      invasiveCount++;
      nodes.add(
        const SongDnaNode(
          id: 'node_invasive_voice_clone',
          parentId: 'node_core',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'Cloned Voice Signature (VHU-SIG)',
          subtitle: 'Zero-Shot Personal Timbre Injected',
          cueLabel: 'Invasive: VHU-SIG Voice',
          icon: PhosphorIconsBold.fingerprint,
          accentColor: Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          isTerminalReceptor: true,
          localPosition: Vector3D(-30, 230, -80),
        ),
      );
    }

    if (remix != null) {
      invasiveCount++;
      nodes.add(
        SongDnaNode(
          id: 'node_invasive_remix',
          parentId: 'node_invasive_reference',
          category: SongDnaNodeCategory.invasiveThirdParty,
          title: 'Parent Reel Remix Lineage',
          subtitle:
              '${remix.parentTrackTitle} by ${remix.parentCreatorDisplayName}',
          cueLabel: 'Invasive: Remix Lineage',
          icon: PhosphorIconsBold.gitFork,
          accentColor: const Color(0xFFD946EF),
          branchUnlockProgress: 1.0,
          isInvasive: true,
          isDetachable: true,
          localPosition: Vector3D(-50, 170, 50),
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
      glow = const Color(0xFFF59E0B); // Amber (Beat/Core)
    }

    // Calculate completeness
    double totalProgress = 0;
    for (final node in nodes) {
      totalProgress += node.branchUnlockProgress;
    }
    final completeness = (totalProgress / nodes.length).clamp(0.0, 1.0);

    state = state.copyWith(
      nodes: nodes,
      selectedNodeId: state.selectedNodeId,
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
    if (nodeId == 'node_invasive_reference' ||
        nodeId == 'node_invasive_ref_beat') {
      _ref.read(studioFormProvider.notifier).setReferenceAudio(null);
    } else if (nodeId == 'node_invasive_remix' ||
        nodeId == 'node_invasive_remix_parent') {
      _ref.read(stemRemixProvider.notifier).clearRemix();
    } else if (nodeId == 'node_invasive_voice_clone') {
      final vocalState = _ref.read(vocalIdentityProvider);
      _ref
          .read(vocalIdentityProvider.notifier)
          .selectArchetype(vocalState.activeArchetype);
    }
    _recomputeGraph();
  }

  void attachSketchpadPreset(String presetTitle) {
    final notifier = _ref.read(melodySketchpadProvider.notifier);
    notifier.applyEuclideanGroove();
    _recomputeGraph();
  }

  /// Sets authority mode for a stem branch (REQ-P52-STEM-01..03).
  void setStemLockMode(String branchId, StemLockMode mode) {
    _ref
        .read(studioFormProvider.notifier)
        .setBranchStemLockMode(branchId, mode);
    _recomputeGraph();
  }

  /// Spawns a new dynamic instrument leaf bubble in 3D space (REQ-P52-LEAF-01).
  void addInstrumentLeaf({
    required String name,
    required PhosphorIconData icon,
    String? subtitle,
  }) {
    final id = 'node_leaf_${name.toLowerCase().replaceAll(' ', '_')}';
    _dynamicInstrumentLeaves.add(
      SongDnaNode(
        id: id,
        parentId: 'node_sketchpad_groove',
        category: SongDnaNodeCategory.instrumentsHarmony,
        title: name,
        subtitle: subtitle ?? 'Acoustic Solo Articulation',
        cueLabel: name,
        icon: icon,
        accentColor: Color(0xFF10B981),
        branchUnlockProgress: 1.0,
        isTerminalReceptor: true,
        localPosition: Vector3D(
          210.0 + (_dynamicInstrumentLeaves.length * 20.0),
          120.0 + (_dynamicInstrumentLeaves.length * 25.0),
          -20.0 + (_dynamicInstrumentLeaves.length * 15.0),
        ),
      ),
    );
    _recomputeGraph();
  }

  /// Exports pre-generation stem authority manifest (REQ-P52-PIPE-01).
  Map<String, dynamic> exportPregenStemLocksManifest() {
    final form = _ref.read(studioFormProvider);
    final manifest = <String, dynamic>{
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'locks': <String, String>{},
    };
    for (final entry in form.branchStemLockModes.entries) {
      manifest['locks'][entry.key] = entry.value.name;
    }
    return manifest;
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
