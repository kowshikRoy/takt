enum ConnectorCategory {
  coordinating,
  subordinating,
  adverbialInversion,
  correlative,
}

class ConnectorExercise {
  final String id;
  final String promptEnglish;
  final String connector;
  final ConnectorCategory category;
  final List<String> options;
  final String correctAnswer;
  final String tip;

  ConnectorExercise({
    required this.id,
    required this.promptEnglish,
    required this.connector,
    required this.category,
    required this.options,
    required this.correctAnswer,
    required this.tip,
  });
}
