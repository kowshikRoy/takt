import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart'; // Keep if used for special things, otherwise remove if unused. Keeping for now as other imports might use it in project.
import 'practice/gender_practice_screen.dart';
import 'practice/compound_practice_screen.dart';
import 'practice/sentence_practice_screen.dart';
import 'practice/vocabulary_practice_screen.dart';
import '../widgets/auth_sync_dialog.dart';
import '../services/auth_service.dart';
import '../services/vocabulary_service.dart';
import '../models/saved_word.dart';
import '../services/profile_service.dart';
import 'package:provider/provider.dart';
import 'settings_screen.dart';
import 'story_reader_screen.dart';
import '../models/article_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),

          const SizedBox(height: 24),

          // Daily Session Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildDailySessionCard(context),
          ),

          const SizedBox(height: 24),

          // Practice Tools Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Practice Tools',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildPracticeGrid(context),
          ),


        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/profile.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guten Morgen!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Level 4 · Explorer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  return IconButton(
                    icon: Icon(
                      auth.isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                      color: auth.isAuthenticated ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Cloud Sync & Account',
                    onPressed: () => AuthSyncDialog.show(context),
                  );
                },
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '12 Days',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFEA580C), // orange-600
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDailySessionCard(BuildContext context) {
    return Consumer2<VocabularyService, ProfileService>(
      builder: (context, vocabService, profileService, _) {
        return FutureBuilder<List<SavedWord>>(
          future: vocabService.getDueWords(),
          builder: (context, dueSnapshot) {
            final dueWords = dueSnapshot.data ?? [];
            final dueCount = dueWords.length;

            final streak = profileService.currentStreak;
            final completedTasks = profileService.dailyTasksCompleted;
            final isGoalAchieved = profileService.isDailyGoalAchieved;

            final bool warmUpDone = profileService.todayReviewsCount > 0 || dueCount == 0;
            final bool storyDone = profileService.todayStoryRead;
            final bool saveDone = profileService.todayWordsSaved > 0;

            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isGoalAchieved
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                      : colorScheme.outlineVariant,
                  width: isGoalAchieved ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: isGoalAchieved
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Daily Session',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: streak > 0
                                            ? const Color(0xFFF9844A).withValues(alpha: 0.2)
                                            : colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            streak > 0 ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
                                            size: 14,
                                            color: streak > 0 ? const Color(0xFFD97706) : colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            streak > 0 ? '$streak Day Streak' : 'Start streak!',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: streak > 0 ? const Color(0xFFD97706) : colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isGoalAchieved
                                      ? '🎉 Daily goal achieved! Outstanding work.'
                                      : '$completedTasks of 3 daily tasks completed',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isGoalAchieved
                                            ? const Color(0xFFD97706)
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: isGoalAchieved ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                ),
                              ],
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isGoalAchieved
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                    : colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$completedTasks/3',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isGoalAchieved ? const Color(0xFFD97706) : colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Task 1: SRS Vocabulary Warm-up
                        GestureDetector(
                          onTap: () {
                            profileService.recordActivityToday(review: true);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen()),
                            );
                          },
                          child: _buildSessionItem(
                            context,
                            iconWidget: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: warmUpDone ? const Color(0xFF22C55E) : colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                warmUpDone ? Icons.check : Icons.school_rounded,
                                color: warmUpDone ? Colors.white : colorScheme.primary,
                                size: 14,
                              ),
                            ),
                            title: warmUpDone
                                ? 'Warm-up: Vocabulary (Completed)'
                                : 'Warm-up: $dueCount words due for review',
                            isCompleted: warmUpDone,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Task 2: German Reading Lesson
                        GestureDetector(
                          onTap: () {
                            profileService.recordActivityToday(story: true);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoryReaderScreen(
                                  article: Article(
                                    id: 'cl1',
                                    title: 'Wüsten der Welt: Die Sahara',
                                    description: 'Extremtemperaturen und faszinierende Dünenlandschaften.',
                                    level: 'B1',
                                    date: DateTime.now(),
                                    imageUrl: 'assets/images/story_desert.png',
                                  ),
                                ),
                              ),
                            );
                          },
                          child: _buildSessionItem(
                            context,
                            iconWidget: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: storyDone ? const Color(0xFF22C55E) : colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: storyDone
                                    ? null
                                    : Border.all(color: colorScheme.primary, width: 2),
                              ),
                              child: Icon(
                                storyDone ? Icons.check : Icons.menu_book_rounded,
                                color: storyDone ? Colors.white : colorScheme.primary,
                                size: 14,
                              ),
                            ),
                            title: storyDone
                                ? 'Lesson: Die Sahara (Read Today)'
                                : 'Lesson: Die Sahara (Tap to Read)',
                            isCompleted: storyDone,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Task 3: Discovery Word Capture
                        _buildSessionItem(
                          context,
                          iconWidget: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: saveDone ? const Color(0xFF22C55E) : colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              saveDone ? Icons.check : Icons.bookmark_add_rounded,
                              color: saveDone ? Colors.white : colorScheme.primary,
                              size: 14,
                            ),
                          ),
                          title: saveDone
                              ? 'Challenge: Captured 1 word today!'
                              : 'Challenge: Save 1 word from Discover/Dictionary',
                          isCompleted: saveDone,
                        ),

                        const SizedBox(height: 20),

                        // Daily Review Item (Dynamic SRS Unlock)
                        FutureBuilder<List<SavedWord>>(
                          future: vocabService.getSavedWords(),
                          builder: (context, snapshot) {
                            final savedCount = snapshot.hasData ? snapshot.data!.length : 0;
                            final isUnlocked = savedCount >= 5;
                            return InkWell(
                              onTap: () {
                                if (isUnlocked) {
                                  profileService.recordActivityToday(review: true);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen()),
                                  );
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.lock_outline_rounded, color: Colors.orange),
                                          SizedBox(width: 10),
                                          Text('Daily Review Locked'),
                                        ],
                                      ),
                                      content: Text(
                                        'Daily Spaced Repetition (SRS) review unlocks after saving 5 words to your dictionary.\n\n'
                                        'You currently have $savedCount / 5 words saved. Visit the Learn tab or Dictionary to save more words!',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Got it'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                      : colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isUnlocked
                                        ? colorScheme.primary.withValues(alpha: 0.3)
                                        : colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isUnlocked ? Icons.style_rounded : Icons.lock_outline_rounded,
                                      color: isUnlocked ? colorScheme.primary : Colors.orange,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUnlocked
                                                ? 'Daily Review: $dueCount Due Now'
                                                : 'Daily Review (Unlock at 5 words)',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isUnlocked
                                                ? 'Review your personalized SRS vocabulary deck'
                                                : '$savedCount of 5 words saved so far',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () {
                              profileService.recordActivityToday(story: true);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StoryReaderScreen(
                                    article: Article(
                                      id: 'cl1',
                                      title: 'Wüsten der Welt: Die Sahara',
                                      description: 'Extremtemperaturen und faszinierende Dünenlandschaften.',
                                      level: 'B1',
                                      date: DateTime.now(),
                                      imageUrl: 'assets/images/story_desert.png',
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(storyDone ? 'Read Again: Die Sahara' : 'Continue Lesson: Die Sahara'),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionItem(BuildContext context, {required Widget iconWidget, required String title, bool isCompleted = false, bool isLocked = false}) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
             color: isLocked ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
             decoration: isCompleted ? TextDecoration.lineThrough : null,
             decorationColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeGrid(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 600;

    return isWide
        ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPracticeCard(context, title: 'Der Die Das', subtitle: 'Gender Trainer', icon: Icons.swipe_rounded, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).brightness == Brightness.light ? const Color(0xFFEFF6FF) : const Color(0xFF1E3A8A).withValues(alpha: 0.3), Theme.of(context).brightness == Brightness.light ? const Color(0xFFFDF2F8) : const Color(0xFF831843).withValues(alpha: 0.3)]), borderColor: const Color(0xFFDBEAFE), iconColor: const Color(0xFF3B82F6), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GenderPracticeScreen())), child: Row(children: const [CircleAvatar(radius: 3, backgroundColor: AppTheme.genderMasc), SizedBox(width: 4), CircleAvatar(radius: 3, backgroundColor: AppTheme.genderFem), SizedBox(width: 4), CircleAvatar(radius: 3, backgroundColor: AppTheme.genderNeu)]))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPracticeCard(context, title: 'Case Color', subtitle: 'Sentence Builder', icon: Icons.palette_rounded, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).brightness == Brightness.light ? const Color(0xFFFFF7ED) : const Color(0xFF7C2D12).withValues(alpha: 0.3), Theme.of(context).brightness == Brightness.light ? const Color(0xFFFEFCE8) : const Color(0xFF713F12).withValues(alpha: 0.3)]), borderColor: const Color(0xFFFFEDD5), iconColor: const Color(0xFFF97316), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SentencePracticeScreen())), child: SizedBox(height: 16, width: 48, child: Stack(children: [Positioned(left: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))), Positioned(left: 12, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))), Positioned(left: 24, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFF87171), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1))))])))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildCompoundPracticeCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSrsPracticeCard(context)),
                ],
              ),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPracticeCard(context, title: 'Der Die Das', subtitle: 'Gender Trainer', icon: Icons.swipe_rounded, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).brightness == Brightness.light ? const Color(0xFFEFF6FF) : const Color(0xFF1E3A8A).withValues(alpha: 0.3), Theme.of(context).brightness == Brightness.light ? const Color(0xFFFDF2F8) : const Color(0xFF831843).withValues(alpha: 0.3)]), borderColor: const Color(0xFFDBEAFE), iconColor: const Color(0xFF3B82F6), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GenderPracticeScreen())), child: Row(children: const [CircleAvatar(radius: 3, backgroundColor: AppTheme.genderMasc), SizedBox(width: 4), CircleAvatar(radius: 3, backgroundColor: AppTheme.genderFem), SizedBox(width: 4), CircleAvatar(radius: 3, backgroundColor: AppTheme.genderNeu)]))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPracticeCard(context, title: 'Case Color', subtitle: 'Sentence Builder', icon: Icons.palette_rounded, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).brightness == Brightness.light ? const Color(0xFFFFF7ED) : const Color(0xFF7C2D12).withValues(alpha: 0.3), Theme.of(context).brightness == Brightness.light ? const Color(0xFFFEFCE8) : const Color(0xFF713F12).withValues(alpha: 0.3)]), borderColor: const Color(0xFFFFEDD5), iconColor: const Color(0xFFF97316), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SentencePracticeScreen())), child: SizedBox(height: 16, width: 48, child: Stack(children: [Positioned(left: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))), Positioned(left: 12, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))), Positioned(left: 24, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFF87171), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1))))])))),
                ],
              ),
              const SizedBox(height: 12),
              _buildCompoundPracticeCard(context),
              const SizedBox(height: 12),
              _buildSrsPracticeCard(context),
            ],
          );
  }

  Widget _buildSrsPracticeCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Theme.of(context).brightness == Brightness.light ? const Color(0xFFF3E8FF) : const Color(0xFF581C87).withValues(alpha: 0.3),
            Theme.of(context).brightness == Brightness.light ? const Color(0xFFFCE7F3) : const Color(0xFF831843).withValues(alpha: 0.3),
          ]),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: const Icon(Icons.style_rounded, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SRS Flashcard Practice',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Review due words with SuperMemo-2',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.purple, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompoundPracticeCard(BuildContext context) {
    return Card(
       elevation: 0,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(16),
         side: BorderSide(color: const Color(0xFFD1FAE5)), // Custom color for visual distinctiveness
       ),
       clipBehavior: Clip.antiAlias,
       child: Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(colors: [
             Theme.of(context).brightness == Brightness.light ? const Color(0xFFECFDF5) : const Color(0xFF064E3B).withValues(alpha: 0.3),
             Theme.of(context).brightness == Brightness.light ? const Color(0xFFF0FDFA) : const Color(0xFF134E4A).withValues(alpha: 0.3),
           ]),
         ),
         child: InkWell(
           onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompoundPracticeScreen())),
           child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: const Icon(Icons.extension_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compound Puzzle', 
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Build massive words', 
                         style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF34D399), size: 28),
              ],
            ),
           ),
         ),
       ),
    );
  }

  Widget _buildPracticeCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Gradient gradient, required Color borderColor, required Color iconColor, required Widget child, VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
         height: 160,
         decoration: BoxDecoration(gradient: gradient),
         child: InkWell(
           onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(height: 16), 
                      Text(
                        title,                  
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,                  
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  child,
                ],
              ),
            ),
         ),
      ),
    );
  }


}
