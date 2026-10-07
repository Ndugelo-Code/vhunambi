import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/collection_entity.dart';
import '../providers/collections_provider.dart';

/// Add / edit collaborator dialog for the split sheet (REQ-COL-25 / REQ-COL-26).
class AddParticipantDialog extends ConsumerStatefulWidget {
  final String collectionId;

  /// `null` when adding; populated when editing an existing collaborator.
  final SplitParticipant? initial;

  const AddParticipantDialog({
    super.key,
    required this.collectionId,
    this.initial,
  });

  /// Opens the dialog for [collectionId].
  static Future<void> show(
    BuildContext context, {
    required String collectionId,
    SplitParticipant? initial,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AddParticipantDialog(
        collectionId: collectionId,
        initial: initial,
      ),
    );
  }

  @override
  ConsumerState<AddParticipantDialog> createState() =>
      _AddParticipantDialogState();
}

class _AddParticipantDialogState extends ConsumerState<AddParticipantDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _shareController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _roleController = TextEditingController(text: initial?.role ?? '');
    _shareController = TextEditingController(
      text: initial == null ? '' : _trim(initial.sharePercent),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  static String _trim(double value) {
    final rounded = value.toStringAsFixed(2);
    return rounded
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double? get _parsedShare {
    final parsed = double.tryParse(_shareController.text.trim());
    if (parsed == null || parsed < 0 || parsed > 100) return null;
    return parsed;
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _roleController.text.trim().isNotEmpty &&
      _parsedShare != null;

  void _save() {
    final share = _parsedShare;
    if (share == null || !_canSave) return;

    final participant = SplitParticipant(
      name: _nameController.text.trim(),
      role: _roleController.text.trim(),
      sharePercent: share,
    );

    final notifier = ref.read(collectionsProvider.notifier);
    if (widget.initial == null) {
      notifier.addParticipant(widget.collectionId, participant);
    } else {
      notifier.updateParticipant(widget.collectionId, participant);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        isEditing ? 'Edit Collaborator' : 'Add Collaborator',
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('participant_name_field'),
            controller: _nameController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Ndugelo Makwela',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('participant_role_field'),
            controller: _roleController,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Role',
              hintText: 'e.g. Producer, Composer, Lyricist',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('participant_share_field'),
            controller: _shareController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Share %',
              hintText: '0 - 100',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          key: const Key('participant_save'),
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
