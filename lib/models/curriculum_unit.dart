import 'package:flutter/material.dart';
import 'lesson_node.dart';

/// A band of frequency-ranked vocabulary the skill tree is generated from.
/// `icon`/`colorSeed` are derived mechanically from the band for v1 — see
/// §4 "Content generation" in the design doc.
class CurriculumUnit {
  final String id;
  final String title;
  final int order;
  final IconData icon;
  final Color colorSeed;
  final List<LessonNode> nodes;

  const CurriculumUnit({
    required this.id,
    required this.title,
    required this.order,
    required this.icon,
    required this.colorSeed,
    required this.nodes,
  });

  CurriculumUnit copyWith({List<LessonNode>? nodes}) {
    return CurriculumUnit(
      id: id,
      title: title,
      order: order,
      icon: icon,
      colorSeed: colorSeed,
      nodes: nodes ?? this.nodes,
    );
  }
}
