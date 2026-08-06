import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/models/article_model.dart';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/services/media_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Article JSON', () {
    test('round-trips through JSON', () {
      final article = Article(
        id: 'a1',
        title: 'Title',
        description: 'Desc',
        level: 'Imported',
        date: DateTime.utc(2026, 1, 1, 12),
        imageUrl: 'https://example.com/img.png',
      );
      final decoded = Article.fromJson(article.toJson());
      expect(decoded.id, article.id);
      expect(decoded.title, article.title);
      expect(decoded.description, article.description);
      expect(decoded.level, article.level);
      expect(decoded.date, article.date);
      expect(decoded.imageUrl, article.imageUrl);
    });
  });

  group('MediaLibraryService sync', () {
    test('getArticlesForSync bundles content with article metadata', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaLibraryService();
      // Wait for the async ctor-triggered loads to settle.
      await Future.delayed(const Duration(milliseconds: 50));

      final article = Article(
        id: 'sync_a1',
        title: 'Synced Article',
        description: 'Desc',
        level: 'Imported',
        date: DateTime.utc(2026, 1, 1),
        imageUrl: 'https://picsum.photos/seed/sync_a1/400/225',
      );
      await service.addImportedArticle(article, 'Full article body text.');

      final payload = await service.getArticlesForSync();
      final entry = payload.firstWhere((e) => e['id'] == 'sync_a1');
      expect(entry['title'], 'Synced Article');
      expect(entry['content'], 'Full article body text.');
    });

    test('mergeArticleFromSync adds a new remote article exactly once', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaLibraryService();
      await Future.delayed(const Duration(milliseconds: 50));
      final before = service.importedArticles.length;

      final remoteJson = {
        'id': 'remote_a1',
        'title': 'Remote Article',
        'description': 'From another device',
        'level': 'Imported',
        'date': DateTime.utc(2026, 1, 2).toIso8601String(),
        'imageUrl': 'https://picsum.photos/seed/remote_a1/400/225',
        'content': 'Remote content body.',
      };

      await service.mergeArticleFromSync(remoteJson);
      expect(service.importedArticles.length, before + 1);
      expect(service.importedArticles.any((a) => a.id == 'remote_a1'), true);
      expect(await service.getCustomContent('remote_a1'), 'Remote content body.');

      // Merging the same remote article again must not duplicate it
      // (additive-only merge, matches the rest of the app's sync philosophy).
      await service.mergeArticleFromSync(remoteJson);
      expect(service.importedArticles.length, before + 1);
    });

    test('getMediaForSync only includes completed videos', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaLibraryService();
      await Future.delayed(const Duration(milliseconds: 50));

      await service.addMediaProcessingTask('task_pending', 'https://youtube.com/watch?v=pending');
      final payload = service.getMediaForSync();
      expect(payload.any((m) => m['id'] == 'task_pending'), false);
    });

    test('mergeMediaFromSync adds a new remote completed video exactly once', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaLibraryService();
      await Future.delayed(const Duration(milliseconds: 50));
      final before = service.processedVideos.length;

      final remoteVideo = ProcessedVideo(
        id: 'remote_v1',
        taskId: 'remote_v1',
        url: 'https://youtube.com/watch?v=remote',
        status: ProcessingStatus.completed,
        subtitles: const [],
        title: 'Remote Video',
      );

      await service.mergeMediaFromSync(remoteVideo.toJson());
      expect(service.processedVideos.length, before + 1);
      expect(service.processedVideos.any((v) => v.id == 'remote_v1'), true);

      await service.mergeMediaFromSync(remoteVideo.toJson());
      expect(service.processedVideos.length, before + 1);
    });
  });
}
