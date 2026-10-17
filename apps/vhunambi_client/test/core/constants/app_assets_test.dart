import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/features/studio/domain/models/bantu_voice_profile.dart';

void main() {
  group('AppAssets Registry Tests', () {
    test('defines valid branding and artwork path tokens', () {
      expect(AppAssets.vhunambiWordmark, 'assets/branding/vhunambi_wordmark.png');
      expect(AppAssets.vhunambiGlyph, 'assets/branding/vhunambi_glyph.png');
      expect(AppAssets.appIconDark, 'assets/branding/app_icon_dark.png');
      expect(AppAssets.appIconLight, 'assets/branding/app_icon_light.png');
      expect(AppAssets.appIconFullBleed, 'assets/branding/app_icon_fullbleed.png');
      expect(AppAssets.timbreElder, 'assets/artwork/timbre_elder.png');
      expect(AppAssets.timbrePoet, 'assets/artwork/timbre_poet.png');
      expect(AppAssets.timbreCrooner, 'assets/artwork/timbre_crooner.png');
      expect(AppAssets.timbreCantor, 'assets/artwork/timbre_cantor.png');
      expect(AppAssets.timbreProducer, 'assets/artwork/timbre_producer.png');
      expect(AppAssets.heritageCrateCover, 'assets/artwork/heritage_crate_cover.png');
      expect(AppAssets.splashHero, 'assets/artwork/splash_hero.png');
    });

    test('voiceTimbreForId maps all 5 canonical Bantu profiles to assets', () {
      for (final profile in kBantuVoiceProfiles) {
        final path = AppAssets.voiceTimbreForId(profile.id);
        expect(path, isNotNull, reason: 'Profile ${profile.id} should have a timbre asset');
        expect(path, startsWith('assets/artwork/timbre_'));
      }

      expect(AppAssets.voiceTimbreForId('non_existent_profile'), isNull);
    });

    testWidgets('renders glyphImage with graceful fallback in widget test',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAssets.glyphImage(size: 40),
          ),
        ),
      );

      // Verify the widget mounts
      expect(find.byKey(const Key('vhunambi_brand_glyph_image')), findsOneWidget);
    });

    testWidgets('renders wordmarkImage with graceful fallback in widget test',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAssets.wordmarkImage(height: 32),
          ),
        ),
      );

      expect(find.byKey(const Key('vhunambi_brand_wordmark_image')), findsOneWidget);
    });
  });
}
