import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/article_model.dart';
import '../models/processed_video.dart';
import '../models/processing_status.dart';
import '../models/subtitle_cue.dart';
import 'backend_service.dart';
import 'ondevice_ai_service.dart';
import 'app_logger.dart';
import 'sync_service.dart';

class MediaLibraryService extends ChangeNotifier {
  static final MediaLibraryService _instance = MediaLibraryService._internal();
  factory MediaLibraryService() => _instance;

  static const String _importedArticlesKey = 'imported_articles';
  static const String _customContentKeyPrefix = 'custom_content_';
  static const String _processedVideosKey = 'processed_videos';
  static const String _deletedMediaKeysKey = 'deleted_media_keys';
  static const String _deletedArticleIdsKey = 'deleted_article_ids';

  final BackendService _backendService = BackendService();
  final Map<String, Timer> _pollingTimers = {};

  List<Article> _importedArticles = [];
  List<ProcessedVideo> _processedVideos = [];
  Set<String> _deletedMediaKeys = {};
  Set<String> _deletedArticleIds = {};

  List<Article> get importedArticles => _importedArticles;
  List<ProcessedVideo> get processedVideos => _processedVideos;

  List<String> getDeletedMediaKeysForSync() => _deletedMediaKeys.toList();
  List<String> getDeletedArticleIdsForSync() => _deletedArticleIds.toList();

  MediaLibraryService._internal() {
    _loadDeletedKeys();
    _loadImportedArticles();
    _loadProcessedVideos();
    clearAllAnalysisCache();
  }

