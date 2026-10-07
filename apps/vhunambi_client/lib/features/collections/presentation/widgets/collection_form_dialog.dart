import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/collection_entity.dart';
import '../collection_format.dart';

/// Create / Edit collection dialog (REQ-COL-17 / REQ-COL-18).
///
/// Passing [initial] pre-populates the title, type, genre, description and
/// release date, turning the dialog into the rename surface used by both the
/// vault overflow menu and the detail view action menu.
class CollectionFormDialog extends StatefulWidget {
  final CollectionEntity? initial;

  /// Receives the submitted values; the dialog pops itself afterwards.
  final void Function(
    String title,
    CollectionType type,
    String genre,
    String description,
    DateTime? releaseDate,
  ) onSubmitted;

  const CollectionFormDialog({super.key, this.initial, required this.onSubmitted});

  @override
  State<CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<CollectionFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _genreController;
  late final TextEditingController _descriptionController;
  late CollectionType _type;
  DateTime? _releaseDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _genreController = TextEditingController(text: initial?.genre ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _type = initial?.type ?? CollectionType.ep;
    _releaseDate = initial?.releaseDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

  Future<void> _pickReleaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _releaseDate = picked);
    }
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmitted(
      _titleController.text.trim(),
      _type,
      _genreController.text.trim(),
      _descriptionController.text.trim(),
      _releaseDate,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        isEditing ? 'Edit Collection' : 'Create New Collection',
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('collection_title_field'),
              controller: _titleController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Collection Title',
                hintText: 'e.g. Ẓe Amapiano EP',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<CollectionType>(
              key: const Key('collection_type_dropdown'),
              initialValue: _type,
              isExpanded: true,
              dropdownColor: AppColors.surfaceModal,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(labelText: 'Collection Type'),
              items: [
                for (final type in CollectionType.values)
                  DropdownMenuItem<CollectionType>(
                    value: type,
                    child: Text(type.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('collection_genre_field'),
              controller: _genreController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Genre',
                hintText: 'e.g. Amapiano',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('collection_description_field'),
              controller: _descriptionController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Log-drum storytelling sessions',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _releaseDate == null
                        ? 'No release date set'
                        : 'Release: ${formatCollectionDate(_releaseDate!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('collection_release_date'),
                  onPressed: _pickReleaseDate,
                  icon: const Icon(Icons.event_rounded, size: 16),
                  label: const Text('Release Date'),
                ),
              ],
            ),
          ],
        ),
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
          key: const Key('collection_dialog_submit'),
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
          ),
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
