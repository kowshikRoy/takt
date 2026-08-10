import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/discovery_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Home screen "Today's Words" card — displays the persistent 20-word Daily Discovery Queue
/// with a minimal vintage editorial aesthetic.
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
        return const Color(0xFF8C2D19);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final l10n = AppLocalizations.of(context);
    final profileService = Provider.of<ProfileService>(context);
    final goalCount = profileService.dailyWordGoalCount;

    return Consumer<DiscoveryService>(
      builder: (context, discoveryService, _) {
        final candidates = discoveryService.pool;
        final isLoading = discoveryService.isLoading;
        final savedToday = discoveryService.savedTodayCount;
        final isEmpty = !isLoading && candidates.isEmpty;

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: inkColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n?.titleDailyDiscovery ?? "DAILY DISCOVERY",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: inkColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: inkColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: inkColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      l10n?.labelSavedCount(savedToday, goalCount) ?? '$savedToday / $goalCount SAVED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: inkColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n?.subtitleDailyDiscovery ?? 'Tap a word to add it to your review list',
                style: TextStyle(
                  fontSize: 12,
                  color: inkColor.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 14),
              if (isLoading && candidates.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (isEmpty)
                _buildEmptyState(context, discoveryService, inkColor, l10n)
              else
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: candidates.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      if (index < candidates.length) {
                        return _buildWordTile(context, candidates[index], inkColor, isDark);
                      } else {
                        return _buildDiscoverMoreTile(context, discoveryService, inkColor, isDark, l10n);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, DiscoveryService discoveryService, Color inkColor, AppLocalizations? l10n) {
    return Row(
      children: [
        Image.asset('assets/images/cat.png', width: 40, height: 40)
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut, begin: const Offset(0.4, 0.4)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.msgAllWordsReviewed ?? "All words in your queue reviewed!",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => discoveryService.discoverMore(limit: 20),
                icon: Icon(Icons.auto_awesome, size: 14, color: inkColor),
                label: Text(
                  l10n?.actionDiscoverMoreWords(20) ?? 'DISCOVER 20 MORE WORDS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: inkColor,
                  ),
                ),
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

  Widget _buildWordTile(BuildContext context, Map<String, dynamic> entry, Color inkColor, bool isDark) {
    final wordStr = entry['word'] as String;
    final isSaving = _savingInFlight.contains(wordStr);
    final gender = entry['gender'] as String?;
    final itemBg = isDark ? const Color(0xFF191715) : const Color(0xFFFAF6F0);

    return GestureDetector(
      onTap: isSaving ? null : () => _saveWord(context, entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 142,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: inkColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (gender != null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _genderColor(gender),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (gender != null) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wordStr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: inkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              (entry['definition'] as String?) ?? '',
              style: TextStyle(
                fontSize: 11,
                color: inkColor.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: inkColor,
                      ),
                    )
                  : Icon(
                      Icons.add_circle_outline_rounded,
                      size: 17,
                      color: inkColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverMoreTile(BuildContext context, DiscoveryService discoveryService, Color inkColor, bool isDark, AppLocalizations? l10n) {
    final isLoading = discoveryService.isLoading;
    final itemBg = isDark ? const Color(0xFF2B2622) : const Color(0xFFE8E2D7);

    return GestureDetector(
      onTap: isLoading ? null : () => discoveryService.discoverMore(limit: 20),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: inkColor.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: inkColor,
                ),
              )
            else
              Icon(
                Icons.auto_awesome,
                color: inkColor,
                size: 22,
              ),
            const SizedBox(height: 6),
            Text(
              isLoading
                  ? (l10n?.labelLoadingEllipsis ?? 'LOADING...')
                  : (l10n?.actionDiscoverMore ?? 'DISCOVER\nMORE'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: inkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
