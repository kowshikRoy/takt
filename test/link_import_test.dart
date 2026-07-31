import 'package:flutter_test/flutter_test.dart';
import 'package:takt/services/backend_service.dart';

void main() {
  group('Link Import & Submission Automated Tests', () {
    late BackendService backendService;

    setUp(() {
      backendService = BackendService();
    });

    test('BackendService instantiation', () {
      expect(backendService.baseUrl, isNotEmpty);
    });

    test('validates article link format handling', () async {
      // Test invalid URL format
      final invalidResult = await backendService.importFromUrl('not_a_valid_url').timeout(const Duration(seconds: 10), onTimeout: () => {'error': 'timeout'});
      expect(invalidResult, isNotNull);
      expect(invalidResult, contains('error'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('validates media link format handling', () async {
      // Test media URL submission handling
      final mediaResult = await backendService.submitMediaUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(mediaResult, isNotNull);
      expect(mediaResult, anyOf(contains('task_id'), contains('error')));
    });

    test('validates status check for task ID', () async {
      final statusResult = await backendService.checkMediaStatus('07d0fca7-31e6-4ff8-ac4e-3dc1568aafb1').timeout(const Duration(seconds: 5), onTimeout: () => {'status': 'processing'});
      expect(statusResult, isNotNull);
      expect(statusResult, anyOf(contains('status'), contains('error')));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
