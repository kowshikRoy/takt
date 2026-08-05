import 'dart:convert';

class TextbookUnit {
  final int unitNumber;
  final String title;
  final List<String> objectives;
  final List<PageModel> pages;
  final List<GrammarModel> grammar;
  final List<RedemittelCategoryModel> redemittel;

  TextbookUnit({
    required this.unitNumber,
    required this.title,
    required this.objectives,
    required this.pages,
    required this.grammar,
    required this.redemittel,
  });

  factory TextbookUnit.fromJson(Map<String, dynamic> json) {
    // 1. Support both "unit_metadata" object and root-level metadata
    final metadata = (json['unit_metadata'] as Map<String, dynamic>?) ?? json;
    final int unitNum = metadata['unit_number'] as int? ?? 1;
    final String title = metadata['title'] as String? ?? '';
    final List<String> objectives =
        ((metadata['learning_objectives'] ?? metadata['objectives'])
                    as List<dynamic>? ??
                [])
            .map((e) => e.toString())
            .toList();

    // 2. Support pages
    final List<PageModel> pages = (json['pages'] as List<dynamic>? ?? [])
        .map((e) => PageModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // 3. Support both "grammar_reference" (map) and "grammar" (list)
    final List<GrammarModel> grammar = [];
    if (json['grammar_reference'] is Map<String, dynamic>) {
      final ref = json['grammar_reference'] as Map<String, dynamic>;
      ref.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          grammar.add(GrammarModel.fromReferenceEntry(key, val));
        }
      });
    } else if (json['grammar'] is List<dynamic>) {
      for (final g in (json['grammar'] as List<dynamic>)) {
        if (g is Map<String, dynamic>) {
          grammar.add(GrammarModel.fromJson(g));
        }
      }
    }

    // 4. Support both "redemittel" map and list
    final List<RedemittelCategoryModel> redemittel = [];
    final rawRedemittel = json['redemittel'];
    if (rawRedemittel is Map<String, dynamic>) {
      rawRedemittel.forEach((key, val) {
        redemittel.add(RedemittelCategoryModel.fromMapEntry(key, val));
      });
    } else if (rawRedemittel is List<dynamic>) {
      for (final r in rawRedemittel) {
        if (r is Map<String, dynamic>) {
          redemittel.add(RedemittelCategoryModel.fromJson(r));
        }
      }
    }

    return TextbookUnit(
      unitNumber: unitNum,
      title: title,
      objectives: objectives,
      pages: pages,
      grammar: grammar,
      redemittel: redemittel,
    );
  }
}

class PageModel {
  final int pageNumber;
  final List<SectionModel> sections;

  PageModel({required this.pageNumber, required this.sections});

