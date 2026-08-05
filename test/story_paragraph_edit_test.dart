import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/article_model.dart';
import 'package:takt/screens/story_reader_screen.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // story_reader_screen.dart looks up word genders via DictionaryService
    // on load, which opens a real sqflite database — unavailable via
    // platform channels in a plain widget test. Point sqflite at the FFI
    // backend and pre-seed an empty `words` table at the exact path
    // DictionaryService expects, so it finds a "valid" DB and skips its
    // network-download fallback entirely.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbDir = await databaseFactory.getDatabasesPath();
    final dbPath = join(dbDir, 'german_dictionary.db');
    if (!await File(dbPath).exists()) {
      final db = await databaseFactory.openDatabase(dbPath);
      await db.execute(
        'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT)',
      );
      await db.close();
    }
  });

  // Paragraph text is rendered word-by-word as RichText/TextSpan (each word
  // is individually tappable for the dictionary lookup feature), not as a
  // single Text widget — so find.text() against the full sentence never
  // matches. Check the RichText's flattened plain text instead.
  Finder richTextContaining(String substring) {
    return find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(substring),
    );
  }

  testWidgets(
    'editing a paragraph replaces its text and persists via saveCustomContent',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final article = Article(
        id: 'test-article-1',
        title: 'Test Story',
        description: 'desc',
        level: 'A1',
        date: DateTime(2026, 1, 1),
        imageUrl: 'assets/images/story_desert.png',
      );

      const originalMarker = 'ORIGINALTEXT';
      const originalText = 'Dies ist der $originalMarker Absatz.';
      const customContent = '$originalText\n\nDies ist der zweite Absatz.';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaLibraryService()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: StoryReaderScreen(
              article: article,
              customContent: customContent,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(richTextContaining(originalMarker), findsOneWidget);

      final editButtonFinder = find.byTooltip('Edit paragraph').first;
      expect(editButtonFinder, findsOneWidget);
      await tester.tap(editButtonFinder);
      // Not pumpAndSettle(): the sheet's TextField is autofocus:true, and
      // its blinking cursor animation never settles, which would hang here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final fieldFinder = find.widgetWithText(TextField, originalText);
      expect(fieldFinder, findsOneWidget, reason: 'sheet TextField should be pre-filled with the paragraph text');

      const editedMarker = 'KORRIGIERTE';
      const editedText = 'Dies ist der $editedMarker Absatz.';
      await tester.enterText(fieldFinder, editedText);
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(richTextContaining(editedMarker), findsOneWidget);
      expect(richTextContaining(originalMarker), findsNothing);

      final mediaLibraryService = MediaLibraryService();
      final persisted = await mediaLibraryService.getCustomContent(article.id);
      expect(persisted, isNotNull);
      expect(persisted!.contains(editedMarker), isTrue);
      expect(persisted.contains(originalMarker), isFalse);
    },
  );
}
