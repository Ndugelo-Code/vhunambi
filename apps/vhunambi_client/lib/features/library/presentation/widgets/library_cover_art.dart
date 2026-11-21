import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';

/// Unified vault track cover backed by [VhunambiTrackArtwork] (`EP-P68-TRACK-ARTWORK`),
/// cleanly resolving `asset:` URIs, remote R2 URLs, and bundled cultural genre covers.
class LibraryCoverArt extends StatelessWidget {
  final LibraryTrack track;
  final double? size;
  final double radius;
  final bool showGlyph;

  const LibraryCoverArt({
    super.key,
    required this.track,
    this.size = 48,
    this.radius = AppRadius.thumb,
    this.showGlyph = false,
  });

  @override
  Widget build(BuildContext context) {
    final artwork = VhunambiTrackArtwork(
      coverUrl: track.coverImageUrl,
      genre: track.genre,
      trackId: track.id,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(radius),
      badgeIconSize: (size ?? 64) * 0.36,
      showSubtleBorder: radius > 0,
    );
    if (size == null) return artwork;
    return SizedBox(width: size, height: size, child: artwork);
  }
}
