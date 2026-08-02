import 'package:flutter/material.dart';

/// Maps directly to the four existing practice screens, plus a review node
/// (SM-2 due-word batch) and a story node (opens the Library). See §4.
enum LessonNodeType { vocab, gender, compound, sentence, review, story }

extension LessonNodeTypeData on LessonNodeType {
  IconData get icon {
    switch (this) {
      case LessonNodeType.vocab:
        return Icons.style_rounded;
      case LessonNodeType.gender:
        return Icons.swipe_rounded;
      case LessonNodeType.compound:
        return Icons.link_rounded;
      case LessonNodeType.sentence:
        return Icons.palette_rounded;
      case LessonNodeType.review:
        return Icons.refresh_rounded;
      case LessonNodeType.story:
        return Icons.menu_book_rounded;
    }
  }

  String get label {
    switch (this) {
      case LessonNodeType.vocab:
        return 'Vocabulary';
      case LessonNodeType.gender:
        return 'Gender Trainer';
      case LessonNodeType.compound:
        return 'Compound Words';
      case LessonNodeType.sentence:
        return 'Sentence Builder';
      case LessonNodeType.review:
        return 'Review';
      case LessonNodeType.story:
        return 'Story';
    }
  }
}

/// A single node in the linear skill tree. `unlocked`/`completed` are
/// derived by CurriculumService from the persisted completed-node set, not
/// stored on the node itself.
class LessonNode {
  final String id;
  final String unitId;
  final int order;
  final LessonNodeType type;
  final String targetId;
  final int xpReward;
  final bool unlocked;
  final bool completed;

  const LessonNode({
    required this.id,
    required this.unitId,
    required this.order,
    required this.type,
    required this.targetId,
    required this.xpReward,
    this.unlocked = false,
    this.completed = false,
  });

  LessonNode copyWith({bool? unlocked, bool? completed}) {
    return LessonNode(
      id: id,
      unitId: unitId,
      order: order,
      type: type,
      targetId: targetId,
      xpReward: xpReward,
      unlocked: unlocked ?? this.unlocked,
      completed: completed ?? this.completed,
    );
  }
}
