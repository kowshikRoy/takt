import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/services/gamification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GamificationService', () {
    test('reports level and mastery score from VocabularyService', () {
      final gamification = GamificationService();
      expect(gamification.level, greaterThanOrEqualTo(1));
      expect(gamification.vocabMasteryScore, greaterThanOrEqualTo(0));
    });

    test('acknowledgeLevelUp resets justLeveledUp flag', () {
      final service = GamificationService();
      service.acknowledgeLevelUp();
      expect(service.justLeveledUp, isFalse);
    });
  });
}
