import 'package:flutter_test/flutter_test.dart';
import 'package:takt/services/home_screen_widget_service.dart';
import 'package:takt/models/saved_word.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreenWidgetService Unit Tests', () {
    test('HomeScreenWidgetService maintains singleton instance', () {
      final s1 = HomeScreenWidgetService();
      final s2 = HomeScreenWidgetService();
      expect(identical(s1, s2), isTrue);
    });

    test('Deep link URI formatting correctly encodes German umlauts and terms', () {
      final word = 'Überraschung';
      final deepLink = 'takt://word?term=${Uri.encodeComponent(word)}';
      final parsed = Uri.parse(deepLink);

      expect(parsed.scheme, 'takt');
      expect(parsed.host, 'word');
      expect(parsed.queryParameters['term'], 'Überraschung');
    });

    test('SavedWord fullWordWithArticle formats properly for widget display', () {
      final masc = SavedWord(
        id: 'tisch',
        word: 'Tisch',
        gender: 'm',
        primaryDefinition: 'table',
      );
      expect(masc.fullWordWithArticle, 'der Tisch');

      final fem = SavedWord(
        id: 'sonne',
        word: 'Sonne',
        gender: 'f',
        primaryDefinition: 'sun',
      );
      expect(fem.fullWordWithArticle, 'die Sonne');

      final neu = SavedWord(
        id: 'haus',
        word: 'Haus',
        gender: 'n',
        primaryDefinition: 'house',
      );
      expect(neu.fullWordWithArticle, 'das Haus');
    });
  });
}
