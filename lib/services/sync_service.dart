import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';
import 'vocabulary_service.dart';

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
      final token = auth.token;
      final headers = {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      };

      // 1. Fetch remote cloud state
      final getResponse = await http.get(
        Uri.parse('${Config.backendUrl}/api/sync'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> remoteData = {};
      if (getResponse.statusCode == 200) {
        remoteData = jsonDecode(utf8.decode(getResponse.bodyBytes));
      }

      // 2. Merge remote vocabulary into local VocabularyService
      final vocabService = VocabularyService();
      
      if (remoteData.containsKey('vocabulary') && remoteData['vocabulary'] is List) {
        final List remoteVocab = remoteData['vocabulary'];
        for (final rItem in remoteVocab) {
          if (rItem is Map<String, dynamic>) {
            await vocabService.mergeWordFromSync(rItem);
          }
        }
      }

      // 3. Push updated local vocabulary to GCP backend
      final updatedLocalWords = await vocabService.getAllSavedWords();
      final vocabPayload = updatedLocalWords.map((w) => w.toJson()).toList();

      final postResponse = await http.post(
        Uri.parse('${Config.backendUrl}/api/sync'),
        headers: headers,
        body: jsonEncode({
          'vocabulary': vocabPayload,
        }),
      ).timeout(const Duration(seconds: 15));

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
      print("[SyncService] Sync error: $e");
      _syncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }
}
