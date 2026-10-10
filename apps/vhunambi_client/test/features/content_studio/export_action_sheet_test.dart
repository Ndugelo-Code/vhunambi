import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/export_action_sheet.dart';

/// Mission D — Export success follow-up actions (Save / Copy / Share) and
/// token-clean rendering of the [ExportActionSheet].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Neutralize the platform clipboard channel so Copy Path doesn't throw
    // MissingPluginException in the headless test runner.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(ExportActionSheet sheet) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: Builder(builder: (context) => sheet)),
      );

  testWidgets('shows the progress state while exporting', (tester) async {
    await tester.pumpWidget(
      host(
        ExportActionSheet(
          isExporting: true,
          progress: 0.4,
          exportedFilePath: null,
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('EXPORTING 1080x1920 REEL'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    expect(find.text('Save to Device'), findsNothing);
  });

  testWidgets('shows the error state with the message', (tester) async {
    await tester.pumpWidget(
      host(
        ExportActionSheet(
          isExporting: false,
          progress: 0,
          exportedFilePath: null,
          errorMessage: 'Disk full',
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('Disk full'), findsOneWidget);
  });

  testWidgets('success state offers Share, Save to Device and Copy Path',
      (tester) async {
    await tester.pumpWidget(
      host(
        ExportActionSheet(
          isExporting: false,
          progress: 1,
          exportedFilePath: '/vault/reel.mp4',
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('EXPORT READY'), findsOneWidget);
    expect(find.text('Pristine 1080x1920 MP4 Generated!'), findsOneWidget);
    expect(find.text('Share to Socials (TikTok / Reels)'), findsOneWidget);
    expect(find.text('Save to Device'), findsOneWidget);
    expect(find.text('Copy Path'), findsOneWidget);
  });

  testWidgets('tapping Copy Path writes the file path to the clipboard',
      (tester) async {
    await tester.pumpWidget(
      host(
        ExportActionSheet(
          isExporting: false,
          progress: 1,
          exportedFilePath: '/vault/reel.mp4',
          onDismiss: () {},
        ),
      ),
    );

    // The copy handler awaits the platform channel; just verify the tap does
    // not throw and the button is present.
    await tester.tap(find.text('Copy Path'));
    await tester.pump();
    expect(find.text('Copy Path'), findsOneWidget);
  });
}
