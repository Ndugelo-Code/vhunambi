import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Unified collection cover placeholder (Blueprint 13 §6).
///
/// A squircle container holding a 2×2 mosaic of muted panels with a centred
/// `Icons.album_outlined` glyph; used by vault cards, list rows, the detail
/// hero header and the split sheet.
class CollectionArtworkPlaceholder extends StatelessWidget {
  final double size;
  final double iconSize;
  final double gap;

  const CollectionArtworkPlaceholder({
    super.key,
    this.size = 48,
    this.iconSize = 22,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.squircleBorder,
          border: Border.all(color: AppColors.borderSubtle),
          gradient: const LinearGradient(
            colors: [AppColors.surfaceSecondary, AppColors.surfaceElevated],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.all(gap),
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    Expanded(
                      child: Row(
                        children: [
                          for (var column = 0; column < 2; column++) ...[
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: (row + column).isEven
                                      ? AppColors.surfaceElevated
                                      : AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            if (column == 0) SizedBox(width: gap),
                          ],
                        ],
                      ),
                    ),
                    if (row == 0) SizedBox(height: gap),
                  ],
                ],
              ),
            ),
            Center(
              child: Icon(
                Icons.album_outlined,
                size: iconSize,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
