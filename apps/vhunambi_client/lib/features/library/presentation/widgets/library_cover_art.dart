import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../domain/models/library_models.dart';

/// Square vault artwork: cached cover image when available, otherwise the
/// regional genre gradient token from [AppGradients] (REQ-LIB-05).
///
/// Pass `size: null` to fill the parent bounds (used by the grid card cover).
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
    this.showGlyph = true,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppGradients.forGenre(track.genre);
    final coverUrl = track.coverImageUrl;

    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => _gradientLayer(gradient),
            errorWidget: (_, _, _) => _gradientLayer(gradient),
          )
        else
          _gradientLayer(gradient),
        if (showGlyph)
          Center(
            child: Icon(
              track.isInstrumental
                  ? Icons.piano_rounded
                  : Icons.music_note_rounded,
              size: (size ?? 96) * 0.36,
              color: AppColors.textPrimary.withAlpha(220),
            ),
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: size == null
          ? content
          : SizedBox(width: size, height: size, child: content),
    );
  }

  Widget _gradientLayer(LinearGradient gradient) {
    return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
  }
}

