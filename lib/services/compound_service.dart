import 'package:flutter/material.dart';
import '../models/compound_word.dart';
import 'dart:math';

class CompoundService {
  final List<CompoundWord> _compounds = [
    const CompoundWord(
      part1: 'Glüh',
      part2: 'birne',
      part1Meaning: 'Glow',
      part2Meaning: 'Pear',
      fullWord: 'Glühbirne',
      fullMeaning: 'Lightbulb',
      gender: 'Die',
      part1Subtitle: '"Glüh-"',
      part2Subtitle: '"-birne"',
      part1Icon: Icons.local_fire_department_rounded,
      part2Icon: Icons.eco_rounded,
      fullIcon: Icons.lightbulb_rounded,
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
      part1Icon: Icons.back_hand_rounded,
      part2Icon: Icons.do_not_step_rounded,
      fullIcon: Icons.pan_tool_rounded,
    ),
    const CompoundWord(
      part1: 'Fern',
      part2: 'sehen',
      part1Meaning: 'Far',
      part2Meaning: 'See',
      fullWord: 'Fernsehen',
      fullMeaning: 'Television',
      gender: 'Das',
      part1Subtitle: '"Fern-"',
      part2Subtitle: '"-sehen"',
      part1Icon: Icons.landscape_rounded,
      part2Icon: Icons.visibility_rounded,
      fullIcon: Icons.tv_rounded,
    ),
    const CompoundWord(
      part1: 'Kühl',
      part2: 'schrank',
      part1Meaning: 'Cool',
      part2Meaning: 'Cupboard',
      fullWord: 'Kühlschrank',
      fullMeaning: 'Fridge',
      gender: 'Der',
      part1Subtitle: '"Kühl-"',
      part2Subtitle: '"-schrank"',
      part1Icon: Icons.ac_unit_rounded,
      part2Icon: Icons.kitchen_rounded,
      fullIcon: Icons.kitchen_rounded,
    ),
    const CompoundWord(
      part1: 'Flug',
      part2: 'zeug',
      part1Meaning: 'Flight',
      part2Meaning: 'Stuff',
      fullWord: 'Flugzeug',
      fullMeaning: 'Airplane',
      gender: 'Das',
      part1Subtitle: '"Flug-"',
      part2Subtitle: '"-zeug"',
      part1Icon: Icons.flight_rounded,
      part2Icon: Icons.category_rounded,
      fullIcon: Icons.flight_rounded,
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
      part1Icon: Icons.translate_rounded,
      part2Icon: Icons.menu_book_rounded,
      fullIcon: Icons.menu_book_rounded,
    ),
    const CompoundWord(
      part1: 'Schild',
      part2: 'kröte',
      part1Meaning: 'Shield',
      part2Meaning: 'Toad',
      fullWord: 'Schildkröte',
      fullMeaning: 'Turtle',
      gender: 'Die',
      part1Subtitle: '"Schild-"',
      part2Subtitle: '"-kröte"',
      part1Icon: Icons.shield_rounded,
      part2Icon: Icons.pets_rounded,
      fullIcon: Icons.pets_rounded,
    ),
  ];

  CompoundWord getRandomWord() {
    final random = Random();
    return _compounds[random.nextInt(_compounds.length)];
  }

  // Get distractor meanings
  List<String> getDistractors(String correctMeaning, int count) {
    final allMeanings = _compounds.map((e) => e.fullMeaning).toSet().toList(); // Unique
    allMeanings.remove(correctMeaning);
    allMeanings.shuffle();
    if (allMeanings.length < count) {
       // Fallback if not enough words
       return allMeanings;
    }
    return allMeanings.take(count).toList();
  }
}
