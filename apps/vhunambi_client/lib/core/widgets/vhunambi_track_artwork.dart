import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_gradients.dart';

/// Unified rounded cover artwork renderer shared across Home, Now Playing, and shelves.
///
/// Resolution order (`REQ-P68-ART-02`):
/// 1. Normalized `http(s)://` URL -> [Image.network] with asset error fallback.
/// 2. `asset:...` URI or `assets/...` path -> [Image.asset].
/// 3. Deterministic cultural genre artwork -> [AppAssets.resolveGenreCoverAsset].
/// 4. Branded [AppGradients.forGenre] + [PhosphorIconsFill.musicNotes] badge.
class VhunambiTrackArtwork extends StatelessWidget {
  final String? coverUrl;
  final String genre;
  final String? trackId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double badgeIconSize;
  final bool showSubtleBorder;

  const VhunambiTrackArtwork({
    super.key,
    this.coverUrl,
    required this.genre,
    this.trackId,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.badgeIconSize = 24,
    this.showSubtleBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedSource = AppAssets.resolveTrackCoverSource(
      coverUrl: coverUrl,
      genre: genre,
      seedId: trackId,
    );
    final genreAssetFallback = AppAssets.resolveGenreCoverAsset(
      genre,
      seedId: trackId,
    );
    final isRemote = resolvedSource.startsWith('http://') ||
        resolvedSource.startsWith('https://');

    Widget buildGradientFallback() {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.forGenre(genre),
        ),
        child: Center(
          child: PhosphorIcon(
            PhosphorIconsFill.musicNotes,
            size: badgeIconSize,
            color: AppColors.textPrimaryOf(context).withValues(alpha: 0.90),
          ),
        ),
      );
    }

    Widget buildAssetImage(String assetPath) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => buildGradientFallback(),
      );
    }

    String? resolveLocalPath(String? rawUrl) {
      if (kIsWeb || rawUrl == null) return null;
      final trimmed = rawUrl.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('file://')) {
        try {
          final p = Uri.parse(trimmed).toFilePath();
          if (File(p).existsSync()) return p;
        } catch (_) {}
        return null;
      }
      if (!trimmed.startsWith('http://') &&
          !trimmed.startsWith('https://') &&
          !trimmed.startsWith('asset:') &&
          !trimmed.startsWith('assets/')) {
        try {
          if (File(trimmed).existsSync()) return trimmed;
        } catch (_) {}
      }
      return null;
    }

    final localPath = resolveLocalPath(coverUrl);
    final Widget imageWidget = localPath != null
        ? Image.file(
            File(localPath),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => buildAssetImage(genreAssetFallback),
          )
        : isRemote
        ? Image.network(
            resolvedSource,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => buildAssetImage(genreAssetFallback),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  buildAssetImage(genreAssetFallback),
                  Container(
                    color: AppColors.surfaceCanvasOf(context)
                        .withValues(alpha: 0.18),
                  ),
                ],
              );
            },
          )
        : buildAssetImage(resolvedSource);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showSubtleBorder
            ? Border.all(
                color: AppColors.borderSubtleOf(context).withValues(alpha: 0.75),
                width: 1,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      ),
    );
  }
}
