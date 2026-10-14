import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/creator_dna/data/repositories/creator_dna_repository.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/domain/models/behavior_event.dart';

void main() {
  group('CreatorDnaRepository', () {
    late Directory tempDir;
    late Box hiveBox;
    late CreatorDnaRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_creator_dna_');
      Hive.init(tempDir.path);
      hiveBox = await Hive.openBox(AppConstants.creatorDnaBoxKey);
      repository = CreatorDnaRepository(hiveBox);
    });

    tearDown(() async {
      await hiveBox.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('loadProfile returns initial unseeded profile when empty', () async {
      final profile = await repository.loadProfile();

      expect(profile.userId, isEmpty);
      expect(profile.lifecycleState, DnaLifecycleState.uninitialized);
      expect(profile.onboardingCompleted, isFalse);
    });

    test('saveProfile and loadProfile round-trip successfully', () async {
      final now = DateTime(2026, 10, 14, 15, 30);
      final profile = CreatorDnaProfile(
        userId: 'creator_99',
        creativeRole: CreativeRole.songwriter,
        experienceLevel: ExperienceLevel.growing,
        genreWeights: {'Afrobeats': 2.5, 'Highlife': 1.2},
        languageWeights: {'Yoruba': 1.5, 'English': 1.0},
        primaryLanguage: 'Yoruba',
        moodWeights: {'Soulful': 1.5},
        tempoPreference: 'slow',
        vocalEnergyPreference: 'soft',
        lifecycleState: DnaLifecycleState.learning,
        totalBehaviorEvents: 14,
        createdAt: now,
        lastUpdatedAt: now,
        onboardingCompleted: true,
        onboardingCompleteness: 1.0,
      );

      await repository.saveProfile(profile);

      final loaded = await repository.loadProfile();
      expect(loaded.userId, 'creator_99');
      expect(loaded.creativeRole, CreativeRole.songwriter);
      expect(loaded.primaryLanguage, 'Yoruba');
      expect(loaded.genreWeights['Afrobeats'], 2.5);
      expect(loaded.lifecycleState, DnaLifecycleState.learning);
    });

    test('appendEvent stores events and limits to 500-event FIFO sliding window', () async {
      final initialEvents = List.generate(
        500,
        (i) => BehaviorEvent.genreFilterTap('Genre_$i'),
      );

      for (int i = 0; i < 500; i++) {
        await repository.appendEvent(initialEvents[i], initialEvents.sublist(0, i));
      }

      var loaded = await repository.loadEventLog();
      expect(loaded.length, 500);

      // Append 5 more events
      final newEvent = BehaviorEvent.genreFilterTap('NewGenre');
      await repository.appendEvent(newEvent, loaded);

      loaded = await repository.loadEventLog();
      expect(loaded.length, 500);
      expect(loaded.last.payload['genre'], 'NewGenre');
    });

    test('clearAll wipes profile and event log', () async {
      final profile = CreatorDnaProfile(
        userId: 'temp_user',
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        onboardingCompleted: true,
      );
      await repository.saveProfile(profile);
      await repository.appendEvent(BehaviorEvent.genreFilterTap('Amapiano'), []);

      expect((await repository.loadProfile()).onboardingCompleted, isTrue);
      expect((await repository.loadEventLog()).length, 1);

      await repository.clearAll();

      expect((await repository.loadProfile()).onboardingCompleted, isFalse);
      expect((await repository.loadEventLog()), isEmpty);
    });

    test('in-memory fallback works when no Hive box is passed', () async {
      final inMemoryRepo = CreatorDnaRepository();
      final profile = CreatorDnaProfile(
        userId: 'fallback_user',
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        onboardingCompleted: true,
      );

      await inMemoryRepo.saveProfile(profile);
      final loaded = await inMemoryRepo.loadProfile();
      expect(loaded.userId, 'fallback_user');
      expect(loaded.onboardingCompleted, isTrue);

      await inMemoryRepo.appendEvent(BehaviorEvent.genreFilterTap('Afro House'), []);
      final events = await inMemoryRepo.loadEventLog();
      expect(events.length, 1);
      expect(events.first.payload['genre'], 'Afro House');

      await inMemoryRepo.clearAll();
      expect((await inMemoryRepo.loadProfile()).onboardingCompleted, isFalse);
      expect((await inMemoryRepo.loadEventLog()), isEmpty);
    });
  });
}
