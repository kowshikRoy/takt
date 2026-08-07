import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/vocabulary_service.dart';
import '../services/profile_service.dart';
import '../models/saved_word.dart';
import '../widgets/capped_width.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CappedWidth(
          maxWidth: 700,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 32),
                Text(
                  'Your Growth',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGrowthCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profileService, _) {
        if (profileService.justUsedStreakFreeze) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            profileService.acknowledgeStreakFreezeUsed();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Image.asset(
                      'assets/images/cat.png',
                      width: 32,
                      height: 32,
                    ).animate().scale(
                      duration: 350.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.4, 0.4),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Streak Freeze used! Your streak is safe. ❄️',
                      ),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }
        return Row(
          children: [
            if (Navigator.canPop(context)) ...[
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
                image: DecorationImage(
                  image: (profileService.photoUrl != null &&
                          profileService.photoUrl!.trim().isNotEmpty &&
                          profileService.photoUrl!.startsWith('http'))
                      ? NetworkImage(profileService.photoUrl!) as ImageProvider
                      : const AssetImage('assets/images/profile.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profileService.displayName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Display Name',
                        onPressed: () =>
                            _showEditNameDialog(context, profileService),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showLevelDialog(context, profileService),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.military_tech_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Level: ${profileService.targetLevel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        profileService.joinDateFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
    final controller = TextEditingController(text: profileService.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              profileService.updateDisplayName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<ProfileService, VocabularyService>(
      builder: (context, profileService, vocabService, _) {
        final words = vocabService.cachedSavedWords;
        final wordsCount = words.length;
        final curStreak = profileService.currentStreak;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black).withValues(
                  alpha: 0.05,
                ),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
                  _buildHeatmapCalendar(context, words),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Words',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$wordsCount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Current Streak',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              if (profileService.streakFreezes > 0) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message:
                                      '${profileService.streakFreezes} streak freeze(s) available',
                                  child: const Text(
                                    '❄️',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$curStreak Days 🔥',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Vocab Level',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Lv.${vocabService.vocabLevel}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vocabService.masteredCount} Mastered',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildHeatmapCalendar(BuildContext context, List<SavedWord> words) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final Map<String, int> dailyCounts = {};
    for (final w in words) {
      final key = '${w.createdAt.year}-${w.createdAt.month}-${w.createdAt.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '12-Week Activity Heatmap',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                Text(
                  'Less ',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildHeatmapSquare(context, 0, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 1, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 2, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 3, primaryColor),
                Text(
                  ' More',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 12,
            itemBuilder: (context, colIndex) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (rowIndex) {
                    final daysAgo = (11 - colIndex) * 7 + (6 - rowIndex);
                    final date = now.subtract(Duration(days: daysAgo));
                    final key = '${date.year}-${date.month}-${date.day}';
                    final count = dailyCounts[key] ?? 0;
                    return Tooltip(
                      message: '$count words on ${date.month}/${date.day}',
                      child: _buildHeatmapSquare(context, count, primaryColor),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapSquare(
    BuildContext context,
    int count,
    Color primaryColor,
  ) {
    Color color;
    if (count == 0) {
      color = Theme.of(context).dividerColor.withValues(alpha: 0.15);
    } else if (count == 1) {
      color = primaryColor.withValues(alpha: 0.35);
    } else if (count == 2) {
      color = primaryColor.withValues(alpha: 0.65);
    } else {
      color = primaryColor;
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  void _showLevelDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
    final levels = [
      ('A1', 'Beginner', 'Basic everyday phrases and essential vocabulary'),
      ('A2', 'Elementary', 'Routine conversations and simple descriptive language'),
      ('B1', 'Intermediate', 'Connected texts, expressions, and nuanced topics'),
      ('B2', 'Upper Intermediate', 'Complex texts, abstract ideas, and fluent speech'),
      ('C1', 'Advanced', 'Specialized domain vocabulary, idioms, and subtle nuance'),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('German Proficiency Level'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: levels.map((lvl) {
                final isSelected = profileService.targetLevel == lvl.$1;
                return RadioListTile<String>(
                  value: lvl.$1,
                  groupValue: profileService.targetLevel,
                  title: Text('${lvl.$1} · ${lvl.$2}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lvl.$3, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onChanged: (val) {
                    if (val != null) {
                      profileService.setTargetLevel(val);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
