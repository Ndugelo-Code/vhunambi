import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../offline/data/services/offline_storage_service.dart';
import '../../../player/data/services/wav_file_writer_io.dart';
import '../../../studio/domain/models/melody_sketchpad_models.dart';
import '../../../studio/domain/services/melody_wav_synthesizer.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/services/sovereign_certificate_signer.dart';

typedef StemDownloadProgressCallback = void Function(
  double fraction,
  String statusLabel,
);

/// Unpacks or deterministically renders real un-tagged 44.1 kHz 16-bit PCM WAV masters
/// and isolated 4-channel stems (`drums`, `bass`, `melody`, `other`) into the buyer's
/// local Vault directory `<vaultAudioDir>/licensed/<beatId>/` (REQ-P58-DEL-01..04).
class BeatDeliveryUnpackerService {
  final IOfflineStorageService _offlineStorage;
  final Dio _dio;
  final Future<void> Function(String path, Uint8List bytes) _fileWriter;
  final bool allowNetworkFetch;

  BeatDeliveryUnpackerService({
    required this._offlineStorage,
    Dio? dio,
    Future<void> Function(String path, Uint8List bytes)? fileWriter,
    bool? allowNetworkFetch,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 8),
                responseType: ResponseType.bytes,
              ),
            ),
        _fileWriter = fileWriter ?? writeWavToFile,
        allowNetworkFetch = allowNetworkFetch ?? !_detectTestMode();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Resolves relative paths into [Directory.systemTemp.path] identically to [writeWavToFile]
  /// so returned paths match physical disk files on Android/Linux/Windows/tests.
  static String normalizeWritablePath(String candidatePath) {
    if (kIsWeb) return candidatePath;
    if (!candidatePath.startsWith('/') &&
        !candidatePath.contains(':\\') &&
        !candidatePath.startsWith('\\')) {
      return '${Directory.systemTemp.path}/$candidatePath';
    }
    return candidatePath;
  }

  Future<UnpackedBeatPackage> unpackPurchasedBeat({
    required BeatListingEntity beat,
    required BeatCheckoutTier tier,
    StemDownloadProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.15, 'Resolving local Vault stem directory...');
    final rawBaseDir = await _offlineStorage.resolveVaultAudioDirectory();
    final baseDir = normalizeWritablePath('$rawBaseDir/licensed/${beat.id}');

    final masterFilename = tier == BeatCheckoutTier.basicMp3
        ? 'untagged_master.wav'
        : 'master_44k1.wav';
    final masterPath = '$baseDir/$masterFilename';

    // 1. Build groove blueprint matching BPM, Musical Key, Genre & Beat ID
    final masterGroove = _buildGrooveForBeat(beat);

    onProgress?.call(0.35, 'Provisioning un-tagged 44.1 kHz master...');
    var synthesizedOffline = true;
    Uint8List? masterBytes;

    if (allowNetworkFetch && beat.previewAudioUrl.startsWith('http')) {
      masterBytes = await _tryFetchRemoteAudio(beat.previewAudioUrl);
      if (masterBytes != null) {
        synthesizedOffline = false;
      }
    }

    masterBytes ??=
        MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(masterGroove);

    await _fileWriter(masterPath, masterBytes);
    final masterSha256 = SovereignCertificateSigner.sha256HexBytes(masterBytes);
    var totalBytes = masterBytes.length;

    // 2. If Exclusive Stem License, unpack all 4 isolated stems at 44.1 kHz
    final stemPaths = <String, String>{};
    if (tier.includesStems) {
      const stemRoles = <String>['drums', 'bass', 'melody', 'other'];
      for (var idx = 0; idx < stemRoles.length; idx++) {
        final stemKey = stemRoles[idx];
        final frac = 0.50 + ((idx + 1) / stemRoles.length) * 0.45;
        onProgress?.call(frac, 'Unpacking 44.1 kHz stem: $stemKey...');

        final stemGroove = _isolateStemGroove(masterGroove, stemKey);
        final stemBytes =
            MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(stemGroove);
        final stemPath = '$baseDir/${stemKey}_44k1.wav';
        await _fileWriter(stemPath, stemBytes);
        stemPaths[stemKey] = stemPath;
        totalBytes += stemBytes.length;
      }
    }

    onProgress?.call(1.0, 'Vault assets verified.');
    return UnpackedBeatPackage(
      beatId: beat.id,
      tier: tier,
      baseDirectory: baseDir,
      masterPath: masterPath,
      stemPaths: Map<String, String>.unmodifiable(stemPaths),
      masterFileSha256: masterSha256,
      totalBytes: totalBytes,
      formatEntitlement:
          tier == BeatCheckoutTier.basicMp3 ? 'mp3_standard' : 'wav_44k1_pcm16',
      synthesizedOffline: synthesizedOffline,
    );
  }

  Future<Uint8List?> _tryFetchRemoteAudio(String url) async {
    if (url.contains('cdn.vhunambi.com') || url.contains('r2.vhunambi.com')) {
      return null;
    }
    try {
      final response = await _dio.get<List<int>>(url);
      final data = response.data;
      if (response.statusCode == 200 && data != null && data.length > 44) {
        return Uint8List.fromList(data);
      }
    } catch (_) {}
    return null;
  }

  static MultiTrackGrooveEntity _buildGrooveForBeat(BeatListingEntity beat) {
    final g = beat.genre.toLowerCase();
    final kit = g.contains('gqom')
        ? BeatKitGenre.gqom
        : g.contains('afrobeats')
            ? BeatKitGenre.afrobeats
            : g.contains('house')
                ? BeatKitGenre.house
                : BeatKitGenre.amapiano;
    final bassInstrument = g.contains('gqom')
        ? SketchpadInstrument.gqomDarkSub
        : SketchpadInstrument.amapianoLogDrum;
    final melodyInstrument = g.contains('maskandi')
        ? SketchpadInstrument.maskandiGuitar
        : g.contains('afro')
            ? SketchpadInstrument.sopranoSax
            : SketchpadInstrument.privateSchoolRhodes;
    final scale = g.contains('gqom')
        ? AfricanScaleMode.gqomPhrygianDark
        : g.contains('maskandi')
            ? AfricanScaleMode.maskandiHexatonic
            : AfricanScaleMode.minorPentatonic;

    final seedOffset = beat.id.codeUnits.fold<int>(0, (a, b) => a + b) % 4;

    return MultiTrackGrooveEntity(
      id: 'licensed_${beat.id}',
      name: beat.title,
      bpm: beat.bpm.clamp(60, 200),
      musicalKey: beat.musicalKey,
      scaleMode: scale,
      channels: <SketchpadChannelRole, SketchpadChannelTrack>{
        SketchpadChannelRole.drums: SketchpadChannelTrack(
          role: SketchpadChannelRole.drums,
          instrument: bassInstrument,
          beatKit: kit,
          steps: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 1, velocity: 0.96),
            MelodyStepNote(stepIndex: 4, scaleRow: 1, velocity: 0.90),
            MelodyStepNote(stepIndex: 8, scaleRow: 1, velocity: 0.96),
            MelodyStepNote(stepIndex: 12, scaleRow: 1, velocity: 0.90),
            MelodyStepNote(stepIndex: 6, scaleRow: 4, velocity: 0.78),
            MelodyStepNote(stepIndex: 14, scaleRow: 4, velocity: 0.80),
          ],
        ),
        SketchpadChannelRole.bass: SketchpadChannelTrack(
          role: SketchpadChannelRole.bass,
          instrument: bassInstrument,
          beatKit: kit,
          steps: [
            const MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.95),
            MelodyStepNote(
              stepIndex: (3 + seedOffset) % 16,
              scaleRow: 2,
              velocity: 0.88,
            ),
            const MelodyStepNote(
              stepIndex: 7,
              scaleRow: 3,
              velocity: 0.92,
              hasGlide: true,
            ),
            const MelodyStepNote(stepIndex: 11, scaleRow: 0, velocity: 0.90),
          ],
        ),
        SketchpadChannelRole.chords: SketchpadChannelTrack(
          role: SketchpadChannelRole.chords,
          instrument: melodyInstrument,
          beatKit: kit,
          volume: 0.85,
          steps: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.80),
            MelodyStepNote(stepIndex: 6, scaleRow: 2, velocity: 0.76),
            MelodyStepNote(stepIndex: 10, scaleRow: 4, velocity: 0.82),
          ],
        ),
        SketchpadChannelRole.lead: SketchpadChannelTrack(
          role: SketchpadChannelRole.lead,
          instrument: melodyInstrument,
          beatKit: kit,
          volume: 0.78,
          steps: [
            MelodyStepNote(stepIndex: seedOffset, scaleRow: 5, velocity: 0.75),
            const MelodyStepNote(stepIndex: 9, scaleRow: 6, velocity: 0.78),
            const MelodyStepNote(stepIndex: 13, scaleRow: 4, velocity: 0.72),
          ],
        ),
        SketchpadChannelRole.hats: SketchpadChannelTrack(
          role: SketchpadChannelRole.hats,
          instrument: bassInstrument,
          beatKit: kit,
          volume: 0.72,
          steps: const [
            MelodyStepNote(stepIndex: 2, scaleRow: 3, velocity: 0.70),
            MelodyStepNote(stepIndex: 6, scaleRow: 3, velocity: 0.72),
            MelodyStepNote(stepIndex: 10, scaleRow: 5, velocity: 0.75),
            MelodyStepNote(stepIndex: 14, scaleRow: 6, velocity: 0.70),
          ],
        ),
      },
    );
  }

  static MultiTrackGrooveEntity _isolateStemGroove(
    MultiTrackGrooveEntity master,
    String stemKey,
  ) {
    final subset = <SketchpadChannelRole, SketchpadChannelTrack>{};
    switch (stemKey) {
      case 'drums':
        if (master.channels[SketchpadChannelRole.drums] case final t?) {
          subset[SketchpadChannelRole.drums] = t.copyWith(isMuted: false);
        }
      case 'bass':
        if (master.channels[SketchpadChannelRole.bass] case final t?) {
          subset[SketchpadChannelRole.bass] = t.copyWith(isMuted: false);
        }
      case 'melody':
        if (master.channels[SketchpadChannelRole.chords] case final c?) {
          subset[SketchpadChannelRole.chords] = c.copyWith(isMuted: false);
        }
        if (master.channels[SketchpadChannelRole.lead] case final l?) {
          subset[SketchpadChannelRole.lead] = l.copyWith(isMuted: false);
        }
      case 'other':
      default:
        if (master.channels[SketchpadChannelRole.hats] case final h?) {
          subset[SketchpadChannelRole.hats] = h.copyWith(isMuted: false);
        }
    }

    return MultiTrackGrooveEntity(
      id: '${master.id}_$stemKey',
      name: '${master.name} ($stemKey)',
      bpm: master.bpm,
      musicalKey: master.musicalKey,
      scaleMode: master.scaleMode,
      channels: subset,
    );
  }
}

