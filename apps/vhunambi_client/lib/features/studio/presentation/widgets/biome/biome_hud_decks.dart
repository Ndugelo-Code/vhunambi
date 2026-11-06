import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../../domain/models/mycelium_biome_models.dart';

/// Bottom-left Network Layers visibility filter deck (REQ-P53-HUD-05).
class BiomeNetworkLayersFilter extends StatelessWidget {
  final Set<MyceliumNetworkLayer> activeLayers;
  final ValueChanged<MyceliumNetworkLayer> onToggleLayer;

  const BiomeNetworkLayersFilter({
    super.key = const Key('biome_network_layers_filter'),
    required this.activeLayers,
    required this.onToggleLayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Network Layers',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...MyceliumNetworkLayer.values.map((layer) {
            final isActive = activeLayers.contains(layer);
            final dotColor = Color(layer.indicatorHex);
            return GestureDetector(
              key: Key('biome_layer_${layer.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleLayer(layer);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive ? dotColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: dotColor, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      layer.displayName,
                      style: AppTypography.caption.copyWith(
                        color: isActive ? Colors.white : Colors.white38,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Bottom-left Interactive Controls deck: Rotate, Zoom, Focus, Compare, Analyse (REQ-P53-HUD-04).
class BiomeInteractiveControlsBar extends StatelessWidget {
  final bool isAutoRotating;
  final bool isMacroZoomed;
  final bool isCompareActive;
  final bool isAnalyseActive;
  final VoidCallback onToggleRotate;
  final VoidCallback onToggleZoom;
  final VoidCallback onFocusReset;
  final VoidCallback onToggleCompare;
  final VoidCallback onToggleAnalyse;

  const BiomeInteractiveControlsBar({
    super.key = const Key('biome_controls_bar'),
    required this.isAutoRotating,
    required this.isMacroZoomed,
    required this.isCompareActive,
    required this.isAnalyseActive,
    required this.onToggleRotate,
    required this.onToggleZoom,
    required this.onFocusReset,
    required this.onToggleCompare,
    required this.onToggleAnalyse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('biome_interactive_controls_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Interactive Controls',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildControlBtn(
                key: const Key('biome_ctrl_rotate'),
                icon: PhosphorIconsBold.arrowsClockwise,
                label: 'Rotate',
                isActive: isAutoRotating,
                onTap: onToggleRotate,
              ),
              const SizedBox(width: 12),
              _buildControlBtn(
                key: const Key('biome_ctrl_zoom'),
                icon: PhosphorIconsBold.magnifyingGlassPlus,
                label: 'Zoom',
                isActive: isMacroZoomed,
                onTap: onToggleZoom,
              ),
              const SizedBox(width: 12),
              _buildControlBtn(
                key: const Key('biome_ctrl_focus'),
                icon: PhosphorIconsBold.crosshair,
                label: 'Focus',
                isActive: false,
                onTap: onFocusReset,
              ),
              const SizedBox(width: 12),
              _buildControlBtn(
                key: const Key('biome_ctrl_compare'),
                icon: PhosphorIconsBold.arrowsLeftRight,
                label: 'Compare',
                isActive: isCompareActive,
                onTap: onToggleCompare,
              ),
              const SizedBox(width: 12),
              _buildControlBtn(
                key: const Key('biome_ctrl_analyse'),
                icon: PhosphorIconsBold.play,
                label: 'Analyse',
                isActive: isAnalyseActive,
                onTap: onToggleAnalyse,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required Key key,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFFFF9E00);
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white24,
              ),
            ),
            child: Center(
              child: PhosphorIcon(
                icon,
                color: isActive ? activeColor : Colors.white70,
                size: 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isActive ? activeColor : Colors.white70,
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
