import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';
import 'vocabulary_service.dart';
import 'profile_service.dart';
import 'curriculum_service.dart';
import 'media_library_service.dart';
import 'app_logger.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  bool _isSyncing = false;
  bool _rerunRequested = false;
  Timer? _debounceTimer;
  DateTime? _lastSyncedAt;
  String? _syncError;

  bool _statsSyncing = false;
  bool _statsRerunRequested = false;
  Timer? _statsDebounceTimer;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get syncError => _syncError;

  /// Debounced entry point for automatic sync triggers fired off the back of
  /// local mutations (word saved, review recorded, lesson completed, ...).
  /// Bursts of these - e.g. reviewing a stack of flashcards in a row - are
  /// coalesced into a single sync a couple seconds after the last mutation,
  /// instead of one full upload/download pair per mutation.
  void requestSync({Duration debounce = const Duration(seconds: 2)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      syncNow();
    });
  }

  /// Debounced entry point for streak/activity updates specifically. Runs
  /// independently of [requestSync]/[syncNow] and posts only `stats` +
  /// `streak_freezes` - no vocabulary/articles/media - so a streak update
  /// reaches the server in one small request instead of waiting behind the
  /// heavier vocabulary sync's DB reads and payload build.
  void requestQuickStatsSync({Duration debounce = const Duration(milliseconds: 800)}) {
    _statsDebounceTimer?.cancel();
    _statsDebounceTimer = Timer(debounce, () {
      quickSyncStats();
    });
  }

  /// Pushes just the current streak/activity stats to the backend. The
  /// backend treats every `SyncPayload` field as optional and only touches
  /// the fields present in the body, so omitting vocabulary/articles/media
  /// here is a no-op on the server for those collections, not a wipe.
  Future<bool> quickSyncStats() async {
    final auth = AuthService();
    if (!auth.isAuthenticated) return false;

    if (_statsSyncing) {
      _statsRerunRequested = true;
      return false;
    }

    _statsDebounceTimer?.cancel();
    _statsSyncing = true;

    try {
      final token = await auth.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      };
      final response = await http
          .post(
            Uri.parse('${Config.backendUrl}/api/sync'),
            headers: headers,
            body: jsonEncode({
              'streak_freezes': ProfileService().streakFreezes,
              'stats': {
                'activity_dates': ProfileService().activityDates.toList(),
                'best_streak': ProfileService().bestStreak,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Quick stats sync error", error: e, tag: 'SyncService');
      return false;
    } finally {
      _statsSyncing = false;
      if (_statsRerunRequested) {
        _statsRerunRequested = false;
        unawaited(quickSyncStats());
      }
    }
  }

  /// Syncs vocabulary between local app and GCP Cloud backend
  Future<bool> syncNow() async {
    final auth = AuthService();
    if (!auth.isAuthenticated) {
      _syncError = "User not logged in";
      notifyListeners();
      return false;
    }

    // A sync is already in flight. Starting another one now would overlap
    // GET/POST pairs and risk a stale snapshot clobbering a fresher one on
    // the server, so just flag that one more pass is needed once this one
    // finishes rather than racing it.
    if (_isSyncing) {
      _rerunRequested = true;
      return false;
    }

    _debounceTimer?.cancel();
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final token = await auth.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      };

      // 1. Fetch remote cloud state
      final getResponse = await http
          .get(Uri.parse('${Config.backendUrl}/api/sync'), headers: headers)
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> remoteData = {};
      if (getResponse.statusCode == 200) {
        remoteData = jsonDecode(utf8.decode(getResponse.bodyBytes));
      }

      // 2. Merge remote state into local services
      final vocabService = VocabularyService();

      if (remoteData.containsKey('vocabulary') &&
          remoteData['vocabulary'] is List) {
        final List remoteVocab = remoteData['vocabulary'];
        await vocabService.mergeWordsFromSync(
          remoteVocab.whereType<Map<String, dynamic>>().toList(),
        );
      }

      if (remoteData['streak_freezes'] is int) {
        await ProfileService().mergeRemoteStreakFreezes(
          remoteData['streak_freezes'] as int,
        );
      }
      if (remoteData['stats'] is Map<String, dynamic>) {
        final stats = remoteData['stats'] as Map<String, dynamic>;
        final remoteDates = stats['activity_dates'] as List<dynamic>?;
        final remoteBestStreak = stats['best_streak'] as int?;
        await ProfileService().mergeRemoteStats(remoteDates, remoteBestStreak);
      }
      if (remoteData['curriculum_progress'] is List) {
        await CurriculumService().mergeRemoteProgress(
          remoteData['curriculum_progress'] as List,
        );
      }
      if (remoteData['articles'] is List) {
        for (final item in remoteData['articles'] as List) {
          if (item is Map<String, dynamic>) {
            await MediaLibraryService().mergeArticleFromSync(item);
          }
        }
      }
      if (remoteData['media'] is List) {
        for (final item in remoteData['media'] as List) {
          if (item is Map<String, dynamic>) {
            await MediaLibraryService().mergeMediaFromSync(item);
          }
        }
      }

      // 3. Push updated local state to GCP backend. Only words that changed
      // since the last successful sync are uploaded - the backend upserts
      // by id/word onto whatever it already has, so a delta is enough and
      // keeps the payload from growing with the whole vocabulary on every
      // single review.
      final dirtyLocalWords = await vocabService.getDirtyWordsForSync();
      final vocabPayload = dirtyLocalWords.map((w) => w.toJson()).toList();
      final dirtyWordIdsSnapshot = dirtyLocalWords.map((w) => w.id).toList();
      final deletedVocabPayload = vocabService.getDeletedWordIdsForSync();
      final articlesPayload = await MediaLibraryService().getArticlesForSync();
      final mediaPayload = MediaLibraryService().getMediaForSync();
      final deletedMediaPayload = MediaLibraryService().getDeletedMediaKeysForSync();
      final deletedArticlesPayload = MediaLibraryService().getDeletedArticleIdsForSync();

      final postResponse = await http
          .post(
            Uri.parse('${Config.backendUrl}/api/sync'),
            headers: headers,
            body: jsonEncode({
              'vocabulary': vocabPayload,
              'deleted_vocabulary_ids': deletedVocabPayload,
              'articles': articlesPayload,
              'media': mediaPayload,
              'deleted_media_ids': deletedMediaPayload,
              'deleted_article_ids': deletedArticlesPayload,
              'streak_freezes': ProfileService().streakFreezes,
              'curriculum_progress': CurriculumService().completedNodeIds
                  .toList(),
              'stats': {
                'activity_dates': ProfileService().activityDates.toList(),
                'best_streak': ProfileService().bestStreak,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (postResponse.statusCode == 200) {
        await vocabService.clearDirtyWordIds(dirtyWordIdsSnapshot);
        await vocabService.clearDeletedWordIds(deletedVocabPayload);
        _lastSyncedAt = DateTime.now();
        return true;
      } else {
        _syncError = "Sync failed (Status ${postResponse.statusCode})";
        return false;
      }
    } catch (e) {
      AppLogger.error("Sync error", error: e, tag: 'SyncService');
      _syncError = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(syncNow());
      }
    }
  }
}
