class Story {
  final String title;
  final String englishTitle;
  final String content;
  final String difficulty;
  final String id;
  final Map<String, String> vocabulary;

  Story({
    required this.title,
    required this.englishTitle,
    required this.content,
    required this.difficulty,
    required this.id,
    required this.vocabulary,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      title: json['title'] ?? '',
      englishTitle: json['englishTitle'] ?? '',
      content: json['content'] ?? '',
      difficulty: json['difficulty'] ?? 'Beginner',
      id: json['id'] ?? '',
      vocabulary: Map<String, String>.from(json['vocabulary'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'englishTitle': englishTitle,
      'content': content,
      'difficulty': difficulty,
      'id': id,
      'vocabulary': vocabulary,
    };
  }
}
