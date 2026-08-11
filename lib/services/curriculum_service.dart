import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/curriculum_unit.dart';
import '../models/lesson_node.dart';
import 'sync_service.dart';
import 'analytics_service.dart';
import 'app_logger.dart';

/// Builds a linear skill tree from frequency-ranked vocabulary bands (no
/// hand-authored curriculum, no network call needed to generate the
/// structure — see §4 "Content generation"). Progress (which nodes are
/// completed) is SharedPreferences-backed locally; `unlocked`/`completed`
/// on each node are derived, not stored.
class CurriculumService extends ChangeNotifier {
  static final CurriculumService _instance = CurriculumService._internal();
  factory CurriculumService() => _instance;

  CurriculumService._internal() {
    _init();
  }

  static const String _keyCompletedNodes = 'curriculum_completed_nodes_v1';

  static const int _unitCount = 10;
  static const int _wordsPerUnit = 500;
  static const List<LessonNodeType> _nodeOrder = [
    LessonNodeType.vocab,
    LessonNodeType.gender,
    LessonNodeType.compound,
    LessonNodeType.sentence,
    LessonNodeType.review,
    LessonNodeType.story,
  ];

  static const List<Color> _unitColors = [
    Color(0xFF277DA1),
    Color(0xFFF94144),
    Color(0xFF90BE6D),
    Color(0xFFEE9B00),
    Color(0xFF9B5DE5),
    Color(0xFF43AA8B),
  ];

  static const List<IconData> _unitIcons = [
    Icons.eco_rounded,
    Icons.terrain_rounded,
    Icons.local_cafe_rounded,
    Icons.directions_bike_rounded,
    Icons.home_work_rounded,
    Icons.flight_takeoff_rounded,
    Icons.restaurant_rounded,
    Icons.celebration_rounded,
  ];

  Set<String> _completedNodeIds = {};
  List<CurriculumUnit> _units = [];

  List<CurriculumUnit> get units => _units;
  Set<String> get completedNodeIds => Set.unmodifiable(_completedNodeIds);

  Future<void> _init() async {
    final rawUnits = _generateUnits();
    try {
      final prefs = await SharedPreferences.getInstance();
      _completedNodeIds = (prefs.getStringList(_keyCompletedNodes) ?? [])
          .toSet();
    } catch (e) {
      AppLogger.error(
        "Error loading progress",
        error: e,
        tag: 'CurriculumService',
      );
    }
    _units = _applyProgress(rawUnits);
    notifyListeners();
  }

  List<CurriculumUnit> _generateUnits() {
    return List.generate(_unitCount, (i) {
      final unitId = 'unit_${i + 1}';
      final minRank = i * _wordsPerUnit + 1;
      final maxRank = (i + 1) * _wordsPerUnit;

      final nodes = List.generate(_nodeOrder.length, (j) {
        final type = _nodeOrder[j];
        return LessonNode(
          id: '${unitId}_${type.name}',
          unitId: unitId,
          order: j,
          type: type,
          targetId: type == LessonNodeType.review
              ? 'due'
              : type == LessonNodeType.story
              ? 'library'
              : '$minRank-$maxRank',
        );
      });

      return CurriculumUnit(
        id: unitId,
        title: 'Unit ${i + 1} · Words $minRank–$maxRank',
        order: i,
        icon: _unitIcons[i % _unitIcons.length],
        colorSeed: _unitColors[i % _unitColors.length],
        nodes: nodes,
      );
    });
  }

  List<CurriculumUnit> _applyProgress(List<CurriculumUnit> rawUnits) {
    final flatNodes = rawUnits.expand((u) => u.nodes).toList();
    final result = <CurriculumUnit>[];

    for (final unit in rawUnits) {
      final updatedNodes = unit.nodes.map((node) {
        final globalIndex = flatNodes.indexWhere((n) => n.id == node.id);
        final completed = _completedNodeIds.contains(node.id);
        final unlocked =
            completed ||
            globalIndex == 0 ||
            _completedNodeIds.contains(flatNodes[globalIndex - 1].id);
        return node.copyWith(unlocked: unlocked, completed: completed);
      }).toList();
      result.add(unit.copyWith(nodes: updatedNodes));
    }
    return result;
  }

  LessonNode? findNode(String nodeId) {
    for (final unit in _units) {
      for (final node in unit.nodes) {
        if (node.id == nodeId) return node;
      }
    }
    return null;
  }

  Future<void> completeNode(String nodeId) async {
    if (_completedNodeIds.contains(nodeId)) return;

    _completedNodeIds.add(nodeId);
    _units = _applyProgress(_units);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCompletedNodes, _completedNodeIds.toList());
    } catch (e) {
      AppLogger.error(
        "Error saving progress",
        error: e,
        tag: 'CurriculumService',
      );
    }

    AnalyticsService.logEvent('lesson_complete', params: {'node_id': nodeId});

    // Trigger sync per design doc §6: "after completing a lesson node".
    try {
      SyncService().requestSync();
    } catch (_) {}
  }

  /// Unions remote completed-node ids into the local set — a completed node
  /// is a fact that never becomes un-true, so a plain set union is a safe,
  /// order-independent merge (no last-write-wins risk).
  Future<void> mergeRemoteProgress(List<dynamic> remoteNodeIds) async {
    final before = _completedNodeIds.length;
    _completedNodeIds.addAll(remoteNodeIds.whereType<String>());
    if (_completedNodeIds.length == before) return;

    _units = _applyProgress(_units);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCompletedNodes, _completedNodeIds.toList());
    } catch (e) {
      AppLogger.error(
        "Error saving merged progress",
        error: e,
        tag: 'CurriculumService',
      );
    }
  }
}
