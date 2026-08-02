import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_word.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Home screen "Today's Words" card — a curated set of N frequency-ranked
/// words (default 5, user-configurable in Settings) pulled via the
/// dictionary frequency endpoint. Tapping a word saves it into the SM-2
/// queue. See design doc §3.4.
class TodayWordsCard extends StatefulWidget {
  const TodayWordsCard({super.key});

  @override
  State<TodayWordsCard> createState() => _TodayWordsCardState();
}

class _TodayWordsCardState extends State<TodayWordsCard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _candidates = [];
  final Set<String> _savingInFlight = {};
  final Set<String> _savedWords = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final goalCount = ProfileService().dailyWordGoalCount;
    final fetched = await DictionaryService().getHighFrequencyWords(limit: goalCount * 4);

    final result = <Map<String, dynamic>>[];
    for (final entry in fetched) {
      final wordStr = entry['word'] as String?;
      if (wordStr == null || wordStr.trim().isEmpty) continue;
      final alreadySaved = await VocabularyService().isWordSaved(wordStr);
      if (alreadySaved) continue;
      if (result.any((e) => (e['word'] as String?)?.toLowerCase() == wordStr.toLowerCase())) continue;
      result.add(entry);
      if (result.length >= goalCount) break;
    }

    if (mounted) {
      setState(() {
        _candidates = result;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWord(Map<String, dynamic> entry) async {
    final wordStr = entry['word'] as String;
    if (_savingInFlight.contains(wordStr) || _savedWords.contains(wordStr)) return;

    setState(() => _savingInFlight.add(wordStr));

    final newWord = SavedWord(
      id: 'freq_${DateTime.now().millisecondsSinceEpoch}',
      word: wordStr,
      gender: entry['gender'] as String?,
      pos: entry['pos'] as String?,
      ipa: entry['ipa'] as String?,
      primaryDefinition: (entry['definition'] as String?)?.trim().isNotEmpty == true
          ? entry['definition'] as String
          : 'No definition available',
    );

    await VocabularyService().upsertWord(newWord);
    await ProfileService().recordActivityToday(wordSaved: true);

    if (mounted) {
      setState(() {
        _savingInFlight.remove(wordStr);
        _savedWords.add(wordStr);
      });
    }
  }

  Color _genderColor(String? gender) {
    switch (gender) {
      case 'm':
      case 'masculine':
      case 'der':
        return AppTheme.genderMasc;
      case 'f':
      case 'feminine':
      case 'die':
        return AppTheme.genderFem;
      case 'n':
      case 'neuter':
      case 'das':
        return AppTheme.genderNeu;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalCount = ProfileService().dailyWordGoalCount;
    final savedCount = _savedWords.length;
    final allDone = !_isLoading && _candidates.isEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Words",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$savedCount/$goalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a word to add it to your review queue',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (allDone)
              _buildEmptyState(context)
            else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _buildWordTile(context, _candidates[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Image.asset('assets/images/cat.png', width: 44, height: 44)
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut, begin: const Offset(0.4, 0.4)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "You're all caught up on today's picks! Check back tomorrow for more.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildWordTile(BuildContext context, Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final wordStr = entry['word'] as String;
    final isSaving = _savingInFlight.contains(wordStr);
    final isSaved = _savedWords.contains(wordStr);
    final gender = entry['gender'] as String?;

    return GestureDetector(
      onTap: isSaved ? null : () => _saveWord(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSaved ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSaved ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (gender != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _genderColor(gender), shape: BoxShape.circle),
                  ),
                if (gender != null) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wordStr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              (entry['definition'] as String?) ?? '',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      isSaved ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      size: 18,
                      color: isSaved ? Colors.green : theme.colorScheme.primary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
