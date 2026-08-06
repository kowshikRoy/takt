
class Article {
  final String id;
  final String title;
  final String description;
  final String level; // A1, A2, B1, etc.
  final DateTime date;
  final String imageUrl;
  final bool isLiked;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.date,
    required this.imageUrl,
    this.isLiked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'level': level,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      level: json['level'] as String? ?? 'Imported',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}
