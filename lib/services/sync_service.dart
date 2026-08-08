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
  DateTime? _lastSyncedAt;
  String? _syncError;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get syncError => _syncError;

  /// Syncs vocabulary between local app and GCP Cloud backend
  Future<bool> syncNow() async {
    final auth = AuthService();
    if (!auth.isAuthenticated) {
      _syncError = "User not logged in";
      notifyListeners();
      return false;
    }

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
        for (final rItem in remoteVocab) {
          if (rItem is Map<String, dynamic>) {
            await vocabService.mergeWordFromSync(rItem);
          }
        }
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

      // 3. Push updated local state to GCP backend
      final updatedLocalWords = await vocabService.getAllSavedWords();
      final vocabPayload = updatedLocalWords.map((w) => w.toJson()).toList();
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
        _lastSyncedAt = DateTime.now();
        _isSyncing = false;
        notifyListeners();
        return true;
      } else {
        _syncError = "Sync failed (Status ${postResponse.statusCode})";
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      AppLogger.error("Sync error", error: e, tag: 'SyncService');
      _syncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }
}
