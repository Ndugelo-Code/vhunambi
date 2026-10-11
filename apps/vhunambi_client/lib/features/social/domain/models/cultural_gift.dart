import 'package:flutter/foundation.dart';

/// An African cultural gift powering creator micro-tipping in Vhunambi (REQ-GFT-02).
@immutable
class CulturalGift {
  final String id;
  final String name;
  final String emoji;
  final int coinPrice;
  final double zarPrice;
  final String culturalMeaning;

  const CulturalGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinPrice,
    required this.zarPrice,
    required this.culturalMeaning,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'coinPrice': coinPrice,
        'zarPrice': zarPrice,
        'culturalMeaning': culturalMeaning,
      };

  factory CulturalGift.fromJson(Map<String, dynamic> json) {
    return CulturalGift(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      coinPrice: (json['coinPrice'] as num).toInt(),
      zarPrice: (json['zarPrice'] as num).toDouble(),
      culturalMeaning: json['culturalMeaning'] as String,
    );
  }
}

/// The 4 canonical African cultural micro-gifts.
const List<CulturalGift> kCulturalGifts = [
  CulturalGift(
    id: 'cowrie_shell',
    name: 'Cowrie Shell (Mbaḓi)',
    emoji: '🐚',
    coinPrice: 5,
    zarPrice: 2.0,
    culturalMeaning:
        'Ancient African currency representing honor, fertility, and lasting community appreciation.',
  ),
  CulturalGift(
    id: 'african_drum',
    name: 'African Drum (Ngoma)',
    emoji: '🥁',
    coinPrice: 15,
    zarPrice: 5.0,
    culturalMeaning:
        'Sacred rhythm salute honoring the primal heartbeat and syncopated spirit of the song.',
  ),
  CulturalGift(
    id: 'log_drum_trophy',
    name: 'Log Drum Trophy (Tshikona)',
    emoji: '🎹',
    coinPrice: 50,
    zarPrice: 15.0,
    culturalMeaning:
        'Trophy for top-tier Amapiano bassline mastery, sonic innovation, and heavy club groove.',
  ),
  CulturalGift(
    id: 'royal_venda_crown',
    name: 'Royal Venda Crown (Khare)',
    emoji: '👑',
    coinPrice: 200,
    zarPrice: 50.0,
    culturalMeaning:
        'Royalty honor reserved for master producers, community legends, and cultural innovators.',
  ),
];