  Future<void> _loadDeletedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deletedMediaKeys = (prefs.getStringList(_deletedMediaKeysKey) ?? []).toSet();
      _deletedArticleIds = (prefs.getStringList(_deletedArticleIdsKey) ?? []).toSet();
    } catch (_) {}
  }

  bool _isMediaDeleted(String? id, String? taskId, String? url) {
    if (id != null && _deletedMediaKeys.contains(id)) return true;
    if (taskId != null && _deletedMediaKeys.contains(taskId)) return true;
    if (url != null) {
      final norm = normalizeMediaUrl(url);
      if (_deletedMediaKeys.contains(norm) || _deletedMediaKeys.contains(url)) return true;
    }
    return false;
  }

  Future<void> clearAllAnalysisCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_analysisCachePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadImportedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? articlesJson = prefs.getString(_importedArticlesKey);

    if (articlesJson != null) {
      final List<dynamic> decodedList = jsonDecode(articlesJson);
      _importedArticles = decodedList
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .where((a) => !_deletedArticleIds.contains(a.id))
          .toList();
    } else {
      _importedArticles = [
        Article(
          id: 'imp1',
          title: 'My Favorite Recipe',
          description: '',
          level: 'Custom',
          date: DateTime.now(),
          imageUrl: 'assets/images/story_hair.png',
        ),
      ];
    }
    notifyListeners();
  }

  static String normalizeMediaUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.contains('youtu.be')) {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (id.isNotEmpty) return 'https://www.youtube.com/watch?v=$id';
      }
      if (uri.pathSegments.contains('shorts')) {
        final idx = uri.pathSegments.indexOf('shorts');
        if (idx + 1 < uri.pathSegments.length) {
          final id = uri.pathSegments[idx + 1];
          if (id.isNotEmpty) return 'https://www.youtube.com/watch?v=$id';
        }
      }
      if (uri.queryParameters.containsKey('v')) {
        final id = uri.queryParameters['v']!;
        if (id.isNotEmpty) return 'https://www.youtube.com/watch?v=$id';
      }
      if (trimmed.endsWith('/')) {
        return trimmed.substring(0, trimmed.length - 1);
      }
    } catch (_) {}
    return trimmed;
  }

  Future<void> _loadProcessedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedList = prefs.getStringList(_deletedMediaKeysKey) ?? [];
    _deletedMediaKeys = deletedList.toSet();

    final String? videosJson = prefs.getString(_processedVideosKey);

    if (videosJson != null) {
      final List<dynamic> decodedList = jsonDecode(videosJson);
      final rawList = decodedList.map((item) => ProcessedVideo.fromJson(item)).toList();

      // Deduplicate by normalized URL, prune deleted, and merge richest data
      final Map<String, ProcessedVideo> uniqueMap = {};
      for (final v in rawList) {
        if (_isMediaDeleted(v.id, v.taskId, v.url)) {
          continue;
        }

        final norm = normalizeMediaUrl(v.url);
        final key = norm.isNotEmpty ? norm : v.id;
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = v;
        } else {
          final existing = uniqueMap[key]!;
          final bestStatus = (v.status == ProcessingStatus.completed) ? v.status : existing.status;
          final bestSubtitles = v.subtitles.isNotEmpty ? v.subtitles : existing.subtitles;
          final bestTitle = (v.title != null && v.title!.isNotEmpty && v.title != 'German Lesson' && v.title != 'YouTube Lesson')
              ? v.title
              : existing.title;
          final bestCategory = v.category?.isNotEmpty == true ? v.category : existing.category;
          final bestThumbnail = (v.thumbnail != null && !v.thumbnail!.contains('picsum.photos'))
              ? v.thumbnail
              : existing.thumbnail;
          final bestVideoUrl = (v.videoUrl?.isNotEmpty == true) ? v.videoUrl : existing.videoUrl;

          uniqueMap[key] = existing.copyWith(
            status: bestStatus,
            subtitles: bestSubtitles,
            title: bestTitle,
            category: bestCategory,
            thumbnail: bestThumbnail,
            videoUrl: bestVideoUrl,
          );
        }
      }
      _processedVideos = uniqueMap.values.toList();
      await _saveProcessedVideos();
    }

    // Resume polling for any video in active/processing state
    for (final video in _processedVideos) {
      if (video.status != ProcessingStatus.completed &&
          video.status != ProcessingStatus.failed &&
          video.taskId != null) {
        _startPollingForTask(video.taskId!, video.url);
      }
    }
    notifyListeners();
  }

  Future<void> updateVideoDetails(String videoId, {String? title, String? category}) async {
    final index = _processedVideos.indexWhere((v) => v.id == videoId || v.taskId == videoId);
    if (index != -1) {
      final current = _processedVideos[index];
      _processedVideos[index] = current.copyWith(
        title: title ?? current.title,
        category: category ?? current.category,
      );
      notifyListeners();
      await _saveProcessedVideos();
    }
  }

  Future<void> submitMediaProcessingTaskInBackground(String originalUrl) async {
    final normalized = normalizeMediaUrl(originalUrl);

    // Un-tombstone if user explicitly re-submits
    _deletedMediaKeys.remove(originalUrl);
    _deletedMediaKeys.remove(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedMediaKeysKey, _deletedMediaKeys.toList());

    // Check if video with this URL already exists (especially if failed or retrying)
    final existingIndex = _processedVideos.indexWhere(
      (v) => normalizeMediaUrl(v.url) == normalized,
    );
    final existing = existingIndex != -1 ? _processedVideos[existingIndex] : null;
    final tempId = existing?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}';
    final initialYtThumb = ProcessedVideo.extractYouTubeThumbnail(originalUrl);
    final existingTitle = existing?.title;
    final existingThumbnail = existing?.thumbnail ?? initialYtThumb;
    final existingCategory = existing?.category;

    final newVideo = ProcessedVideo(
      id: tempId,
      taskId: tempId,
      url: originalUrl,
      status: ProcessingStatus.downloading,
      stageMessage: 'Connecting to server...',
      progressPercentage: 5,
      subtitles: existing?.subtitles ?? [],
      title: existingTitle,
      thumbnail: existingThumbnail,
      category: existingCategory,
    );

    if (existingIndex != -1) {
      _processedVideos[existingIndex] = newVideo;
    } else {
      _processedVideos.insert(0, newVideo);
    }

    // Remove any duplicate entries for this normalized URL if they existed
    _processedVideos.removeWhere(
      (v) => normalizeMediaUrl(v.url) == normalized && v.id != tempId,
    );

    notifyListeners();
    await _saveProcessedVideos();

    try {
      final submitResponse = await _backendService.submitMediaUrl(originalUrl);
      final index = _processedVideos.indexWhere(
        (v) => v.id == tempId || v.taskId == tempId || normalizeMediaUrl(v.url) == normalized,
      );

      if (submitResponse != null && submitResponse.containsKey('task_id')) {
        final realTaskId = submitResponse['task_id'] as String;
        final initialTitle = existingTitle?.isNotEmpty == true ? existingTitle : (submitResponse['title'] as String?);
        final initialThumbnail = (submitResponse['thumbnail'] as String?) ?? existingThumbnail;
        if (index != -1) {
          _processedVideos[index] = ProcessedVideo(
            id: realTaskId,
            taskId: realTaskId,
            url: originalUrl,
            status: ProcessingStatus.downloading,
            stageMessage: 'Checking for subtitles & audio stream...',
            progressPercentage: 15,
            subtitles: [],
            title: initialTitle,
            thumbnail: initialThumbnail,
            category: existingCategory,
          );
          notifyListeners();
          await _saveProcessedVideos();
          _startPollingForTask(realTaskId, originalUrl);
        }
      } else {
        if (index != -1) {
          _processedVideos[index] = ProcessedVideo(
            id: tempId,
            taskId: tempId,
            url: originalUrl,
            status: ProcessingStatus.failed,
            stageMessage: 'Backend server timed out or unreachable',
            errorMessage: submitResponse?['error'] ?? 'Connection timed out',
            progressPercentage: 0,
            subtitles: [],
            title: existingTitle,
            thumbnail: existingThumbnail,
            category: existingCategory,
          );
          notifyListeners();
          await _saveProcessedVideos();
        }
      }
    } catch (e) {
      final index = _processedVideos.indexWhere(
        (v) => v.id == tempId || v.taskId == tempId || normalizeMediaUrl(v.url) == normalized,
      );
      if (index != -1) {
        _processedVideos[index] = ProcessedVideo(
          id: tempId,
          taskId: tempId,
          url: originalUrl,
          status: ProcessingStatus.failed,
          stageMessage: 'Connection timed out',
          errorMessage: e.toString(),
          progressPercentage: 0,
          subtitles: [],
          title: existingTitle,
          thumbnail: existingThumbnail,
          category: existingCategory,
        );
        notifyListeners();
        await _saveProcessedVideos();
      }
    }
  }

  Future<void> addMediaProcessingTask(String taskId, String originalUrl) async {
    final normalized = normalizeMediaUrl(originalUrl);
    final existingIndex = _processedVideos.indexWhere((v) => normalizeMediaUrl(v.url) == normalized);
    
    final newVideo = ProcessedVideo(
      id: taskId,
      taskId: taskId,
      url: originalUrl,
      status: ProcessingStatus.downloading,
      stageMessage: 'Connecting & downloading media...',
      progressPercentage: 10,
      subtitles: [],
    );

    if (existingIndex != -1) {
      _processedVideos[existingIndex] = newVideo;
    } else {
      _processedVideos.insert(0, newVideo);
    }
    notifyListeners();
    await _saveProcessedVideos();

    _startPollingForTask(taskId, originalUrl);
  }

  Future<void> retryProcessingTask(String oldTaskId, String originalUrl) async {
    await submitMediaProcessingTaskInBackground(originalUrl);
  }

  Future<bool> refreshVideoUrl(String id, String originalUrl) async {
    final freshUrl = await _backendService.getFreshVideoUrl(originalUrl);
    if (freshUrl != null && freshUrl.isNotEmpty) {
      final index = _processedVideos.indexWhere((v) => v.id == id || v.taskId == id);
      if (index != -1) {
        final old = _processedVideos[index];
        _processedVideos[index] = ProcessedVideo(
          id: old.id,
          taskId: old.taskId,
          url: old.url,
          status: old.status,
          stageMessage: old.stageMessage,
          errorMessage: null,
          subtitles: old.subtitles,
          videoUrl: freshUrl,
          mediaType: old.mediaType,
          thumbnail: old.thumbnail,
          title: old.title,
          category: old.category,
        );
        notifyListeners();
        await _saveProcessedVideos();
        return true;
      }
    }
    return false;
  }

  void _startPollingForTask(String taskId, String originalUrl) {
    if (_pollingTimers.containsKey(taskId)) return;

    int pollAttempts = 0;
    const maxPollAttempts = 80; // 80 * 3s = 4 minutes maximum polling
    final normalized = normalizeMediaUrl(originalUrl);

    final timer = Timer.periodic(const Duration(seconds: 3), (t) async {
      pollAttempts++;
      if (pollAttempts > maxPollAttempts) {
        t.cancel();
        _pollingTimers.remove(taskId);
        final index = _processedVideos.indexWhere(
          (v) => v.taskId == taskId || v.id == taskId || normalizeMediaUrl(v.url) == normalized,
        );
        if (index != -1 && _processedVideos[index].status != ProcessingStatus.completed) {
          final current = _processedVideos[index];
          _processedVideos[index] = ProcessedVideo(
            id: taskId,
            taskId: taskId,
            url: originalUrl,
            status: ProcessingStatus.failed,
            stageMessage: 'Processing timed out',
            errorMessage: 'Task exceeded maximum time limit.',
            progressPercentage: 0,
            subtitles: [],
            title: current.title,
            thumbnail: current.thumbnail,
            category: current.category,
          );
          notifyListeners();
          await _saveProcessedVideos();
        }
        return;
      }

      final statusResponse = await _backendService.checkMediaStatus(taskId);
      if (statusResponse == null) return;

      final statusStr = (statusResponse['status'] as String?)?.toLowerCase();
      final stageMsg = statusResponse['stage_message'] as String?;
      final errorMsg = statusResponse['error'] as String?;
      final progressPct = (statusResponse['progress_percentage'] as num?)?.toInt() ?? 0;
      final statusCode = statusResponse['statusCode'] as int?;

      // Auto-recover if server restarted or task 404'd
      if (statusStr == 'not_found' || statusCode == 404) {
        t.cancel();
        _pollingTimers.remove(taskId);
        AppLogger.debug("Server task $taskId returned 404. Automatically resubmitting URL: $originalUrl", tag: 'MediaLibraryService');
        retryProcessingTask(taskId, originalUrl);
        return;
      }

      final index = _processedVideos.indexWhere(
        (v) => v.taskId == taskId || v.id == taskId || normalizeMediaUrl(v.url) == normalized,
      );

      if (statusStr == 'processing' || statusStr == 'downloading' || statusStr == 'transcribing' || statusStr == 'pending') {
        if (index != -1) {
          final current = _processedVideos[index];
          final incomingTitle = statusResponse['title'] as String?;
          final incomingThumbnail = statusResponse['thumbnail'] as String?;

          final updatedTitle = current.title?.isNotEmpty == true ? current.title : (incomingTitle ?? current.title);
          final updatedThumbnail = incomingThumbnail ?? current.thumbnail;

          if (current.stageMessage != stageMsg || 
              current.progressPercentage != progressPct ||
              current.title != updatedTitle ||
              current.thumbnail != updatedThumbnail) {
            _processedVideos[index] = ProcessedVideo(
              id: taskId,
              taskId: taskId,
              url: originalUrl,
              status: ProcessingStatus.transcribing,
              stageMessage: stageMsg ?? current.stageMessage,
              progressPercentage: progressPct > 0 ? progressPct : current.progressPercentage,
              subtitles: current.subtitles,
              videoUrl: current.videoUrl,
              mediaType: current.mediaType,
              thumbnail: updatedThumbnail,
              title: updatedTitle,
              category: current.category,
            );
            notifyListeners();
            await _saveProcessedVideos();
          }
        }
      } else if (statusStr == 'completed') {
        t.cancel();
        _pollingTimers.remove(taskId);

        final resultData = (statusResponse['result'] as Map<String, dynamic>?) ?? statusResponse;
        final mediaTypeStr = resultData['media_type'] as String? ?? 'video';
        final videoUrl = resultData['video_url'] as String?;
        final thumbnail = resultData['thumbnail'] as String?;
        final title = resultData['title'] as String?;
        final subtitlesRaw = resultData['subtitles'] as List<dynamic>? ?? [];

        List<SubtitleCue> subtitles = subtitlesRaw.map((cue) {
          return SubtitleCue(
            start: (cue['start'] as num).toDouble(),
            end: (cue['end'] as num).toDouble(),
            original: (cue['original'] as String?) ?? '',
            translated: (cue['translated'] as String?) ?? '',
          );
        }).toList();

        // Translate missing cues locally via On-Device ML Kit
        final onDeviceAI = OnDeviceAIService();
        subtitles = await onDeviceAI.translateSubtitlesOnDevice(subtitles);

        if (index != -1) {
          final current = _processedVideos[index];
          final incomingTitle = (title != null && title.isNotEmpty && title != 'German Dialogue Lesson' && title != 'YouTube Lesson' && title != 'German Lesson') ? title : null;
          final effectiveTitle = (current.title != null && current.title!.isNotEmpty && current.title != 'German Dialogue Lesson' && current.title != 'YouTube Lesson')
              ? current.title
              : (incomingTitle ?? current.title);

          final effectiveThumbnail = (thumbnail != null && thumbnail.isNotEmpty && !thumbnail.contains('picsum.photos'))
              ? thumbnail
              : ((current.thumbnail != null && !current.thumbnail!.contains('picsum.photos')) ? current.thumbnail : ProcessedVideo.extractYouTubeThumbnail(originalUrl));

          _processedVideos[index] = ProcessedVideo(
            id: taskId,
            taskId: taskId,
            url: originalUrl,
            status: ProcessingStatus.completed,
            stageMessage: stageMsg ?? 'Ready 🎬',
            progressPercentage: 100,
            subtitles: subtitles,
            videoUrl: videoUrl,
            mediaType: mediaTypeStr,
            thumbnail: effectiveThumbnail,
            title: effectiveTitle,
            category: current.category,
          );
          notifyListeners();
          await _saveProcessedVideos();
        }
      } else if (statusStr == 'failed') {
        t.cancel();
        _pollingTimers.remove(taskId);

        if (index != -1) {
          final current = _processedVideos[index];
          _processedVideos[index] = ProcessedVideo(
            id: taskId,
            taskId: taskId,
            url: originalUrl,
            status: ProcessingStatus.failed,
            stageMessage: stageMsg ?? 'Processing failed',
            errorMessage: errorMsg,
            progressPercentage: 0,
            subtitles: [],
            title: current.title,
            thumbnail: current.thumbnail,
            category: current.category,
          );
          notifyListeners();
          await _saveProcessedVideos();
        }
      }
    });

    _pollingTimers[taskId] = timer;
  }

  Future<void> _saveProcessedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_processedVideos.map((v) => v.toJson()).toList());
    await prefs.setString(_processedVideosKey, encodedList);
  }

  Future<void> updateProcessedVideoSubtitles(String id, List<SubtitleCue> subtitles) async {
    final index = _processedVideos.indexWhere((v) => v.id == id || v.taskId == id);
    if (index != -1) {
      final old = _processedVideos[index];
      _processedVideos[index] = ProcessedVideo(
        id: old.id,
        taskId: old.taskId,
        url: old.url,
        status: old.status,
        stageMessage: old.stageMessage,
        title: old.title,
        mediaType: old.mediaType,
        videoUrl: old.videoUrl,
        thumbnail: old.thumbnail,
        subtitles: subtitles,
        errorMessage: old.errorMessage,
        category: old.category,
      );
      notifyListeners();
      await _saveProcessedVideos();
    }
  }

  Future<void> deleteProcessedVideo(String id, {String? url}) async {
    ProcessedVideo? videoToDelete;
    for (final v in _processedVideos) {
      if (v.id == id || v.taskId == id || (url != null && normalizeMediaUrl(v.url) == normalizeMediaUrl(url))) {
        videoToDelete = v;
        break;
      }
    }

    final targetUrl = url ?? videoToDelete?.url;
    final normalizedUrl = targetUrl != null ? normalizeMediaUrl(targetUrl) : null;
    final taskId = videoToDelete?.taskId;

    // 1. Remove from in-memory list
    _processedVideos.removeWhere((v) =>
        v.id == id ||
        v.taskId == id ||
        (taskId != null && (v.id == taskId || v.taskId == taskId)) ||
        (normalizedUrl != null && normalizeMediaUrl(v.url) == normalizedUrl));

    // 2. Cancel all associated polling timers
    if (taskId != null) {
      _pollingTimers[taskId]?.cancel();
      _pollingTimers.remove(taskId);
    }
    _pollingTimers[id]?.cancel();
    _pollingTimers.remove(id);

    // 3. Mark as deleted in persistent tombstone set
    _deletedMediaKeys.add(id);
    if (taskId != null) _deletedMediaKeys.add(taskId);
    if (videoToDelete?.id != null) _deletedMediaKeys.add(videoToDelete!.id);
    if (targetUrl != null) _deletedMediaKeys.add(targetUrl);
    if (normalizedUrl != null) _deletedMediaKeys.add(normalizedUrl);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedMediaKeysKey, _deletedMediaKeys.toList());

    notifyListeners();
    await _saveProcessedVideos();

    // 4. Trigger cloud sync to update remote database immediately
    try {
      unawaited(SyncService().syncNow());
    } catch (_) {}
  }

  Future<void> importWebArticleInBackground(String url) async {
    Map<String, dynamic>? result;
    try {
      result = await _backendService.importFromUrl(url);
    } catch (_) {}

    String title = '';
    String content = '';
    String description = '';

    if (result != null && !result.containsKey('error')) {
      title = (result['title'] as String?) ?? '';
      content = (result['content'] as String?) ?? '';
      description = (result['description'] as String?) ?? '';
    }

    // Direct local HTML scraper fallback if backend call fails or times out
    if (content.trim().isEmpty) {
      try {
        final res = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final html = utf8.decode(res.bodyBytes);
          final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
          if (titleMatch != null) {
            title = titleMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
          }

          final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(html);
          final pTexts = pMatches.map((m) {
            return m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
          }).where((t) => t.length > 25).toList();

          content = pTexts.join('\n\n');
        }
      } catch (e) {
        AppLogger.error("Local fallback web scraper error", error: e, tag: 'MediaLibraryService');
      }
    }

    if (title.isEmpty) {
      try {
        title = Uri.parse(url).host;
      } catch (_) {
        title = 'Imported Article';
      }
    }

    if (content.trim().isEmpty) {
      content = 'Could not extract article content automatically. URL: $url';
    }

    final articleId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    // Prefer the backend-extracted cover image (og:image/twitter:image/first
    // <img>/favicon); fall back to a Picsum placeholder seeded by the
    // article id, mirroring the backend's own get_picsum_thumbnail fallback
    // used for video thumbnails.
    final backendCoverImage = result?['cover_image_url'] as String?;
    final imageUrl = (backendCoverImage != null && backendCoverImage.startsWith('http'))
        ? backendCoverImage
        : 'https://picsum.photos/seed/$articleId/400/225';

    final newArticle = Article(
      id: articleId,
      title: title,
      description: description,
      level: 'Imported',
      date: DateTime.now(),
      imageUrl: imageUrl,
    );

    await addImportedArticle(newArticle, content);
  }

  Future<void> addImportedArticle(Article article, String content) async {
    _deletedArticleIds.remove(article.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedArticleIdsKey, _deletedArticleIds.toList());

    _importedArticles.insert(0, article);
    notifyListeners();
    await _saveImportedArticles();
    await saveCustomContent(article.id, content);
  }

  Future<void> deleteArticle(String id) async {
    _importedArticles.removeWhere((a) => a.id == id);
    _deletedArticleIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedArticleIdsKey, _deletedArticleIds.toList());
    await prefs.remove('$_customContentKeyPrefix$id');
    notifyListeners();
    await _saveImportedArticles();

    try {
      unawaited(SyncService().syncNow());
    } catch (_) {}
  }

  Future<void> _saveImportedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList =
        jsonEncode(_importedArticles.map((article) => article.toJson()).toList());

    await prefs.setString(_importedArticlesKey, encodedList);
  }

  Future<void> saveCustomContent(String articleId, String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_customContentKeyPrefix$articleId', content);
  }

  Future<String?> getCustomContent(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_customContentKeyPrefix$articleId');
  }

  static const String _analysisCachePrefix = 'analysis_cache_';

  Future<void> saveCachedAnalysis(String storyId, Map<int, Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> serializable = {};
    data.forEach((key, val) {
      serializable[key.toString()] = val;
    });
    await prefs.setString('$_analysisCachePrefix$storyId', jsonEncode(serializable));
  }

  Future<Map<int, Map<String, dynamic>>?> getCachedAnalysis(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('$_analysisCachePrefix$storyId');
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      final Map<int, Map<String, dynamic>> result = {};
      decoded.forEach((key, val) {
        int? intKey = int.tryParse(key);
        if (intKey != null && val is Map) {
          result[intKey] = Map<String, dynamic>.from(val);
        }
      });
      return result.isNotEmpty ? result : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteImportedArticle(String articleId) async {
    _importedArticles.removeWhere((article) => article.id == articleId);
    _deletedArticleIds.add(articleId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedArticleIdsKey, _deletedArticleIds.toList());
    await prefs.remove('$_customContentKeyPrefix$articleId');
    await prefs.remove('$_analysisCachePrefix$articleId');
    notifyListeners();
    await _saveImportedArticles();

    try {
      unawaited(SyncService().syncNow());
    } catch (_) {}
  }

  /// Builds the sync payload for imported articles, bundling each article's
  /// metadata with its full text content (stored separately locally via
  /// [saveCustomContent]) so other devices can restore both from one item.
  Future<List<Map<String, dynamic>>> getArticlesForSync() async {
    final List<Map<String, dynamic>> result = [];
    for (final article in _importedArticles) {
      final content = await getCustomContent(article.id) ?? '';
      result.add({...article.toJson(), 'content': content});
    }
    return result;
  }

  /// Builds the sync payload for processed media — only completed items,
  /// since in-progress/failed tasks are ephemeral, device-local polling
  /// state that other devices have no use for.
  List<Map<String, dynamic>> getMediaForSync() {
    return _processedVideos
        .where((v) => v.status == ProcessingStatus.completed)
        .map((v) => v.toJson())
        .toList();
  }

  /// Merges one remote article into local state. Additive-only (matches the
  /// rest of this app's sync philosophy — see CurriculumService/vocab merge):
  /// if an article with this id already exists locally, it's left alone.
  Future<void> mergeArticleFromSync(Map<String, dynamic> json) async {
    final id = json['id'] as String?;
    if (id == null || _deletedArticleIds.contains(id) || _importedArticles.any((a) => a.id == id)) return;

    final content = json['content'] as String? ?? '';
    final article = Article.fromJson(json);
    _importedArticles.insert(0, article);
    await _saveImportedArticles();
    await saveCustomContent(article.id, content);
    notifyListeners();
  }

  /// Merges one remote processed-media item into local state. Additive-only,
  /// same rationale as [mergeArticleFromSync].
  Future<void> mergeMediaFromSync(Map<String, dynamic> json) async {
    final id = json['id'] as String?;
    final taskId = json['taskId'] as String?;
    final url = json['url'] as String?;

    if (_isMediaDeleted(id, taskId, url)) return;

    final norm = url != null ? normalizeMediaUrl(url) : '';
    if (id == null || _processedVideos.any((v) => v.id == id || v.taskId == id || (norm.isNotEmpty && normalizeMediaUrl(v.url) == norm))) {
      return;
    }

    _processedVideos.insert(0, ProcessedVideo.fromJson(json));
    await _saveProcessedVideos();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    super.dispose();
  }
}
