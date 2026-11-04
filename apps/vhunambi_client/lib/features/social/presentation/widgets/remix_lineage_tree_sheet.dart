import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';
import '../providers/remix_lineage_provider.dart';
import 'open_verse_remix_cockpit_sheet.dart';

/// Bottom sheet displaying the interactive viral genealogical remix tree (REQ-TREE-01 / Phase 37).
class RemixLineageTreeSheet extends ConsumerWidget {
  final String trackOrClipId;
  final PublishedClip clip;

  const RemixLineageTreeSheet({
    super.key,
    required this.trackOrClipId,
    required this.clip,
  });

  static Future<void> show(
    BuildContext context, {
    required String trackOrClipId,
    required PublishedClip clip,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RemixLineageTreeSheet(
        trackOrClipId: trackOrClipId,
        clip: clip,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootNode = ref.watch(remixLineageTreeProvider(trackOrClipId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.cardBorder,
                ),
                child: const Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.gitFork,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remix Lineage Tree',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${rootNode.totalDescendantsCount} Remixes · Automatic 70/30 Splits',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Scrollable Tree Graph
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNodeCard(context, rootNode, isRoot: true),
                  for (final child in rootNode.children) ...[
                    _buildBranchConnector(),
                    _buildNodeCard(context, child),
                    for (final grandChild in child.children) ...[
                      _buildBranchConnector(indent: 28),
                      _buildNodeCard(context, grandChild, indent: 28),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Bottom Action: Drop Your Verse on This Chain
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('lineage_drop_verse_btn'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                OpenVerseRemixCockpitSheet.show(context, clip: clip);
              },
              icon: const PhosphorIcon(PhosphorIconsBold.microphone, size: 18),
              label: const Text('Drop Your Verse on This Chain'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchConnector({double indent = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: 24 + indent),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 14,
          color: AppColors.borderSubtle,
        ),
      ),
    );
  }

  Widget _buildNodeCard(
    BuildContext context,
    RemixNode node, {
    bool isRoot = false,
    double indent = 0,
  }) {
    return Container(
      margin: EdgeInsets.only(left: indent),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isRoot
            ? AppColors.brandPrimary.withValues(alpha: 0.08)
            : AppColors.surfaceSecondary,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isRoot
              ? AppColors.brandPrimary.withValues(alpha: 0.35)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              node.creatorDisplayName.isNotEmpty
                  ? node.creatorDisplayName[0].toUpperCase()
                  : 'A',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.creatorDisplayName,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (node.isVerified) ...[
                      const SizedBox(width: 4),
                      const PhosphorIcon(
                        PhosphorIconsFill.checkCircle,
                        size: 13,
                        color: AppColors.brandPrimary,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      node.creatorHandle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  node.title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        node.lineageDescriptor,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: isRoot ? AppColors.brandPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (node.coCreationSplits.isNotEmpty && !isRoot) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          node.coCreationSplits
                              .map((s) => '${s.sharePercent.toStringAsFixed(0)}%')
                              .join('/'),
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Play audition button
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsBold.play, size: 16),
            onPressed: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing take from ${node.creatorHandle}...'),
                  backgroundColor: AppColors.brandPrimary,
                ),
              );
            },
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

