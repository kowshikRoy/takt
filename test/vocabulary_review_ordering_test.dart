import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await VocabularyService.resetForTesting();
  });

  SavedWord dueWord(String id, DateTime dueDate) => SavedWord(
        id: id,
        word: id,
        primaryDefinition: 'def-$id',
        category: VocabCategory.learning,
        dueDate: dueDate,
        createdAt: dueDate,
      );

  test('getDueWords reviews the most-overdue day first, shuffling within same-day ties', () async {
    final vocab = VocabularyService();
    final now = DateTime.now();

    // 3 days overdue: a single word.
    await vocab.upsertWord(dueWord('old1', now.subtract(const Duration(days: 3))), notify: false, triggerSync: false);
    // 1 day overdue: three words tied on the same calendar day.
    await vocab.upsertWord(dueWord('mid1', now.subtract(const Duration(days: 1, hours: 1))), notify: false, triggerSync: false);
    await vocab.upsertWord(dueWord('mid2', now.subtract(const Duration(days: 1, hours: 2))), notify: false, triggerSync: false);
    await vocab.upsertWord(dueWord('mid3', now.subtract(const Duration(days: 1, hours: 3))), notify: false, triggerSync: false);
    // Due just now: a single word.
    await vocab.upsertWord(dueWord('new1', now.subtract(const Duration(minutes: 1))), notify: false, triggerSync: false);

    final result = await vocab.getDueWords();
    expect(result.map((w) => w.id).toSet(), {'old1', 'mid1', 'mid2', 'mid3', 'new1'});

    // Day-bucket order must still be oldest-overdue-first, regardless of shuffling.
    final ids = result.map((w) => w.id).toList();
    final oldIdx = ids.indexOf('old1');
    final midIdxs = ['mid1', 'mid2', 'mid3'].map(ids.indexOf).toList();
    final newIdx = ids.indexOf('new1');
    expect(oldIdx, lessThan(midIdxs.reduce((a, b) => a < b ? a : b)));
    expect(midIdxs.reduce((a, b) => a > b ? a : b), lessThan(newIdx));

    // The 3 same-day-tied words must not always land in the exact same
    // relative order every call — across enough runs, at least one
    // different ordering should appear (astronomically unlikely to fail
    // if shuffling is actually happening).
    final seenOrders = <String>{};
    for (var i = 0; i < 30; i++) {
      final r = await vocab.getDueWords();
      final midOrder = r.map((w) => w.id).where(['mid1', 'mid2', 'mid3'].contains).join(',');
      seenOrders.add(midOrder);
    }
    expect(seenOrders.length, greaterThan(1), reason: 'same-day-tied words should not always sort identically');
  });
}
