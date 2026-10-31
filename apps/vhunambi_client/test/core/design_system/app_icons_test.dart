import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';

void main() {
  group('AppIcons Design Token Registry Tests', () {
    test('Navigation tokens resolve to valid icon data with correct codePoints', () {
      expect(AppIcons.navHome.codePoint, isPositive);
      expect(AppIcons.navHomeActive.codePoint, isPositive);
      expect(AppIcons.navExplore.codePoint, isPositive);
      expect(AppIcons.navExploreActive.codePoint, isPositive);
      expect(AppIcons.navCreate.codePoint, isPositive);
      expect(AppIcons.navLibrary.codePoint, isPositive);
      expect(AppIcons.navLibraryActive.codePoint, isPositive);
      expect(AppIcons.navMarket.codePoint, isPositive);
      expect(AppIcons.navMarketActive.codePoint, isPositive);
    });

    test('Gamification and status icon tokens replace UI emojis cleanly', () {
      expect(AppIcons.flame.codePoint, isPositive);
      expect(AppIcons.coin.codePoint, isPositive);
      expect(AppIcons.coins.codePoint, isPositive);
      expect(AppIcons.sparkle.codePoint, isPositive);
      expect(AppIcons.lightning.codePoint, isPositive);
      expect(AppIcons.trophy.codePoint, isPositive);
      expect(AppIcons.crown.codePoint, isPositive);
      expect(AppIcons.dna.codePoint, isPositive);
      expect(AppIcons.verified.codePoint, isPositive);
      expect(AppIcons.heart.codePoint, isPositive);
      expect(AppIcons.share.codePoint, isPositive);
    });

    test('DAW and Studio cockpit tokens resolve to valid vector glyphs', () {
      expect(AppIcons.songs.codePoint, isPositive);
      expect(AppIcons.releases.codePoint, isPositive);
      expect(AppIcons.beatstore.codePoint, isPositive);
      expect(AppIcons.vocals.codePoint, isPositive);
      expect(AppIcons.mic.codePoint, isPositive);
      expect(AppIcons.drums.codePoint, isPositive);
      expect(AppIcons.piano.codePoint, isPositive);
      expect(AppIcons.guitar.codePoint, isPositive);
      expect(AppIcons.magicWand.codePoint, isPositive);
      expect(AppIcons.voiceClone.codePoint, isPositive);
      expect(AppIcons.mastering.codePoint, isPositive);
    });

    test('Media transport controls resolve to valid vector glyphs', () {
      expect(AppIcons.play.codePoint, isPositive);
      expect(AppIcons.pause.codePoint, isPositive);
      expect(AppIcons.skipForward.codePoint, isPositive);
      expect(AppIcons.skipBack.codePoint, isPositive);
      expect(AppIcons.shuffle.codePoint, isPositive);
      expect(AppIcons.repeat.codePoint, isPositive);
      expect(AppIcons.volumeHigh.codePoint, isPositive);
      expect(AppIcons.volumeMute.codePoint, isPositive);
      expect(AppIcons.disc.codePoint, isPositive);
      expect(AppIcons.waveform.codePoint, isPositive);
    });

    test('Common UI action and navigation tokens resolve correctly', () {
      expect(AppIcons.search.codePoint, isPositive);
      expect(AppIcons.bell.codePoint, isPositive);
      expect(AppIcons.settings.codePoint, isPositive);
      expect(AppIcons.filter.codePoint, isPositive);
      expect(AppIcons.sort.codePoint, isPositive);
      expect(AppIcons.close.codePoint, isPositive);
      expect(AppIcons.plus.codePoint, isPositive);
      expect(AppIcons.check.codePoint, isPositive);
      expect(AppIcons.arrowLeft.codePoint, isPositive);
      expect(AppIcons.caretDown.codePoint, isPositive);
      expect(AppIcons.dotsVertical.codePoint, isPositive);
      expect(AppIcons.chat.codePoint, isPositive);
      expect(AppIcons.remix.codePoint, isPositive);
      expect(AppIcons.trash.codePoint, isPositive);
      expect(AppIcons.download.codePoint, isPositive);
      expect(AppIcons.edit.codePoint, isPositive);
      expect(AppIcons.eye.codePoint, isPositive);
      expect(AppIcons.user.codePoint, isPositive);
    });
  });
}