  factory PageModel.fromJson(Map<String, dynamic> json) {
    return PageModel(
      pageNumber: json['page_number'] as int? ?? 1,
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((e) => SectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SectionModel {
  final String id;
  final String type;
  final String? title;
  final String? instruction;
  final String? audioId;
  final String? textContent;
  final List<ProfileModel>? profiles;
  final List<ChatMessageModel>? chatMessages;
  final List<ExerciseItemModel>? items;
  final Map<String, dynamic> rawJson;

  SectionModel({
    required this.id,
    required this.type,
    this.title,
    this.instruction,
    this.audioId,
    this.textContent,
    this.profiles,
    this.chatMessages,
    this.items,
    required this.rawJson,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    final id = (json['section_id'] ?? json['id'] ?? '') as String;
    return SectionModel(
      id: id,
      type: (json['type'] ?? 'text_block') as String,
      title: json['title'] as String?,
      instruction: json['instruction'] as String?,
      audioId: json['audio_id'] as String?,
      textContent: (json['text_content'] ?? json['text']) as String?,
      profiles: json['profiles'] != null
          ? (json['profiles'] as List<dynamic>)
              .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      chatMessages: json['chat_messages'] != null
          ? (json['chat_messages'] as List<dynamic>)
              .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
              .map((e) => ExerciseItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      rawJson: json,
    );
  }
}

class ProfileModel {
  final String id;
  final String name;
  final String text;
  final Map<String, String>? attributes;

  ProfileModel({
    required this.id,
    required this.name,
    required this.text,
    this.attributes,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
      attributes: json['attributes'] != null
          ? Map<String, String>.from(json['attributes'] as Map)
          : null,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String sender;
  final String text;
  final String? time;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.time,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      text: json['text'] as String? ?? '',
      time: json['time'] as String?,
    );
  }
}

class ExerciseItemModel {
  final String id;
  final String prompt;
  final String? answer;
  final List<String>? options;
  final String? matchTarget;

  ExerciseItemModel({
    required this.id,
    required this.prompt,
    this.answer,
    this.options,
    this.matchTarget,
  });

  factory ExerciseItemModel.fromJson(Map<String, dynamic> json) {
    return ExerciseItemModel(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String?,
      options: json['options'] != null
          ? (json['options'] as List<dynamic>).map((e) => e.toString()).toList()
          : null,
      matchTarget: json['match_target'] as String?,
    );
  }
}

class GrammarModel {
  final String title;
  final String rule;
  final List<String> examples;
  final Map<String, List<String>>? tableData;

  GrammarModel({
    required this.title,
    required this.rule,
    required this.examples,
    this.tableData,
  });

  factory GrammarModel.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>>? tables;
    if (json['table_data'] is Map<String, dynamic>) {
      tables = {};
      (json['table_data'] as Map<String, dynamic>).forEach((k, v) {
        if (v is List<dynamic>) {
          tables![k] = v.map((e) => e.toString()).toList();
        }
      });
    }

    return GrammarModel(
      title: json['title'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      examples: (json['examples'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      tableData: tables,
    );
  }

  factory GrammarModel.fromReferenceEntry(String key, Map<String, dynamic> map) {
    String title = key;
    if (key == 'genitiv') title = 'Genitiv: Name + s';
    if (key == 'perfekt') title = 'Perfekt';
    if (key == 'nebensatz_mit_weil') title = 'Nebensatz mit weil';

    final String rule = (map['rule'] ?? map['structure'] ?? '') as String;
    final List<String> examples = [];
    if (map['examples'] is List<dynamic>) {
      for (final e in (map['examples'] as List<dynamic>)) {
        examples.add(e.toString());
      }
    }
    if (map['special_cases'] is Map<String, dynamic>) {
      final sc = map['special_cases'] as Map<String, dynamic>;
      if (sc['rule'] != null) {
        examples.add('Sonderfall: ${sc['rule']}');
      }
      if (sc['examples'] is List<dynamic>) {
        for (final e in (sc['examples'] as List<dynamic>)) {
          examples.add(e.toString());
        }
      }
    }
    if (map['partizip_2_formation'] is List<dynamic>) {
      for (final item in (map['partizip_2_formation'] as List<dynamic>)) {
        if (item is Map<String, dynamic>) {
          examples.add('${item['type']} (${item['pattern']}): ${(item['examples'] as List<dynamic>? ?? []).join(', ')}');
        }
      }
    }
    return GrammarModel(title: title, rule: rule, examples: examples);
  }
}

class RedemittelCategoryModel {
  final String category;
  final List<RedemittelItemModel> items;

  RedemittelCategoryModel({required this.category, required this.items});

  factory RedemittelCategoryModel.fromJson(Map<String, dynamic> json) {
    return RedemittelCategoryModel(
      category: json['category'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) =>
              RedemittelItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory RedemittelCategoryModel.fromMapEntry(String catKey, dynamic value) {
    String title = catKey.replaceAll('_', ' ');
    title = title.isNotEmpty
        ? title[0].toUpperCase() + title.substring(1)
        : title;
    final List<RedemittelItemModel> items = [];

    if (value is List<dynamic>) {
      items.add(RedemittelItemModel(
        title: 'Allgemein',
        phrases: value.map((e) => e.toString()).toList(),
      ));
    } else if (value is Map<String, dynamic>) {
      value.forEach((subKey, subVal) {
        String subTitle = subKey.replaceAll('_', ' ');
        subTitle = subTitle.isNotEmpty
            ? subTitle[0].toUpperCase() + subTitle.substring(1)
            : subTitle;
        if (subVal is List<dynamic>) {
          items.add(RedemittelItemModel(
            title: subTitle,
            phrases: subVal.map((e) => e.toString()).toList(),
          ));
        }
      });
    }
    return RedemittelCategoryModel(category: title, items: items);
  }
}

class RedemittelItemModel {
  final String title;
  final List<String> phrases;

  RedemittelItemModel({required this.title, required this.phrases});

  factory RedemittelItemModel.fromJson(Map<String, dynamic> json) {
    return RedemittelItemModel(
      title: json['title'] as String? ?? '',
      phrases: (json['phrases'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
