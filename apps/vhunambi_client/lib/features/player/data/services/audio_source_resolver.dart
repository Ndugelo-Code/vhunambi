import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/track.dart';
import '../../../offline/data/services/offline_storage_service.dart';

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

  const ResolvedAudioSource({
    required this.uri,
    required this.isLocalFile,
    this.localFilePath,
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
///
/// Building the audio handler must never touch Phase 8's Hive vault: an eager
/// `offlineStorageServiceProvider` read opens boxes while a widget test is still
/// booting, and Hive reports the resulting failure through an unlistened
/// `Completer` that escapes the caller's zone. Source resolution only needs the
/// store once a track is actually played.
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

  /// Live query for `OfflinePreferenceState.isOfflineModeForced`.
  ///
  /// Injected as a callback (instead of a captured bool) so the resolver always
  /// observes the current preference without being rebuilt by Riverpod.
  final bool Function()? offlineModeGuard;

  AudioSourceResolver({required this.offlineStorage, this.offlineModeGuard});

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
        return ResolvedAudioSource(
          uri: Uri.file(localPath),
          isLocalFile: true,
          localFilePath: localPath,
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
