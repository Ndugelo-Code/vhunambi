import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/playlist_entity.dart';

/// Dynamic playlist cover art (Mission 10).
///
/// Resolution order:
///   1. `playlist.coverImageUrl` — the user's custom cover image.
///   2. `tracks.length >= 4` — a 2×2 collage of the first four song covers
///      (genre-gradient placeholders when a song has no artwork).
///   3. `tracks.length >= 1` — the first song's cover / gradient.
///   4. empty — a deterministic brand gradient derived from the title hash
///      with a centred music-note glyph.
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

  /// Subtle brand tokens cycled deterministically by title hash for the empty
  /// playlist gradient. No raw hex — every value is an [AppColors] token.
  static const List<List<Color>> _emptyPalettes = [
    [AppColors.brandPrimary, AppColors.coinGold],
    [AppColors.streakFire, AppColors.brandPrimary],
    [AppColors.badgeCyan, AppColors.success],
    [AppColors.coinGold, AppColors.streakFire],
  ];

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
      return _networkCover(coverUrl, fallback: _emptyCover());
    }

    if (tracks.length >= 4) {
      return _quadCollage();
    }

    if (tracks.isNotEmpty) {
      return _singleCover(tracks.first);
    }

    return _emptyCover();
  }

  Widget _networkCover(String url, {required Widget fallback}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  Widget _singleCover(Track track) {
    final url = _coverUrlOf(track);
    if (url != null) {
      return _networkCover(url, fallback: _gradientTile(AppGradients.forGenre(track.genre)));
    }
    return _gradientTile(AppGradients.forGenre(track.genre));
  }

  Widget _quadCollage() {
    final quad = tracks.take(4).toList();
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
                      child: _singleCover(quad[row * 2 + col]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _gradientTile(LinearGradient gradient) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: const SizedBox.expand(),
    );
  }

  Widget _emptyCover() {
    final palette =
        _emptyPalettes[playlist.title.hashCode.abs() % _emptyPalettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.4,
          color: AppColors.textPrimary.withAlpha(220),
        ),
      ),
    );
  }

  String? _coverUrlOf(Track track) => track.coverUrl;
}
