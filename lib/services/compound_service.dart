import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/compound_word.dart';

class CompoundService {
  List<CompoundWord> _compounds = [
    const CompoundWord(
      part1: 'Glüh',
      part2: 'birne',
      part1Meaning: 'Glow',
      part2Meaning: 'Pear',
      fullWord: 'Glühbirne',
      fullMeaning: 'Light bulb',
      gender: 'Die',
      part1Subtitle: '"Glüh-"',
      part2Subtitle: '"-birne"',
    ),
    const CompoundWord(
      part1: 'Hand',
      part2: 'schuh',
      part1Meaning: 'Hand',
      part2Meaning: 'Shoe',
      fullWord: 'Handschuh',
      fullMeaning: 'Glove',
      gender: 'Der',
      part1Subtitle: '"Hand-"',
      part2Subtitle: '"-schuh"',
    ),
    const CompoundWord(
      part1: 'Fern',
      part2: 'sehen',
      part1Meaning: 'Remote',
      part2Meaning: 'See',
      fullWord: 'Fernsehen',
      fullMeaning: 'Tv',
      gender: 'Das',
      part1Subtitle: '"Fern-"',
      part2Subtitle: '"-sehen"',
    ),
    const CompoundWord(
      part1: 'Kühl',
      part2: 'schrank',
      part1Meaning: 'Cool',
      part2Meaning: 'Wardrobe',
      fullWord: 'Kühlschrank',
      fullMeaning: 'Refrigerator',
      gender: 'Der',
      part1Subtitle: '"Kühl-"',
      part2Subtitle: '"-schrank"',
    ),
    const CompoundWord(
      part1: 'Flug',
      part2: 'zeug',
      part1Meaning: 'Flight',
      part2Meaning: 'Things',
      fullWord: 'Flugzeug',
      fullMeaning: 'Airplane',
      gender: 'Das',
      part1Subtitle: '"Flug-"',
      part2Subtitle: '"-zeug"',
    ),
    const CompoundWord(
      part1: 'Wörter',
      part2: 'buch',
      part1Meaning: 'Words',
      part2Meaning: 'Book',
      fullWord: 'Wörterbuch',
      fullMeaning: 'Dictionary',
      gender: 'Das',
      part1Subtitle: '"Wörter-"',
      part2Subtitle: '"-buch"',
    ),
    const CompoundWord(
      part1: 'Schild',
      part2: 'kröte',
      part1Meaning: 'Sign',
      part2Meaning: 'Toad',
      fullWord: 'Schildkröte',
      fullMeaning: 'Tortoise',
      gender: 'Die',
      part1Subtitle: '"Schild-"',
      part2Subtitle: '"-kröte"',
    ),
    const CompoundWord(
      part1: 'Regen',
      part2: 'schirm',
      part1Meaning: 'Rain',
      part2Meaning: 'Screen',
      fullWord: 'Regenschirm',
      fullMeaning: 'Umbrella',
      gender: 'Der',
      part1Subtitle: '"Regen-"',
      part2Subtitle: '"-schirm"',
    ),
    const CompoundWord(
      part1: 'Zahn',
      part2: 'bürste',
      part1Meaning: 'Tooth',
      part2Meaning: 'Brush',
      fullWord: 'Zahnbürste',
      fullMeaning: 'Toothbrush',
      gender: 'Die',
      part1Subtitle: '"Zahn-"',
      part2Subtitle: '"-bürste"',
    ),
    const CompoundWord(
      part1: 'Fahr',
      part2: 'rad',
      part1Meaning: 'Drive',
      part2Meaning: 'Wheel',
      fullWord: 'Fahrrad',
      fullMeaning: 'Bicycle',
      gender: 'Das',
      part1Subtitle: '"Fahr-"',
      part2Subtitle: '"-rad"',
    ),
  ];

  bool _isLoaded = false;

  /// Loads verified programmatic compounds from assets/compound_words.json
  Future<void> loadAssetCompounds() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/compound_words.json');
      final List data = json.decode(jsonStr);
      final loaded = data.map((item) => CompoundWord(
        part1: item['part1'],
        part2: item['part2'],
        part1Meaning: item['part1Meaning'],
        part2Meaning: item['part2Meaning'],
        fullWord: item['fullWord'],
        fullMeaning: item['fullMeaning'],
        gender: item['gender'],
        part1Subtitle: item['part1Subtitle'],
        part2Subtitle: item['part2Subtitle'],
      )).toList();

      if (loaded.isNotEmpty) {
        _compounds = loaded;
      }
      _isLoaded = true;
    } catch (_) {}
  }

  CompoundWord getRandomWord() {
    final random = Random();
    return _compounds[random.nextInt(_compounds.length)];
  }

  List<CompoundWord> getAllWords() {
    return List.unmodifiable(_compounds);
  }

  // Get distractor meanings
  List<String> getDistractors(String correctMeaning, int count) {
    final allMeanings = _compounds.map((e) => e.fullMeaning).toSet().toList(); // Unique
    allMeanings.remove(correctMeaning);
    allMeanings.shuffle();
    if (allMeanings.length < count) {
       return allMeanings;
    }
    return allMeanings.take(count).toList();
  }
}
