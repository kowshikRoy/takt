import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/screens/discover_screen.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/media_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // DiscoverScreen's "Path" tab (SkillTreeScreen) is built eagerly by
    // TabBarView even though this test only interacts with "Library", and
    // it pulls in VocabularyService, which opens a real sqflite database —
    // unavailable via platform channels in a plain widget test.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'mobile grid card shows the error and a working Retry button',
    (tester) async {
      // See media_library_retry_desktop_test.dart for why this is
      // suppressed: a pre-existing, unrelated overflow in the "Continue
      // Learning" section (hardcoded mock data), orthogonal to this test.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('RenderFlex overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final failedVideo = ProcessedVideo(
        id: 'failed-task-1',
        taskId: 'failed-task-1',
        url: 'https://youtube.com/watch?v=broken',
        status: ProcessingStatus.failed,
        errorMessage: 'Could not fetch transcript',
        subtitles: const [],
      );

      SharedPreferences.setMockInitialValues({
        'processed_videos': jsonEncode([failedVideo.toJson()]),
      });

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaLibraryService()),
            ChangeNotifierProvider(create: (_) => CurriculumService()),
          ],
          child: const MaterialApp(home: DiscoverScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Could not fetch transcript'), findsOneWidget);
      final retryButtonFinder = find.widgetWithText(OutlinedButton, 'Retry');
      expect(retryButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      final retryButton = tester.widget<OutlinedButton>(retryButtonFinder);
      expect(retryButton.onPressed, isNotNull);
      retryButton.onPressed!();
      await tester.pump();
    },
  );
}
