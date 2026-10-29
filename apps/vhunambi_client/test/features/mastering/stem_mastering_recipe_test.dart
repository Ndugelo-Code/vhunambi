import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/mastering/domain/models/stem_mastering_recipe.dart';

void main() {
  group('StemMasteringRecipe Domain & Presets (REQ-MST-DOM-01..04)', () {
    test('Default recipe initializes with Amapiano Club Knock values', () {
      const recipe = StemMasteringRecipe();

      expect(recipe.presetId, 'amapiano_club_knock');
      expect(recipe.targetLufs, -9.5);
      expect(recipe.vocals.flavor, VocalCleanseFlavor.studioClean);
      expect(recipe.vocals.neuralDenoiseStrength, 0.85);
      expect(recipe.bass.flavor, BassCharacterFlavor.heavyWoodenKnock);
      expect(recipe.bass.knockDriveDb, 4.5);
      expect(recipe.bass.subHarmonicMix, 0.55);
      expect(recipe.bass.sidechainDuckDb, -3.5);
      expect(recipe.drums.flavor, DrumCharacterFlavor.crispShakers);
      expect(recipe.melodic.flavor, MelodicCharacterFlavor.wideStereoPocket);
      expect(recipe.melodic.midVocalPocketCutDb, -2.5);
    });

    test('All 6 regional Genre Master Presets are registered and distinct', () {
      expect(kGenreMasterPresets.length, 6);

      final ids = kGenreMasterPresets.map((p) => p.id).toSet();
      expect(ids.length, 6);
      expect(
        ids,
        containsAll([
          'amapiano_club_knock',
          'private_school_warmth',
          'gqom_warehouse_sub',
          'maskandi_acoustic_clarity',
          'afro_house_horizon',
          'kwaito_golden_tape',
        ]),
      );
    });

    test('StemMasteringRecipe.forGenre resolves regional defaults deterministically', () {
      final amapiano = StemMasteringRecipe.forGenre('Amapiano');
      expect(amapiano.presetId, 'amapiano_club_knock');
      expect(amapiano.targetLufs, -9.5);

      final maskandi = StemMasteringRecipe.forGenre('Maskandi');
      expect(maskandi.presetId, 'maskandi_acoustic_clarity');
      expect(maskandi.vocals.neuralDereverbStrength, 0.75);

      final gqom = StemMasteringRecipe.forGenre('Gqom');
      expect(gqom.presetId, 'gqom_warehouse_sub');
      expect(gqom.bass.subHarmonicMix, 0.7);

      final afroHouse = StemMasteringRecipe.forGenre('Afro House');
      expect(afroHouse.presetId, 'afro_house_horizon');

      final kwaito = StemMasteringRecipe.forGenre('Kwaito');
      expect(kwaito.presetId, 'kwaito_golden_tape');

      final unknown = StemMasteringRecipe.forGenre('Ambient');
      expect(unknown.presetId, 'amapiano_club_knock');
    });

    test('Recipe serializes to JSON and round-trips with full fidelity', () {
      final original = StemMasteringRecipe.forGenre('Maskandi');
      final json = original.toJson();
      final roundTrip = StemMasteringRecipe.fromJson(json);

      expect(roundTrip.presetId, original.presetId);
      expect(roundTrip.targetLufs, original.targetLufs);
      expect(roundTrip.vocals.flavor, original.vocals.flavor);
      expect(roundTrip.vocals.eq.airGainDb, original.vocals.eq.airGainDb);
      expect(roundTrip.bass.knockDriveDb, original.bass.knockDriveDb);
      expect(roundTrip.drums.transientAttackSnap, original.drums.transientAttackSnap);
      expect(roundTrip.melodic.stereoWidthBoost, original.melodic.stereoWidthBoost);
    });

    test('Tier A gain multipliers reflect DSP parameters', () {
      const defaultRecipe = StemMasteringRecipe();

      expect(defaultRecipe.vocalGainMultiplier, greaterThan(1.0));
      expect(defaultRecipe.bassGainMultiplier, greaterThan(1.1));
      expect(defaultRecipe.drumsGainMultiplier, greaterThan(1.0));
      expect(defaultRecipe.melodicGainMultiplier, greaterThan(1.0));
      expect(defaultRecipe.estimatedIntegratedLufs, -9.5);
      expect(defaultRecipe.estimatedTruePeakDbtp, -1.0);
    });

    test('Flavor enums parse from wire string and handle fallback safely', () {
      expect(VocalCleanseFlavor.fromWire('studio_clean'), VocalCleanseFlavor.studioClean);
      expect(VocalCleanseFlavor.fromWire('warm_intimate'), VocalCleanseFlavor.warmIntimate);
      expect(VocalCleanseFlavor.fromWire('unknown_xyz'), VocalCleanseFlavor.studioClean);

      expect(BassCharacterFlavor.fromWire('heavy_wooden_knock'), BassCharacterFlavor.heavyWoodenKnock);
      expect(BassCharacterFlavor.fromWire('deep_sub_808'), BassCharacterFlavor.deepSub808);
      expect(BassCharacterFlavor.fromWire(null), BassCharacterFlavor.heavyWoodenKnock);

      expect(DrumCharacterFlavor.fromWire('crisp_shakers'), DrumCharacterFlavor.crispShakers);
      expect(MelodicCharacterFlavor.fromWire('wide_stereo_pocket'), MelodicCharacterFlavor.wideStereoPocket);
    });
  });
}

