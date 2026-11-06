import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../controllers/biome_camera_controller.dart';
import 'heritage_crate_provider.dart';
import 'melody_sketchpad_provider.dart';
import 'studio_form_provider.dart';
import 'vocal_identity_provider.dart';

/// Provides the active 3D Mycelium Biome Graph, non-destructively entangled
/// with all 5 Studio Cockpit providers (REQ-P54-SYNC-01..04).
final myceliumBiomeGraphProvider =
    StateNotifierProvider<MyceliumBiomeGraphNotifier, MusicalDnaGraph>((ref) {
      final notifier = MyceliumBiomeGraphNotifier(ref);

      ref.listen<StudioFormState>(
        studioFormProvider,
        (_, _) => notifier.reconcileWithCockpitState(),
      );
      ref.listen<MelodySketchpadState>(
        melodySketchpadProvider,
        (_, _) => notifier.reconcileWithCockpitState(),
      );
      ref.listen<MpcSlicerState>(
        mpcSlicerProvider,
        (_, _) => notifier.reconcileWithCockpitState(),
      );
      ref.listen<HeritageCrateState>(
        heritageCrateProvider,
        (_, _) => notifier.reconcileWithCockpitState(),
      );
      ref.listen<VocalIdentityState>(
        vocalIdentityProvider,
        (_, _) => notifier.reconcileWithCockpitState(),
      );

      return notifier;
    });

/// Manages 3D Y-Up camera orbit, zoom, auto-rotation, and canopy flight targets.
final biomeCameraProvider =
    StateNotifierProvider<BiomeCameraNotifier, BiomeCameraState>((ref) {
      return BiomeCameraNotifier();
    });

class MyceliumBiomeGraphNotifier extends StateNotifier<MusicalDnaGraph> {
  final Ref _ref;
  final List<MyceliumChildNode> _customHarmonyLeaves = [];

  MyceliumBiomeGraphNotifier(this._ref)
    : super(
        _createInitialGraph(
          _ref.read(studioFormProvider),
          _ref.read(melodySketchpadProvider),
          _ref.read(mpcSlicerProvider),
          _ref.read(vocalIdentityProvider),
        ),
      );

  static MusicalDnaGraph _createInitialGraph(
    StudioFormState form,
    MelodySketchpadState sketchpad,
    MpcSlicerState mpc,
    VocalIdentityState vocal,
  ) {
    final seed = _computeSongFingerprintSeed(form);
    final rawClusters = _buildCanonicalClusters(
      form: form,
      sketchpad: sketchpad,
      mpc: mpc,
      vocal: vocal,
      customLeaves: const [],
    );

    final lumMap = _sectionLuminosity(SongJourneySection.chorus);
    final clusters = <MyceliumClusterDomain, MushroomFruitingBody>{};
    for (final entry in rawClusters.entries) {
      clusters[entry.key] = entry.value.copyWith(
        currentLuminosity: lumMap[entry.key] ?? 1.0,
      );
    }

    final hyphae = _buildCanonicalHyphae(clusters);
    final tendrils = _buildCanonicalTendrils(clusters, seed);
    final sprouts = _buildCanonicalSprouts(clusters, hyphae, seed);

    return MusicalDnaGraph(
      clusters: clusters,
      hyphaeEdges: hyphae,
      rootTendrils: tendrils,
      sproutNodes: sprouts,
      activeSection: SongJourneySection.chorus,
      growthPhase: BiomeGrowthPhase.ecosystemMature,
      growthProgress: 1.0,
      songFingerprintSeed: seed,
    );
  }

  static int _computeSongFingerprintSeed(StudioFormState form) {
    int hash = 5381;
    final seedStr =
        '${form.genre}_${form.tempo.name}_${form.prompt}_${form.language}';
    for (int i = 0; i < seedStr.length; i++) {
      hash = ((hash << 5) + hash) + seedStr.codeUnitAt(i);
      hash &= 0x7FFFFFFF;
    }
    return hash == 0 ? 42891 : hash;
  }

  static double _morphScale(double energy, [double baseline = 0.80]) {
    if ((energy - baseline).abs() < 0.05) return 1.0;
    return (1.0 + 0.15 * ((energy - baseline) / baseline)).clamp(0.85, 1.15);
  }

  static bool _isDomainLocked(
    StudioFormState form,
    MyceliumClusterDomain domain,
  ) {
    return form.branchStemLockModes[domain.studioBranchKey] ==
            StemLockMode.lockedPure44k ||
        form.branchStemLockModes[domain.legacyBranchAliasKey] ==
            StemLockMode.lockedPure44k;
  }

