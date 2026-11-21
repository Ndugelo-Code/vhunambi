import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Immutable bundled studio sticker descriptor (`STD-UIUX-001` — zero raw Unicode emojis).
@immutable
class SovereignSticker {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final Color borderColor;

  const SovereignSticker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.borderColor,
  });
}

/// Curated offline-ready Vhunambi Sovereign Cultural Sticker Pack (`EP-P73-GIF-STICKER-MEDIA`).
abstract final class SovereignStickerPack {
  static const List<SovereignSticker> all = <SovereignSticker>[
    SovereignSticker(
      id: 'stk_log_drum_hit',
      title: 'Log Drum Hit',
      subtitle: '113 BPM DROP',
      icon: PhosphorIconsFill.waveform,
      startColor: Color(0xFFF59E0B),
      endColor: Color(0xFFB45309),
      borderColor: Color(0xFFFDE68A),
    ),
    SovereignSticker(
      id: 'stk_100_real',
      title: '100% Real',
      subtitle: 'HUMAN CRAFT',
      icon: PhosphorIconsFill.sealCheck,
      startColor: Color(0xFF10B981),
      endColor: Color(0xFF047857),
      borderColor: Color(0xFFA7F3D0),
    ),
    SovereignSticker(
      id: 'stk_amapiano_groove',
      title: 'Amapiano Groove',
      subtitle: 'PRIVATE SCHOOL',
      icon: PhosphorIconsFill.pianoKeys,
      startColor: Color(0xFF8B5CF6),
      endColor: Color(0xFF5B21B6),
      borderColor: Color(0xFFDDD6FE),
    ),
    SovereignSticker(
      id: 'stk_makhado_wave',
      title: 'Makhado Wave',
      subtitle: 'LIMPOPO SUNSET',
      icon: PhosphorIconsFill.sunHorizon,
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFC2410C),
      borderColor: Color(0xFFFED7AA),
    ),
    SovereignSticker(
      id: 'stk_crown_royalty',
      title: 'Crown Royalty',
      subtitle: 'KHARE SALUTE',
      icon: PhosphorIconsFill.crown,
      startColor: Color(0xFFEAB308),
      endColor: Color(0xFFA16207),
      borderColor: Color(0xFFFEF08A),
    ),
    SovereignSticker(
      id: 'stk_studio_cookin',
      title: 'Studio Cookin',
      subtitle: 'PURE HEAT',
      icon: PhosphorIconsFill.fire,
      startColor: Color(0xFFEF4444),
      endColor: Color(0xFF991B1B),
      borderColor: Color(0xFFFECACA),
    ),
    SovereignSticker(
      id: 'stk_mic_drop',
      title: 'Mic Drop',
      subtitle: 'ONE TAKE',
      icon: PhosphorIconsFill.microphoneStage,
      startColor: Color(0xFF06B6D4),
      endColor: Color(0xFF0E7490),
      borderColor: Color(0xFFA5F3FC),
    ),
    SovereignSticker(
      id: 'stk_sa_heritage',
      title: 'SA Heritage',
      subtitle: 'SOVEREIGN ROOTS',
      icon: PhosphorIconsFill.sparkle,
      startColor: Color(0xFFEC4899),
      endColor: Color(0xFF9D174D),
      borderColor: Color(0xFFFBCFE8),
    ),
  ];

  static SovereignSticker? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Crisp custom-painted studio sticker graphic (`STD-UIUX-001` compliant).
class SovereignStickerGraphic extends StatelessWidget {
  final SovereignSticker sticker;
  final double width;
  final double height;

  const SovereignStickerGraphic({
    super.key,
    required this.sticker,
    this.width = 128,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    final safeHeight = height.isFinite ? height : 96.0;
    final isCompact = safeHeight < 64.0;
    final iconSize = (safeHeight * 0.34).clamp(16.0, 42.0);
    return Container(
      width: width,
      height: height,
      padding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 10 : 18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[sticker.startColor, sticker.endColor],
        ),
        border: Border.all(
          color: sticker.borderColor.withValues(alpha: 0.70),
          width: isCompact ? 1.0 : 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: sticker.endColor.withValues(alpha: 0.28),
            blurRadius: isCompact ? 4 : 10,
            offset: Offset(0, isCompact ? 2 : 4),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(sticker.icon, size: iconSize, color: Colors.white),
              if (!isCompact) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  sticker.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.badge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                Text(
                  sticker.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
