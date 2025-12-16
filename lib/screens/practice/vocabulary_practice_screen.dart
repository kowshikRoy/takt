import 'package:flutter/material.dart';
import 'sentence_practice_screen.dart';
import 'gender_practice_screen.dart';
import 'meaning_practice_screen.dart';

class VocabularyPracticeScreen extends StatelessWidget {
  const VocabularyPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Warm-up'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SentencePracticeScreen()),
                );
              },
              child: const Text('Sentence Practice'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GenderPracticeScreen()),
                );
              },
              child: const Text('Gender Practice'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MeaningPracticeScreen()),
                );
              },
              child: const Text('Meaning Practice'),
            ),
          ],
        ),
      ),
    );
  }
}
