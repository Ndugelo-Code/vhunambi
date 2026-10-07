import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_stem_download_service.dart';
import 'package:vhunambi_client/features/studio/data/services/stem_download_service.dart';

/// T10.5 — Stem download orchestrator suite.
void main() {
  group('FakeStemDownloadService', () {
    test('downloadMaster emits exactly three progress ticks', () async {
      final fake = FakeStemDownloadService(stepDelay: Duration.zero);

      final ticks = await fake.downloadMaster('https://cdn/master.mp3').toList();

      expect(ticks, hasLength(3));
      expect(ticks.every((tick) => tick.url == 'https://cdn/master.mp3'),
          isTrue);
    });

    test('progress climbs monotonically to completion', () async {
      final fake = FakeStemDownloadService(stepDelay: Duration.zero);

      final ticks = await fake.downloadMaster('https://cdn/master.mp3').toList();

      expect(ticks.map((tick) => tick.progress).toList(), <Matcher>[
        closeTo(0.25, 0.001),
        closeTo(0.75, 0.001),
        closeTo(1.0, 0.001),
      ]);
      for (var index = 1; index < ticks.length; index++) {
        expect(ticks[index].progress,
            greaterThanOrEqualTo(ticks[index - 1].progress));
      }
    });

    test('the terminal tick is complete and carries the local path', () async {
      final fake = FakeStemDownloadService(stepDelay: Duration.zero);

      final ticks = await fake.downloadMaster('https://cdn/master.mp3').toList();

      expect(ticks.last.isComplete, isTrue);
      expect(ticks.last.localPath, '/tmp/fake_track.mp3');
      expect(ticks.last.hasError, isFalse);
      expect(ticks.first.isComplete, isFalse);
    });

    test('downloadStems reuses the same contract and records the url',
        () async {
      final fake = FakeStemDownloadService(stepDelay: Duration.zero);

      final ticks = await fake.downloadStems('https://cdn/stems.zip').toList();

      expect(ticks, hasLength(3));
      expect(fake.downloadedUrls, <String>['https://cdn/stems.zip']);
    });

    test('cancelDownload records the url and completes cleanly', () async {
      final fake = FakeStemDownloadService(stepDelay: Duration.zero);

      await fake.cancelDownload('https://cdn/master.mp3');

      expect(fake.cancelledUrls, <String>['https://cdn/master.mp3']);
    });
  });

  group('StemDownloadService (pure helpers)', () {
    test('derives a deterministic file name from the master url', () {
      expect(
        StemDownloadService.fileNameForUrl(
          'https://cdn.vhunambi.com/masters/trk_1.mp3',
        ),
        'trk_1.mp3',
      );
      expect(
        StemDownloadService.fileNameForUrl('https://cdn.vhunambi.com/trk_2'),
        'trk_2.mp3',
      );
      expect(
        StemDownloadService.fileNameForUrl('https://cdn.vhunambi.com/'),
        'master.mp3',
      );
    });

    test('builds the destination inside the downloads directory', () async {
      final directory = Directory.systemTemp.createTempSync('vhunambi_dl_');
      addTearDown(() => directory.deleteSync(recursive: true));

      final destination = StemDownloadService.destinationFor(
        directory,
        'https://cdn.vhunambi.com/masters/trk_1.mp3',
      );

      expect(destination, '${directory.path}/trk_1.mp3');
      expect(StemDownloadService.downloadDirectoryName, 'vhunambi_downloads');
    });

    test('resolveDownloadDirectory honours the injected override', () async {
      final directory = Directory.systemTemp.createTempSync('vhunambi_dl_');
      addTearDown(() => directory.deleteSync(recursive: true));

      final service = StemDownloadService(directoryOverride: () => directory);

      expect(await service.resolveDownloadDirectory(), same(directory));
    });
  });
}
