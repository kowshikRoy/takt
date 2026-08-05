import 'dart:convert';

enum VocabCategory {
  learning,
  mastered,
  reviewLater,
  ignored,
}

enum ReviewRating {
  again, // Rating 1: Failed recall
  hard,  // Rating 2: Difficult recall
  good,  // Rating 3: Good recall
  easy,  // Rating 4: Effortless recall
}

class SavedWord {
  final String id;
  final String word;
  final String? baseForm;
  final String? pos;
  final String? gender; // m, f, n
  final String primaryDefinition;
  final List<String> definitions;
  final String? ipa;
  final String? contextSentence;
  final String? sourceTitle;

  VocabCategory category;

  // Spaced Repetition Metadata (SM-2 Algorithm)
  int interval; // In days
  double easeFactor; // Default 2.5
  int repetitions; // Consecutive successful reviews
  DateTime dueDate; // Scheduled review date
  DateTime? lastReviewed;
  DateTime createdAt;

  SavedWord({
    required this.id,
    required this.word,
    this.baseForm,
    this.pos,
    this.gender,
    required this.primaryDefinition,
    this.definitions = const [],
    this.ipa,
    this.contextSentence,
    this.sourceTitle,
    this.category = VocabCategory.learning,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    DateTime? dueDate,
    this.lastReviewed,
    DateTime? createdAt,
  })  : dueDate = dueDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isDue => category == VocabCategory.learning && DateTime.now().isAfter(dueDate);

  // Backward compatibility getters
  String get germanWord => word;
  String get translation => primaryDefinition;
  DateTime get dateSaved => createdAt;

  /// Returns 0 to 4 mastery level:
  /// Level 0: New (0 repetitions)
  /// Level 1: Apprentice (1 repetition or interval <= 3 days)
  /// Level 2: Familiar (2 repetitions or interval <= 10 days)
  /// Level 3: Proficient (3-4 repetitions or interval <= 30 days)
  /// Level 4: Mastered (5+ repetitions or interval > 30 days or category == VocabCategory.mastered)
  int get masteryLevel {
    if (category == VocabCategory.mastered) return 4;
    if (repetitions == 0) return 0;
    if (repetitions == 1 || interval <= 3) return 1;
    if (repetitions == 2 || interval <= 10) return 2;
    if (repetitions <= 4 || interval <= 30) return 3;
    return 4;
  }

  String get masteryLevelLabel {
    switch (masteryLevel) {
      case 0:
        return 'Lvl 0 • Neu';
      case 1:
        return 'Lvl 1 • Anfänger';
      case 2:
        return 'Lvl 2 • Vertraut';
      case 3:
        return 'Lvl 3 • Fortgeschritten';
      case 4:
      default:
        return 'Lvl 4 • Meister';
    }
  }

