/// Root model for a complete German Grammar Lesson.
class GrammarLesson {
  final String id;
  final String level; // "A1", "A2", "B1", "B2"
  final String title;
  final String subtitle;
  final String category; // "Verben & Zeiten", "Satzbau", "Kasus & Präpositionen", "Nomen & Artikel"
  final String summary;
  final List<GrammarSection> sections;

  GrammarLesson({
    required this.id,
    required this.level,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.summary,
    required this.sections,
  });

  factory GrammarLesson.fromJson(Map<String, dynamic> json) {
    return GrammarLesson(
      id: json['id'] as String,
      level: json['level'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      category: json['category'] as String,
      summary: json['summary'] as String,
      sections: (json['sections'] as List? ?? [])
          .map((e) => GrammarSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'summary': summary,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }
}

/// Polymorphic sealed class for compile-time exhaustive checking in Flutter widgets.
sealed class GrammarSection {
  final String id;
  final String type;
  final String? title;

  const GrammarSection({
    required this.id,
    required this.type,
    this.title,
  });

  factory GrammarSection.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'explanation';
    final id = json['id'] as String? ?? '';
    final title = json['title'] as String?;

    switch (type) {
      case 'explanation':
        return ExplanationSection(
          id: id,
          title: title,
          payload: json['explanation_payload'] != null
              ? ExplanationPayload.fromJson(
                  json['explanation_payload'] as Map<String, dynamic>,
                )
              : ExplanationPayload(text: ''),
        );
      case 'formula':
        return FormulaSection(
          id: id,
          title: title,
          payload: json['formula_payload'] != null
              ? FormulaPayload.fromJson(
                  json['formula_payload'] as Map<String, dynamic>,
                )
              : FormulaPayload(formulaStructure: '', blocks: []),
        );
      case 'table':
        return TableSection(
          id: id,
          title: title,
          payload: json['table_payload'] != null
              ? TablePayload.fromJson(
                  json['table_payload'] as Map<String, dynamic>,
                )
              : TablePayload(headers: [], rows: []),
        );
      case 'examples':
        return ExamplesSection(
          id: id,
          title: title,
          examples: (json['example_payload'] as List? ?? [])
              .map((e) => ExamplePayload.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      case 'exceptions':
        return ExceptionsSection(
          id: id,
          title: title,
          exceptions: (json['exception_payload'] as List? ?? [])
              .map((e) => ExceptionPayload.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      case 'tip':
        return TipSection(
          id: id,
          title: title,
          payload: json['tip_payload'] != null
              ? TipPayload.fromJson(json['tip_payload'] as Map<String, dynamic>)
              : TipPayload(title: '', content: '', isWarning: false),
        );
      default:
        return ExplanationSection(
          id: id,
          title: title,
          payload: ExplanationPayload(
            text: json['explanation_payload']?['text']?.toString() ?? '',
          ),
        );
    }
  }

  Map<String, dynamic> toJson();
}

class ExplanationSection extends GrammarSection {
  final ExplanationPayload payload;
  const ExplanationSection({
    required super.id,
    super.title,
    required this.payload,
  }) : super(type: 'explanation');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'explanation_payload': payload.toJson(),
      };
}

class FormulaSection extends GrammarSection {
  final FormulaPayload payload;
  const FormulaSection({
    required super.id,
    super.title,
    required this.payload,
  }) : super(type: 'formula');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'formula_payload': payload.toJson(),
      };
}

class TableSection extends GrammarSection {
  final TablePayload payload;
  const TableSection({
    required super.id,
    super.title,
    required this.payload,
  }) : super(type: 'table');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'table_payload': payload.toJson(),
      };
}

class ExamplesSection extends GrammarSection {
  final List<ExamplePayload> examples;
  const ExamplesSection({
    required super.id,
    super.title,
    required this.examples,
  }) : super(type: 'examples');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'example_payload': examples.map((e) => e.toJson()).toList(),
      };
}

class ExceptionsSection extends GrammarSection {
  final List<ExceptionPayload> exceptions;
  const ExceptionsSection({
    required super.id,
    super.title,
    required this.exceptions,
  }) : super(type: 'exceptions');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'exception_payload': exceptions.map((e) => e.toJson()).toList(),
      };
}

class TipSection extends GrammarSection {
  final TipPayload payload;
  const TipSection({
    required super.id,
    super.title,
    required this.payload,
  }) : super(type: 'tip');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'tip_payload': payload.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Payloads
// ---------------------------------------------------------------------------

class ExplanationPayload {
  final String text;
  final List<String>? bulletPoints;

