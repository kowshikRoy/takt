import 'package:flutter/material.dart';

class CompoundWord {
  final String part1; // German
  final String part2; // German
  final String part1Meaning; // English
  final String part2Meaning; // English
  final String fullWord; // German
  final String fullMeaning; // English
  final String gender; // Die/Der/Das
  final String part1Subtitle; // e.g. "Glüh-"
  final String part2Subtitle; // e.g. "-birne"
  final IconData? part1Icon;
  final IconData? part2Icon;
  final IconData? fullIcon;

  const CompoundWord({
    required this.part1,
    required this.part2,
    required this.part1Meaning,
    required this.part2Meaning,
    required this.fullWord,
    required this.fullMeaning,
    required this.gender,
    required this.part1Subtitle,
    required this.part2Subtitle,
    this.part1Icon,
    this.part2Icon,
    this.fullIcon,
  });
}
