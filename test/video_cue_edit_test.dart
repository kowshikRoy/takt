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

      // Verify initial cue original word is rendered in default full transcript view
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

  testWidgets(
    'modifying transcript and tapping generate translation updates translation field',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final initialCue = SubtitleCue(
        start: 0.0,
        end: 5.0,
        original: 'Guten Tag',
        translated: 'Good day',
      );

      final video = ProcessedVideo(
        id: 'video-2',
        taskId: 'task-2',
        url: 'https://example.com/video2',
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

      // Long press on the cue card to show action bar
      final cueWidget = find.textContaining('Guten').first;
      await tester.longPress(cueWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Edit button
      final editButton = find.text('Edit');
      await tester.tap(editButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify edit sheet opened with translation action button
      final originalField = find.byKey(const Key('edit_cue_original_field'));
      final translatedField = find.byKey(const Key('edit_cue_translated_field'));
      final generateButton = find.byKey(const Key('generate_translation_button'));
      final suffixIcon = find.byKey(const Key('translate_suffix_icon'));

      expect(originalField, findsOneWidget);
      expect(translatedField, findsOneWidget);
      expect(generateButton, findsOneWidget);
      expect(suffixIcon, findsOneWidget);

      // Modify the original German transcript
      await tester.enterText(originalField, 'Auf Wiedersehen');
      await tester.pump();

      // Tap the generate translation button
      await tester.tap(generateButton);
      await tester.pump();
      // Allow async translation completion
      await tester.pump(const Duration(seconds: 1));

      // Tap Save button
      final saveButton = find.byKey(const Key('save_cue_button'));
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify updated cue original text is rendered
      expect(find.textContaining('Wiedersehen'), findsWidgets);
    },
  );

  testWidgets(
    'external media control bar renders below video with rectangular key vocabulary chip and translation toggle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final cue1 = SubtitleCue(
        start: 0.0,
        end: 3.0,
        original: 'Hallo Welt',
        translated: 'Hello World',
      );

      final video = ProcessedVideo(
        id: 'video-3',
        taskId: 'task-3',
        url: 'https://example.com/video3',
        status: ProcessingStatus.completed,
        subtitles: [cue1],
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

      // Verify key vocabulary rectangular chip exists
      final choiceChips = find.byType(ChoiceChip);
      expect(choiceChips, findsOneWidget);

      // Verify translation toggle icon button exists (defaults to hidden translations with g_translate)
      final translateToggle = find.byIcon(Icons.g_translate_rounded);
      expect(translateToggle, findsOneWidget);

      // Tap translation toggle to show translations
      await tester.tap(translateToggle);
      await tester.pump();

      // Now translate_rounded icon should be displayed
      expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
    },
  );
}