  ExplanationPayload({required this.text, this.bulletPoints});

  factory ExplanationPayload.fromJson(Map<String, dynamic> json) =>
      ExplanationPayload(
        text: json['text'] as String? ?? '',
        bulletPoints: json['bullet_points'] != null
            ? List<String>.from(json['bullet_points'] as List)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (bulletPoints != null) 'bullet_points': bulletPoints,
      };
}

class FormulaPayload {
  final String formulaStructure;
  final List<FormulaBlock> blocks;

  FormulaPayload({required this.formulaStructure, required this.blocks});

  factory FormulaPayload.fromJson(Map<String, dynamic> json) => FormulaPayload(
        formulaStructure: json['formula_structure'] as String? ?? '',
        blocks: (json['blocks'] as List? ?? [])
            .map((e) => FormulaBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'formula_structure': formulaStructure,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };
}

class FormulaBlock {
  final String position;
  final String label;
  final String exampleWord;
  final String? colorTag; // 'primary', 'warning', 'accent', 'neutral'

  FormulaBlock({
    required this.position,
    required this.label,
    required this.exampleWord,
    this.colorTag,
  });

  factory FormulaBlock.fromJson(Map<String, dynamic> json) => FormulaBlock(
        position: json['position'] as String? ?? '',
        label: json['label'] as String? ?? '',
        exampleWord: json['example_word'] as String? ?? '',
        colorTag: json['color_tag'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'label': label,
        'example_word': exampleWord,
        if (colorTag != null) 'color_tag': colorTag,
      };
}

class TablePayload {
  final List<String> headers;
  final List<List<String>> rows;
  final String? footnote;

  TablePayload({required this.headers, required this.rows, this.footnote});

  factory TablePayload.fromJson(Map<String, dynamic> json) => TablePayload(
        headers: List<String>.from(json['headers'] as List? ?? []),
        rows: (json['rows'] as List? ?? [])
            .map((r) => List<String>.from(r as List))
            .toList(),
        footnote: json['footnote'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'headers': headers,
        'rows': rows,
        if (footnote != null) 'footnote': footnote,
      };
}

class ExamplePayload {
  final String german;
  final String english;
  final String? note;
  final List<String>? highlightedWords;

  ExamplePayload({
    required this.german,
    required this.english,
    this.note,
    this.highlightedWords,
  });

  factory ExamplePayload.fromJson(Map<String, dynamic> json) => ExamplePayload(
        german: json['german'] as String? ?? '',
        english: json['english'] as String? ?? '',
        note: json['note'] as String?,
        highlightedWords: json['highlighted_words'] != null
            ? List<String>.from(json['highlighted_words'] as List)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'german': german,
        'english': english,
        if (note != null) 'note': note,
        if (highlightedWords != null) 'highlighted_words': highlightedWords,
      };
}

class ExceptionPayload {
  final String ruleName;
  final String description;
  final List<String> exampleSentences;

  ExceptionPayload({
    required this.ruleName,
    required this.description,
    required this.exampleSentences,
  });

  factory ExceptionPayload.fromJson(Map<String, dynamic> json) => ExceptionPayload(
        ruleName: json['rule_name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        exampleSentences: List<String>.from(
          json['example_sentences'] as List? ?? [],
        ),
      );

  Map<String, dynamic> toJson() => {
        'rule_name': ruleName,
        'description': description,
        'example_sentences': exampleSentences,
      };
}

class TipPayload {
  final String title;
  final String content;
  final bool isWarning;

  TipPayload({
    required this.title,
    required this.content,
    required this.isWarning,
  });

  factory TipPayload.fromJson(Map<String, dynamic> json) => TipPayload(
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        isWarning: json['is_warning'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'is_warning': isWarning,
      };
}
