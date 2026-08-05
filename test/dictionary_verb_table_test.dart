import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/screens/dictionary_screen.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:takt/services/auth_service.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/gamification_service.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/services/notification_service.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/sound_service.dart';
import 'package:takt/services/sync_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await DictionaryService.resetForTesting();
    await VocabularyService.resetForTesting();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbDir = await databaseFactory.getDatabasesPath();
    final dbPath = join(dbDir, 'german_dictionary.db');
    if (await File(dbPath).exists()) {
      await File(dbPath).delete();
    }
    final db = await databaseFactory.openDatabase(dbPath);
    await db.execute(
      'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT, freq_rank INTEGER)',
    );
    await db.execute(
      'CREATE TABLE definitions (id INTEGER PRIMARY KEY, word_id INTEGER, definition TEXT)',
    );
    await db.execute(
      'CREATE TABLE forms (id INTEGER PRIMARY KEY, word_id INTEGER, form TEXT, tag_id INTEGER)',
    );
    await db.execute(
      'CREATE TABLE tags (id INTEGER PRIMARY KEY, tags TEXT)',
    );
    await db.execute(
      'CREATE TABLE examples (id INTEGER PRIMARY KEY, word_id INTEGER, de TEXT, en TEXT)',
    );

    await db.insert('words', {
      'id': 1,
      'word': 'lernen',
      'pos': 'verb',
      'gender': null,
      'ipa': '/ˈlɛʁnən/',
      'base_form': null,
      'freq_rank': 1,
    });
    await db.insert('definitions', {
      'id': 1,
      'word_id': 1,
      'definition': 'to learn',
    });

    final tagsList = [
      'present singular first-person',
      'present singular second-person',
      'present singular third-person',
      'present plural first-person',
      'present plural second-person',
      'present plural third-person',
      'preterite singular first-person',
      'preterite singular second-person',
      'preterite singular third-person',
      'preterite plural first-person',
      'preterite plural second-person',
      'preterite plural third-person',
      'auxiliary',
    ];
    for (int i = 0; i < tagsList.length; i++) {
      await db.insert('tags', {'id': i + 1, 'tags': tagsList[i]});
    }

    final formsList = [
      {'form': 'lerne', 'tag_id': 1},
      {'form': 'lernst', 'tag_id': 2},
      {'form': 'lernt', 'tag_id': 3},
      {'form': 'lernen', 'tag_id': 4},
      {'form': 'lernt', 'tag_id': 5},
      {'form': 'lernen', 'tag_id': 6},
      {'form': 'lernte', 'tag_id': 7},
      {'form': 'lerntest', 'tag_id': 8},
      {'form': 'lernte', 'tag_id': 9},
      {'form': 'lernten', 'tag_id': 10},
      {'form': 'lerntet', 'tag_id': 11},
      {'form': 'lernten', 'tag_id': 12},
      {'form': 'haben', 'tag_id': 13},
    ];
    for (int i = 0; i < formsList.length; i++) {
      await db.insert('forms', {
        'id': i + 1,
        'word_id': 1,
        'form': formsList[i]['form'],
        'tag_id': formsList[i]['tag_id'],
      });
    }

    await db.close();
  });

  Widget createTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MediaLibraryService()),
        ChangeNotifierProvider(create: (_) => VocabularyService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => GamificationService()),
        ChangeNotifierProvider(create: (_) => CurriculumService()),
        ChangeNotifierProvider(create: (_) => SoundService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxIterations = 50}) async {
    await tester.runAsync(() async {
      for (int i = 0; i < maxIterations; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (finder.evaluate().isNotEmpty) return;
      }
    });
  }

  testWidgets(
    'DictionaryScreen renders verb conjugation table without unbounded width exception on mobile',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(const DictionaryScreen(initialSearchQuery: 'lernen')),
      );

      await pumpUntilFound(tester, find.text('to learn'));

      await tester.tap(find.text('to learn'));

      await pumpUntilFound(tester, find.text('Verb Conjugation Table'));

      expect(find.text('Verb Conjugation Table'), findsOneWidget);
      expect(find.text('PERFECT'), findsOneWidget);
    },
  );

  testWidgets(
    'DictionaryScreen renders verb conjugation table without unbounded width exception on desktop',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(const DictionaryScreen(initialSearchQuery: 'lernen')),
      );

      await pumpUntilFound(tester, find.text('to learn'));

      await tester.tap(find.text('to learn'));

      await pumpUntilFound(tester, find.text('Verb Conjugation Table'));

      expect(find.text('Verb Conjugation Table'), findsOneWidget);
      expect(find.text('PERFECT'), findsOneWidget);
    },
  );
}
