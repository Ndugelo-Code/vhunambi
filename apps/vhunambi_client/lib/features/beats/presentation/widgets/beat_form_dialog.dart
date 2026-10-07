import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../beat_format.dart';

/// Submitted values of [BeatFormDialog] (REQ-BEAT-18).
@immutable
class BeatFormResult {
  final String title;
  final String genre;
  final int bpm;
  final String musicalKey;
  final List<String> tags;
  final int priceInCredits;
  final BeatLicenseTier licenseTier;
  final BeatStatus status;

  const BeatFormResult({
    required this.title,
    required this.genre,
    required this.bpm,
    required this.musicalKey,
    required this.tags,
    required this.priceInCredits,
    required this.licenseTier,
    required this.status,
  });
}

/// Create / convert / edit beat dialog (REQ-BEAT-18 / Blueprint 14 §2.3).
///
/// Passing [initial] pre-populates every field, turning the dialog into the
/// metadata editor launched from the vault overflow menus and the cockpit.
class BeatFormDialog extends StatefulWidget {
  final ProducerBeatEntity? initial;
  final void Function(BeatFormResult result) onSubmitted;

  /// Injectable clock backing the tap-tempo control (test seam).
  final DateTime Function()? clock;

  const BeatFormDialog({
    super.key,
    this.initial,
    required this.onSubmitted,
    this.clock,
  });

  @override
  State<BeatFormDialog> createState() => _BeatFormDialogState();
}

class _BeatFormDialogState extends State<BeatFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bpmController;
  late final TextEditingController _tagsController;
  late String _genre;
  late String _musicalKey;
  late int _priceInCredits;
  late BeatLicenseTier _licenseTier;
  late BeatStatus _status;

  DateTime? _lastTap;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _bpmController = TextEditingController(
      text: '${initial?.bpm ?? defaultBeatBpm}',
    );
    _tagsController = TextEditingController(
      text: initial?.tags.join(', ') ?? '',
    );
    _genre = initial?.genre ?? beatGenreCatalog.first;
    _musicalKey = initial?.musicalKey ?? beatMusicalKeyCatalog.first;
    _priceInCredits = initial?.priceInCredits ?? 10;
    _licenseTier =
        initial?.licenseTier ?? BeatLicenseTier.nonExclusiveCommercial;
    _status = initial?.status ?? BeatStatus.draft;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bpmController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

  int get _bpm => int.tryParse(_bpmController.text.trim()) ?? defaultBeatBpm;

  /// Price presets, always including the currently selected value.
  List<int> get _pricePresets {
    final presets = <int>{...beatPricePresets, _priceInCredits}.toList()..sort();
    return presets;
  }

  void _applyBpm(int bpm) {
    final clamped = clampBeatBpm(bpm);
    _bpmController.text = '$clamped';
    setState(() {});
  }

  /// Tap-tempo estimator: consecutive taps inside 2s derive the BPM from the
  /// gap between them (Blueprint 14 §2.3).
  void _registerTap() {
    final now = _now();
    final last = _lastTap;
    _lastTap = now;

    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      return;
    }

    final gapMs = now.difference(last).inMilliseconds;
    if (gapMs <= 0) return;
    _applyBpm((60000 / gapMs).round());
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmitted(
      BeatFormResult(
        title: _titleController.text.trim(),
        genre: _genre,
        bpm: clampBeatBpm(_bpm),
        musicalKey: _musicalKey,
        tags: parseBeatTags(_tagsController.text),
        priceInCredits: _priceInCredits,
        licenseTier: _licenseTier,
        status: _status,
      ),
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
        isEditing ? 'Edit Beat Listing' : 'Configure Beat Listing',
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('beat_title_field'),
                controller: _titleController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Beat Title',
                  hintText: 'e.g. Soshanguve Pulse',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('beat_genre_dropdown'),
                initialValue: _genre,
                isExpanded: true,
                dropdownColor: AppColors.surfaceModal,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(labelText: 'Genre'),
                items: [
                  for (final genre in beatGenreCatalog)
                    DropdownMenuItem<String>(value: genre, child: Text(genre)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _genre = value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('beat_bpm_field'),
                      controller: _bpmController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: AppTypography.bodyLarge,
                      decoration:
                          const InputDecoration(labelText: 'Tempo (BPM)'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton.icon(
                    key: const Key('beat_tap_tempo'),
                    onPressed: _registerTap,
                    icon: const Icon(Icons.touch_app_rounded, size: 16),
                    label: const Text('Tap Tempo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ],
              ),
              Slider(
                key: const Key('beat_bpm_slider'),
                value: _bpm.clamp(60, 180).toDouble(),
                min: 60,
                max: 180,
                divisions: 60,
                activeColor: AppColors.brandPrimary,
                inactiveColor: AppColors.surfaceSecondary,
                label: '$_bpm BPM',
                onChanged: (value) => _applyBpm(value.round()),
              ),
              DropdownButtonFormField<String>(
                key: const Key('beat_key_dropdown'),
                initialValue: _musicalKey,
                isExpanded: true,
                dropdownColor: AppColors.surfaceModal,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(labelText: 'Musical Key'),
                items: [
                  for (final key in beatMusicalKeyCatalog)
                    DropdownMenuItem<String>(value: key, child: Text(key)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _musicalKey = value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('beat_tags_field'),
                controller: _tagsController,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'e.g. Log Drum, Private School',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('beat_price_dropdown'),
                      initialValue: _priceInCredits,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceModal,
                      style: AppTypography.bodyLarge,
                      decoration:
                          const InputDecoration(labelText: 'Price in Credits'),
                      items: [
                        for (final price in _pricePresets)
                          DropdownMenuItem<int>(
                            value: price,
                            child: Text('⚡ $price Credits'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priceInCredits = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: DropdownButtonFormField<BeatLicenseTier>(
                      key: const Key('beat_tier_dropdown'),
                      initialValue: _licenseTier,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceModal,
                      style: AppTypography.bodyLarge,
                      decoration:
                          const InputDecoration(labelText: 'Licensing Tier'),
                      items: [
                        for (final tier in BeatLicenseTier.values)
                          DropdownMenuItem<BeatLicenseTier>(
                            value: tier,
                            child: Text(
                              tier.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _licenseTier = value;
                          _priceInCredits = value.defaultPriceCredits;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Initial Status',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: _StatusOption(
                      chipKey: const Key('beat_status_draft'),
                      label: 'Draft (Vault Only)',
                      icon: Icons.edit_note_rounded,
                      isSelected: _status == BeatStatus.draft,
                      onTap: () => setState(() => _status = BeatStatus.draft),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _StatusOption(
                      chipKey: const Key('beat_status_publish'),
                      label: 'Publish Now',
                      icon: Icons.rocket_launch_rounded,
                      isSelected: _status == BeatStatus.published,
                      onTap: () =>
                          setState(() => _status = BeatStatus.published),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          key: const Key('beat_dialog_submit'),
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
          ),
          child: Text(isEditing ? 'Save Beat' : 'Create Beat'),
        ),
      ],
    );
  }
}

/// Draft / Publish-now radio card used by the authoring dialog.
class _StatusOption extends StatelessWidget {
  final Key chipKey;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.chipKey,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: AppRadius.inputBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.amberInset : AppColors.surfaceSecondary,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color:
                isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color:
                  isSelected ? AppColors.brandPrimary : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
