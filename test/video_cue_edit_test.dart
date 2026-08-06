import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/models/subtitle_cue.dart';
import 'package:takt/screens/video_screen.dart';
import 'package:takt/services/media_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'editing a subtitle cue updates the cue text and key vocabulary',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final initialCue = SubtitleCue(
        start: 0.0,
        end: 5.0,
        original: 'Original Cue Text',
        translated: 'Original Translation',
      );

      final video = ProcessedVideo(
        id: 'video-1',
        taskId: 'task-1',
        url: 'https://example.com/video',
        status: ProcessingStatus.completed,
        subtitles: [initialCue],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaLibraryService()),
          ],
          child: MaterialApp(
            home: VideoScreen(processedVideo: video),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Full Transcript view tab (ChoiceChip 1)
      final choiceChips = find.byType(ChoiceChip);
      expect(choiceChips, findsNWidgets(2));
      await tester.tap(choiceChips.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify initial cue original word is rendered
      expect(find.textContaining('Original'), findsWidgets);

      // Long press on the cue card to show action bar
      final cueWidget = find.textContaining('Original').first;
      await tester.longPress(cueWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Edit button is visible
      final editButton = find.text('Edit');
      expect(editButton, findsOneWidget);

      // Tap Edit button
      await tester.tap(editButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify edit sheet opened with text fields
      final originalField = find.byKey(const Key('edit_cue_original_field'));
      expect(originalField, findsOneWidget);

      // Change original text
      const updatedOriginal = 'Updated Cue Text';
      await tester.enterText(originalField, updatedOriginal);
      await tester.pump();

      // Tap Save button
      final saveButton = find.byKey(const Key('save_cue_button'));
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify updated cue word is displayed in transcript view
      expect(find.textContaining('Updated'), findsWidgets);
      expect(find.textContaining('Original'), findsNothing);
    },
  );
}
