// ignore_for_file: experimental_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/track.dart';
import '../../../offline/data/services/offline_storage_service.dart';
import '../../../offline/domain/services/vault_envelope_crypto.dart';

/// Raised when no playable audio source can be resolved for a track
/// (REQ-AUD-09). Offline-forced playback of an uncached track must surface this
/// cleanly instead of freezing or crashing the transport.
@immutable
class AudioSourceException implements Exception {
  final String message;
  final String trackId;

  /// `true` when the failure is caused by forced-offline mode with no local copy.
  final bool requiresConnectivity;

  const AudioSourceException(
    this.message, {
    required this.trackId,
    this.requiresConnectivity = false,
  });

  @override
  String toString() => 'AudioSourceException($trackId): $message';
}

/// Outcome of hybrid vault/cloud audio source resolution.
@immutable
class ResolvedAudioSource {
  /// Either a `file:` URI pointing at the Phase 8 vault cipher payload or the
  /// remote CDN stream URI.
  final Uri uri;

  /// `true` when [uri] addresses the local encrypted vault file.
  final bool isLocalFile;

  /// Absolute local path when [isLocalFile] is `true`.
  final String? localFilePath;

  /// Custom StreamAudioSource providing decrypted chunks on-the-fly for just_audio.
  final StreamAudioSource? streamSource;

  const ResolvedAudioSource({
    required this.uri,
    required this.isLocalFile,
    this.localFilePath,
    this.streamSource,
  });

  /// `'vault'` for offline cache hits, `'stream'` for cloud playback.
  String get sourceLabel => isLocalFile ? 'vault' : 'stream';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedAudioSource &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          isLocalFile == other.isLocalFile &&
          localFilePath == other.localFilePath;

  @override
  int get hashCode => Object.hash(uri, isLocalFile, localFilePath);

  @override
  String toString() =>
      'ResolvedAudioSource(uri: $uri, isLocalFile: $isLocalFile, '
      'localFilePath: $localFilePath)';
}

abstract class IAudioSourceResolver {
  Future<ResolvedAudioSource> resolveSource(Track track);
}

/// Defers construction of the concrete hybrid resolver until the first playback
/// request.
class DeferredAudioSourceResolver implements IAudioSourceResolver {
  DeferredAudioSourceResolver(this.resolveDelegate);

  /// Late factory for the concrete resolver.
  final IAudioSourceResolver Function() resolveDelegate;

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) =>
      resolveDelegate().resolveSource(track);
}

/// Hybrid source resolver: Phase 8 offline vault first, cloud CDN fallback.
class AudioSourceResolver implements IAudioSourceResolver {
  final IOfflineStorageService offlineStorage;
  final VaultEnvelopeCrypto crypto;

  /// Live query for `OfflinePreferenceState.isOfflineModeForced`.
  final bool Function()? offlineModeGuard;

  AudioSourceResolver({
    required this.offlineStorage,
    VaultEnvelopeCrypto? crypto,
    this.offlineModeGuard,
  }) : crypto = crypto ?? VaultEnvelopeCrypto();

  /// `true` when the user has forced offline playback.
  bool get isOfflineModeForced => offlineModeGuard?.call() ?? false;

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) async {
    // 1. Vault priority — Phase 8 cached master with a materialised file.
    final isCached = await offlineStorage.isTrackCachedLocally(track.id);
    if (isCached) {
      final metadata = await offlineStorage.getTrackMetadata(track.id);
      final localPath = metadata?['localAudioFilePath'] as String?;
      if (localPath != null && localPath.isNotEmpty && _fileExists(localPath)) {
        final streamSource = EncryptedVmfStreamSource(
          filePath: localPath,
          crypto: crypto,
        );
        return ResolvedAudioSource(
          uri: Uri.file(localPath),
          isLocalFile: true,
          localFilePath: localPath,
          streamSource: streamSource,
        );
      }
    }

    // 2. Forced offline mode with no usable local copy is a hard failure.
    final remoteUrl = track.audioUrl;
    if (isOfflineModeForced) {
      throw AudioSourceException(
        'Offline mode is enabled and "${track.title}" is not cached in the '
        'device vault. Connect to download it for offline playback.',
        trackId: track.id,
        requiresConnectivity: true,
      );
    }

    // 3. Cloud stream fallback (explicit track URL, then catalog convention).
    final resolvedUrl = (remoteUrl != null && remoteUrl.isNotEmpty)
        ? remoteUrl
        : '${AppConstants.defaultOrigin}/audio/${track.id}.mp3';

    return ResolvedAudioSource(
      uri: Uri.parse(resolvedUrl),
      isLocalFile: false,
    );
  }

  /// Guards against an unreadable vault path in restricted environments.
  bool _fileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}

/// Custom just_audio StreamAudioSource decrypting the .vmf envelope on-the-fly.
class EncryptedVmfStreamSource extends StreamAudioSource {
  final String filePath;
  final VaultEnvelopeCrypto crypto;

  EncryptedVmfStreamSource({
    required this.filePath,
    required this.crypto,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final file = File(filePath);
    final envelopeBytes = await file.readAsBytes();

    // Check if envelope starts with VHUN magic header
    Uint8List decryptedAudio;
    if (envelopeBytes.length >= 30 &&
        envelopeBytes[0] == 0x56 &&
        envelopeBytes[1] == 0x48 &&
        envelopeBytes[2] == 0x55 &&
        envelopeBytes[3] == 0x4E) {
      decryptedAudio = crypto.decryptFromEnvelope(envelopeBytes);
    } else {
      decryptedAudio = envelopeBytes;
    }

    final byteLength = decryptedAudio.length;
    final startIndex = start ?? 0;
    final endIndex = (end ?? byteLength).clamp(0, byteLength);

    final slice = decryptedAudio.sublist(startIndex, endIndex);

    return StreamAudioResponse(
      sourceLength: byteLength,
      contentLength: slice.length,
      offset: startIndex,
      contentType: 'audio/mpeg',
      stream: Stream<List<int>>.value(slice),
    );
  }
}
