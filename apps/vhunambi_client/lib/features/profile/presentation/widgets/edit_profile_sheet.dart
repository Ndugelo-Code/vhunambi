import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/profile_models.dart';
import '../providers/profile_providers.dart';

/// Modal sheet for modifying creator profile details (Phase 33 REQ-PRF-02).
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const EditProfileSheet(),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late List<String> _selectedGenres;
  late CreatorIdentityArchetype _selectedArchetype;

  static const List<String> _availableGenres = [
    'Amapiano',
    'House',
    'Maskandi',
    'Gqom',
    'Afro Tech',
    'Afrobeats',
    'Kwaito',
    'Mbaqanga',
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(ownerProfileProvider);
    _nameController = TextEditingController(text: profile.displayName);
    _usernameController = TextEditingController(text: profile.username);
    _bioController = TextEditingController(text: profile.bio);
    _selectedArchetype = profile.archetype;
    _selectedGenres = List<String>.from(profile.topGenres);
    if (_selectedGenres.isEmpty) {
      _selectedGenres = ['Amapiano', 'House'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    HapticFeedback.mediumImpact();
    final cleanName = _nameController.text.trim();
    final cleanUser = _usernameController.text
        .trim()
        .replaceAll('@', '')
        .replaceAll(' ', '_')
        .toLowerCase();
    final cleanBio = _bioController.text.trim();

    ref.read(ownerProfileProvider.notifier).updateProfileDetails(
          displayName: cleanName.isNotEmpty ? cleanName : null,
          username: cleanUser.isNotEmpty ? cleanUser : null,
          bio: cleanBio,
          topGenres: _selectedGenres,
          archetype: _selectedArchetype,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Creator Profile',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const PhosphorIcon(AppIcons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Display Name Field
              Text(
                'Display Name',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_name_field'),
                controller: _nameController,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'e.g. Ndugelo Musician',
                  prefixIcon: PhosphorIcon(
                    AppIcons.user,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Username Handle Field
              Text(
                'Username (@handle)',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_username_field'),
                controller: _usernameController,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'e.g. ndugelo_musician',
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.at,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bio Field
              Text(
                'Bio / Artistic Description',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_bio_field'),
                controller: _bioController,
                maxLines: 3,
                style: AppTypography.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Describe your musical rhythm and story...',
                ),
              ),
              const SizedBox(height: 14),

              // Signature Regional Genres Picker
              Text(
                'Signature African Genres',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in _availableGenres)
                    FilterChip(
                      label: Text(genre),
                      selected: _selectedGenres.contains(genre),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedGenres.contains(genre)) {
                              _selectedGenres.add(genre);
                            }
                          } else {
                            _selectedGenres.remove(genre);
                          }
                        });
                      },
                      selectedColor: AppColors.brandPrimary.withAlpha(35),
                      checkmarkColor: AppColors.brandPrimary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: _selectedGenres.contains(genre)
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedGenres.contains(genre)
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _selectedGenres.contains(genre)
                            ? AppColors.brandPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('edit_profile_save_btn'),
                  onPressed: _save,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.check,
                    size: 18,
                    color: AppColors.brandContrast,
                  ),
                  label: Text(
                    'Save Profile',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

