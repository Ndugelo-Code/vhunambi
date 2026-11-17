import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Zone 4: Slim direct Studio CTA capsule paired with a clean 4-tool strip
/// (`REQ-P68-HUB-01`). Replaces both the 190dp fake prompt wrapper and duplicate
/// `AI Studio` grid card.
class CreationLaunchStrip extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback? onOpenStudio;
  final VoidCallback onOpenVoiceClone;
  final VoidCallback onOpenSketchpad;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenLibrary;

  const CreationLaunchStrip({
    super.key,
    required this.isDesktop,
    this.onOpenStudio,
    required this.onOpenVoiceClone,
    required this.onOpenSketchpad,
    this.onOpenMarket,
    this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final tools = <({
      Key key,
      String label,
      IconData icon,
      Color accent,
      VoidCallback? onTap,
    })>[
      (
        key: const Key('home_hub_voice_clone'),
        label: 'Voice Clone',
        icon: PhosphorIconsFill.microphoneStage,
        accent: AppColors.brandPrimary,
        onTap: onOpenVoiceClone,
      ),
      (
        key: const Key('home_hub_melody_sketchpad'),
        label: 'Sketchpad',
        icon: PhosphorIconsFill.musicNotesPlus,
        accent: AppColors.accentElectric,
        onTap: onOpenSketchpad,
      ),
      (
        key: const Key('home_hub_beats_market'),
        label: 'Beats Market',
        icon: PhosphorIconsFill.storefront,
        accent: AppColors.coinGold,
        onTap: onOpenMarket,
      ),
      (
        key: const Key('home_hub_asset_vault'),
        label: 'Asset Vault',
        icon: PhosphorIconsFill.folderSimpleLock,
        accent: AppColors.badgeCyan,
        onTap: onOpenLibrary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: AppColors.brandPrimary,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            key: const Key('home_create_studio_cta'),
            borderRadius: AppRadius.cardBorder,
            onTap: onOpenStudio,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.sparkle,
                      size: 18,
                      color: AppColors.brandContrast,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create in AI Studio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.brandContrast,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const PhosphorIcon(
                      PhosphorIconsBold.arrowRight,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isDesktop)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: tools.map((t) => _CreationToolCard(tool: t)).toList(),
          )
        else
          Row(
            children: <Widget>[
              for (var i = 0; i < tools.length; i++) ...<Widget>[
                Expanded(child: _CreationToolCard(tool: tools[i])),
                if (i < tools.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _CreationToolCard extends StatelessWidget {
  final ({
    Key key,
    String label,
    IconData icon,
    Color accent,
    VoidCallback? onTap,
  }) tool;

  const _CreationToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevatedOf(context),
      borderRadius: AppRadius.inputBorder,
      child: InkWell(
        key: tool.key,
        borderRadius: AppRadius.inputBorder,
        onTap: tool.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.inputBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tool.accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: Center(
                  child: PhosphorIcon(
                    tool.icon,
                    size: 16,
                    color: tool.accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tool.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
