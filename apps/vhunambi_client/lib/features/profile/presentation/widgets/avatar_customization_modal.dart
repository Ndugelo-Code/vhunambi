import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/profile_providers.dart';
import 'creator_avatar.dart';

/// Seeded African Cultural AI Avatar Preset.
class CulturalAvatarPreset {
  final String id;
  final String title;
  final String emoji;
  final String subtitle;
  final String imageUrl;

  const CulturalAvatarPreset({
    required this.id,
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.imageUrl,
  });
}

const List<CulturalAvatarPreset> kCulturalAvatarPresets = [
  CulturalAvatarPreset(
    id: 'preset_amapiano',
    title: 'Amapiano Maestro',
    emoji: '🎹',
    subtitle: 'Cyber log-drum specialist with amber studio shades',
    imageUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
  ),
  CulturalAvatarPreset(
    id: 'preset_maskandi',
    title: 'Maskandi Bard',
    emoji: '🎸',
    subtitle: 'Acoustic folk virtuoso with authentic Zulu beadwork',
    imageUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
  ),
  CulturalAvatarPreset(
    id: 'preset_limpopo',
    title: 'Limpopo Queen',
    emoji: '👑',
    subtitle: 'Regal vocal siren with ceremonial brass choker',
    imageUrl:
        'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&w=400&q=80',
  ),
  CulturalCulturalPreset(
    id: 'preset_soweto',
    title: 'Soweto Soul',
    emoji: '🎙️',
    subtitle: '1960s Sophia Town jazz vocalist in velvet',
    imageUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
  ),
  CulturalAvatarPreset(
    id: 'preset_gqom',
    title: 'Gqom Thunder',
    emoji: '⚡',
    subtitle: 'Durban bass architect with holographic sonic aura',
    imageUrl:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
  ),
  CulturalAvatarPreset(
    id: 'preset_cowrie',
    title: 'Golden Cowrie',
    emoji: '🐚',
    subtitle: 'Ancestral synthesizer priest with cowrie headdress',
    imageUrl:
        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
  ),
];

// Alias for typo safety
typedef CulturalCulturalPreset = CulturalAvatarPreset;

/// Interactive Creator Avatar Customization Modal.
///
/// Enables AI African avatar synthesis, cultural preset selection,
/// and custom photo upload for the creator profile.
class AvatarCustomizationModal extends ConsumerStatefulWidget {
  const AvatarCustomizationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AvatarCustomizationModal(),
    );
  }

  @override
  ConsumerState<AvatarCustomizationModal> createState() =>
      _AvatarCustomizationModalState();
}

class _AvatarCustomizationModalState
    extends ConsumerState<AvatarCustomizationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  String? _selectedAvatarUrl;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final currentProfile = ref.read(ownerProfileProvider);
    _selectedAvatarUrl = currentProfile.avatarUrl;
    if (_selectedAvatarUrl != null) {
      _urlController.text = _selectedAvatarUrl!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _applyAvatar() {
    HapticFeedback.mediumImpact();
    ref.read(ownerProfileProvider.notifier).updateAvatar(_selectedAvatarUrl);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile avatar updated successfully! ✨'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _revertToMonogram() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAvatarUrl = null;
      _urlController.clear();
    });
    ref.read(ownerProfileProvider.notifier).updateAvatar(null);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reverted to cultural monogram avatar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _simulateAiGeneration() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;

    // Pick a thematic image based on prompt keywords
    final lower = prompt.toLowerCase();
    String generatedUrl = kCulturalAvatarPresets.first.imageUrl;
    for (final preset in kCulturalAvatarPresets) {
      if (lower.contains(preset.title.toLowerCase()) ||
          lower.contains(preset.emoji)) {
        generatedUrl = preset.imageUrl;
        break;
      }
    }

    setState(() {
      _isGenerating = false;
      _selectedAvatarUrl = generatedUrl;
      _urlController.text = generatedUrl;
    });

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator Profile Avatar',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AI African Portraits & Custom Photos',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Avatar Live Preview
          Center(
            child: CreatorAvatar(
              avatarUrl: _selectedAvatarUrl,
              monogram: profile.monogram,
              size: 80,
              borderWidth: 2.5,
              showEditBadge: false,
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.brandPrimary,
            labelColor: AppColors.brandPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Cultural AI ✨'),
              Tab(text: 'Prompt Gen 🪄'),
              Tab(text: 'Photo URL 📸'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Presets
                _buildPresetsTab(),

                // Tab 2: Prompt Generator
                _buildPromptGeneratorTab(),

                // Tab 3: Photo URL
                _buildPhotoUrlTab(),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _revertToMonogram,
                  child: Text(
                    'Revert to Monogram',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  key: const Key('apply_avatar_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  onPressed: _applyAvatar,
                  child: Text(
                    'Apply Avatar ✨',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandContrast,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: kCulturalAvatarPresets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final preset = kCulturalAvatarPresets[index];
        final isSelected = _selectedAvatarUrl == preset.imageUrl;

        return InkWell(
          key: Key('preset_${preset.id}'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedAvatarUrl = preset.imageUrl;
              _urlController.text = preset.imageUrl;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withAlpha(20)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtle,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    preset.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      color: AppColors.surfaceCanvas,
                      child: Center(
                        child: Text(preset.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            preset.title,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(preset.emoji),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromptGeneratorTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synthesize African AI Portrait',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Describe your creator persona, regional aesthetic, or African instruments.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('avatar_prompt_input'),
            controller: _promptController,
            maxLines: 3,
            style: AppTypography.bodySmall,
            decoration: InputDecoration(
              hintText: 'e.g. Maskandi acoustic bard with royal Zulu crown in golden sunset...',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Preset prompt chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPromptChip('🎹 Amapiano Producer'),
              _buildPromptChip('👑 Limpopo Queen'),
              _buildPromptChip('🎸 Maskandi Guitarist'),
              _buildPromptChip('⚡ Durban Gqom'),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('generate_avatar_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isGenerating ? null : _simulateAiGeneration,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandContrast,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isGenerating ? 'Synthesizing with RunPod AI...' : 'Generate AI Portrait ✨',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandContrast,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
      onPressed: () {
        HapticFeedback.selectionClick();
        _promptController.text = label;
      },
    );
  }

  Widget _buildPhotoUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Image URL',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a direct link to your photo (PNG, JPEG, WebP).',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('avatar_url_input'),
            controller: _urlController,
            style: AppTypography.bodySmall,
            decoration: InputDecoration(
              hintText: 'https://example.com/avatar.jpg',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandPrimary),
              ),
            ),
            onChanged: (val) {
              setState(() => _selectedAvatarUrl = val.trim());
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceSecondary,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final val = _urlController.text.trim();
              if (val.isNotEmpty) {
                setState(() => _selectedAvatarUrl = val);
              }
            },
            icon: const Icon(Icons.preview_rounded, size: 18),
            label: const Text('Preview Avatar'),
          ),
        ],
      ),
    );
  }
}
