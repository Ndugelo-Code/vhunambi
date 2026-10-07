import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/collection_entity.dart';

/// Blueprint 13 §5 icon contract per collection type.
IconData collectionTypeIcon(CollectionType type) => switch (type) {
      CollectionType.single => Icons.music_note_rounded,
      CollectionType.ep => Icons.album_rounded,
      CollectionType.album => Icons.library_music_rounded,
      CollectionType.conceptProject => Icons.auto_awesome_mosaic_rounded,
    };

/// Compact type chip used by vault cards, list rows and the detail header
/// (REQ-COL-15).
///
/// EP/Single render in cyan tokens; Album/Concept Project in amber tokens.
class CollectionTypeBadge extends StatelessWidget {
  final CollectionType type;

  const CollectionTypeBadge({super.key, required this.type});

  bool get _isCyan =>
      type == CollectionType.ep || type == CollectionType.single;

  @override
  Widget build(BuildContext context) {
    final background = _isCyan ? AppColors.badgeCyanBg : AppColors.amberInset;
    final foreground = _isCyan ? AppColors.badgeCyan : AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.squircleBorder,
        border: Border.all(color: foreground.withAlpha(90)),
      ),
      child: Text(
        type.badgeLabel,
        style: AppTypography.badge.copyWith(color: foreground),
      ),
    );
  }
}
