
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
}
