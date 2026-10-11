import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/bantu_voice_profile.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';

void main() {
  group('BantuVoiceProfile & kBantuVoiceProfiles', () {
    test('contains 5 canonical Bantu voice profiles', () {
      expect(kBantuVoiceProfiles.length, 5);

      final ids = kBantuVoiceProfiles.map((p) => p.id).toList();
      expect(ids, containsAll([
        'venda_folk_elder',
        'soweto_soul_lead',
        'durban_gqom_chanter',
        'maskandi_bard',
        'limpopo_pop_queen',
      ]));
    });

    test('serializes and deserializes BantuVoiceProfile accurately', () {
      const profile = BantuVoiceProfile(
        id: 'venda_folk_elder',
        name: 'Venda Folk Elder',
        language: 'Tshivenḓa',
        region: 'Limpopo / Makhado',
        timbreDescription: 'Deep chest resonance',
        iconEmoji: '👴',
        loraScale: 0.90,
        characteristicAdLibs: ['Ndi zwone!', 'Aa!'],
      );

      final json = profile.toJson();
      expect(json['id'], 'venda_folk_elder');
      expect(json['loraScale'], 0.90);
      expect(json['characteristicAdLibs'], contains('Ndi zwone!'));

      final fromJson = BantuVoiceProfile.fromJson(json);
      expect(fromJson.id, profile.id);
      expect(fromJson.name, profile.name);
      expect(fromJson.loraScale, profile.loraScale);
      expect(fromJson.characteristicAdLibs, profile.characteristicAdLibs);
    });

    test('DialectInflectionConfig copyWith and serialization', () {
      const config = DialectInflectionConfig(
        vowelElongation: 0.5,
        vibratoDepth: 0.4,
        callAndResponseIntensity: 0.6,
        adLibFrequency: 0.5,
      );

      final updated = config.copyWith(
        vowelElongation: 0.85,
        adLibFrequency: 0.9,
      );

      expect(updated.vowelElongation, 0.85);
      expect(updated.vibratoDepth, 0.4);
      expect(updated.adLibFrequency, 0.9);

      final json = updated.toJson();
      final fromJson = DialectInflectionConfig.fromJson(json);
      expect(fromJson.vowelElongation, 0.85);
      expect(fromJson.vibratoDepth, 0.4);
      expect(fromJson.callAndResponseIntensity, 0.6);
      expect(fromJson.adLibFrequency, 0.9);
    });

    test('StudioFormState embeds Bantu voice LoRA and inflection in SongMetadataDna', () {
      const customProfile = BantuVoiceProfile(
        id: 'durban_gqom_chanter',
        name: 'Durban Gqom Chanter',
        language: 'isiZulu',
        region: 'KwaZulu-Natal / Durban',
        timbreDescription: 'Raw percussive chants',
        iconEmoji: '⚡',
        loraScale: 0.92,
      );

      const customInflection = DialectInflectionConfig(
        vowelElongation: 0.75,
        vibratoDepth: 0.3,
        callAndResponseIntensity: 0.8,
        adLibFrequency: 0.85,
      );

      const formState = StudioFormState(
        prompt: 'Gqom banger',
        genre: 'Gqom',
        selectedVoiceProfile: customProfile,
        dialectInflection: customInflection,
      );

      final dna = formState.toSongMetadataDna();
      expect(dna.vocals.loras.isNotEmpty, isTrue);

      final loraEntry = dna.vocals.loras.first;
      expect(loraEntry['profileId'], 'durban_gqom_chanter');
      expect(loraEntry['loraScale'], 0.92);
      expect(loraEntry['dialectInflection']['vowelElongation'], 0.75);
    });
  });
}
