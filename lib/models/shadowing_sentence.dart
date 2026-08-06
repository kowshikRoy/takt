class ShadowingSentence {
  final String id;
  final String german;
  final String english;
  final String level;

  ShadowingSentence({
    required this.id,
    required this.german,
    required this.english,
    required this.level,
  });

  factory ShadowingSentence.fromJson(Map<String, dynamic> json) {
    return ShadowingSentence(
      id: json['id'] as String,
      german: json['german'] as String,
      english: json['english'] as String,
      level: json['level'] as String,
    );
  }
}
