import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect Word via Dart Services', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final targetWord = Platform.environment['WORD']?.trim() ?? 'bestimmen';
    final projectDir = Directory.current.path;
    final assetsDir = p.join(projectDir, 'assets');

    String? dbPath = Platform.environment['DB_PATH'];
    if (dbPath == null) {
      final assetDirObj = Directory(assetsDir);
      if (assetDirObj.existsSync()) {
        final dbFiles = assetDirObj
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.db') && f.lengthSync() > 100 * 1024)
            .toList();

        dbFiles.sort((a, b) {
          final aName = p.basename(a.path);
          final bName = p.basename(b.path);
          final aVer = int.tryParse(RegExp(r'v(\d+)').firstMatch(aName)?.group(1) ?? '0') ?? 0;
          final bVer = int.tryParse(RegExp(r'v(\d+)').firstMatch(bName)?.group(1) ?? '0') ?? 0;
          if (aVer != bVer) return bVer.compareTo(aVer);
          final aLite = aName.contains('_lite') ? 1 : 0;
          final bLite = bName.contains('_lite') ? 1 : 0;
          return bLite.compareTo(aLite);
        });

        if (dbFiles.isNotEmpty) {
          dbPath = dbFiles.first.path;
        }
      }
    }

    final dbDir = await databaseFactory.getDatabasesPath();
    final targetDbFile = File(p.join(dbDir, 'german_dictionary.db'));
    if (dbPath != null && File(dbPath).existsSync()) {
      if (!targetDbFile.existsSync() || targetDbFile.lengthSync() != File(dbPath).lengthSync()) {
        await Directory(dbDir).create(recursive: true);
        await File(dbPath).copy(targetDbFile.path);
      }
    }

    await DictionaryService.resetForTesting();
    final dictService = DictionaryService();

    print('\n============================================================');
    print(' TAKT DART WORD INSPECTOR (Using Dart Services)');
    if (dbPath != null) {
      print(' Database:   ${p.basename(dbPath)}');
    }
    print(' Target Word: "$targetWord"');
    print('============================================================\n');

    final results = await dictService.lookupConsolidatedWord(targetWord);
    if (results.isEmpty) {
      print('No results found for "$targetWord" via DictionaryService.\n');
      return;
    }

    for (int i = 0; i < results.length; i++) {
      final w = results[i];
      final word = w['word']?.toString() ?? targetWord;
      final pos = w['pos']?.toString() ?? '-';
      final gender = w['gender']?.toString() ?? '-';
      final ipa = w['ipa']?.toString() ?? '-';
      final baseForm = w['base_form']?.toString() ?? '-';
      final freq = w['freq_rank'];
      final cefr = DictionaryService.getCefrLevel(freq);
      final source = w['sourceLabel'] ?? w['source'] ?? 'Unknown';
      final vClass = w['verb_class']?.toString();

      print('[${pos.toUpperCase()}] Sense #${i + 1}: $word');
      print('------------------------------------------------------------');
      print('  Word:          $word');
      print('  POS:           $pos');
      if (pos.toLowerCase() == 'noun' || (gender != '-' && gender.isNotEmpty)) {
        print('  Gender:        $gender');
      }
      print('  IPA:           $ipa');
      print('  Base Form:     $baseForm');
      print('  CEFR / Rank:   $cefr (${freq != null ? '#$freq' : 'N/A'})');
      print('  Data Source:   $source');

      if (pos.toLowerCase() == 'verb' || vClass != null) {
        final labelMap = {
          'weak': 'Regular (Schwach)',
          'strong': 'Irregular (Stark)',
          'mixed': 'Irregular (Gemischt)',
          'irregular': 'Irregular (Auxiliary / Hilfsverb)',
          'modal': 'Modal Verb',
        };
        final displayStrength = labelMap[vClass?.toLowerCase()] ?? (vClass ?? 'None / Regular');
        print('  Verb Strength: $displayStrength');
      }

      // Definitions
      final defs = (w['definitions'] as List?)?.whereType<String>().toList() ?? [];
      if (defs.isNotEmpty) {
        print('\n  Definitions (${defs.length}):');
        for (final d in defs) {
          print('    • $d');
        }
      }

      // Examples
      final examples = (w['examples'] as List?) ?? [];
      if (examples.isNotEmpty) {
        print('\n  Examples (${examples.length}):');
        for (final ex in examples) {
          if (ex is Map) {
            final de = ex['de']?.toString() ?? '';
            final en = ex['en']?.toString();
            final enSuffix = (en != null && en.isNotEmpty) ? ' ($en)' : '';
            print('    • $de$enSuffix');
          }
        }
      }

      // Forms
      final forms = (w['forms'] as List?) ?? [];
      if (forms.isNotEmpty) {
        print('\n  Forms & Inflections (${forms.length}):');
        for (final f in forms.take(15)) {
          if (f is Map) {
            print('    • ${f['form']} ${f['tags']}');
          }
        }
        if (forms.length > 15) {
          print('    ... and ${forms.length - 15} more forms');
        }
      }
      print('');
    }
  });
}
