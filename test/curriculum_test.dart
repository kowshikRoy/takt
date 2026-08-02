import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/models/lesson_node.dart';
import 'package:takt/services/curriculum_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurriculumService', () {
    test('generates a linear tree where only the first node starts unlocked', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CurriculumService();
      await Future.delayed(const Duration(milliseconds: 50));

      final units = service.units;
      expect(units, isNotEmpty);
      expect(units.first.nodes, isNotEmpty);

      final flatNodes = units.expand((u) => u.nodes).toList();
      expect(flatNodes.first.unlocked, isTrue);
      expect(flatNodes.first.completed, isFalse);

      for (final node in flatNodes.skip(1)) {
        expect(node.unlocked, isFalse, reason: '${node.id} should start locked');
      }

      // Node types run in a fixed pedagogical order within each unit.
      expect(
        units.first.nodes.map((n) => n.type).toList(),
        [
          LessonNodeType.vocab,
          LessonNodeType.gender,
          LessonNodeType.compound,
          LessonNodeType.sentence,
          LessonNodeType.review,
          LessonNodeType.story,
        ],
      );
    });

    test('completing a node unlocks exactly the next node and is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CurriculumService();
      await Future.delayed(const Duration(milliseconds: 50));

      final flatBefore = service.units.expand((u) => u.nodes).toList();
      final firstId = flatBefore[0].id;
      final secondId = flatBefore[1].id;
      final thirdId = flatBefore[2].id;

      await service.completeNode(firstId);

      final flatAfter = service.units.expand((u) => u.nodes).toList();
      final first = flatAfter.firstWhere((n) => n.id == firstId);
      final second = flatAfter.firstWhere((n) => n.id == secondId);
      final third = flatAfter.firstWhere((n) => n.id == thirdId);

      expect(first.completed, isTrue);
      expect(first.unlocked, isTrue);
      expect(second.unlocked, isTrue);
      expect(second.completed, isFalse);
      expect(third.unlocked, isFalse);

      // Completing the same node again must not double-count or change state.
      await service.completeNode(firstId);
      final flatAgain = service.units.expand((u) => u.nodes).toList();
      expect(flatAgain.where((n) => n.completed).length, 1);
    });

    test('the last node of a unit unlocks the first node of the next unit', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CurriculumService();
      await Future.delayed(const Duration(milliseconds: 50));

      final unit1Nodes = service.units[0].nodes;
      for (final node in unit1Nodes) {
        await service.completeNode(node.id);
      }

      final unit2FirstNode = service.units[1].nodes.first;
      expect(unit2FirstNode.unlocked, isTrue);
      expect(unit2FirstNode.completed, isFalse);
    });

    test('mergeRemoteProgress unions completed-node ids and unlocks accordingly', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CurriculumService();
      await Future.delayed(const Duration(milliseconds: 50));

      final flat = service.units.expand((u) => u.nodes).toList();
      final firstId = flat[0].id;
      final secondId = flat[1].id;

      // Simulate a GET response reporting that another device already
      // completed the first node.
      await service.mergeRemoteProgress([firstId]);
      expect(service.completedNodeIds, contains(firstId));

      final flatAfter = service.units.expand((u) => u.nodes).toList();
      expect(flatAfter.firstWhere((n) => n.id == firstId).completed, isTrue);
      expect(flatAfter.firstWhere((n) => n.id == secondId).unlocked, isTrue);

      // Merging an id already known locally must not change anything.
      final countBefore = service.completedNodeIds.length;
      await service.mergeRemoteProgress([firstId]);
      expect(service.completedNodeIds.length, countBefore);
    });
  });
}
