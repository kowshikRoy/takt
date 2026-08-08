import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../config.dart';
import '../models/saved_word.dart';
import 'app_logger.dart';
import 'native_nlp_service.dart';
import 'ondevice_ai_service.dart';
import 'vocabulary_service.dart';

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  static Database? _database;
  static Completer<Database>? _dbCompleter;

  // Progress & State Notifiers for On-Demand Database Download UI
  final ValueNotifier<double> downloadProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> downloadErrorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> hasUpdateNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> latestVersionNotifier = ValueNotifier<String?>(null);

  final Map<String, String?> _imageUrlCache = {};

  factory DictionaryService() => _instance;

  @visibleForTesting
  static Future<void> resetForTesting() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    _dbCompleter = null;
  }

  DictionaryService._internal();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    
    if (_dbCompleter == null || _dbCompleter!.isCompleted) {
      _dbCompleter = Completer<Database>();
      _initDatabase().then((db) {
        _database = db;
        _dbCompleter!.complete(db);
      }).catchError((e) {
        _dbCompleter!.completeError(e);
      });
    }
    
    return _dbCompleter!.future;
  }

  static const String _dbFileName = "german_dictionary.db";

  /// Maps a frequency rank to its CEFR difficulty level (A1, A2, B1, B2, C1, C2)
  static String getCefrLevel(dynamic freqRaw, {String fallback = 'B1'}) {
    final rank = freqRaw != null ? int.tryParse(freqRaw.toString()) : null;
    if (rank == null || rank <= 0) return fallback;
    if (rank <= 600) return 'A1';
    if (rank <= 1600) return 'A2';
    if (rank <= 3800) return 'B1';
    if (rank <= 8500) return 'B2';
    if (rank <= 15000) return 'C1';
    return 'C2';
  }

  Future<String> _getDatabasePath() async {
    final dbDir = await getDatabasesPath();
    final newPath = join(dbDir, _dbFileName);
    final oldPath = join(dbDir, "german_dictionary_v3.db");

    if (!File(newPath).existsSync() && File(oldPath).existsSync()) {
      try {
        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }
        File(oldPath).renameSync(newPath);
      } catch (_) {
        try { if (File(oldPath).existsSync()) File(oldPath).deleteSync(); } catch (_) {}
      }
    }
    return newPath;
  }

  Future<Database> _initDatabase() async {
    final path = await _getDatabasePath();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final db = await openDatabase(path);
      await db.execute(
        'CREATE TABLE IF NOT EXISTS words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT, freq_rank INTEGER, custom_image_url TEXT, is_user_created INTEGER, definitions TEXT, examples TEXT);',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS examples (id INTEGER PRIMARY KEY, word_id INTEGER, de TEXT, en TEXT);',
      );
      await _ensureSchemaColumns(db);
      return db;
    }

    if (!File(path).existsSync()) {
      await _downloadDatabaseFile(path);
    }

    try {
      final db = await openDatabase(path);
      await db.rawQuery("SELECT count(*) FROM words LIMIT 1;");
      await _ensureSchemaColumns(db);
      return db;
    } catch (e) {
      AppLogger.error("Database open/verify failed: $e. Will re-download.", error: e, tag: 'DictionaryService');
      try { await deleteDatabase(path); } catch (_) {}
      await _downloadDatabaseFile(path);
      final db = await openDatabase(path);
      await _ensureSchemaColumns(db);
      return db;
    }
  }

  bool _hasCheckedColumns = false;
  bool _supportsBaseForm = false;
  bool _supportsFreqRank = false;

  Future<void> _ensureSchemaColumns(Database db) async {
    if (_hasCheckedColumns) return;
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery("PRAGMA table_info(words);");
      final colNames = columns.map((c) => c['name'].toString()).toSet();

      _supportsBaseForm = colNames.contains('base_form');
      _supportsFreqRank = colNames.contains('freq_rank');

      if (!_supportsBaseForm) {
        try {
          await db.execute("ALTER TABLE words ADD COLUMN base_form TEXT;");
          _supportsBaseForm = true;
        } catch (_) {}
      }
      if (!_supportsFreqRank) {
        try {
          await db.execute("ALTER TABLE words ADD COLUMN freq_rank INTEGER;");
          _supportsFreqRank = true;
        } catch (_) {}
      }
      if (!colNames.contains('verb_class')) {
        try {
          await db.execute("ALTER TABLE words ADD COLUMN verb_class TEXT;");
        } catch (_) {}
      }
      if (!colNames.contains('custom_image_url')) {
        try {
          await db.execute("ALTER TABLE words ADD COLUMN custom_image_url TEXT;");
        } catch (_) {}
      }
      if (!colNames.contains('is_user_created')) {
        try {
          await db.execute("ALTER TABLE words ADD COLUMN is_user_created INTEGER DEFAULT 0;");
        } catch (_) {}
      }
      _hasCheckedColumns = true;
    } catch (_) {}
  }

  Future<void> _downloadDatabaseFile(String path) async {
    if (_latestAssetDownloadUrl == null) {
      try {
        await checkForDatabaseUpdate();
      } catch (_) {}
    }

    final downloadUrl = _latestAssetDownloadUrl ??
        "https://github.com/kowshikRoy/takt/releases/latest/download/german_dictionary_v18_lite.db";
    AppLogger.debug("Downloading dictionary database on-demand from $downloadUrl...", tag: 'DictionaryService');
    
    isDownloadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;
    downloadErrorNotifier.value = null;

    try {
      final client = http.Client();
      Uri currentUri = Uri.parse(downloadUrl);
      http.StreamedResponse? response;

      // Automatically resolve HTTP redirects (e.g. GitHub Release -> AWS S3)
      for (int i = 0; i < 5; i++) {
        final request = http.Request('GET', currentUri);
        final res = await client.send(request);
        if (res.statusCode == 301 || res.statusCode == 302 || res.statusCode == 307 || res.statusCode == 308) {
          final location = res.headers['location'];
          if (location != null) {
            currentUri = Uri.parse(location);
            continue;
          }
        }
        response = res;
        break;
      }

      if (response == null || response.statusCode != 200) {
        throw Exception("Server returned HTTP status ${response?.statusCode}");
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final file = File(path);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          downloadProgressNotifier.value = downloadedBytes / contentLength;
        }
      }

      await sink.close();
      client.close();
      AppLogger.debug("Database downloaded successfully to $path.", tag: 'DictionaryService');
    } catch (e) {
      AppLogger.error("Error downloading database", error: e, tag: 'DictionaryService');
      downloadErrorNotifier.value = "Failed to download dictionary database: $e";
      rethrow;
    } finally {
      isDownloadingNotifier.value = false;
    }
  }

  int _parseVersionNumber(String verStr) {
    final clean = verStr.replaceAll(RegExp(r'[^\d.]'), '').trim();
    if (clean.isEmpty) return 0;
    final major = clean.split('.').first;
    return int.tryParse(major) ?? 0;
  }

  Future<String> getDatabaseVersion() async {
    try {
      final db = await database;
      if (db != null && db.isOpen) {
        final List<Map<String, dynamic>> res = await db.rawQuery("PRAGMA user_version;");
        int v = res.first['user_version'] as int? ?? 0;
        if (v > 0) return "v$v.0";
      }
      final path = await _getDatabasePath();
      if (await File(path).exists()) {
        final db = await openDatabase(path, readOnly: true);
        final List<Map<String, dynamic>> res = await db.rawQuery("PRAGMA user_version;");
        await db.close();
        int v = res.first['user_version'] as int? ?? 0;
        if (v > 0) return "v$v.0";
      }
      return "v0.0";
    } catch (_) {
      return "v0.0";
    }
  }

  Future<String> getDatabaseSizeFormatted() async {
    try {
      final path = await _getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        final mb = bytes / (1024 * 1024);
        return "${mb.toStringAsFixed(1)} MB";
      }
      return "0 MB";
    } catch (_) {
      return "Unknown";
    }
  }

  String? _latestAssetDownloadUrl;

  Future<void> checkForDatabaseUpdate() async {
    isCheckingNotifier.value = true;
    try {
      final currentVerStr = await getDatabaseVersion();
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/kowshikRoy/takt/releases/latest"),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'TaktApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tag = data['tag_name']?.toString() ?? '';
        latestVersionNotifier.value = tag;

        // Parse assets array to dynamically discover the latest .db asset URL
        final assets = (data['assets'] as List<dynamic>?) ?? [];
        for (var asset in assets) {
          final name = asset['name']?.toString() ?? '';
          final downloadUrl = asset['browser_download_url']?.toString();
          if (name.endsWith('.db') && downloadUrl != null) {
            _latestAssetDownloadUrl = downloadUrl;
            break;
          }
        }

        final currentNum = _parseVersionNumber(currentVerStr);
        final latestNum = _parseVersionNumber(tag);

        hasUpdateNotifier.value = currentNum > 0 && latestNum > currentNum;

        AppLogger.debug("DEBUG Check DB update: status=${response.statusCode}, current=$currentVerStr, latestTag=$tag, asset=$_latestAssetDownloadUrl, hasUpdate=${hasUpdateNotifier.value}", tag: 'DictionaryService');
      }
    } catch (e) {
      AppLogger.error("Check for DB update error", error: e, tag: 'DictionaryService');
    } finally {
      isCheckingNotifier.value = false;
    }
  }

  Future<void> redownloadDatabase() async {
    try {
      final path = await _getDatabasePath();
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }
      if (_dbCompleter != null) {
        _dbCompleter = null;
      }
      try { await deleteDatabase(path); } catch (_) {}
      await _downloadDatabaseFile(path);
      
      final db = await openDatabase(path);
      _database = db;
      await _ensureSchemaColumns(db);

      if (latestVersionNotifier.value != null) {
        final tagNum = _parseVersionNumber(latestVersionNotifier.value!);
        if (tagNum > 0) {
          try {
            await db.execute("PRAGMA user_version = $tagNum;");
          } catch (_) {}
        }
      }

      hasUpdateNotifier.value = false;
    } catch (e) {
      downloadErrorNotifier.value = "Failed to update database: $e";
      isDownloadingNotifier.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.isEmpty) return [];

    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        String sqlLike = '$query%';
        try {
          final results = await db.rawQuery('''
            SELECT w.id, w.word, w.pos, w.gender, w.ipa, w.base_form,
                   COALESCE(d.definition, d_base.definition) as definition 
            FROM words w
            LEFT JOIN definitions d ON w.id = d.word_id
            LEFT JOIN words w_base ON w.base_form = w_base.word
            LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
            WHERE w.word LIKE ?
            ORDER BY LENGTH(w.word) ASC, w.word ASC, w.id ASC
          ''', [sqlLike]);

          Map<String, Map<String, dynamic>> grouped = {};
          Map<String, int> lowestIdForPosKey = {};

          for (var r in results) {
            final id = r['id'] as int;
            final wStr = (r['word'] as String? ?? '').toLowerCase();
            final posStr = (r['pos'] as String? ?? '').toLowerCase();
            final key = "${wStr}_$posStr";

            if (!lowestIdForPosKey.containsKey(key)) {
              lowestIdForPosKey[key] = id;
              grouped[key] = Map<String, dynamic>.from(r);
            }
          }

          return grouped.values.take(20).toList();
        } catch (e) {
          AppLogger.error("Local SQLite Search error", error: e, tag: 'DictionaryService');
        }
      }
    }

    // Step 2: Live Consolidated Lookup (User DB -> Wiktionary -> NMT) with Auto-Caching
    try {
      final consolidated = await lookupConsolidatedWord(query);
      if (consolidated.isNotEmpty) {
        return consolidated;
      }
    } catch (e) {
      AppLogger.error("Consolidated search fallback error", error: e, tag: 'DictionaryService');
    }

    // Step 3: Web / API Fallback via OmniScribe REST API
    try {
      final backendUrl = Config.backendUrl;
      final uri = Uri.parse('$backendUrl/api/dictionary/search?q=${Uri.encodeComponent(query)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        if (results.isNotEmpty) return results;
      }
    } catch (e) {
      AppLogger.error("OmniScribe dictionary API search error", error: e, tag: 'DictionaryService');
    }

    // Step 4: Direct Google Translate NMT Fallback
    final onlineResult = await translateWordOnline(query);
    if (onlineResult != null) {
      return [onlineResult];
    }

    return [];
  }

  /// Real example sentences from the `examples` table (sourced from
  /// Wiktionary/Kaikki at DB-build time). Older cached DBs built before this
  /// table existed will throw "no such table" here — caught and treated as
  /// "no examples available" rather than crashing.
  Future<List<Map<String, String?>>> _getExamplesForWord(
    Database db,
    int wordId,
    String? baseForm,
  ) async {
    try {
      List<Map<String, dynamic>> rows = await db.query(
        'examples',
        columns: ['de', 'en'],
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      if (rows.isEmpty && baseForm != null && baseForm.isNotEmpty) {
        final baseRows = await db.query(
          'words',
          columns: ['id'],
          where: 'word = ? COLLATE NOCASE',
          whereArgs: [baseForm],
          limit: 1,
        );
        if (baseRows.isNotEmpty) {
          rows = await db.query(
            'examples',
            columns: ['de', 'en'],
            where: 'word_id = ?',
            whereArgs: [baseRows.first['id']],
          );
        }
      }

      return rows
          .map((e) => {'de': e['de'] as String?, 'en': e['en'] as String?})
          .where((e) => e['de'] != null && e['de']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String?>>> getExamplesForWord(String word) async {
    final clean = word.trim();
    if (clean.isEmpty) return [];
    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        final wordRes = await db.query(
          'words',
          columns: ['id', 'base_form'],
          where: 'word = ? COLLATE NOCASE',
          whereArgs: [clean],
        );
        if (wordRes.isNotEmpty) {
          final wordId = wordRes.first['id'] as int;
          final baseForm = wordRes.first['base_form'] as String?;
          return await _getExamplesForWord(db, wordId, baseForm);
        }
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getWordDetails(int wordId) async {
    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        final List<Map<String, dynamic>> wordRes = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
        if (wordRes.isNotEmpty) {
          final word = Map<String, dynamic>.from(wordRes.first);
          final List<Map<String, dynamic>> defRes = await db.query('definitions', where: 'word_id = ?', whereArgs: [wordId]);
          List<String> rawDefinitions = defRes.map((d) => d['definition'] as String).toList();
          
          List<String> definitions = await cleanAndResolveDefinitions(
            word: word['word'] as String? ?? '',
            rawDefinitions: rawDefinitions,
            baseForm: word['base_form'] as String?,
          );

          word['definitions'] = definitions;

          // If gender or verb_class is missing and base_form is present, resolve from base word
          if (word['base_form'] != null) {
            try {
              final baseRes = await db.query(
                'words',
                columns: ['gender', 'verb_class'],
                where: 'word = ? AND base_form IS NULL',
                whereArgs: [word['base_form']],
                limit: 1,
              );
              if (baseRes.isNotEmpty) {
                if ((word['gender'] == null || word['gender'].toString().isEmpty) && baseRes.first['gender'] != null) {
                  word['gender'] = baseRes.first['gender'];
                }
                if ((word['verb_class'] == null || word['verb_class'].toString().isEmpty) && baseRes.first['verb_class'] != null) {
                  word['verb_class'] = baseRes.first['verb_class'];
                }
              }
            } catch (_) {}
          }

          try {
            List<Map<String, dynamic>> formsRes = await db.rawQuery(
              'SELECT f.form, t.tags FROM forms f LEFT JOIN tags t ON f.tag_id = t.id WHERE f.word_id = ?',
              [wordId],
            );
            if (formsRes.isEmpty && word['base_form'] != null) {
              formsRes = await db.rawQuery(
                'SELECT f.form, t.tags FROM forms f LEFT JOIN tags t ON f.tag_id = t.id WHERE f.word_id = (SELECT id FROM words WHERE word = ? AND base_form IS NULL LIMIT 1)',
                [word['base_form']],
              );
            }
            word['forms'] = formsRes;
          } catch (_) {
            word['forms'] = [];
          }

          word['examples'] = await _getExamplesForWord(
            db,
            wordId,
            word['base_form'] as String?,
          );

          word['synonyms'] = [];
          word['antonyms'] = [];
          word['related'] = [];

          return word;
        }
      }
    }

    // Web / API Fallback via OmniScribe REST API
    try {
      final backendUrl = Config.backendUrl;
      final uri = Uri.parse('$backendUrl/api/dictionary/word/$wordId');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      AppLogger.error("OmniScribe getWordDetails API error", error: e, tag: 'DictionaryService');
    }

    return null;
  }

  /// Ultra-fast single-query word lookup for On-Device AI (<1ms per word)
  Future<List<Map<String, dynamic>>> lookupWordFast(String word) async {
    final db = await database;
    if (db == null) return [];
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return [];

    try {
      List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT w.id, w.word, w.pos, w.gender, w.ipa, w.base_form, w.freq_rank,
               COALESCE(d.definition, d_base.definition) as definition
        FROM words w
        LEFT JOIN definitions d ON w.id = d.word_id
        LEFT JOIN words w_base ON w.base_form = w_base.word
        LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
        WHERE w.word = ? COLLATE NOCASE
        ORDER BY w.id ASC
      ''', [cleanWord]);
      
      // If direct match not found, resolve inflected forms via forms table
      if (results.isEmpty) {
        try {
          results = await db.rawQuery('''
            SELECT w.id, w.word, w.pos, w.gender, w.ipa, w.base_form, w.freq_rank,
                   COALESCE(d.definition, d_base.definition) as definition
            FROM forms f
            JOIN words w ON f.word_id = w.id
            LEFT JOIN definitions d ON w.id = d.word_id
            LEFT JOIN words w_base ON w.base_form = w_base.word
            LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
            WHERE f.form = ? COLLATE NOCASE
            ORDER BY w.id ASC
          ''', [cleanWord]);
        } catch (_) {}
      }

      if (results.isEmpty) return [];
      return _groupDbResultsByPos(results, cleanWord);
    } catch (e) {
      AppLogger.error("Lookup fast error", error: e, tag: 'DictionaryService');
      return [];
    }
  }

  /// Fetches a representative photo for a word via German Wikipedia's
  /// page-summary API (free, no API key). Restricted to nouns: the headword
  /// maps reliably to a single Wikipedia article title for concrete nouns,
  /// but verbs/adjectives/function words are much more likely to collide
  /// with an unrelated article (e.g. a surname or place sharing the word),
  /// which would show a misleading image — better to show none than a
  /// wrong one, same reasoning as the example-sentence fix.
  Future<String?> getWordImageUrl(String word, {String? pos}) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return null;

    // A user-set custom image always wins, regardless of the POS
    // restriction below — that restriction only exists to keep the
    // *automatic* Wikipedia lookup from guessing wrong.
    final customUrl = await _getCustomImageUrl(cleanWord);
    if (customUrl != null && customUrl.isNotEmpty) return customUrl;

    final posLower = pos?.toLowerCase().trim() ?? '';
    if (posLower != 'noun' && posLower != 'n' && posLower != 'n.') {
      return null;
    }

    if (_imageUrlCache.containsKey(cleanWord)) {
      return _imageUrlCache[cleanWord];
    }

    try {
      final uri = Uri.parse(
        'https://de.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanWord)}',
      );
      final response = await http
          .get(
            uri,
            headers: {
              // Wikimedia asks API clients to identify themselves.
              'User-Agent': 'TaktApp/1.0 (https://github.com/kowshikRoy/takt)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // Disambiguation pages ("Bank" = bench/financial institution/etc.)
        // don't reliably point at one concept, so skip them.
        if (data is Map && data['type'] == 'disambiguation') {
          _imageUrlCache[cleanWord] = null;
          return null;
        }
        final thumbnail = data is Map ? data['thumbnail'] : null;
        var url = thumbnail is Map ? thumbnail['source'] as String? : null;

        // Wikipedia often illustrates species/general-topic articles with a
        // multi-photo montage (e.g. "Collage_of_Six_Cats...") as the infobox
        // image, which reads badly on a single-photo learner card. Wikidata's
        // P18 "image" property is curated to be one canonical photo per
        // concept, so prefer that when the article image is a montage.
        if (url != null && _isMontageImage(url)) {
          final qid = data is Map ? data['wikibase_item'] as String? : null;
          url = qid != null ? await _fetchWikidataImageUrl(qid) : null;
        }

        _imageUrlCache[cleanWord] = url;
        return url;
      }
    } catch (e) {
      AppLogger.error("Wikipedia image lookup error", error: e, tag: 'DictionaryService');
    }

    _imageUrlCache[cleanWord] = null;
    return null;
  }

  /// Resolves a Wikidata entity's P18 ("image") claim to a displayable URL.
  /// P18 stores a bare Commons filename, which then needs a second hop
  /// through the Commons imageinfo API to get a real thumbnail URL.
  Future<String?> _fetchWikidataImageUrl(String qid) async {
    try {
      // `origin=*` is required by the MediaWiki Action API to return CORS
      // headers for anonymous cross-origin requests — without it the call
      // is blocked outright in the browser (Flutter web).
      final uri = Uri.parse(
        'https://www.wikidata.org/w/api.php?action=wbgetclaims&entity=$qid&property=P18&format=json&origin=*',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TaktApp/1.0 (https://github.com/kowshikRoy/takt)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final claims = data is Map ? data['claims'] : null;
      final p18 = claims is Map ? claims['P18'] : null;
      if (p18 is! List || p18.isEmpty) return null;

      final first = p18.first;
      final mainsnak = first is Map ? first['mainsnak'] : null;
      final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
      final fileName = datavalue is Map ? datavalue['value'] as String? : null;
      if (fileName == null || fileName.isEmpty) return null;

      return await _fetchCommonsThumbUrl(fileName);
    } catch (e) {
      AppLogger.error("Wikidata P18 image lookup error", error: e, tag: 'DictionaryService');
      return null;
    }
  }

  /// Turns a bare Commons filename into a thumbnail URL on
  /// upload.wikimedia.org. Note this must NOT use commons.wikimedia.org's
  /// Special:FilePath redirect: that serves no CORS headers, so while it
  /// works in a plain <img> tag it fails on Flutter web, which fetches the
  /// image bytes over HTTP.
  Future<String?> _fetchCommonsThumbUrl(String fileName) async {
    try {
      final uri = Uri.parse(
        'https://commons.wikimedia.org/w/api.php?action=query'
        '&titles=${Uri.encodeComponent('File:$fileName')}'
        '&prop=imageinfo&iiprop=url&iiurlwidth=640&format=json&origin=*',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TaktApp/1.0 (https://github.com/kowshikRoy/takt)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final query = data is Map ? data['query'] : null;
      final pages = query is Map ? query['pages'] : null;
      if (pages is! Map || pages.isEmpty) return null;

      final page = pages.values.first;
      final imageInfo = page is Map ? page['imageinfo'] : null;
      if (imageInfo is! List || imageInfo.isEmpty) return null;

      final info = imageInfo.first;
      return info is Map ? info['thumburl'] as String? : null;
    } catch (e) {
      AppLogger.error("Commons thumbnail lookup error", error: e, tag: 'DictionaryService');
      return null;
    }
  }

  bool _isMontageImage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('collage') ||
        lower.contains('montage') ||
        lower.contains('composite');
  }

  /// Strip HTML tags and HTML entities for clean Wiktionary definition text
  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Caches a dynamically fetched fallback word (Wiktionary or NMT) directly into german_dictionary.db
  Future<int?> _cacheFetchedWordInDatabase({
    required String word,
    required String pos,
    String? gender,
    String? ipa,
    required List<String> definitions,
    List<Map<String, String?>> examples = const [],
  }) async {
    if (kIsWeb) return null;
    try {
      final db = await database;
      if (db == null) return null;

      final existing = await db.query(
        'words',
        columns: ['id'],
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [word],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }

      final int wordId = await db.insert('words', {
        'word': word,
        'pos': pos,
        'gender': gender,
        'ipa': ipa,
      });

      for (final def in definitions) {
        if (def.trim().isNotEmpty) {
          await db.insert('definitions', {
            'word_id': wordId,
            'definition': def.trim(),
          });
        }
      }

      for (final ex in examples) {
        final deText = ex['de']?.trim();
        if (deText != null && deText.isNotEmpty) {
          try {
            await db.insert('examples', {
              'word_id': wordId,
              'de': deText,
              'en': ex['en']?.trim(),
            });
          } catch (_) {}
        }
      }

      AppLogger.info("Cached dynamic word '$word' ($pos) with ${examples.length} examples in german_dictionary.db with ID $wordId", tag: 'DictionaryService');
      return wordId;
    } catch (e) {
      AppLogger.error("Failed to cache dynamic word in DB", error: e, tag: 'DictionaryService');
      return null;
    }
  }

  Future<String?> _getCustomImageUrl(String word) async {
    if (kIsWeb) return null;
    try {
      final db = await database;
      if (db == null) return null;
      final res = await db.query(
        'words',
        columns: ['custom_image_url'],
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [word],
        limit: 1,
      );
      if (res.isNotEmpty) {
        return res.first['custom_image_url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Saves a user's manual edits to a dictionary entry, or creates a brand
  /// new one if [word] doesn't exist yet (case-insensitive match). This is
  /// a "full replace" for definitions/examples — whatever list the edit
  /// form currently holds becomes the entry's complete list, rather than
  /// merging with what was there before, matching the edit UI's model of
  /// "this is the whole entry now."
  Future<int?> saveUserWordEdit({
    required String word,
    String? pos,
    String? gender,
    String? ipa,
    required List<String> definitions,
    List<Map<String, String?>> examples = const [],
    String? customImageUrl,
  }) async {
    if (kIsWeb) return null;
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return null;

    try {
      final db = await database;
      if (db == null) return null;

      final existing = await db.query(
        'words',
        columns: ['id'],
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [cleanWord],
        limit: 1,
      );

      int wordId;
      if (existing.isNotEmpty) {
        wordId = existing.first['id'] as int;
        await db.update(
          'words',
          {
            'pos': pos,
            'gender': gender,
            'ipa': ipa,
            'custom_image_url': customImageUrl,
          },
          where: 'id = ?',
          whereArgs: [wordId],
        );
      } else {
        wordId = await db.insert('words', {
          'word': cleanWord,
          'pos': pos,
          'gender': gender,
          'ipa': ipa,
          'custom_image_url': customImageUrl,
          'is_user_created': 1,
        });
      }

      await db.delete(
        'definitions',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      for (final def in definitions) {
        final trimmed = def.trim();
        if (trimmed.isNotEmpty) {
          await db.insert('definitions', {
            'word_id': wordId,
            'definition': trimmed,
          });
        }
      }

      await db.delete('examples', where: 'word_id = ?', whereArgs: [wordId]);
      for (final ex in examples) {
        final de = ex['de']?.trim();
        if (de != null && de.isNotEmpty) {
          await db.insert('examples', {
            'word_id': wordId,
            'de': de,
            'en': ex['en']?.trim(),
          });
        }
      }

      _imageUrlCache.remove(cleanWord);
      AppLogger.info(
        "Saved user edit for word '$cleanWord' (id $wordId)",
        tag: 'DictionaryService',
      );
      return wordId;
    } catch (e) {
      AppLogger.error(
        "Failed to save user word edit",
        error: e,
        tag: 'DictionaryService',
      );
      return null;
    }
  }

  static String inferGender(String wordStr, {String? rawGender, String? pos}) {
    if (rawGender != null && rawGender.trim().isNotEmpty) {
      final g = rawGender.trim().toLowerCase();
      if (g == 'masculine' || g == 'm') return 'm';
      if (g == 'feminine' || g == 'f') return 'f';
      if (g == 'neuter' || g == 'n') return 'n';
    }

    final lower = wordStr.trim().toLowerCase();
    
    if (lower.endsWith('schaft') ||
        lower.endsWith('ung') ||
        lower.endsWith('heit') ||
        lower.endsWith('keit') ||
        lower.endsWith('tät') ||
        lower.endsWith('tion') ||
        lower.endsWith('ei') ||
        lower.endsWith('in') ||
        lower.endsWith('ik')) {
      return 'f';
    }
    if (lower.endsWith('chen') ||
        lower.endsWith('lein') ||
        lower.endsWith('tum') ||
        lower.endsWith('ment') ||
        lower.endsWith('um')) {
      return 'n';
    }
    if (lower.endsWith('ismus') || lower.endsWith('ling') || lower.endsWith('or') || lower.endsWith('ist')) {
      return 'm';
    }

    return '';
  }

  String _inferGenderIfNull(String wordStr, String? rawGender, String? pos) =>
      inferGender(wordStr, rawGender: rawGender, pos: pos);

  /// Wiktionary REST API Fallback (Fetches definitions, Part of Speech, Gender, IPA & example sentences)
  /// Normalizes part of speech strings into standardized canonical identifiers
  static String normalizePos(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final lower = raw.trim().toLowerCase();
    if (lower.contains('pron') || lower.contains('pronomen')) return 'pron';
    if (lower.contains('adv') || lower.contains('adverb')) return 'adv';
    if (lower.contains('adj') || lower.contains('adjektiv')) return 'adj';
    if (lower.contains('noun') || lower == 'n' || lower.contains('substantiv') || lower.contains('nomen')) return 'noun';
    if (lower.contains('verb') || lower == 'v') return 'verb';
    if (lower.contains('prep') || lower.contains('präposition') || lower.contains('praeposition')) return 'prep';
    if (lower.contains('conj') || lower.contains('konjunktion')) return 'conj';
    if (lower.contains('interj') || lower.contains('interjektion')) return 'interj';
    if (lower.contains('num') || lower.contains('numeral') || lower.contains('zahlwort')) return 'num';
    if (lower.contains('phrase') || lower.contains('idiom') || lower.contains('redewendung')) return 'phrase';
    return lower;
  }

  List<Map<String, dynamic>> _groupDbResultsByPos(List<Map<String, dynamic>> results, String cleanWord) {
    Map<String, Map<String, dynamic>> groupedByPosKey = {};
    Map<String, int> lowestIdForPosKey = {};

    for (var r in results) {
      final id = r['id'] as int;
      final wStr = (r['word'] as String? ?? cleanWord).toLowerCase();
      final posStr = (r['pos'] as String? ?? '').toLowerCase();
      final key = "${wStr}_$posStr";

      if (!lowestIdForPosKey.containsKey(key)) {
        lowestIdForPosKey[key] = id;
        groupedByPosKey[key] = {
          'id': id,
          'word': r['word'],
          'pos': r['pos'],
          'gender': r['gender'],
          'ipa': r['ipa'],
          'base_form': r['base_form'],
          'verb_class': r['verb_class'],
          'freq_rank': r['freq_rank'] is int ? r['freq_rank'] as int : null,
          'definitions': <String>[],
        };
      }

      if (r['definition'] != null && r['definition'].toString().trim().isNotEmpty) {
        final defs = groupedByPosKey[key]!['definitions'] as List<String>;
        final defStr = r['definition'].toString().trim();
        if (!defs.contains(defStr)) {
          defs.add(defStr);
        }
      }
    }

    final list = groupedByPosKey.values.toList();
    list.sort((a, b) {
      // 1. Prioritize senses that actually have definitions over empty stubs
      final aHasDefs = (a['definitions'] as List?)?.isNotEmpty ?? false;
      final bHasDefs = (b['definitions'] as List?)?.isNotEmpty ?? false;
      if (aHasDefs && !bHasDefs) return -1;
      if (!aHasDefs && bHasDefs) return 1;

      // 2. Prioritize exact case match
      final aWord = a['word']?.toString() ?? '';
      final bWord = b['word']?.toString() ?? '';
      final aExact = aWord == cleanWord;
      final bExact = bWord == cleanWord;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      // 3. If query starts with uppercase or noun, prioritize Noun over verb stubs
      final isCapitalized = cleanWord.isNotEmpty &&
          cleanWord[0] == cleanWord[0].toUpperCase() &&
          cleanWord[0] != cleanWord[0].toLowerCase();
      if (isCapitalized) {
        final aIsNoun = normalizePos(a['pos']?.toString()) == 'noun';
        final bIsNoun = normalizePos(b['pos']?.toString()) == 'noun';
        if (aIsNoun && !bIsNoun) return -1;
        if (!aIsNoun && bIsNoun) return 1;
      }

      // 4. Prioritize headwords over inflected forms
      final aIsHeadword = a['base_form'] == null || a['base_form'] == aWord;
      final bIsHeadword = b['base_form'] == null || b['base_form'] == bWord;
      if (aIsHeadword && !bIsHeadword) return -1;
      if (!aIsHeadword && bIsHeadword) return 1;

      // 5. Frequency rank
      final aRank = a['freq_rank'] as int? ?? 999999;
      final bRank = b['freq_rank'] as int? ?? 999999;
      return aRank.compareTo(bRank);
    });

    return list;
  }

  Future<Map<String, dynamic>?> fetchWiktionaryFallback(String word, {String? targetPos}) async {
    final cleanWord = word.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanWord.isEmpty) return null;

    final normTargetPos = normalizePos(targetPos);

    // German words (especially nouns) on Wiktionary require exact casing (e.g. 'Buddhismus' not 'buddhismus').
    final candidateWords = <String>[cleanWord];
    final capitalized = cleanWord.isNotEmpty ? cleanWord[0].toUpperCase() + cleanWord.substring(1) : '';
    if (capitalized.isNotEmpty && !candidateWords.contains(capitalized)) {
      candidateWords.add(capitalized);
    }
    final lower = cleanWord.toLowerCase();
    if (!candidateWords.contains(lower)) {
      candidateWords.add(lower);
    }

    for (final candidate in candidateWords) {
      try {
        final uri = Uri.parse(
          'https://api.wiktapi.dev/v1/en/word/${Uri.encodeComponent(candidate)}?lang=de'
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          final List<dynamic>? entries = data['entries'] as List<dynamic>?;
          if (entries != null && entries.isNotEmpty) {
            String pos = normTargetPos.isNotEmpty ? normTargetPos : 'word';
            String? gender;
            String? ipa;
            String? audioUrl;
            List<String> definitions = [];
            List<Map<String, String?>> examples = [];
            List<Map<String, dynamic>> forms = [];

            for (final entry in entries) {
              if (entry is Map<String, dynamic>) {
                // Extract sounds (IPA & Native Audio MP3)
                final sounds = entry['sounds'] as List<dynamic>?;
                if (sounds != null) {
                  for (final s in sounds) {
                    if (s is Map<String, dynamic>) {
                      if (ipa == null && s['ipa'] != null) {
                        ipa = s['ipa'].toString();
                      }
                      if (audioUrl == null && s['mp3_url'] != null) {
                        audioUrl = s['mp3_url'].toString();
                      }
                    }
                  }
                }

                // Extract inflection forms
                final formList = entry['forms'] as List<dynamic>?;
                if (formList != null) {
                  for (final f in formList) {
                    if (f is Map<String, dynamic> && f['form'] != null) {
                      forms.add(Map<String, dynamic>.from(f));
                    }
                  }
                }

                // Identify Part of Speech
                final rawEntryPos = entry['pos']?.toString().toLowerCase();
                if (rawEntryPos != null && rawEntryPos.isNotEmpty) {
                  final entryNormPos = normalizePos(rawEntryPos);
                  if (pos == 'word' || pos.isEmpty) {
                    pos = entryNormPos;
                  }
                }

                final senses = entry['senses'] as List<dynamic>?;
                if (senses != null) {
                  for (final sense in senses) {
                    if (sense is Map<String, dynamic>) {
                      // Check tags for grammatical gender
                      final tags = (sense['tags'] as List<dynamic>?)?.map((t) => t.toString().toLowerCase()).toList() ?? [];
                      if (gender == null) {
                        if (tags.contains('feminine')) {
                          gender = 'f';
                          if (pos == 'word') pos = 'noun';
                        } else if (tags.contains('masculine')) {
                          gender = 'm';
                          if (pos == 'word') pos = 'noun';
                        } else if (tags.contains('neuter')) {
                          gender = 'n';
                          if (pos == 'word') pos = 'noun';
                        }
                      }

                      // Check categories for POS fallback
                      final categories = (sense['categories'] as List<dynamic>?)?.map((c) => c.toString().toLowerCase()).toList() ?? [];
                      if (pos == 'word') {
                        if (categories.any((c) => c.contains('german nouns'))) {
                          pos = 'noun';
                        } else if (categories.any((c) => c.contains('german verbs'))) {
                          pos = 'verb';
                        } else if (categories.any((c) => c.contains('german adjectives'))) {
                          pos = 'adj';
                        } else if (categories.any((c) => c.contains('german adverbs'))) {
                          pos = 'adv';
                        }
                      }

                      // Extract clean English definitions (glosses)
                      final glosses = sense['glosses'] as List<dynamic>?;
                      if (glosses != null) {
                        for (final g in glosses) {
                          final gStr = g.toString().trim();
                          if (gStr.isNotEmpty && !definitions.contains(gStr)) {
                            definitions.add(gStr);
                          }
                        }
                      }

                      // Extract contextual usage examples
                      final senseExamples = sense['examples'] as List<dynamic>?;
                      if (senseExamples != null) {
                        for (final ex in senseExamples) {
                          if (ex is Map<String, dynamic>) {
                            final text = ex['text']?.toString().trim();
                            final trans = ex['translation']?.toString().trim() ?? ex['english']?.toString().trim();
                            if (text != null && text.isNotEmpty && !examples.any((e) => e['de'] == text)) {
                              examples.add({'de': text, 'en': trans});
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            final resolvedWord = (pos == 'noun' && candidate.isNotEmpty)
                ? candidate[0].toUpperCase() + candidate.substring(1)
                : candidate;

            if (gender == null && pos == 'noun') {
              final inferred = _inferGenderIfNull(resolvedWord, null, pos);
              if (inferred.isNotEmpty) gender = inferred;
            }

            if (definitions.isNotEmpty) {
              final int? cachedId = await _cacheFetchedWordInDatabase(
                word: resolvedWord,
                pos: pos,
                gender: gender,
                definitions: definitions,
                examples: examples,
              );

              // Auto-save into My Library (VocabularyService) as wiktionary_fetched
              try {
                final vocabService = VocabularyService();
                final existing = await vocabService.getSavedWordByWord(resolvedWord);
                if (existing == null) {
                  final newSaved = SavedWord(
                    id: resolvedWord.toLowerCase().trim(),
                    word: resolvedWord,
                    baseForm: resolvedWord,
                    pos: pos,
                    gender: gender,
                    primaryDefinition: definitions.first,
                    definitions: definitions,
                    ipa: ipa,
                    source: 'wiktionary_fetched',
                    category: VocabCategory.learning,
                  );
                  await vocabService.upsertWord(newSaved, notify: false);
                }
              } catch (_) {}

              return {
                'id': cachedId ?? -1,
                'word': resolvedWord,
                'pos': pos,
                'gender': gender,
                'ipa': ipa,
                'audioUrl': audioUrl,
                'freq_rank': null,
                'definitions': definitions,
                'forms': forms,
                'examples': examples,
                'synonyms': <String>[],
                'antonyms': <String>[],
                'related': <String>[],
                'source': 'wiktionary_fetched',
                'sourceLabel': 'Wiktionary',
                'isWiktionaryFallback': true,
              };
            }
          }
        }
      } catch (e) {
        AppLogger.error("WiktAPI fallback error for candidate '$candidate'", error: e, tag: 'DictionaryService');
      }
    }

    return null;
  }

  /// Direct client-side Google Translate NMT Fallback (0 Backend Server Required)
  Future<Map<String, dynamic>?> translateWordOnline(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=de&tl=en&dt=t&q=${Uri.encodeComponent(cleanWord)}'
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty && data[0] is List && (data[0] as List).isNotEmpty) {
          final translatedText = data[0][0][0] as String?;
          if (translatedText != null &&
              translatedText.isNotEmpty &&
              translatedText.toLowerCase() != cleanWord.toLowerCase()) {
            return {
              'id': -1,
              'word': cleanWord,
              'pos': 'word',
              'gender': null,
              'ipa': null,
              'freq_rank': null,
              'definitions': [translatedText],
              'forms': <Map<String, dynamic>>[],
              'examples': <Map<String, String?>>[],
              'synonyms': <String>[],
              'antonyms': <String>[],
              'related': <String>[],
              'isNmtTranslation': true,
            };
          }
        }
      }
    } catch (e) {
      AppLogger.error("Direct Google Translate NMT fallback error", error: e, tag: 'DictionaryService');
    }
    return null;
  }

  /// Translates a full sentence/phrase using On-Device ML Kit with Online NMT Fallback
  Future<String> translateSentence(
    String text, {
    String sourceLang = 'de',
    String targetLang = 'en',
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';

    // 1. Try On-Device ML Kit Translator first (fast offline)
    try {
      final onDeviceResult = await OnDeviceAIService().translateText(cleanText);
      if (onDeviceResult.isNotEmpty &&
          onDeviceResult.trim().toLowerCase() != cleanText.toLowerCase()) {
        return onDeviceResult.trim();
      }
    } catch (_) {}

    // 2. Direct client-side Google Translate NMT (multi-segment capable)
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(cleanText)}'
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty && data[0] is List) {
          final segments = data[0] as List;
          final buffer = StringBuffer();
          for (final seg in segments) {
            if (seg is List && seg.isNotEmpty && seg[0] is String) {
              buffer.write(seg[0]);
            }
          }
          final translated = buffer.toString().trim();
          if (translated.isNotEmpty) {
            return translated;
          }
        }
      }
    } catch (e) {
      AppLogger.error("translateSentence NMT error", error: e, tag: 'DictionaryService');
    }

    return cleanText;
  }

  Future<Map<String, dynamic>?> lookupWord(String word, {String? targetPos}) async {
    final cleanWord = word.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanWord.isEmpty) return null;

    final consolidated = await lookupConsolidatedWord(cleanWord, pos: targetPos);
    if (consolidated.isNotEmpty) {
      return consolidated.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> lookupWordAllPOS(String word) async {
    final db = await database;
    if (db == null) return [];
    final clean = word.trim();
    if (clean.isEmpty) return [];

    try {
      List<Map<String, dynamic>> results = [];
      try {
        results = await db.rawQuery('''
          SELECT w.id, w.word, w.pos, COALESCE(w.gender, w_base.gender) as gender,
                 w.ipa, COALESCE(w.base_form, w_base.word) as base_form,
                 COALESCE(w.verb_class, w_base.verb_class) as verb_class,
                 w.freq_rank,
                 COALESCE(d.definition, d_base.definition) as definition
          FROM words w
          LEFT JOIN definitions d ON w.id = d.word_id
          LEFT JOIN words w_base ON w.base_form = w_base.word
          LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
          WHERE w.word = ? COLLATE NOCASE OR w.base_form = ? COLLATE NOCASE
          ORDER BY LENGTH(w.word) ASC, w.id ASC
        ''', [clean, clean]);
      } catch (_) {
        results = await db.rawQuery('''
          SELECT w.id, w.word, w.pos, w.gender, w.ipa, w.verb_class, w.freq_rank, d.definition
          FROM words w
          LEFT JOIN definitions d ON w.id = d.word_id
          WHERE w.word = ? COLLATE NOCASE
          ORDER BY LENGTH(w.word) ASC, w.id ASC
        ''', [clean]);
      }
      if (results.isEmpty) {
        final onlineResult = await lookupWord(clean);
        if (onlineResult != null) {
          final String def = onlineResult['definition'] ??
              ((onlineResult['definitions'] as List?)?.firstOrNull?.toString() ?? '');
          final String pos = onlineResult['pos']?.toString() ?? 'word';
          return [
            {
              'id': onlineResult['id'] ?? -1,
              'word': clean,
              'pos': pos,
              'gender': onlineResult['gender'],
              'ipa': onlineResult['ipa'],
              'base_form': clean,
              'freq_rank': onlineResult['freq_rank'] is int ? onlineResult['freq_rank'] as int : null,
              'definition': def,
              'definitions': onlineResult['definitions'] ?? [def],
              'isWiktionaryFallback': onlineResult['isWiktionaryFallback'] ?? false,
              'isNmtTranslation': onlineResult['isNmtTranslation'] ?? false,
            }
          ];
        }
        return [];
      }

      return _groupDbResultsByPos(results, clean);
    } catch (e) {
      AppLogger.error("Lookup all POS error", error: e, tag: 'DictionaryService');
      return [];
    }
  }

  Future<Map<String, String>> getGendersForWords(List<String> words) async {
    final db = await database;
    if (db == null || words.isEmpty) return {};

    try {
      final Set<String> cleanWords = words.map((w) => w.trim()).where((w) => w.isNotEmpty).toSet();
      if (cleanWords.isEmpty) return {};

      final wordList = cleanWords.toList();
      String placeholders = List.filled(wordList.length, '?').join(',');

      List<Map<String, dynamic>> results = [];
      try {
        results = await db.rawQuery('''
          SELECT w.word, w.base_form, COALESCE(w.gender, w_base.gender) as gender
          FROM words w
          LEFT JOIN words w_base ON w.base_form = w_base.word
          WHERE w.word COLLATE NOCASE IN ($placeholders)
            AND COALESCE(w.gender, w_base.gender) IS NOT NULL
        ''', wordList);
      } catch (_) {
        results = await db.query(
          'words',
          columns: ['word', 'gender'],
          where: 'word COLLATE NOCASE IN ($placeholders) AND gender IS NOT NULL',
          whereArgs: wordList,
        );
      }

      Map<String, String> genderMap = {};
      for (var row in results) {
        if (row['gender'] != null) {
          final g = row['gender'].toString().toLowerCase().trim();
          if (g.isEmpty) continue;

          if (row['word'] != null) {
            final w = row['word'].toString();
            if (!genderMap.containsKey(w) || (genderMap[w] == 'n' && (g == 'm' || g == 'f'))) {
              genderMap[w] = g;
            }
            final lower = w.toLowerCase();
            if (!genderMap.containsKey(lower) || (genderMap[lower] == 'n' && (g == 'm' || g == 'f'))) {
              genderMap[lower] = g;
            }
          }
          if (row.containsKey('base_form') && row['base_form'] != null) {
            final bf = row['base_form'].toString();
            if (!genderMap.containsKey(bf) || (genderMap[bf] == 'n' && (g == 'm' || g == 'f'))) {
              genderMap[bf] = g;
            }
            final lowerBf = bf.toLowerCase();
            if (!genderMap.containsKey(lowerBf) || (genderMap[lowerBf] == 'n' && (g == 'm' || g == 'f'))) {
              genderMap[lowerBf] = g;
            }
          }
        }
      }

      // Map inflected/plural query words back to their resolved singular gender (e.g. Lehren -> Lehre -> die/f)
      for (var word in wordList) {
        final lower = word.toLowerCase();
        if (genderMap.containsKey(lower)) {
          genderMap[word] = genderMap[lower]!;
          continue;
        }

        if (lower.endsWith('en') && lower.length > 3) {
          final stem = lower.substring(0, lower.length - 2);
          if (genderMap.containsKey('${stem}e')) {
            genderMap[lower] = genderMap['${stem}e']!;
            genderMap[word] = genderMap['${stem}e']!;
          } else if (genderMap.containsKey(stem)) {
            genderMap[lower] = genderMap[stem]!;
            genderMap[word] = genderMap[stem]!;
          }
        } else if (lower.endsWith('n') && lower.length > 3) {
          final stem = lower.substring(0, lower.length - 1);
          if (genderMap.containsKey(stem)) {
            genderMap[lower] = genderMap[stem]!;
            genderMap[word] = genderMap[stem]!;
          }
        } else if (lower.endsWith('e') && lower.length > 3) {
          final stem = lower.substring(0, lower.length - 1);
          if (genderMap.containsKey(stem)) {
            genderMap[lower] = genderMap[stem]!;
            genderMap[word] = genderMap[stem]!;
          }
        }
      }

      return genderMap;

    } catch (e) {
      AppLogger.error("Batch gender lookup error", error: e, tag: 'DictionaryService');
      return {};
    }
  }

  static const Set<String> _separablePrefixes = {
    'an', 'auf', 'aus', 'bei', 'ein', 'mit', 'nach', 'vor', 'zu', 'zurück', 'ab', 'durch', 'über', 'um', 'unter', 'weg', 'weiter'
  };

  static const Set<String> _copulaVerbs = {
    'bin', 'bist', 'ist', 'sind', 'seid', 'war', 'warst', 'waren', 'wart', 'sei',
    'wird', 'wirst', 'werden', 'werdet', 'wurde', 'wurdest', 'wurden', 'wurdet',
  };

  /// Guesses whether [cleanWord] is used as an adjective at its position in
  /// [contextSentence]: attributive (directly before a capitalized noun) or
  /// predicate (after a copula verb, at the end of its clause).
  String? _guessAdjOrVerbPos(String cleanWord, String contextSentence) {
    final rawTokens = contextSentence.trim().split(RegExp(r'\s+'));
    final lowerTokens = rawTokens
        .map((t) => t.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').toLowerCase())
        .toList();
    final idx = lowerTokens.indexOf(cleanWord.toLowerCase());
    if (idx == -1) return null;

    final tappedRaw = rawTokens[idx];
    final nextRaw = idx + 1 < rawTokens.length ? rawTokens[idx + 1] : '';
    final nextClean = nextRaw.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '');
    final prevLower = idx > 0 ? lowerTokens[idx - 1] : '';

    final followedByNoun = nextClean.isNotEmpty && nextClean[0] == nextClean[0].toUpperCase();
    if (followedByNoun) return 'adj';

    final tappedEndsClause = RegExp(r'[.,!?;]$').hasMatch(tappedRaw.trim());
    final endsClause = nextClean.isEmpty || RegExp(r'^[.,!?;]').hasMatch(nextRaw.trim()) || tappedEndsClause;
    if (_copulaVerbs.contains(prevLower) && endsClause) return 'adj';

    return null;
  }

  /// Performs context-aware word lookup with separable verb re-assembly & gender/POS disambiguation
  Future<List<Map<String, dynamic>>> lookupContextualWord(String word, {String? contextSentence}) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    if (cleanWord.isEmpty) return [];

    // 1. Try separable verb re-assembly if sentence is provided
    if (contextSentence != null && contextSentence.isNotEmpty) {
      final tokens = contextSentence
          .replaceAll(RegExp(r'[^\wäöüÄÖÜß\s]'), '')
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isNotEmpty) {
        String? matchedPrefix;
        for (int i = tokens.length - 1; i >= (tokens.length - 3).clamp(0, tokens.length - 1); i--) {
          if (_separablePrefixes.contains(tokens[i])) {
            matchedPrefix = tokens[i];
            break;
          }
        }

        if (matchedPrefix != null && matchedPrefix != cleanWord.toLowerCase()) {
          final baseDetails = await lookupWordAllPOS(cleanWord);
          String candidateLemma = cleanWord;
          if (baseDetails.isNotEmpty && baseDetails.first['base_form'] != null) {
            candidateLemma = baseDetails.first['base_form'].toString();
          }

          final compoundWord = "$matchedPrefix$candidateLemma".toLowerCase();
          final compoundDetails = await lookupWordAllPOS(compoundWord);

          if (compoundDetails.isNotEmpty) {
            List<Map<String, dynamic>> enriched = [];
            for (var detail in compoundDetails) {
              final Map<String, dynamic> mutableDetail = Map<String, dynamic>.from(detail);
              mutableDetail['contextNote'] = "Reassembled separable verb ($matchedPrefix...$candidateLemma)";
              enriched.add(mutableDetail);
            }
            return enriched;
          }
        }
      }
    }

    // 2. Fall back to standard lookup for all POS
    final results = await lookupWordAllPOS(cleanWord);
    if (results.isEmpty) return [];

    final List<Map<String, dynamic>> working = List<Map<String, dynamic>>.from(results);

    // 3. Native OpenNLP (Android) / NLTagger (iOS) POS Tagging for Context Sentence
    if (contextSentence != null && contextSentence.trim().isNotEmpty && working.length > 1) {
      try {
        final tagged = await NativeNlpService().getTaggedTokens(contextSentence);
        if (tagged.isNotEmpty) {
          final cleanLower = cleanWord.toLowerCase();
          final match = tagged.firstWhere(
            (t) => (t['token'] ?? '').replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').toLowerCase() == cleanLower,
            orElse: () => {},
          );
          final rawPos = match['pos']?.toLowerCase();
          if (rawPos != null && rawPos.isNotEmpty) {
            final normTag = normalizePos(rawPos);
            if (normTag.isNotEmpty && normTag != 'unknown' && normTag != 'word') {
              working.sort((a, b) {
                final aPos = normalizePos(a['pos']?.toString());
                final bPos = normalizePos(b['pos']?.toString());
                if (aPos == normTag && bPos != normTag) return -1;
                if (bPos == normTag && aPos != normTag) return 1;
                return 0;
              });
              return working;
            }
          }
        }
      } catch (_) {}
    }

    // 4. Preceding Article / Determiner -> check if word is Adjective modifying a Noun vs. the Noun itself
    if (contextSentence != null && working.length > 1) {
      final rawTokens = contextSentence.trim().split(RegExp(r'\s+'));
      final lowerTokens = rawTokens
          .map((t) => t.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').toLowerCase())
          .toList();
      final idx = lowerTokens.indexOf(cleanWord.toLowerCase());

      if (idx != -1) {
        final nextRaw = idx + 1 < rawTokens.length ? rawTokens[idx + 1] : '';
        final nextClean = nextRaw.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '');
        final followedByCapitalizedNoun = nextClean.isNotEmpty &&
            nextClean[0] == nextClean[0].toUpperCase() &&
            nextClean[0] != nextClean[0].toLowerCase();

        final prevLower = idx > 0 ? lowerTokens[idx - 1] : '';
        const articlesAndDeterminers = {
          'der', 'die', 'das', 'den', 'dem', 'des',
          'ein', 'eine', 'einen', 'einem', 'einer', 'eines',
          'kein', 'keine', 'keinen', 'keinem', 'keiner', 'keines',
          'mein', 'meine', 'meinen', 'meinem', 'meiner',
          'dein', 'deine', 'deinen', 'deinem', 'deiner',
          'sein', 'seine', 'seinen', 'seinem', 'seiner',
          'ihr', 'ihre', 'ihren', 'ihrem', 'ihrer',
          'unser', 'unsere', 'unseren', 'unserem', 'unserer',
          'euer', 'eure', 'euren', 'eurem', 'eurer',
          'am', 'im', 'vom', 'zum', 'zur'
        };
        final isPrecededByArticle = articlesAndDeterminers.contains(prevLower);

        if (isPrecededByArticle && followedByCapitalizedNoun) {
          // Attributive Adjective before a Noun (e.g. "der kleine Mann") -> Prioritize ADJ over Noun!
          working.sort((a, b) {
            final aIsAdj = normalizePos(a['pos']?.toString()) == 'adj';
            final bIsAdj = normalizePos(b['pos']?.toString()) == 'adj';
            if (aIsAdj && !bIsAdj) return -1;
            if (!aIsAdj && bIsAdj) return 1;
            return 0;
          });
        } else if (isPrecededByArticle && !followedByCapitalizedNoun) {
          // Preceded by Article and directly heads the noun phrase (e.g. "der Mann") -> Prioritize Noun!
          working.sort((a, b) {
            final aIsNoun = normalizePos(a['pos']?.toString()) == 'noun';
            final bIsNoun = normalizePos(b['pos']?.toString()) == 'noun';
            if (aIsNoun && !bIsNoun) return -1;
            if (!aIsNoun && bIsNoun) return 1;
            return 0;
          });
        }
      }
    }

    // 4. Gender Disambiguation if sentence contains articles
    if (contextSentence != null && working.length > 1) {
      final lowerSentence = contextSentence.toLowerCase();
      String? expectedGender;
      if (lowerSentence.contains(RegExp(r'\b(der|den|dem|des)\b'))) {
        expectedGender = 'masculine';
      } else if (lowerSentence.contains(RegExp(r'\b(die|einer)\b'))) {
        expectedGender = 'feminine';
      } else if (lowerSentence.contains(RegExp(r'\b(das|einem|eines)\b'))) {
        expectedGender = 'neuter';
      }

      if (expectedGender != null) {
        working.sort((a, b) {
          final gA = (a['gender'] as String?)?.toLowerCase();
          final gB = (b['gender'] as String?)?.toLowerCase();
          if (gA == expectedGender || (gA != null && gA.startsWith(expectedGender![0]))) return -1;
          if (gB == expectedGender || (gB != null && gB.startsWith(expectedGender![0]))) return 1;
          return 0;
        });
      }
    }

    // 4. Verb vs. Adjective disambiguation via word order context
    if (contextSentence != null && working.length > 1) {
      final hasVerb = working.any((r) => (r['pos'] as String?)?.toLowerCase() == 'verb');
      final hasAdj = working.any((r) => (r['pos'] as String?)?.toLowerCase() == 'adj');
      if (hasVerb && hasAdj) {
        final preferredPos = _guessAdjOrVerbPos(cleanWord, contextSentence);
        if (preferredPos != null) {
          working.sort((a, b) {
            final pA = (a['pos'] as String?)?.toLowerCase();
            final pB = (b['pos'] as String?)?.toLowerCase();
            if (pA == preferredPos && pB != preferredPos) return -1;
            if (pB == preferredPos && pA != preferredPos) return 1;
            return 0;
          });
        }
      }
    }

    return working;
  }

  /// Consolidated word meaning resolution hierarchy:
  /// 1. User Database (`VocabularyService` saved words matching word & POS)
  /// 2. German Dictionary Database (`dict.db` SQLite matching word & POS)
  /// 3. Wiktionary REST API (matching word & POS with auto-caching)
  /// 4. Online NMT translation (safety net)
  ///
  /// Supports single words, phrases with spaces (e.g. "Platz nehmen", "es gibt"),
  /// and disambiguates multiple meanings across Parts of Speech (noun, verb, adj, etc.).
  Future<List<Map<String, dynamic>>> lookupConsolidatedWord(
    String word, {
    String? pos,
    String? contextSentence,
  }) async {
    final cleanWord = word.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanWord.isEmpty) return [];

    final normPos = normalizePos(pos);
    final List<Map<String, dynamic>> consolidatedResults = [];

    // =========================================================================
    // STEP 1: Check User Database (SavedWord in VocabularyService)
    // =========================================================================
    try {
      final vocabService = VocabularyService();
      final savedWords = await vocabService.getSavedWords();
      final matchingSaved = savedWords.where((sw) {
        final sameWord = sw.word.toLowerCase().trim() == cleanWord.toLowerCase() ||
            (sw.baseForm != null && sw.baseForm!.toLowerCase().trim() == cleanWord.toLowerCase());
        if (!sameWord) return false;
        if (normPos.isNotEmpty && sw.pos != null && sw.pos!.isNotEmpty) {
          return normalizePos(sw.pos) == normPos;
        }
        return true;
      }).toList();

      for (final sw in matchingSaved) {
        final defs = <String>[
          if (sw.primaryDefinition.isNotEmpty) sw.primaryDefinition,
          ...sw.definitions.where((d) => d != sw.primaryDefinition && d.isNotEmpty),
        ];

        final examples = <Map<String, String?>>[];
        if (sw.contextSentence != null && sw.contextSentence!.isNotEmpty) {
          examples.add({'de': sw.contextSentence!, 'en': null});
        }
        for (final ex in sw.contextExamples) {
          if (ex.sentence.isNotEmpty && !examples.any((e) => e['de'] == ex.sentence)) {
            examples.add({'de': ex.sentence, 'en': ex.translation});
          }
        }

        final String effectiveSource = sw.source.isNotEmpty ? sw.source : 'user_added';
        final String effectiveLabel = effectiveSource == 'wiktionary_fetched'
            ? 'Wiktionary'
            : (effectiveSource == 'user_edited' ? 'User Edited' : 'Saved in your library');

        consolidatedResults.add({
          'id': sw.id.hashCode.abs(),
          'word': sw.word,
          'pos': sw.pos != null && sw.pos!.isNotEmpty ? sw.pos! : (normPos.isNotEmpty ? normPos : 'word'),
          'gender': sw.gender,
          'ipa': sw.ipa,
          'base_form': sw.baseForm ?? sw.word,
          'freq_rank': null,
          'definitions': defs,
          'definition': sw.primaryDefinition,
          'examples': examples,
          'category': sw.category.name,
          'isFromUserDatabase': true,
          'source': effectiveSource,
          'sourceLabel': effectiveLabel,
        });
      }
    } catch (e) {
      AppLogger.error('Error querying user database in lookupConsolidatedWord', error: e, tag: 'DictionaryService');
    }

    // =========================================================================
    // STEP 2: Check German Dictionary Database (SQLite dict.db)
    // =========================================================================
    List<Map<String, dynamic>> dbResults = [];
    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        try {
          if (normPos.isNotEmpty) {
            // Targeted POS search in words table
            final raw = await db.rawQuery('''
              SELECT w.id, w.word, w.pos, COALESCE(w.gender, w_base.gender) as gender,
                     w.ipa, COALESCE(w.base_form, w_base.word) as base_form,
                     COALESCE(w.verb_class, w_base.verb_class) as verb_class,
                     w.freq_rank,
                     COALESCE(d.definition, d_base.definition) as definition
              FROM words w
              LEFT JOIN definitions d ON w.id = d.word_id
              LEFT JOIN words w_base ON w.base_form = w_base.word
              LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
              WHERE (w.word = ? COLLATE NOCASE OR w.base_form = ? COLLATE NOCASE)
                AND (w.pos LIKE ? COLLATE NOCASE OR w.pos LIKE ? COLLATE NOCASE)
              ORDER BY LENGTH(w.word) ASC, w.id ASC
            ''', [cleanWord, cleanWord, '%$normPos%', '%${pos?.trim()}%']);

            if (raw.isNotEmpty) {
              dbResults = _groupDbResultsByPos(raw, cleanWord);
            }
          }

          // If no POS-specific match found or no POS supplied, query all POS senses
          if (dbResults.isEmpty) {
            if (contextSentence != null && contextSentence.isNotEmpty) {
              dbResults = await lookupContextualWord(cleanWord, contextSentence: contextSentence);
            } else {
              dbResults = await lookupWordAllPOS(cleanWord);
            }
          }
        } catch (e) {
          AppLogger.error('Dictionary DB lookup error in lookupConsolidatedWord', error: e, tag: 'DictionaryService');
        }
      }
    }

    // If SQLite returned results, fetch examples/forms and merge
    for (final r in dbResults) {
      final enriched = Map<String, dynamic>.from(r);
      enriched['source'] = 'german_dictionary';
      enriched['sourceLabel'] = 'German Dictionary';

      final db = await database;
      if (db != null) {
        final id = enriched['id'] as int?;
        if (id != null && id > 0) {
          final baseForm = (enriched['base_form'] as String?)?.trim();
          enriched['examples'] = await _getExamplesForWord(db, id, baseForm);
          try {
            enriched['forms'] = await db.rawQuery(
              'SELECT f.form, t.tags FROM forms f LEFT JOIN tags t ON f.tag_id = t.id WHERE f.word_id = ? OR f.word_id = (SELECT id FROM words WHERE word = ? AND base_form IS NULL LIMIT 1)',
              [id, (baseForm != null && baseForm.isNotEmpty) ? baseForm : enriched['word']],
            );
          } catch (_) {
            enriched['forms'] = <Map<String, dynamic>>[];
          }
        }
      }

      final existingIndex = consolidatedResults.indexWhere((c) {
        final cPos = normalizePos(c['pos']?.toString());
        final ePos = normalizePos(enriched['pos']?.toString());
        return cPos == ePos || cPos == 'word' || cPos.isEmpty;
      });

      if (existingIndex != -1) {
        final userDefs = List<String>.from(consolidatedResults[existingIndex]['definitions'] ?? []);
        final dbDefs = List<String>.from(enriched['definitions'] ?? [enriched['definition'] ?? '']);
        for (final d in dbDefs) {
          if (!userDefs.contains(d) && d.trim().isNotEmpty) {
            userDefs.add(d);
          }
        }
        consolidatedResults[existingIndex]['definitions'] = userDefs;

        // Merge examples from dictionary
        final userExs = List<Map<String, String?>>.from(consolidatedResults[existingIndex]['examples'] ?? []);
        final dbExs = (enriched['examples'] as List?)?.whereType<Map<String, dynamic>>().map((e) => {
          'de': e['de']?.toString() ?? '',
          'en': e['en']?.toString(),
        }).where((e) => e['de']!.isNotEmpty).toList() ?? [];
        for (final dex in dbExs) {
          if (!userExs.any((u) => u['de'] == dex['de'])) {
            userExs.add(dex);
          }
        }
        consolidatedResults[existingIndex]['examples'] = userExs;

        // Upgrade generic POS to specific POS
        if (consolidatedResults[existingIndex]['pos'] == 'word' || consolidatedResults[existingIndex]['pos'] == null) {
          consolidatedResults[existingIndex]['pos'] = enriched['pos'];
        }
        if (consolidatedResults[existingIndex]['gender'] == null && enriched['gender'] != null) {
          consolidatedResults[existingIndex]['gender'] = enriched['gender'];
        }
        if (consolidatedResults[existingIndex]['ipa'] == null && enriched['ipa'] != null) {
          consolidatedResults[existingIndex]['ipa'] = enriched['ipa'];
        }
        if (consolidatedResults[existingIndex]['base_form'] == null && enriched['base_form'] != null) {
          consolidatedResults[existingIndex]['base_form'] = enriched['base_form'];
        }
        if (consolidatedResults[existingIndex]['verb_class'] == null && enriched['verb_class'] != null) {
          consolidatedResults[existingIndex]['verb_class'] = enriched['verb_class'];
        }
        if (consolidatedResults[existingIndex]['forms'] == null || (consolidatedResults[existingIndex]['forms'] as List).isEmpty) {
          consolidatedResults[existingIndex]['forms'] = enriched['forms'] ?? [];
        }
        if (consolidatedResults[existingIndex]['source'] == 'wiktionary_fetched') {
          consolidatedResults[existingIndex]['source'] = 'german_dictionary';
          consolidatedResults[existingIndex]['sourceLabel'] = 'Dictionary';
        }
      } else {
        consolidatedResults.add(enriched);
      }
    }

    // =========================================================================
    // STEP 3: Wiktionary API Fallback (with POS-targeted query & example enrichment)
    // =========================================================================
    final hasRequestedPos = normPos.isEmpty || consolidatedResults.any((c) => normalizePos(c['pos']?.toString()) == normPos);
    final hasExamples = consolidatedResults.any((c) => (c['examples'] as List?)?.isNotEmpty ?? false);
    if (!hasRequestedPos || consolidatedResults.isEmpty || !hasExamples) {
      try {
        final wiktionaryResult = await fetchWiktionaryFallback(cleanWord, targetPos: pos);
        if (wiktionaryResult != null) {
          final enriched = Map<String, dynamic>.from(wiktionaryResult);
          enriched['source'] = 'wiktionary';
          enriched['sourceLabel'] = 'Wiktionary';

          final existingIndex = consolidatedResults.indexWhere((c) {
            final cPos = normalizePos(c['pos']?.toString());
            final ePos = normalizePos(enriched['pos']?.toString());
            return cPos == ePos || cPos == 'word' || cPos.isEmpty;
          });

          if (existingIndex == -1) {
            consolidatedResults.add(enriched);
          } else {
            // Merge WiktAPI rich examples, IPA, and forms into the existing entry
            final existingExs = List<Map<String, String?>>.from(consolidatedResults[existingIndex]['examples'] ?? []);
            final wiktExs = (enriched['examples'] as List?)?.whereType<Map<String, dynamic>>().map((e) => {
              'de': e['de']?.toString() ?? '',
              'en': e['en']?.toString(),
            }).where((e) => e['de']!.isNotEmpty).toList() ?? [];
            for (final wex in wiktExs) {
              if (!existingExs.any((u) => u['de'] == wex['de'])) {
                existingExs.add(wex);
              }
            }
            consolidatedResults[existingIndex]['examples'] = existingExs;

            if (consolidatedResults[existingIndex]['ipa'] == null && enriched['ipa'] != null) {
              consolidatedResults[existingIndex]['ipa'] = enriched['ipa'];
            }
            if (consolidatedResults[existingIndex]['audioUrl'] == null && enriched['audioUrl'] != null) {
              consolidatedResults[existingIndex]['audioUrl'] = enriched['audioUrl'];
            }
            if (consolidatedResults[existingIndex]['forms'] == null || (consolidatedResults[existingIndex]['forms'] as List).isEmpty) {
              consolidatedResults[existingIndex]['forms'] = enriched['forms'] ?? [];
            }
            if (consolidatedResults[existingIndex]['pos'] == 'word' && enriched['pos'] != 'word') {
              consolidatedResults[existingIndex]['pos'] = enriched['pos'];
            }
            if (consolidatedResults[existingIndex]['gender'] == null && enriched['gender'] != null) {
              consolidatedResults[existingIndex]['gender'] = enriched['gender'];
            }
          }
        }
      } catch (e) {
        AppLogger.error('Wiktionary fallback error in lookupConsolidatedWord', error: e, tag: 'DictionaryService');
      }
    }

    // =========================================================================
    // STEP 4: Safety Net (NMT Translation)
    // =========================================================================
    if (consolidatedResults.isEmpty) {
      try {
        final nmtResult = await translateWordOnline(cleanWord);
        if (nmtResult != null) {
          final enriched = Map<String, dynamic>.from(nmtResult);
          enriched['source'] = 'nmt_translation';
          enriched['sourceLabel'] = 'Machine Translation';
          consolidatedResults.add(enriched);
        }
      } catch (_) {}
    }

    // Priority sorting: Exact requested POS on top
    if (normPos.isNotEmpty && consolidatedResults.length > 1) {
      consolidatedResults.sort((a, b) {
        final aPos = normalizePos(a['pos']?.toString());
        final bPos = normalizePos(b['pos']?.toString());
        final aMatch = aPos == normPos;
        final bMatch = bPos == normPos;
        if (aMatch && !bMatch) return -1;
        if (!aMatch && bMatch) return 1;
        return 0;
      });
    }

    return consolidatedResults;
  }

  Future<List<Map<String, dynamic>>> getRandomNouns({int limit = 10}) async {
    final db = await database;
    if (db == null) return [];
    try {
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
        SELECT w.id, w.word, w.gender, w.ipa, d.definition
        FROM words w
        JOIN definitions d ON w.id = d.word_id
        WHERE w.gender IS NOT NULL
          AND w.gender IN ('m', 'f', 'n', 'masculine', 'feminine', 'neuter')
          AND d.definition IS NOT NULL
          AND d.definition NOT LIKE 'inflection of%'
          AND d.definition NOT LIKE 'past participle%'
          AND d.definition NOT LIKE 'strong/%'
          AND d.definition NOT LIKE 'weak/%'
          AND d.definition NOT LIKE 'mixed/%'
          AND d.definition NOT LIKE 'plural of%'
        GROUP BY w.id
        ORDER BY RANDOM()
        LIMIT 50
      ''');

      List<Map<String, dynamic>> nounRows = [];
      for (var row in rawRows) {
        final word = row['word'] as String?;
        if (word != null && word.isNotEmpty && word[0] == word[0].toUpperCase()) {
          nounRows.add(row);
          if (nounRows.length >= limit) break;
        }
      }
      return nounRows;
    } catch (e) {
      AppLogger.error("Error fetching random nouns", error: e, tag: 'DictionaryService');
      return [];
    }
  }

  /// Fetches random high-frequency German words within a dynamic rank range based on user's learned words count.
  /// Initial range is top 500 frequency rank, expanding by 50 for each learned word.
  Future<List<Map<String, dynamic>>> getHighFrequencyWords({
    String pos = 'all',
    int limit = 30,
    int learnedCount = 0,
  }) async {
    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        try {
          int maxRank = 500 + (learnedCount * 50);

          String posFilter = "";
          List<dynamic> args = [maxRank];

          if (pos != 'all' && pos.isNotEmpty) {
            posFilter = "AND pos = ?";
            args.add(pos);
          }
          args.add(limit);

          if (_supportsFreqRank) {
            final List<Map<String, dynamic>> rows = await db.rawQuery('''
              SELECT w.id, w.word, w.pos, w.gender, w.ipa, d.definition, w.freq_rank
              FROM (
                SELECT id, word, pos, gender, ipa, freq_rank
                FROM words
                WHERE freq_rank IS NOT NULL AND freq_rank <= ? $posFilter
                GROUP BY word, pos
                HAVING id = MIN(id)
              ) w
              JOIN definitions d ON w.id = d.word_id
              WHERE d.definition IS NOT NULL
              GROUP BY w.id
              ORDER BY RANDOM()
              LIMIT ?
            ''', args);

            if (rows.isNotEmpty) return rows;
          }
        } catch (e) {
          AppLogger.error("Error fetching discover words", error: e, tag: 'DictionaryService');
        }
        return getHighFrequencyNouns(limit: limit);
      }
    }

    // Web / API Fallback via OmniScribe REST API
    try {
      final backendUrl = Config.backendUrl;
      final uri = Uri.parse('$backendUrl/api/dictionary/frequency?pos=$pos&limit=$limit&learned_count=$learnedCount&random=true');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final list = List<Map<String, dynamic>>.from(data['results'] ?? []);
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      AppLogger.error("OmniScribe getHighFrequencyWords API error", error: e, tag: 'DictionaryService');
    }

    return [];
  }

  /// Fetches German nouns sorted/filtered by offline dictionary frequency rank.
  /// Allows filtering by rank range (e.g. minRank: 1, maxRank: 500) and random sampling
  /// so quiz decks remain fresh and varied across sessions.
  Future<List<Map<String, dynamic>>> getRankedNouns({
    int minRank = 1,
    int maxRank = 5000,
    int limit = 15,
    bool randomize = true,
  }) async {
    if (kIsWeb) {
      return getHighFrequencyWords(pos: 'noun', limit: limit);
    }
    final db = await database;
    if (db == null) return getHighFrequencyWords(pos: 'noun', limit: limit);

    try {
      if (_supportsFreqRank) {
        final orderBy = randomize ? 'RANDOM()' : 'w.freq_rank ASC';
        final List<Map<String, dynamic>> rows = await db.rawQuery('''
          SELECT w.id, w.word, w.gender, w.ipa, w.freq_rank, d.definition
          FROM words w
          JOIN definitions d ON w.id = d.word_id
          WHERE (LOWER(w.pos) = 'noun' OR w.pos LIKE 'noun%' OR w.pos = 'n' OR w.pos = 'n.' OR (w.gender IS NOT NULL AND w.gender != ''))
            AND w.gender IS NOT NULL
            AND w.gender IN ('m', 'f', 'n', 'masculine', 'feminine', 'neuter', 'der', 'die', 'das', 'r', 'e', 's')
            AND w.freq_rank IS NOT NULL
            AND w.freq_rank >= ?
            AND w.freq_rank <= ?
            AND LENGTH(w.word) >= 3
            AND w.word NOT IN ('Ich','Du','Es','Sie','Wir','Ihr','Ja','Nein','Aber','Wenn','Hier','Ach','Als','Oder','Dass','Weil','Wie')
            AND d.definition IS NOT NULL
            AND d.definition NOT LIKE 'inflection of%'
            AND d.definition NOT LIKE 'plural of%'
            AND d.definition NOT LIKE 'the pronoun%'
            AND d.definition NOT LIKE 'the % letter%'
          GROUP BY w.word
          ORDER BY $orderBy
          LIMIT ?
        ''', [minRank, maxRank, limit]);

        if (rows.isNotEmpty) return rows;
      }
    } catch (e) {
      AppLogger.error("Error fetching ranked nouns", error: e, tag: 'DictionaryService');
    }

    return getHighFrequencyNouns(limit: limit);
  }

  /// Fetches essential high-frequency German nouns for practice (ordered by frequency rank)
  Future<List<Map<String, dynamic>>> getHighFrequencyNouns({int limit = 15}) async {
    if (kIsWeb) {
      return getHighFrequencyWords(pos: 'noun', limit: limit);
    }
    final db = await database;
    if (db == null) return getHighFrequencyWords(pos: 'noun', limit: limit);

    try {
      final ranked = await getRankedNouns(minRank: 1, maxRank: 1500, limit: limit, randomize: true);
      if (ranked.isNotEmpty) return ranked;
    } catch (_) {}

    const commonWords = [
      'Zeit', 'Tag', 'Mann', 'Frau', 'Kind', 'Haus', 'Stadt', 'Land', 'Auge', 
      'Hand', 'Wort', 'Mensch', 'Schule', 'Wasser', 'Freund', 'Tisch', 'Stuhl', 
      'Zeitung', 'Wohnung', 'Bäckerei', 'Auto', 'Brot', 'Mädchen', 'Schmetterling', 
      'Krankenhaus', 'Möglichkeit', 'Gesundheit', 'Musik', 'Bild', 'Arbeit', 
      'Weg', 'Stück', 'Ende', 'Stunde', 'Tür', 'Mutter', 'Vater', 'Bruder', 
      'Schwester', 'Uhr', 'Flugzeug', 'Tier', 'Garten', 'Sonne', 'Blume', 'Buch'
    ];

    try {
      final placeholders = List.filled(commonWords.length, '?').join(',');
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
        SELECT w.id, w.word, w.gender, w.ipa, d.definition
        FROM words w
        JOIN definitions d ON w.id = d.word_id
        WHERE w.word IN ($placeholders)
          AND w.gender IS NOT NULL
          AND d.definition IS NOT NULL
        GROUP BY w.id
        ORDER BY RANDOM()
        LIMIT ?
      ''', [...commonWords, limit]);

      return rawRows;
    } catch (e) {
      AppLogger.error("Error fetching high-frequency nouns", error: e, tag: 'DictionaryService');
      return [];
    }
  }

  /// Fetches plural form from forms table for a noun if available
  Future<String?> getPluralForm(int wordId, String wordStr, {String? baseForm}) async {
    final db = await database;
    if (db == null) return null;
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery(
        'SELECT f.form, t.tags FROM forms f LEFT JOIN tags t ON f.tag_id = t.id WHERE f.word_id = ? OR f.word_id = (SELECT id FROM words WHERE word = ? LIMIT 1)',
        [wordId, baseForm ?? wordStr],
      );

      final targetWord = (baseForm != null && baseForm.isNotEmpty) ? baseForm : wordStr;

      // Priority 1: Nominative plural tag
      for (var row in res) {
        final form = row['form'] as String?;
        final tags = (row['tags'] as String? ?? '').toLowerCase();
        if (form != null && form.isNotEmpty && form.toLowerCase() != targetWord.toLowerCase()) {
          if (tags.contains('plural') &&
              (tags.contains('nominative') || (!tags.contains('genitive') && !tags.contains('dative')))) {
            return form.toLowerCase().startsWith('die ') ? form : 'die $form';
          }
        }
      }

      // Priority 2: Any plural tag
      for (var row in res) {
        final form = row['form'] as String?;
        final tags = (row['tags'] as String? ?? '').toLowerCase();
        if (form != null && form.isNotEmpty && form.toLowerCase() != targetWord.toLowerCase()) {
          if (tags.contains('plural')) {
            return form.toLowerCase().startsWith('die ') ? form : 'die $form';
          }
        }
      }
    } catch (_) {}
    return null;
  }
  bool isGrammaticalJargon(String def) {
    final lower = def.trim().toLowerCase();
    return lower.startsWith('strong ') ||
        lower.startsWith('weak ') ||
        lower.startsWith('mixed ') ||
        lower.startsWith('inflection of') ||
        lower.startsWith('past participle of') ||
        lower.startsWith('present participle of') ||
        lower.startsWith('plural of') ||
        lower.startsWith('genitive ') ||
        lower.startsWith('dative ') ||
        lower.startsWith('accusative ') ||
        lower.startsWith('nominative ') ||
        lower.contains('singular of') ||
        lower.contains('plural of') ||
        lower.contains('degree of');
  }

  Future<List<String>> cleanAndResolveDefinitions({
    required String word,
    required List<String> rawDefinitions,
    String? baseForm,
  }) async {
    final db = await database;
    List<String> cleanList = [];

    for (var def in rawDefinitions) {
      if (!isGrammaticalJargon(def)) {
        cleanList.add(def);
      }
    }

    String? targetBase = baseForm;
    if (targetBase == null && rawDefinitions.isNotEmpty) {
      final match = RegExp(r'\bof ([a-zA-ZäöüÄÖÜß]+)\b', caseSensitive: false).firstMatch(rawDefinitions.first);
      if (match != null) {
        targetBase = match.group(1);
      }
    }

    if (db != null && targetBase != null && targetBase.toLowerCase() != word.toLowerCase()) {
      final baseRes = await db.query(
        'words',
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [targetBase],
        limit: 1,
      );

      if (baseRes.isNotEmpty) {
        int baseId = baseRes.first['id'] as int;
        final baseDefsRes = await db.query('definitions', where: 'word_id = ?', whereArgs: [baseId]);
        final baseDefs = baseDefsRes
            .map((d) => d['definition'] as String)
            .where((d) => !isGrammaticalJargon(d))
            .toList();

        if (baseDefs.isNotEmpty) {
          cleanList = [...baseDefs, ...cleanList];
        }
      }
    }

    if (cleanList.isEmpty) {
      return rawDefinitions.map((d) {
        if (isGrammaticalJargon(d)) {
          final m = RegExp(r'\bof ([a-zA-ZäöüÄÖÜß]+)\b', caseSensitive: false).firstMatch(d);
          if (m != null) return 'Form of "${m.group(1)}"';
        }
        return d;
      }).toList();
    }

    return cleanList;
  }
}