  static Map<MyceliumClusterDomain, MushroomFruitingBody>
  _buildCanonicalClusters({
    required StudioFormState form,
    required MelodySketchpadState sketchpad,
    required MpcSlicerState mpc,
    required VocalIdentityState vocal,
    required List<MyceliumChildNode> customLeaves,
  }) {
    // 1. melodyCore: Central Root Y ~= 32dp, Base Apex 140dp
    final notesCount = sketchpad.activePattern.notes.length;
    final tempoFactor = switch (form.tempo) {
      TempoBracket.slow => 0.65,
      TempoBracket.medium => 0.80,
      TempoBracket.fast => 0.90,
      TempoBracket.veryFast => 0.96,
    };
    final melEnergy =
        (0.92 +
                (notesCount > 6 ? (notesCount - 6) / 10.0 * 0.06 : 0.0) +
                (tempoFactor - 0.80) * 0.2)
            .clamp(0.40, 0.99);
    final melComplexity =
        (0.78 + (sketchpad.activePattern.conditioningStrength - 0.72) * 0.2)
            .clamp(0.40, 0.99);
    final melMorph = melEnergy == 0.92
        ? 1.0
        : (1.0 + 0.15 * ((melEnergy - 0.92) / 0.92)).clamp(0.85, 1.15);
    final melRootY = BiomeTerrainMath.heightAt(0.0, 0.0);
    final melStipe = (140.0 - melRootY) * melMorph;
    final melCapR = melMorph == 1.0 ? 56.0 : 56.0 * melMorph;
    final melLocked = _isDomainLocked(form, MyceliumClusterDomain.melodyCore);
    final melTelemetry =
        '${sketchpad.activePattern.instrument.label} • ${sketchpad.activePattern.musicalKey} ${sketchpad.activePattern.scaleMode.label}';

    final melCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.melodyCore,
      rootPosition: Vector3D(0.0, melRootY, 0.0),
      stipeHeight: melStipe,
      capRadius: melCapR,
      capDepth: 34.0 * melMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * melEnergy).round().clamp(40, 99),
      complexityPercent: (100 * melComplexity).round().clamp(40, 99),
      influencePercent: melEnergy == 0.92 && melComplexity == 0.78
          ? 95
          : (60 * melEnergy + 40 * melComplexity).round().clamp(45, 99),
      isStemLocked: melLocked,
      liveTelemetrySummary: melTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.harmonyNetwork,
        MyceliumClusterDomain.vocalNetwork,
        MyceliumClusterDomain.rhythmNetwork,
        MyceliumClusterDomain.emotionNetwork,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_mel_lead',
          parentDomain: MyceliumClusterDomain.melodyCore,
          title: '${form.genre} DNA Hook',
          subtitle:
              '${sketchpad.activePattern.bpm} BPM • ${sketchpad.activePattern.name}',
          iconIdentifier: 'musicNotes',
          intensityWeight: 0.94,
          localOffset: const Vector3D(0.0, 18.0, 36.0),
          isStemLocked: melLocked,
          studioMutatorKey: 'prompt',
        ),
        MyceliumChildNode(
          id: 'node_leaf_mel_instrument',
          parentDomain: MyceliumClusterDomain.melodyCore,
          title: sketchpad.activePattern.instrument.label,
          subtitle: 'Active Lead Synthesizer',
          iconIdentifier: 'pianoKeys',
          intensityWeight: 0.88,
          localOffset: const Vector3D(-28.0, 14.0, 20.0),
          isStemLocked: melLocked,
          studioMutatorKey: 'instrument',
        ),
        MyceliumChildNode(
          id: 'node_leaf_mel_key',
          parentDomain: MyceliumClusterDomain.melodyCore,
          title:
              'Key: ${sketchpad.activePattern.musicalKey} ${sketchpad.activePattern.scaleMode.label}',
          subtitle: 'Melodic Scale Anchor',
          iconIdentifier: 'waveform',
          intensityWeight: 0.82,
          localOffset: const Vector3D(28.0, 14.0, 20.0),
          isStemLocked: melLocked,
          studioMutatorKey: 'scale',
        ),
        MyceliumChildNode(
          id: 'node_leaf_mel_tracks',
          parentDomain: MyceliumClusterDomain.melodyCore,
          title: 'MultiTrack: 5 Channels',
          subtitle:
              '${sketchpad.multiTrackGroove.channels.length} Synchronized Tracks',
          iconIdentifier: 'sliders',
          intensityWeight: 0.85,
          localOffset: const Vector3D(-22.0, 10.0, -22.0),
          isStemLocked: melLocked,
          studioMutatorKey: 'tracks',
        ),
        MyceliumChildNode(
          id: 'node_leaf_mel_cond',
          parentDomain: MyceliumClusterDomain.melodyCore,
          title:
              'Melody Conditioning ${(sketchpad.activePattern.conditioningStrength * 100).round()}%',
          subtitle: 'Latent Diffusion Prior',
          iconIdentifier: 'sparkle',
          intensityWeight: 0.90,
          localOffset: const Vector3D(22.0, 10.0, -22.0),
          isStemLocked: melLocked,
          studioMutatorKey: 'conditioning',
        ),
      ],
    );

    // 2. rhythmNetwork: (-195, 95), Root Y ~= 22dp, Base Apex 96dp
    final rhyEnergy = ((mpc.bpm - 112.0) / 100.0 + 0.85).clamp(0.40, 0.99);
    final rhyComplexity =
        ((mpc.pads.length - 8) * 0.05 +
                (mpc.timeStretchRatio - 1.0) * 0.2 +
                0.80)
            .clamp(0.40, 0.99);
    final rhyMorph = (rhyEnergy - 0.85).abs() < 0.001
        ? 1.0
        : (1.0 + 0.15 * ((rhyEnergy - 0.85) / 0.85)).clamp(0.85, 1.15);
    final rhyRootY = BiomeTerrainMath.heightAt(-195.0, 95.0);
    final rhyStipe = (96.0 - rhyRootY) * rhyMorph;
    final rhyCapR = rhyMorph == 1.0 ? 42.0 : 42.0 * rhyMorph;
    final rhyLocked = _isDomainLocked(
      form,
      MyceliumClusterDomain.rhythmNetwork,
    );
    final rhyTelemetry =
        '${mpc.sourceTitle} • ${mpc.bpm} BPM (${form.tempo.label})';

    final rhyCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.rhythmNetwork,
      rootPosition: Vector3D(-195.0, rhyRootY, 95.0),
      stipeHeight: rhyStipe,
      capRadius: rhyCapR,
      capDepth: 26.0 * rhyMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * rhyEnergy).round().clamp(40, 99),
      complexityPercent: (100 * rhyComplexity).round().clamp(40, 99),
      influencePercent: (60 * rhyEnergy + 40 * rhyComplexity).round().clamp(
        45,
        99,
      ),
      isStemLocked: rhyLocked,
      liveTelemetrySummary: rhyTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.melodyCore,
        MyceliumClusterDomain.productionNetwork,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_rhy_bpm',
          parentDomain: MyceliumClusterDomain.rhythmNetwork,
          title: '${mpc.bpm} BPM Groove Engine',
          subtitle: form.tempo.label,
          iconIdentifier: 'metronome',
          intensityWeight: 0.96,
          localOffset: const Vector3D(0.0, 16.0, 28.0),
          isStemLocked: rhyLocked,
          studioMutatorKey: 'tempo',
        ),
        MyceliumChildNode(
          id: 'node_leaf_rhy_source',
          parentDomain: MyceliumClusterDomain.rhythmNetwork,
          title: 'Source: ${mpc.sourceTitle}',
          subtitle: '8-Pad MPC Sliced Audio',
          iconIdentifier: 'squaresFour',
          intensityWeight: 0.90,
          localOffset: const Vector3D(-22.0, 12.0, 16.0),
          isStemLocked: rhyLocked,
          studioMutatorKey: 'mpc',
        ),
        MyceliumChildNode(
          id: 'node_leaf_rhy_stretch',
          parentDomain: MyceliumClusterDomain.rhythmNetwork,
          title: 'Time Stretch ${mpc.timeStretchRatio.toStringAsFixed(1)}x',
          subtitle: 'Granular Pitch Anchor',
          iconIdentifier: 'waveSine',
          intensityWeight: 0.84,
          localOffset: const Vector3D(22.0, 12.0, 16.0),
          isStemLocked: rhyLocked,
          studioMutatorKey: 'stretch',
        ),
        MyceliumChildNode(
          id: 'node_leaf_rhy_sub',
          parentDomain: MyceliumClusterDomain.rhythmNetwork,
          title: '808 Log Sub Sync',
          subtitle: 'Amapiano / Urban Transient',
          iconIdentifier: 'speakerHigh',
          intensityWeight: 0.92,
          localOffset: const Vector3D(-18.0, 8.0, -18.0),
          isStemLocked: rhyLocked,
          studioMutatorKey: 'sub',
        ),
        MyceliumChildNode(
          id: 'node_leaf_rhy_clave',
          parentDomain: MyceliumClusterDomain.rhythmNetwork,
          title: 'Polyrhythmic Clave',
          subtitle: 'Syncopated High-Hat Grid',
          iconIdentifier: 'activity',
          intensityWeight: 0.86,
          localOffset: const Vector3D(18.0, 8.0, -18.0),
          isStemLocked: rhyLocked,
          studioMutatorKey: 'clave',
        ),
      ],
    );

    // 3. vocalNetwork: (-155, -90), Root Y ~= 26dp, Base Apex 120dp
    final voxEnergyBase = switch (form.vocalEnergy) {
      VocalEnergy.soft => 0.55,
      VocalEnergy.mid => 0.78,
      VocalEnergy.intense => 0.95,
    };
    final voxEnergy =
        (voxEnergyBase + (form.selectedVoiceProfile.loraScale - 0.8) * 0.3)
            .clamp(0.40, 0.99);
    final voxComplexity =
        (0.60 +
                (form.language == 'Tshivenḓa' || form.language == 'isiZulu'
                    ? 0.25
                    : 0.15))
            .clamp(0.40, 0.99);
    final voxMorph = _morphScale(voxEnergy);
    final voxRootY = BiomeTerrainMath.heightAt(-155.0, -90.0);
    final voxStipe = (120.0 - voxRootY) * voxMorph;
    final voxCapR = 47.0 * voxMorph;
    final voxLocked = _isDomainLocked(form, MyceliumClusterDomain.vocalNetwork);
    final voxTelemetry =
        '${form.selectedVoiceProfile.name} • ${form.language} (${(form.selectedVoiceProfile.loraScale * 100).round()}% LoRA)';

    final voxCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.vocalNetwork,
      rootPosition: Vector3D(-155.0, voxRootY, -90.0),
      stipeHeight: voxStipe,
      capRadius: voxCapR,
      capDepth: 29.0 * voxMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * voxEnergy).round().clamp(40, 99),
      complexityPercent: (100 * voxComplexity).round().clamp(40, 99),
      influencePercent: (60 * voxEnergy + 40 * voxComplexity).round().clamp(
        45,
        99,
      ),
      isStemLocked: voxLocked,
      liveTelemetrySummary: voxTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.melodyCore,
        MyceliumClusterDomain.emotionNetwork,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_vox_profile',
          parentDomain: MyceliumClusterDomain.vocalNetwork,
          title: form.selectedVoiceProfile.name,
          subtitle:
              '${(form.selectedVoiceProfile.loraScale * 100).round()}% LoRA Weight',
          iconIdentifier: 'microphone',
          intensityWeight: 0.95,
          localOffset: const Vector3D(0.0, 16.0, 32.0),
          isStemLocked: voxLocked,
          studioMutatorKey: 'vocalProfile',
        ),
        MyceliumChildNode(
          id: 'node_leaf_vox_lang',
          parentDomain: MyceliumClusterDomain.vocalNetwork,
          title: 'Language: ${form.language}',
          subtitle: 'Bantu Dialect & Accent',
          iconIdentifier: 'translate',
          intensityWeight: 0.90,
          localOffset: const Vector3D(-24.0, 12.0, 18.0),
          isStemLocked: voxLocked,
          studioMutatorKey: 'language',
        ),
        MyceliumChildNode(
          id: 'node_leaf_vox_mode',
          parentDomain: MyceliumClusterDomain.vocalNetwork,
          title: 'Vocal Mode: ${form.vocalMode.name.toUpperCase()}',
          subtitle: '${form.vocalGender.name} ${form.vocalVoices.name}',
          iconIdentifier: 'userSound',
          intensityWeight: 0.85,
          localOffset: const Vector3D(24.0, 12.0, 18.0),
          isStemLocked: voxLocked,
          studioMutatorKey: 'vocalMode',
        ),
        MyceliumChildNode(
          id: 'node_leaf_vox_energy',
          parentDomain: MyceliumClusterDomain.vocalNetwork,
          title: 'Energy: ${form.vocalEnergy.name.toUpperCase()}',
          subtitle: 'Timbre Dynamics & Breath',
          iconIdentifier: 'flame',
          intensityWeight: 0.88,
          localOffset: const Vector3D(-20.0, 8.0, -20.0),
          isStemLocked: voxLocked,
          studioMutatorKey: 'vocalEnergy',
        ),
        MyceliumChildNode(
          id: 'node_leaf_vox_inflect',
          parentDomain: MyceliumClusterDomain.vocalNetwork,
          title: 'Vibrato & Articulation',
          subtitle: 'Phonetic Ancestral Cadence',
          iconIdentifier: 'soundWave',
          intensityWeight: 0.82,
          localOffset: const Vector3D(20.0, 8.0, -20.0),
          isStemLocked: voxLocked,
          studioMutatorKey: 'inflection',
        ),
      ],
    );

    // 4. harmonyNetwork: (165, -85), Root Y ~= 25dp, Base Apex 115dp
    final harmEnergy = 0.78;
    final harmComplexity = 0.82;
    final harmMorph = _morphScale(harmEnergy, 0.78);
    final harmRootY = BiomeTerrainMath.heightAt(165.0, -85.0);
    final harmStipe = (115.0 - harmRootY) * harmMorph;
    final harmCapR = 45.0 * harmMorph;
    final harmLocked = _isDomainLocked(
      form,
      MyceliumClusterDomain.harmonyNetwork,
    );
    final harmTelemetry =
        '${sketchpad.activePattern.musicalKey} Root • ${sketchpad.activePattern.scaleMode.label}';

    final harmCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.harmonyNetwork,
      rootPosition: Vector3D(165.0, harmRootY, -85.0),
      stipeHeight: harmStipe,
      capRadius: harmCapR,
      capDepth: 28.0 * harmMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * harmEnergy).round().clamp(40, 99),
      complexityPercent: (100 * harmComplexity).round().clamp(40, 99),
      influencePercent: (60 * harmEnergy + 40 * harmComplexity).round().clamp(
        45,
        99,
      ),
      isStemLocked: harmLocked,
      liveTelemetrySummary: harmTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.melodyCore,
        MyceliumClusterDomain.emotionNetwork,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_harm_rhodes',
          parentDomain: MyceliumClusterDomain.harmonyNetwork,
          title: 'Private School Rhodes 7ths',
          subtitle: 'Warm Neo-Soul Voicings',
          iconIdentifier: 'pianoKeys',
          intensityWeight: 0.88,
          localOffset: const Vector3D(0.0, 16.0, 30.0),
          isStemLocked: harmLocked,
          studioMutatorKey: 'chords',
        ),
        MyceliumChildNode(
          id: 'node_leaf_harm_scale',
          parentDomain: MyceliumClusterDomain.harmonyNetwork,
          title: 'Scale: ${sketchpad.activePattern.scaleMode.label}',
          subtitle: 'Modal Polyphony Matrix',
          iconIdentifier: 'scales',
          intensityWeight: 0.85,
          localOffset: const Vector3D(-24.0, 12.0, 18.0),
          isStemLocked: harmLocked,
          studioMutatorKey: 'scale',
        ),
        MyceliumChildNode(
          id: 'node_leaf_harm_crate',
          parentDomain: MyceliumClusterDomain.harmonyNetwork,
          title: 'Crate Heritage Chop',
          subtitle: 'African Ethnomusicology',
          iconIdentifier: 'vinylRecord',
          intensityWeight: 0.82,
          localOffset: const Vector3D(24.0, 12.0, 18.0),
          isStemLocked: harmLocked,
          studioMutatorKey: 'crate',
        ),
        MyceliumChildNode(
          id: 'node_leaf_harm_pad',
          parentDomain: MyceliumClusterDomain.harmonyNetwork,
          title: 'Warm Pad Atmosphere',
          subtitle: 'Analog Synthesizer Bed',
          iconIdentifier: 'cloudFog',
          intensityWeight: 0.80,
          localOffset: const Vector3D(0.0, 8.0, -22.0),
          isStemLocked: harmLocked,
          studioMutatorKey: 'pad',
        ),
        ...customLeaves,
      ],
    );

    // 5. emotionNetwork: (190, 75), Root Y ~= 21dp, Base Apex 96dp
    final emoEnergyBase = switch (form.mood.toLowerCase()) {
      'dark & intense' || 'dark' => 0.92,
      'uplifting & vibrant' || 'uplifting' || 'joyful' => 0.88,
      'soulful & nostalgic' || 'melancholic' => 0.76,
      'peaceful & spiritual' || 'calm' || 'spiritual' => 0.65,
      _ => 0.80,
    };
    final emoEnergy = emoEnergyBase.clamp(0.40, 0.99);
    final emoComplexity = 0.75;
    final emoMorph = _morphScale(emoEnergy, 0.88);
    final emoRootY = BiomeTerrainMath.heightAt(190.0, 75.0);
    final emoStipe = (96.0 - emoRootY) * emoMorph;
    final emoCapR = 41.0 * emoMorph;
    final emoLocked = _isDomainLocked(
      form,
      MyceliumClusterDomain.emotionNetwork,
    );
    final emoTelemetry =
        'Mood: ${form.mood} • ${form.prompt.isEmpty ? "Curated African Vibe" : "Custom Prompt DNA"}';

    final emoCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.emotionNetwork,
      rootPosition: Vector3D(190.0, emoRootY, 75.0),
      stipeHeight: emoStipe,
      capRadius: emoCapR,
      capDepth: 25.0 * emoMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * emoEnergy).round().clamp(40, 99),
      complexityPercent: (100 * emoComplexity).round().clamp(40, 99),
      influencePercent: (60 * emoEnergy + 40 * emoComplexity).round().clamp(
        45,
        99,
      ),
      isStemLocked: emoLocked,
      liveTelemetrySummary: emoTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.melodyCore,
        MyceliumClusterDomain.vocalNetwork,
        MyceliumClusterDomain.harmonyNetwork,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_emo_mood',
          parentDomain: MyceliumClusterDomain.emotionNetwork,
          title: 'Mood: ${form.mood}',
          subtitle: 'Emotional Progression',
          iconIdentifier: 'heart',
          intensityWeight: 0.94,
          localOffset: const Vector3D(0.0, 15.0, 26.0),
          isStemLocked: emoLocked,
          studioMutatorKey: 'mood',
        ),
        MyceliumChildNode(
          id: 'node_leaf_emo_arc',
          parentDomain: MyceliumClusterDomain.emotionNetwork,
          title: 'Tension Arc: Dynamic',
          subtitle: 'African Dance Build & Drop',
          iconIdentifier: 'trendUp',
          intensityWeight: 0.88,
          localOffset: const Vector3D(-20.0, 11.0, 16.0),
          isStemLocked: emoLocked,
          studioMutatorKey: 'arc',
        ),
        MyceliumChildNode(
          id: 'node_leaf_emo_reverb',
          parentDomain: MyceliumClusterDomain.emotionNetwork,
          title: 'Soul Plate Reverb',
          subtitle: 'Spatial Depth & Warmth',
          iconIdentifier: 'sparkle',
          intensityWeight: 0.82,
          localOffset: const Vector3D(20.0, 11.0, 16.0),
          isStemLocked: emoLocked,
          studioMutatorKey: 'reverb',
        ),
        MyceliumChildNode(
          id: 'node_leaf_emo_spirit',
          parentDomain: MyceliumClusterDomain.emotionNetwork,
          title: 'Ancestral Call Resonance',
          subtitle: 'Spiritual Harmonic Weight',
          iconIdentifier: 'sun',
          intensityWeight: 0.86,
          localOffset: const Vector3D(0.0, 8.0, -20.0),
          isStemLocked: emoLocked,
          studioMutatorKey: 'spirit',
        ),
      ],
    );

    // 6. productionNetwork: (-35, 155), Root Y ~= 18dp, Base Apex 82dp
    final prodEnergy = 0.82;
    final prodComplexity = 0.78;
    final prodMorph = _morphScale(prodEnergy, 0.82);
    final prodRootY = BiomeTerrainMath.heightAt(-35.0, 155.0);
    final prodStipe = (82.0 - prodRootY) * prodMorph;
    final prodCapR = 39.0 * prodMorph;
    final prodLocked = _isDomainLocked(
      form,
      MyceliumClusterDomain.productionNetwork,
    );
    const prodTelemetry = 'Ceiling: -0.3dB • 44.1 kHz Studio Mastering Ceiling';

    final prodCluster = MushroomFruitingBody(
      domain: MyceliumClusterDomain.productionNetwork,
      rootPosition: Vector3D(-35.0, prodRootY, 155.0),
      stipeHeight: prodStipe,
      capRadius: prodCapR,
      capDepth: 23.0 * prodMorph,
      currentLuminosity: 1.0,
      dynamicPulseRate: 1.0,
      intensityPercent: (100 * prodEnergy).round().clamp(40, 99),
      complexityPercent: (100 * prodComplexity).round().clamp(40, 99),
      influencePercent: (60 * prodEnergy + 40 * prodComplexity).round().clamp(
        45,
        99,
      ),
      isStemLocked: prodLocked,
      liveTelemetrySummary: prodTelemetry,
      connectedDomains: const [
        MyceliumClusterDomain.rhythmNetwork,
        MyceliumClusterDomain.melodyCore,
      ],
      childLeaves: [
        MyceliumChildNode(
          id: 'node_leaf_prod_ceiling',
          parentDomain: MyceliumClusterDomain.productionNetwork,
          title: 'Master Ceiling -0.3dB',
          subtitle: 'True-peak broadcast limiter',
          iconIdentifier: 'shieldCheck',
          intensityWeight: 0.92,
          localOffset: const Vector3D(0.0, 14.0, 28.0),
          isStemLocked: prodLocked,
          studioMutatorKey: 'limiter',
        ),
        MyceliumChildNode(
          id: 'node_leaf_prod_stereo',
          parentDomain: MyceliumClusterDomain.productionNetwork,
          title: '3D Binaural Spread',
          subtitle: 'Spatial Pan & Phase Alignment',
          iconIdentifier: 'headphones',
          intensityWeight: 0.88,
          localOffset: const Vector3D(-20.0, 10.0, 16.0),
          isStemLocked: prodLocked,
          studioMutatorKey: 'spatial',
        ),
        MyceliumChildNode(
          id: 'node_leaf_prod_eq',
          parentDomain: MyceliumClusterDomain.productionNetwork,
          title: 'Dynamic Low-End EQ',
          subtitle: 'Sub Log Control 30-80 Hz',
          iconIdentifier: 'slidersHorizontal',
          intensityWeight: 0.85,
          localOffset: const Vector3D(20.0, 10.0, 16.0),
          isStemLocked: prodLocked,
          studioMutatorKey: 'eq',
        ),
        MyceliumChildNode(
          id: 'node_leaf_prod_tape',
          parentDomain: MyceliumClusterDomain.productionNetwork,
          title: 'Analog Tape Warmth',
          subtitle: 'Odd/Even Harmonic Polish',
          iconIdentifier: 'cassetteTape',
          intensityWeight: 0.86,
          localOffset: const Vector3D(0.0, 7.0, -18.0),
          isStemLocked: prodLocked,
          studioMutatorKey: 'tape',
        ),
      ],
    );

    return {
      MyceliumClusterDomain.melodyCore: melCluster,
      MyceliumClusterDomain.rhythmNetwork: rhyCluster,
      MyceliumClusterDomain.vocalNetwork: voxCluster,
      MyceliumClusterDomain.harmonyNetwork: harmCluster,
      MyceliumClusterDomain.emotionNetwork: emoCluster,
      MyceliumClusterDomain.productionNetwork: prodCluster,
    };
  }

  static List<MyceliumHyphaEdge> _buildCanonicalHyphae(
    Map<MyceliumClusterDomain, MushroomFruitingBody> clusters,
  ) {
    final edges = <MyceliumHyphaEdge>[];
    final domains = MyceliumClusterDomain.values;

    int edgeIdx = 0;
    for (int i = 0; i < domains.length; i++) {
      for (int j = i + 1; j < domains.length; j++) {
        final src = domains[i];
        final tgt = domains[j];
        final cSrc = clusters[src]!;
        final cTgt = clusters[tgt]!;

        final isArterial = cSrc.connectedDomains.contains(tgt);
        final condWeight = isArterial ? 0.92 : 0.55;

        // Vector perpendicular in horizontal XZ plane
        final dx = cTgt.rootPosition.x - cSrc.rootPosition.x;
        final dz = cTgt.rootPosition.z - cSrc.rootPosition.z;
        final len = math.sqrt(dx * dx + dz * dz);
        final nx = len > 1e-4 ? -dz / len : 0.0;
        final nz = len > 1e-4 ? dx / len : 1.0;

        // 9 3D Catmull-Rom spline waypoints on Y = h(X, Z) + 1.5
        const int numWp = 9;
        final waypoints = <Vector3D>[];
        for (int m = 0; m < numWp; m++) {
          final tm = m / (numWp - 1);
          final latWave =
              22.0 *
              math.sin(math.pi * tm) *
              math.sin(2.0 * math.pi * tm + edgeIdx * 0.7);
          final x =
              (1.0 - tm) * cSrc.rootPosition.x +
              tm * cTgt.rootPosition.x +
              latWave * nx;
          final z =
              (1.0 - tm) * cSrc.rootPosition.z +
              tm * cTgt.rootPosition.z +
              latWave * nz;
          final y = BiomeTerrainMath.heightAt(x, z) + 1.5;
          waypoints.add(Vector3D(x, y, z));
        }

        edges.add(
          MyceliumHyphaEdge(
            id: 'hypha_${src.name}_${tgt.name}',
            sourceDomain: src,
            targetDomain: tgt,
            splineWaypoints: waypoints,
            conductivityWeight: condWeight,
            isPrimaryArterial: isArterial,
            isStemLocked: cSrc.isStemLocked && cTgt.isStemLocked,
            photonCount: isArterial ? 4 : 2,
          ),
        );
        edgeIdx++;
      }
    }
    return edges;
  }

  static List<MyceliumRootTendril> _buildCanonicalTendrils(
    Map<MyceliumClusterDomain, MushroomFruitingBody> clusters,
    int seed,
  ) {
    final tendrils = <MyceliumRootTendril>[];

    for (final cluster in clusters.values) {
      const int tendrilsPerCluster = 12;
      for (int j = 0; j < tendrilsPerCluster; j++) {
        final angle =
            (2.0 * math.pi * j) / tendrilsPerCluster +
            (cluster.domain.index * 0.35);
        final waypoints = <Vector3D>[];
        const int steps = 5;
        const double stepLen = 18.0;

        double currX = cluster.rootPosition.x;
        double currZ = cluster.rootPosition.z;

        for (int s = 0; s < steps; s++) {
          final segDist = s * stepLen;
          final wiggle = 3.5 * math.sin(s * 1.2 + j);
          final x =
              currX + (segDist * math.cos(angle)) - (wiggle * math.sin(angle));
          final z =
              currZ + (segDist * math.sin(angle)) + (wiggle * math.cos(angle));
          final y = BiomeTerrainMath.heightAt(x, z) + 0.8;
          waypoints.add(Vector3D(x, y, z));
        }

        tendrils.add(
          MyceliumRootTendril(
            id: 'tendril_${cluster.domain.name}_$j',
            originDomain: cluster.domain,
            waypoints: waypoints,
            thickness: (1.2 - j * 0.04).clamp(0.6, 1.4),
            luminosity: (0.75 + 0.25 * math.sin(j * 0.8)).clamp(0.4, 1.0),
          ),
        );
      }
    }
    return tendrils;
  }

  static List<MyceliumSproutNode> _buildCanonicalSprouts(
    Map<MyceliumClusterDomain, MushroomFruitingBody> clusters,
    List<MyceliumHyphaEdge> hyphae,
    int seed,
  ) {
    final sprouts = <MyceliumSproutNode>[];
    const int count = 16;

    for (int i = 0; i < count; i++) {
      final edge = hyphae[i % hyphae.length];
      final t = 0.22 + 0.56 * ((i * 7 + 3) % 11) / 10.0;
      final pos = edge.sampleAt(t);
      final height = 9.0 + (i % 5) * 2.2; // 9.0 to 17.8 dp
      final capR = 5.0 + (i % 4) * 1.8; // 5.0 to 10.4 dp

      sprouts.add(
        MyceliumSproutNode(
          id: 'sprout_$i',
          rootPosition: Vector3D(
            pos.x,
            BiomeTerrainMath.heightAt(pos.x, pos.z),
            pos.z,
          ),
          height: height,
          capRadius: capR,
          hexColor: edge.sourceDomain.hexColor,
          pulsePhase: (i * 0.45) % (2.0 * math.pi),
        ),
      );
    }
    return sprouts;
  }

  static Map<MyceliumClusterDomain, double> _sectionLuminosity(
    SongJourneySection section,
  ) {
    return switch (section) {
      SongJourneySection.intro => {
        MyceliumClusterDomain.melodyCore: 0.75,
        MyceliumClusterDomain.rhythmNetwork: 0.88,
        MyceliumClusterDomain.vocalNetwork: 0.35,
        MyceliumClusterDomain.harmonyNetwork: 0.70,
        MyceliumClusterDomain.emotionNetwork: 0.50,
        MyceliumClusterDomain.productionNetwork: 0.82,
      },
      SongJourneySection.verse => {
        MyceliumClusterDomain.melodyCore: 0.80,
        MyceliumClusterDomain.rhythmNetwork: 0.85,
        MyceliumClusterDomain.vocalNetwork: 0.92,
        MyceliumClusterDomain.harmonyNetwork: 0.68,
        MyceliumClusterDomain.emotionNetwork: 0.72,
        MyceliumClusterDomain.productionNetwork: 0.65,
      },
      SongJourneySection.chorus => {
        MyceliumClusterDomain.melodyCore: 1.0,
        MyceliumClusterDomain.rhythmNetwork: 0.98,
        MyceliumClusterDomain.vocalNetwork: 1.0,
        MyceliumClusterDomain.harmonyNetwork: 0.95,
        MyceliumClusterDomain.emotionNetwork: 1.0,
        MyceliumClusterDomain.productionNetwork: 0.94,
      },
      SongJourneySection.bridge => {
        MyceliumClusterDomain.melodyCore: 0.68,
        MyceliumClusterDomain.rhythmNetwork: 0.55,
        MyceliumClusterDomain.vocalNetwork: 0.82,
        MyceliumClusterDomain.harmonyNetwork: 0.96,
        MyceliumClusterDomain.emotionNetwork: 0.94,
        MyceliumClusterDomain.productionNetwork: 0.88,
      },
      SongJourneySection.outro => {
        MyceliumClusterDomain.melodyCore: 0.60,
        MyceliumClusterDomain.rhythmNetwork: 0.50,
        MyceliumClusterDomain.vocalNetwork: 0.40,
        MyceliumClusterDomain.harmonyNetwork: 0.65,
        MyceliumClusterDomain.emotionNetwork: 0.48,
        MyceliumClusterDomain.productionNetwork: 0.70,
      },
    };
  }

  /// Reconciles 3D Mycelium Biome state non-destructively with all 5 Studio providers (REQ-P54-SYNC-01..04).
  void reconcileWithCockpitState() {
    final form = _ref.read(studioFormProvider);
    final sketchpad = _ref.read(melodySketchpadProvider);
    final mpc = _ref.read(mpcSlicerProvider);
    final vocal = _ref.read(vocalIdentityProvider);

    final rawClusters = _buildCanonicalClusters(
      form: form,
      sketchpad: sketchpad,
      mpc: mpc,
      vocal: vocal,
      customLeaves: _customHarmonyLeaves,
    );

    final lumMap = _sectionLuminosity(state.activeSection);
    final updatedClusters = <MyceliumClusterDomain, MushroomFruitingBody>{};
    for (final entry in rawClusters.entries) {
      updatedClusters[entry.key] = entry.value.copyWith(
        currentLuminosity: lumMap[entry.key] ?? 1.0,
      );
    }

    final updatedHyphae = _buildCanonicalHyphae(updatedClusters);
    final seed = _computeSongFingerprintSeed(form);
    final updatedTendrils = _buildCanonicalTendrils(updatedClusters, seed);
    final updatedSprouts = _buildCanonicalSprouts(
      updatedClusters,
      updatedHyphae,
      seed,
    );

    state = state.copyWith(
      clusters: updatedClusters,
      hyphaeEdges: updatedHyphae,
      rootTendrils: updatedTendrils,
      sproutNodes: updatedSprouts,
    );
  }

  void focusCluster(MyceliumClusterDomain? domain) {
    if (state.focusedDomain == domain) return;
    state = state.copyWith(
      focusedDomain: domain,
      clearFocusedDomain: domain == null,
      clearSelectedChildNode: true,
    );
  }

  void selectChildLeaf(String? leafId) {
    state = state.copyWith(
      selectedChildNodeId: leafId,
      clearSelectedChildNode: leafId == null,
    );
  }

  void toggleNetworkLayer(MyceliumNetworkLayer layer) {
    final updated = Set<MyceliumNetworkLayer>.from(state.activeLayers);
    if (updated.contains(layer)) {
      if (updated.length > 1) {
        updated.remove(layer);
      }
    } else {
      updated.add(layer);
    }
    state = state.copyWith(activeLayers: updated);
  }

  void selectSongJourneySection(SongJourneySection section) {
    final lumMap = _sectionLuminosity(section);
    final updatedClusters = <MyceliumClusterDomain, MushroomFruitingBody>{};
    for (final entry in state.clusters.entries) {
      updatedClusters[entry.key] = entry.value.copyWith(
        currentLuminosity: lumMap[entry.key] ?? 1.0,
      );
    }

    state = state.copyWith(activeSection: section, clusters: updatedClusters);
  }

  void setGrowthProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final phase = switch (clamped) {
      < 0.12 => BiomeGrowthPhase.nucleusSeed,
      < 0.30 => BiomeGrowthPhase.primaryNodesEmerge,
      < 0.62 => BiomeGrowthPhase.hyphaeBranching,
      < 0.90 => BiomeGrowthPhase.fruitingBodiesSprout,
      _ => BiomeGrowthPhase.ecosystemMature,
    };
    state = state.copyWith(growthProgress: clamped, growthPhase: phase);
  }

  void toggleCompareMode() {
    state = state.copyWith(isCompareModeActive: !state.isCompareModeActive);
  }

  void toggleAnalyseOverlay() {
    state = state.copyWith(
      isAnalyseOverlayActive: !state.isAnalyseOverlayActive,
    );
  }

  void toggleClusterStemLock(MyceliumClusterDomain domain) {
    _ref.read(studioFormProvider.notifier).cycleClusterStemLockMode(domain);
    reconcileWithCockpitState();
  }

  void addInstrumentLeaf({
    required String name,
    required String iconIdentifier,
  }) {
    final targetDomain = MyceliumClusterDomain.harmonyNetwork;
    final leafId = 'node_leaf_custom_${DateTime.now().millisecondsSinceEpoch}';
    final count =
        (state.clusters[targetDomain]?.childLeaves.length ?? 0) +
        _customHarmonyLeaves.length;
    final angle = (2.0 * math.pi * count) / (count + 1);

    final newLeaf = MyceliumChildNode(
      id: leafId,
      parentDomain: targetDomain,
      title: name,
      subtitle: 'Dynamic Instrument Leaf',
      iconIdentifier: iconIdentifier,
      intensityWeight: 0.85,
      localOffset: Vector3D(
        34.0 * math.cos(angle),
        14.0,
        30.0 * math.sin(angle),
      ),
    );

    _customHarmonyLeaves.add(newLeaf);
    reconcileWithCockpitState();
  }
}
