import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/connector_exercise.dart';

class ConnectorService {
  List<ConnectorExercise> _exercises = [
    ConnectorExercise(
      id: 'coord_aber',
      promptEnglish: "I like coffee, but I don't drink tea.",
      connector: 'aber',
      category: ConnectorCategory.coordinating,
      options: [
        'Ich mag Kaffee, aber ich trinke keinen Tee.',
        'Ich mag Kaffee, aber ich keinen Tee trinke.',
        'Ich mag Kaffee, dass ich trinke keinen Tee.',
        'Ich mag Kaffee, obwohl ich trinke keinen Tee.',
      ],
      correctAnswer: 'Ich mag Kaffee, aber ich trinke keinen Tee.',
      tip: "aber is coordinating — it doesn't change word order, the second clause stays normal Verb-Second.",
    ),
    ConnectorExercise(
      id: 'coord_denn',
      promptEnglish: "She's staying home, because she is sick.",
      connector: 'denn',
      category: ConnectorCategory.coordinating,
      options: [
        'Sie bleibt zu Hause, denn sie ist krank.',
        'Sie bleibt zu Hause, denn ist sie krank.',
        'Sie bleibt zu Hause, weil sie ist krank.',
        'Sie bleibt zu Hause, sondern sie ist krank.',
      ],
      correctAnswer: 'Sie bleibt zu Hause, denn sie ist krank.',
      tip: "denn is coordinating, unlike weil — the verb stays in second position, it doesn't move to the end.",
    ),
    ConnectorExercise(
      id: 'sub_weil',
      promptEnglish: "I'm learning German because I want to move to Berlin.",
      connector: 'weil',
      category: ConnectorCategory.subordinating,
      options: [
        'Ich lerne Deutsch, weil ich nach Berlin ziehen möchte.',
        'Ich lerne Deutsch, weil ich möchte nach Berlin ziehen.',
        'Ich lerne Deutsch, aber ich nach Berlin ziehen möchte.',
        'Ich lerne Deutsch, weil ich nach Berlin möchte ziehen.',
      ],
      correctAnswer: 'Ich lerne Deutsch, weil ich nach Berlin ziehen möchte.',
      tip: 'weil is subordinating — it pushes the conjugated verb (möchte) all the way to the end of its clause.',
    ),
    ConnectorExercise(
      id: 'sub_dass',
      promptEnglish: 'I know that he is tired.',
      connector: 'dass',
      category: ConnectorCategory.subordinating,
      options: [
        'Ich weiß, dass er müde ist.',
        'Ich weiß, dass er ist müde.',
        'Ich weiß, weil er müde ist.',
        'Ich weiß, dass müde er ist.',
      ],
      correctAnswer: 'Ich weiß, dass er müde ist.',
      tip: 'dass is subordinating, so the verb (ist) moves to the end — and dass introduces a fact, not a reason like weil does.',
    ),
    ConnectorExercise(
      id: 'adv_deshalb',
      promptEnglish: "It's raining, that's why I'm staying home.",
      connector: 'deshalb',
      category: ConnectorCategory.adverbialInversion,
      options: [
        'Es regnet, deshalb bleibe ich zu Hause.',
        'Es regnet, deshalb ich bleibe zu Hause.',
        'Es regnet, deshalb ich zu Hause bleibe.',
        'Es regnet, obwohl ich bleibe zu Hause.',
      ],
      correctAnswer: 'Es regnet, deshalb bleibe ich zu Hause.',
      tip: 'deshalb takes position 1, so the verb (bleibe) comes right after it and the subject (ich) moves after the verb.',
    ),
    ConnectorExercise(
      id: 'adv_trotzdem',
      promptEnglish: "It's raining, nevertheless we're going for a walk.",
      connector: 'trotzdem',
      category: ConnectorCategory.adverbialInversion,
      options: [
        'Es regnet, trotzdem gehen wir spazieren.',
        'Es regnet, trotzdem wir gehen spazieren.',
        'Es regnet, trotzdem wir spazieren gehen.',
        'Es regnet, deshalb gehen wir spazieren.',
      ],
      correctAnswer: 'Es regnet, trotzdem gehen wir spazieren.',
      tip: 'trotzdem ("nevertheless") triggers verb-subject inversion just like deshalb — and it fits a contrast here, not a reason.',
    ),
    ConnectorExercise(
      id: 'corr_entweder_oder_1',
      promptEnglish: 'We are traveling either by car or by train.',
      connector: 'entweder...oder',
      category: ConnectorCategory.correlative,
      options: [
        'Wir fahren entweder mit dem Auto oder mit dem Zug.',
        'Wir fahren entweder mit dem Auto noch mit dem Zug.',
        'Wir fahren sowohl mit dem Auto als auch mit dem Zug.',
        'Wir entweder fahren mit dem Auto oder mit dem Zug.',
      ],
      correctAnswer: 'Wir fahren entweder mit dem Auto oder mit dem Zug.',
      tip: 'entweder pairs only with oder. sowohl...als auch means "both...and", not "either...or".',
    ),
    ConnectorExercise(
      id: 'corr_sowohl_als_auch_1',
      promptEnglish: 'She speaks both German and English.',
      connector: 'sowohl...als auch',
      category: ConnectorCategory.correlative,
      options: [
        'Sie spricht sowohl Deutsch als auch Englisch.',
        'Sie spricht sowohl Deutsch noch Englisch.',
        'Sie spricht entweder Deutsch oder Englisch.',
        'Sie spricht sowohl als auch Deutsch Englisch.',
      ],
      correctAnswer: 'Sie spricht sowohl Deutsch als auch Englisch.',
      tip: 'sowohl pairs only with als auch. entweder...oder means "either...or", a different meaning entirely.',
    ),
  ];

  bool _isLoaded = false;

  static ConnectorCategory? _categoryFromKey(String? key) {
    switch (key) {
      case 'coordinating':
        return ConnectorCategory.coordinating;
      case 'subordinating':
        return ConnectorCategory.subordinating;
      case 'adverbialInversion':
        return ConnectorCategory.adverbialInversion;
      case 'correlative':
        return ConnectorCategory.correlative;
      default:
        return null;
    }
  }

  /// Loads the curated connector/word-order exercise bank from
  /// assets/connector_exercises.json, falling back to the hardcoded set above
  /// on any load/parse failure (same defensive pattern as CompoundService).
  Future<void> loadAssetConnectors() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/connector_exercises.json');
      final List data = json.decode(jsonStr);
      final loaded = <ConnectorExercise>[];
      for (final item in data) {
        final category = _categoryFromKey(item['category'] as String?);
        if (category == null) continue;
        final options = (item['options'] as List?)?.whereType<String>().toList() ?? [];
        final correctAnswer = item['correctAnswer'] as String?;
        if (options.length < 2 || correctAnswer == null || !options.contains(correctAnswer)) continue;
        loaded.add(ConnectorExercise(
          id: item['id'] as String,
          promptEnglish: item['promptEnglish'] as String,
          connector: item['connector'] as String,
          category: category,
          options: options,
          correctAnswer: correctAnswer,
          tip: item['tip'] as String? ?? '',
        ));
      }

      if (loaded.isNotEmpty) {
        _exercises = loaded;
      }
      _isLoaded = true;
    } catch (_) {}
  }

  List<ConnectorExercise> getAllExercises() {
    return List.unmodifiable(_exercises);
  }
}
