import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Dynamic playlist cover art backed by [VhunambiTrackArtwork] (`EP-P68-TRACK-ARTWORK`).
class PlaylistCoverArt extends StatelessWidget {
  final PlaylistEntity playlist;
  final List<Track> tracks;
  final double size;

  const PlaylistCoverArt({
    super.key,
    required this.playlist,
    required this.tracks,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.thumb),
      child: SizedBox(width: size, height: size, child: _content()),
    );
  }

  Widget _content() {
    final coverUrl = playlist.coverImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return VhunambiTrackArtwork(
        coverUrl: coverUrl,
        genre: tracks.isNotEmpty ? tracks.first.genre : 'Amapiano',
        trackId: playlist.id,
        width: size,
        height: size,
        borderRadius: BorderRadius.zero,
        showSubtleBorder: false,
      );
    }

    if (tracks.length >= 4) {
      final quad = tracks.take(4).toList(growable: false);
      return Column(
        children: [
          for (var row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(0.5),
                        child: VhunambiTrackArtwork(
                          coverUrl: quad[row * 2 + col].coverUrl,
                          genre: quad[row * 2 + col].genre,
                          trackId: quad[row * 2 + col].id,
                          borderRadius: BorderRadius.zero,
                          showSubtleBorder: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    if (tracks.isNotEmpty) {
      final first = tracks.first;
      return VhunambiTrackArtwork(
        coverUrl: first.coverUrl,
        genre: first.genre,
        trackId: first.id,
        width: size,
        height: size,
        borderRadius: BorderRadius.zero,
        showSubtleBorder: false,
      );
    }

    return VhunambiTrackArtwork(
      genre: 'Amapiano',
      trackId: playlist.id,
      width: size,
      height: size,
      borderRadius: BorderRadius.zero,
      showSubtleBorder: false,
    );
  }
}
