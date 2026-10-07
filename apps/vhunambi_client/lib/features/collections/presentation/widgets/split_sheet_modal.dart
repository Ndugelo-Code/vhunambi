import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/collection_entity.dart';
import '../collection_format.dart';

/// Human-readable split sheet summary (REQ-COL-27).
///
/// Centered dialog on desktop (>=1024px), scroll-controlled bottom sheet on
/// mobile/tablet. Supports `Copy to Clipboard` of the formatted summary.
class SplitSheetModal extends StatelessWidget {
  final CollectionEntity collection;
  final String durationLabel;

  const SplitSheetModal({
    super.key,
    required this.collection,
    this.durationLabel = '0 mins',
  });

  /// Opens the split sheet for [collection].
  static Future<void> show(
    BuildContext context,
    CollectionEntity collection, {
    String durationLabel = '0 mins',
  }) {
    final sheet = SplitSheetModal(
      collection: collection,
      durationLabel: durationLabel,
    );

    if (ResponsiveUtils.isDesktop(context)) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surfaceModal,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: sheet,
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalBorder),
      builder: (_) => sheet,
    );
  }

  /// Plain-text summary written to the clipboard.
  String get summaryText {
    final buffer = StringBuffer()
      ..writeln('Split Sheet — ${collection.title}')
      ..writeln('Project: ${collection.title}')
      ..writeln('Type: ${collection.typeLabel}')
      ..writeln('Genre: ${collection.genre.isEmpty ? '—' : collection.genre}')
      ..writeln('Tracks: ${collection.trackCountLabel}')
      ..writeln('Duration: $durationLabel')
      ..writeln('Created: ${formatCollectionDate(collection.createdAt)}')
      ..writeln()
      ..writeln('PARTICIPANTS');

    if (collection.participants.isEmpty) {
      buffer.writeln('No collaborators added yet.');
    } else {
      for (final participant in collection.participants) {
        buffer.writeln(
          '${participant.name} | ${participant.role} | ${participant.shareLabel}',
        );
      }
    }

    buffer.write('Total: ${collection.totalSharePercent.toStringAsFixed(0)}%');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final participants = collection.participants;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📄 Split Sheet — ${collection.title}',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(label: 'Project', value: collection.title),
          _MetaRow(label: 'Type', value: collection.typeLabel),
          _MetaRow(
            label: 'Genre',
            value: collection.genre.isEmpty ? '—' : collection.genre,
          ),
          _MetaRow(label: 'Tracks', value: collection.trackCountLabel),
          _MetaRow(label: 'Duration', value: durationLabel),
          _MetaRow(
            label: 'Created',
            value: formatCollectionDate(collection.createdAt),
          ),
          const Divider(color: AppColors.borderSubtle, height: AppSpacing.xl),
          Text(
            'PARTICIPANTS',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (participants.isEmpty)
            Text(
              'No collaborators added yet.',
              style: AppTypography.bodyMuted,
            )
          else ...[
            const _ParticipantRow(
              name: 'Name',
              role: 'Role',
              share: 'Share',
              isHeader: true,
            ),
            for (final participant in participants)
              _ParticipantRow(
                name: participant.name,
                role: participant.role,
                share: participant.shareLabel,
              ),
          ],
          if (!collection.isSplitBalanced) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '⚠ Shares must sum to 100%',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('split_sheet_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                key: const Key('split_sheet_copy'),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: summaryText),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy to Clipboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `Label: value` metadata row used by the split sheet header block.
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-column split-sheet table row (header + data).
class _ParticipantRow extends StatelessWidget {
  final String name;
  final String role;
  final String share;
  final bool isHeader;

  const _ParticipantRow({
    required this.name,
    required this.role,
    required this.share,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? AppTypography.caption.copyWith(color: AppColors.textTertiary)
        : AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(name, style: style)),
          Expanded(flex: 3, child: Text(role, style: style)),
          Expanded(
            flex: 2,
            child: Text(share, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
