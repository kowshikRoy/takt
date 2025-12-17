import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/story.dart';

class StoryService {
  // Use a raw GitHub URL or similar. For now, we can use a placeholder.
  // In a real app, this would be the URL to the generated JSON file.
  // Since we are mocking the "Cloud" generation, we'll try to fetch from a local file
  // or a mocked response if we can't serve files easily.
  // However, the task is to implement the "fetching from cloud" part.

  // I will use a raw githubusercontent URL that WOULD exist if this was pushed.
  // For testing purposes, I might need to mock this service or use a local asset loader
  // if the internet access is restricted or the file doesn't exist yet.

  final String _storiesUrl = 'https://raw.githubusercontent.com/username/repo/main/assets/data/stories.json';

  Future<List<Story>> fetchStories() async {
    try {
      final response = await http.get(Uri.parse(_storiesUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Story.fromJson(json)).toList();
      } else {
        // Fallback for demo if URL fails (which it will since it's fake)
        return _getMockStories();
      }
    } catch (e) {
      // Fallback for demo
      return _getMockStories();
    }
  }

  List<Story> _getMockStories() {
    return [
      Story(
        id: '1',
        title: 'Der verlorene Schlüssel',
        englishTitle: 'The Lost Key',
        difficulty: 'Beginner',
        content: 'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter...',
        vocabulary: {'Schmetterling': 'Butterfly'},
      ),
      Story(
        id: '2',
        title: 'Ein neuer Freund',
        englishTitle: 'A New Friend',
        difficulty: 'Beginner',
        content: 'Jonas ging in den Park. Er sah einen kleinen Hund. Der Hund war allein.',
        vocabulary: {'Hund': 'Dog'},
      ),
       Story(
        id: '3',
        title: 'Das Frühstück',
        englishTitle: 'The Breakfast',
        difficulty: 'Beginner',
        content: 'Maja isst gerne Brot mit Marmelade. Heute gibt es aber nur Müsli.',
        vocabulary: {'Marmelade': 'Jam'},
      ),
    ];
  }
}
