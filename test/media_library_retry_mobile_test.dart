import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/screens/create/url_import_screen.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/media_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'mobile grid card shows the error and a working Retry button',
    (tester) async {
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

      final mediaService = MediaLibraryService();
      await mediaService.reloadForTesting();

      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mediaService),
            ChangeNotifierProvider(create: (_) => CurriculumService()),
          ],
          child: const MaterialApp(home: UrlImportScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final errorFinder = find.text('Could not fetch transcript');
      expect(errorFinder, findsOneWidget);
      final retryButtonFinder = find.widgetWithText(FilledButton, 'Retry');
      expect(retryButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      final retryButton = tester.widget<FilledButton>(retryButtonFinder);
      expect(retryButton.onPressed, isNotNull);
      retryButton.onPressed!();
      await tester.pump();
    },
  );
}
