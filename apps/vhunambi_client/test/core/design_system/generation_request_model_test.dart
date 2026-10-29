import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/models/generation_request_model.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';

void main() {
  group('GenerationRequestModel', () {
    test('creates model with default values', () {
      final model = GenerationRequestModel.defaults();
      expect(model.genre, equals(Genre.amapiano));
      expect(model.mood, equals(Mood.joyful));
      expect(model.bpm, equals(120));
      expect(model.dnaStrength, equals(0.5));
      expect(model.visibility, equals('private'));
      expect(model.lyrics, isNull);
      expect(model.prompt, isNull);
    });

    test('copyWith creates modified copy', () {
      const original = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: 'private',
      );
      final copy = original.copyWith(
        genre: Genre.gqom,
        bpm: 140,
        dnaStrength: 0.8,
        visibility: 'public',
        lyrics: 'Test lyrics',
      );

      expect(copy.genre, equals(Genre.gqom));
      expect(copy.mood, equals(Mood.joyful));
      expect(copy.bpm, equals(140));
      expect(copy.dnaStrength, equals(0.8));
      expect(copy.visibility, equals('public'));
      expect(copy.lyrics, equals('Test lyrics'));
      expect(copy.prompt, isNull);
    });

    test('copyWith preserves unspecified fields', () {
      const original = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: 'private',
      );
      final copy = original.copyWith(bpm: 100);

      expect(copy.bpm, equals(100));
      expect(copy.genre, equals(Genre.amapiano));
      expect(copy.mood, equals(Mood.joyful));
      expect(copy.dnaStrength, equals(0.5));
      expect(copy.visibility, equals('private'));
    });

    test('validate passes for valid model', () {
      final model = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: 'public',
      );
      expect(() => model.validate(), returnsNormally);
    });

    test('validate fails for BPM out of range', () {
      final model = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 300,
        dnaStrength: 0.5,
        visibility: 'public',
      );
      expect(
        () => model.validate(),
        throwsA(isA<GenerationRequestValidationException>()),
      );
    });

    test('validate fails for DNA strength out of range', () {
      final model = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 1.5,
        visibility: 'public',
      );
      expect(
        () => model.validate(),
        throwsA(isA<GenerationRequestValidationException>()),
      );
    });

    test('validate fails for empty visibility', () {
      final model = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: '',
      );
      expect(
        () => model.validate(),
        throwsA(isA<GenerationRequestValidationException>()),
      );
    });

    test('toJson serializes all fields', () {
      final model = GenerationRequestModel(
        genre: Genre.gqom,
        mood: Mood.energetic,
        bpm: 140,
        dnaStrength: 0.7,
        visibility: 'public',
        lyrics: 'Test lyrics',
        prompt: 'Test prompt',
      );
      final json = model.toJson();
      expect(json['genre'], equals('gqom'));
      expect(json['mood'], equals('energetic'));
      expect(json['bpm'], equals(140));
      expect(json['dna_strength'], equals(0.7));
      expect(json['visibility'], equals('public'));
      expect(json['lyrics'], equals('Test lyrics'));
      expect(json['prompt'], equals('Test prompt'));
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'genre': 'maskandi',
        'mood': 'romantic',
        'bpm': 110,
        'dna_strength': 0.3,
        'visibility': 'private',
        'lyrics': 'Loaded lyrics',
        'prompt': 'Loaded prompt',
      };
      final model = GenerationRequestModel.fromJson(json);
      expect(model.genre, equals(Genre.maskandi));
      expect(model.mood, equals(Mood.romantic));
      expect(model.bpm, equals(110));
      expect(model.dnaStrength, equals(0.3));
      expect(model.visibility, equals('private'));
      expect(model.lyrics, equals('Loaded lyrics'));
      expect(model.prompt, equals('Loaded prompt'));
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};
      final model = GenerationRequestModel.fromJson(json);
      expect(model.genre, equals(Genre.amapiano));
      expect(model.mood, equals(Mood.joyful));
      expect(model.bpm, equals(120));
      expect(model.dnaStrength, equals(0.5));
      expect(model.visibility, equals('private'));
    });

    test('fromJson handles unknown genre gracefully', () {
      final json = {'genre': 'unknown_genre', 'mood': 'joyful'};
      final model = GenerationRequestModel.fromJson(json);
      expect(model.genre, equals(Genre.amapiano));
    });

    test('equality is based on all fields', () {
      const m1 = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: 'private',
      );
      const m2 = GenerationRequestModel(
        genre: Genre.amapiano,
        mood: Mood.joyful,
        bpm: 120,
        dnaStrength: 0.5,
        visibility: 'private',
      );
      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
    });
  });
}