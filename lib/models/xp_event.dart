/// Sources of XP, per docs/duolingo-style-redesign.md §3.1.
enum XpSource {
  exerciseCorrect,
  lessonComplete,
  dailyGoalMet,
  reviewCompleted,
  streakMilestone,
}

extension XpSourceData on XpSource {
  String get id {
    switch (this) {
      case XpSource.exerciseCorrect:
        return 'exercise_correct';
      case XpSource.lessonComplete:
        return 'lesson_complete';
      case XpSource.dailyGoalMet:
        return 'daily_goal_met';
      case XpSource.reviewCompleted:
        return 'review_completed';
      case XpSource.streakMilestone:
        return 'streak_milestone';
    }
  }

  int get defaultAmount {
    switch (this) {
      case XpSource.exerciseCorrect:
        return 10;
      case XpSource.lessonComplete:
        return 25;
      case XpSource.dailyGoalMet:
        return 20;
      case XpSource.reviewCompleted:
        return 5;
      case XpSource.streakMilestone:
        return 50;
    }
  }

  static XpSource fromId(String id) {
    return XpSource.values.firstWhere(
      (s) => s.id == id,
      orElse: () => XpSource.exerciseCorrect,
    );
  }
}

/// An append-only XP ledger entry. Locally persisted for now; syncs to the
/// backend as an additive log once /api/sync is extended (§6).
class XpEvent {
  final String id;
  final String? userId;
  final XpSource source;
  final int amount;
  final DateTime timestamp;

  XpEvent({
    required this.id,
    this.userId,
    required this.source,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'source': source.id,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      };

  factory XpEvent.fromJson(Map<String, dynamic> json) {
    return XpEvent(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      source: XpSourceData.fromId(json['source'] as String),
      amount: json['amount'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
