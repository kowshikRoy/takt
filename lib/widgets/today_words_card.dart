import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/discovery_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Home screen "Today's Words" card — displays the persistent 20-word Daily Discovery Queue.
/// Tapping a word saves it to the review queue. Users can also tap "Discover More" to load more words.
class TodayWordsCard extends StatefulWidget {
  const TodayWordsCard({super.key});

  @override
  State<TodayWordsCard> createState() => _TodayWordsCardState();
}

class _TodayWordsCardState extends State<TodayWordsCard> {
  final Set<String> _savingInFlight = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DiscoveryService>(context, listen: false).loadPool();
    });
  }

  Future<void> _saveWord(BuildContext context, Map<String, dynamic> entry) async {
    final wordStr = entry['word'] as String?;
    if (wordStr == null || _savingInFlight.contains(wordStr)) return;

    setState(() => _savingInFlight.add(wordStr));

    final discoveryService = Provider.of<DiscoveryService>(context, listen: false);
    await discoveryService.saveWordFromDiscovery(entry);

    if (mounted) {
      setState(() => _savingInFlight.remove(wordStr));
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

    return Consumer<DiscoveryService>(
      builder: (context, discoveryService, _) {
        final candidates = discoveryService.pool;
        final isLoading = discoveryService.isLoading;
        final savedToday = discoveryService.savedTodayCount;
        final isEmpty = !isLoading && candidates.isEmpty;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
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
                      "Daily Discovery Queue",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$savedToday/$goalCount saved',
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
                  'Tap a word to add it to your review queue • ${candidates.length} in queue',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (isLoading && candidates.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (isEmpty)
                  _buildEmptyState(context, discoveryService)
                else
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: candidates.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index < candidates.length) {
                          return _buildWordTile(context, candidates[index]);
                        } else {
                          return _buildDiscoverMoreTile(context, discoveryService);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, DiscoveryService discoveryService) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Image.asset('assets/images/cat.png', width: 44, height: 44)
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut, begin: const Offset(0.4, 0.4)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You've reviewed all words in your queue!",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => discoveryService.discoverMore(limit: 20),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Discover 20 More Words'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordTile(BuildContext context, Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final wordStr = entry['word'] as String;
    final isSaving = _savingInFlight.contains(wordStr);
    final gender = entry['gender'] as String?;

    return GestureDetector(
      onTap: isSaving ? null : () => _saveWord(context, entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
                    decoration: BoxDecoration(
                      color: _genderColor(gender),
                      shape: BoxShape.circle,
                    ),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverMoreTile(BuildContext context, DiscoveryService discoveryService) {
    final theme = Theme.of(context);
    final isLoading = discoveryService.isLoading;

    return GestureDetector(
      onTap: isLoading ? null : () => discoveryService.discoverMore(limit: 20),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            const SizedBox(height: 8),
            Text(
              isLoading ? 'Loading...' : 'Discover\nMore Words',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