  /// Computes the next SRS state based on SM-2 algorithm rules
  SavedWord calculateNextReview(ReviewRating rating) {
    int nextInterval = interval;
    double nextEaseFactor = easeFactor;
    int nextReps = repetitions;
    final now = DateTime.now();

    switch (rating) {
      case ReviewRating.again:
        nextReps = 0;
        nextInterval = 1; // Due next day
        nextEaseFactor = (easeFactor - 0.2).clamp(1.3, 3.0);
        break;

      case ReviewRating.hard:
        nextReps = nextReps + 1;
        nextInterval = (interval == 0 ? 1 : (interval * 1.2).round()).clamp(1, 365);
        nextEaseFactor = (easeFactor - 0.15).clamp(1.3, 3.0);
        break;

      case ReviewRating.good:
        nextReps = nextReps + 1;
        if (nextReps == 1) {
          nextInterval = 1;
        } else if (nextReps == 2) {
          nextInterval = 6;
        } else {
          nextInterval = (interval * easeFactor).round().clamp(1, 365);
        }
        break;

      case ReviewRating.easy:
        nextReps = nextReps + 1;
        if (nextReps == 1) {
          nextInterval = 4;
        } else if (nextReps == 2) {
          nextInterval = 10;
        } else {
          nextInterval = (interval * easeFactor * 1.3).round().clamp(1, 365);
        }
        nextEaseFactor = (easeFactor + 0.15).clamp(1.3, 3.0);
        break;
    }

    final nextDueDate = now.add(Duration(days: nextInterval));

    return SavedWord(
      id: id,
      word: word,
      baseForm: baseForm,
      pos: pos,
      gender: gender,
      primaryDefinition: primaryDefinition,
      definitions: definitions,
      ipa: ipa,
      contextSentence: contextSentence,
      sourceTitle: sourceTitle,
      category: category,
      interval: nextInterval,
      easeFactor: nextEaseFactor,
      repetitions: nextReps,
      dueDate: nextDueDate,
      lastReviewed: now,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'baseForm': baseForm,
        'pos': pos,
        'gender': gender,
        'primaryDefinition': primaryDefinition,
        'definitions': definitions,
        'ipa': ipa,
        'contextSentence': contextSentence,
        'sourceTitle': sourceTitle,
        'category': category.name,
        'interval': interval,
        'easeFactor': easeFactor,
        'repetitions': repetitions,
        'dueDate': dueDate.toIso8601String(),
        'lastReviewed': lastReviewed?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedWord.fromJson(Map<String, dynamic> jsonMap) {
    List<String> defs = [];
    if (jsonMap['definitions'] is List) {
      defs = List<String>.from(jsonMap['definitions']);
    } else if (jsonMap['definitions'] is String) {
      try {
        defs = List<String>.from(jsonDecode(jsonMap['definitions']));
      } catch (_) {}
    }
    return SavedWord(
      id: jsonMap['id'] as String? ?? jsonMap['word'].toString().toLowerCase().trim(),
      word: jsonMap['word'] as String? ?? '',
      baseForm: jsonMap['baseForm'] as String?,
      pos: jsonMap['pos'] as String?,
      gender: jsonMap['gender'] as String?,
      primaryDefinition: jsonMap['primaryDefinition'] as String? ?? jsonMap['word'] as String? ?? '',
      definitions: defs,
      ipa: jsonMap['ipa'] as String?,
      contextSentence: jsonMap['contextSentence'] as String?,
      sourceTitle: jsonMap['sourceTitle'] as String?,
      category: VocabCategory.values.firstWhere(
        (e) => e.name == jsonMap['category'],
        orElse: () => VocabCategory.learning,
      ),
      interval: (jsonMap['interval'] as num?)?.toInt() ?? 0,
      easeFactor: (jsonMap['easeFactor'] as num?)?.toDouble() ?? 2.5,
      repetitions: (jsonMap['repetitions'] as num?)?.toInt() ?? 0,
      dueDate: jsonMap['dueDate'] != null ? DateTime.tryParse(jsonMap['dueDate'] as String) ?? DateTime.now() : DateTime.now(),
      lastReviewed: jsonMap['lastReviewed'] != null ? DateTime.tryParse(jsonMap['lastReviewed'] as String) : null,
      createdAt: jsonMap['createdAt'] != null ? DateTime.tryParse(jsonMap['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'word': word,
        'baseForm': baseForm,
        'pos': pos,
        'gender': gender,
        'primaryDefinition': primaryDefinition,
        'definitions': jsonEncode(definitions),
        'ipa': ipa,
        'contextSentence': contextSentence,
        'sourceTitle': sourceTitle,
        'category': category.name,
        'interval': interval,
        'easeFactor': easeFactor,
        'repetitions': repetitions,
        'dueDate': dueDate.toIso8601String(),
        'lastReviewed': lastReviewed?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedWord.fromMap(Map<String, dynamic> map) => SavedWord(
        id: map['id'] as String,
        word: map['word'] as String,
        baseForm: map['baseForm'] as String?,
        pos: map['pos'] as String?,
        gender: map['gender'] as String?,
        primaryDefinition: map['primaryDefinition'] as String? ?? '',
        definitions: map['definitions'] != null
            ? List<String>.from(jsonDecode(map['definitions'] as String))
            : [],
        ipa: map['ipa'] as String?,
        contextSentence: map['contextSentence'] as String?,
        sourceTitle: map['sourceTitle'] as String?,
        category: VocabCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => VocabCategory.learning,
        ),
        interval: (map['interval'] as num?)?.toInt() ?? 0,
        easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
        repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : DateTime.now(),
        lastReviewed: map['lastReviewed'] != null ? DateTime.parse(map['lastReviewed'] as String) : null,
        createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      );
}
