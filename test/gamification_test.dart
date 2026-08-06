import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/models/xp_event.dart';
import 'package:takt/services/gamification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XpEvent', () {
    test('source ids and default amounts match the design doc', () {
      expect(XpSource.exerciseCorrect.id, 'exercise_correct');
      expect(XpSource.exerciseCorrect.defaultAmount, 10);
      expect(XpSource.lessonComplete.defaultAmount, 25);
      expect(XpSource.dailyGoalMet.defaultAmount, 20);
      expect(XpSource.reviewCompleted.defaultAmount, 5);
      expect(XpSource.streakMilestone.defaultAmount, 50);
    });

    test('round-trips through JSON', () {
      final event = XpEvent(
        id: 'xp_1',
        userId: 'user_1',
        source: XpSource.reviewCompleted,
        amount: 5,
        timestamp: DateTime.utc(2026, 1, 1, 12),
      );
      final decoded = XpEvent.fromJson(event.toJson());
      expect(decoded.id, event.id);
      expect(decoded.userId, event.userId);
      expect(decoded.source, event.source);
      expect(decoded.amount, event.amount);
      expect(decoded.timestamp, event.timestamp);
    });
  });

  group('GamificationService', () {
    test('awardXp accumulates totalXp, computes level, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = GamificationService();

      // GamificationService() is a singleton constructed once per process;
      // wait for its async _init() (from a possibly-earlier test) to settle.
      await Future.delayed(const Duration(milliseconds: 50));
      final startingXp = service.totalXp;
      final startingEventCount = service.events.length;

      await service.awardXp(XpSource.exerciseCorrect); // +10
      expect(service.totalXp, startingXp + 10);

      await service.awardXp(XpSource.reviewCompleted); // +5
      expect(service.totalXp, startingXp + 15);

      await service.awardXp(XpSource.streakMilestone, amountOverride: 985); // push well past a level boundary
      final total = service.totalXp;
      expect(total, startingXp + 1000);

      // level = floor(sqrt(totalXp / 100)), matching GamificationService.level
      final expectedLevel = sqrt(total / 100).floor();
      expect(service.level, expectedLevel);

      expect(service.events.length, startingEventCount + 3);
      expect(service.events.last.source, XpSource.streakMilestone);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('gamification_total_xp_v1'), total);
    });

    test('justLeveledUp flips true exactly when totalXp crosses a level boundary, and acknowledge clears it', () async {
      final service = GamificationService();
      await Future.delayed(const Duration(milliseconds: 50));

      // Clear any unacknowledged flag left over from an earlier test in this
      // file (the service is a singleton shared across tests in-process).
      service.acknowledgeLevelUp();
      final levelBefore = service.level;

      // A tiny award that doesn't cross a level boundary shouldn't flag a level-up.
      await service.awardXp(XpSource.exerciseCorrect, amountOverride: 1);
      if (service.level == levelBefore) {
        expect(service.justLeveledUp, isFalse);
      }

      // Pushing well past the next level boundary should.
      const needed = 500;
      await service.awardXp(XpSource.streakMilestone, amountOverride: needed);
      expect(service.level, greaterThan(levelBefore));
      expect(service.justLeveledUp, isTrue);

      service.acknowledgeLevelUp();
      expect(service.justLeveledUp, isFalse);
    });

    test('mergeRemoteEvents unions by id without double-counting and does not trigger a level-up', () async {
      final service = GamificationService();
      await Future.delayed(const Duration(milliseconds: 50));
      service.acknowledgeLevelUp();

      final localIds = service.events.map((e) => e.id).toSet();
      final totalBefore = service.totalXp;

      // Re-merging an event already present locally must not change totalXp.
      if (localIds.isNotEmpty) {
        final existing = service.events.first;
        await service.mergeRemoteEvents([existing.toJson()]);
        expect(service.totalXp, totalBefore);
      }

      // A genuinely new remote event must be added exactly once.
      final newEvent = {
        'id': 'xp_remote_merge_test',
        'userId': 'remote_user',
        'source': 'exercise_correct',
        'amount': 10,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await service.mergeRemoteEvents([newEvent, newEvent]); // duplicate within the same payload too
      expect(service.totalXp, totalBefore + 10);
      expect(service.events.where((e) => e.id == 'xp_remote_merge_test').length, 1);

      // Merging never flags the level-up celebration (reserved for live awardXp).
      expect(service.justLeveledUp, isFalse);
    });
  });
}
