import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'practice/gender_practice_screen.dart';
import 'practice/compound_practice_screen.dart';
import 'practice/sentence_practice_screen.dart';
import 'practice/vocabulary_practice_screen.dart';
import '../widgets/auth_sync_dialog.dart';
import '../services/auth_service.dart';
import '../services/vocabulary_service.dart';
import '../services/profile_service.dart';
import '../services/gamification_service.dart';
import 'package:provider/provider.dart';
import 'profile_screen.dart';
import 'story_reader_screen.dart';
import '../models/article_model.dart';
import '../widgets/today_words_card.dart';
import '../services/sync_service.dart';
import '../services/book_guide_service.dart';
import '../models/book_guide.dart';
import '../theme/books_modernist_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'books/book_detail_screen.dart';
import 'books/textbook_unit_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenLearnTab;

  const HomeScreen({super.key, this.onOpenLearnTab});

  // Single source of truth for the still-hardcoded "today's lesson" mock
  // content — was previously duplicated verbatim in two places (Task 2's
  // tap target and the bottom CTA button below it), which meant the two
  // could silently drift out of sync.
  static Article get _dailyLessonArticle => Article(
    id: 'cl1',
    title: 'Wüsten der Welt: Die Sahara',
    description: 'Extremtemperaturen und faszinierende Dünenlandschaften.',
    level: 'B1',
    date: DateTime.now(),
    imageUrl: 'assets/images/story_desert.png',
  );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await SyncService().syncNow();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modernist Header
            _buildHeader(context),
            ModernistProgressBar(progress: 1.0, height: 2),

            const SizedBox(height: 20),

            // Daily Session Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY SESSION',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDailySessionCard(context),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Words Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S WORDS",
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const TodayWordsCard(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Course Books Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COURSE BOOKS',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCourseBooksSection(context),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Practice Tools Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PRACTICE TOOLS',
                        style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w800,
                          color: BooksModernist.accentDark,
                        ),
                      ),
                      if (onOpenLearnTab != null)
                        GestureDetector(
                          onTap: onOpenLearnTab,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Structured Path',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPracticeGrid(context),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseBooksSection(BuildContext context) {
    return const _CourseBooksSection();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Consumer<ProfileService>(
                  builder: (context, profileService, _) {
                    final photoUrl = profileService.photoUrl;
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BooksModernist.accent,
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: (photoUrl != null &&
                                  photoUrl.trim().isNotEmpty &&
                                  photoUrl.startsWith('http'))
                              ? NetworkImage(photoUrl) as ImageProvider
                              : const AssetImage('assets/images/profile.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GUTEN MORGEN!',
                    style: BooksModernist.heading(size: 15, context: context),
                  ),
                  Consumer<GamificationService>(
                    builder: (context, gamification, _) {
                      return Text(
                        'Level ${gamification.level}',
                        style: BooksModernist.body(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
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
                      auth.isAuthenticated
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_queue_rounded,
                      color: auth.isAuthenticated
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Cloud Sync & Account',
                    onPressed: () => AuthSyncDialog.show(context),
                  );
                },
              ),
              const SizedBox(width: 4),
              Consumer<ProfileService>(
                builder: (context, profileService, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: BooksModernist.accent100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: BooksModernist.accent200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: BooksModernist.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profileService.currentStreak} Days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: BooksModernist.accentDark,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySessionCard(BuildContext context) {
    return Consumer2<VocabularyService, ProfileService>(
      builder: (context, vocabService, profileService, _) {
        final dueCount = vocabService.cachedDueCount;
        final savedCount = vocabService.cachedSavedCount;

        final completedTasks = profileService.dailyTasksCompleted;
        final isGoalAchieved = profileService.isDailyGoalAchieved;

        final bool warmUpDone = profileService.todayReviewsCount > 0 || dueCount == 0;
        final bool storyDone = profileService.todayStoryRead;
        final bool saveDone = profileService.todayWordsSaved > 0;

        final bool isUnlocked = savedCount >= 5;
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: isGoalAchieved
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                  : colorScheme.outlineVariant,
              width: isGoalAchieved ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Tasks',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                              article: _dailyLessonArticle,
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
                    InkWell(
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
                                'Daily review unlocks after saving 5 words to your dictionary.\n\n'
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
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
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
                                        ? 'Review your personalized vocabulary deck'
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

  Widget _buildSessionItem(
    BuildContext context, {
    required Widget iconWidget,
    required String title,
    bool isCompleted = false,
    bool isLocked = false,
  }) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLocked
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                  Expanded(
                    child: _buildPracticeCard(
                      context,
                      title: 'Der Die Das',
                      subtitle: 'Gender Trainer',
                      icon: Icons.swipe_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GenderPracticeScreen(),
                        ),
                      ),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderMasc,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderFem,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderNeu,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPracticeCard(
                      context,
                      title: 'Case Color',
                      subtitle: 'Sentence Builder',
                      icon: Icons.palette_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SentencePracticeScreen(),
                        ),
                      ),
                      child: SizedBox(
                        height: 16,
                        width: 48,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF60A5FA),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF87171),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                  Expanded(
                    child: _buildPracticeCard(
                      context,
                      title: 'Der Die Das',
                      subtitle: 'Gender Trainer',
                      icon: Icons.swipe_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GenderPracticeScreen(),
                        ),
                      ),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderMasc,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderFem,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: AppTheme.genderNeu,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPracticeCard(
                      context,
                      title: 'Case Color',
                      subtitle: 'Sentence Builder',
                      icon: Icons.palette_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SentencePracticeScreen(),
                        ),
                      ),
                      child: SizedBox(
                        height: 16,
                        width: 48,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF60A5FA),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF87171),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
      color: BooksModernist.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: BooksModernist.dividerThin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BooksModernist.accent100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BooksModernist.accent200),
                ),
                child: const Icon(
                  Icons.style_rounded,
                  color: BooksModernist.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vocabulary Flashcard Practice',
                      style: BooksModernist.heading(size: 14, context: context),
                    ),
                    Text(
                      'Review your saved vocabulary cards',
                      style: BooksModernist.body(
                        size: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BooksModernist.accentDark,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompoundPracticeCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: BooksModernist.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: BooksModernist.dividerThin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CompoundPracticeScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BooksModernist.accent100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BooksModernist.accent200),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: BooksModernist.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compound Puzzle',
                      style: BooksModernist.heading(size: 14, context: context),
                    ),
                    Text(
                      'Build massive words',
                      style: BooksModernist.body(
                        size: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BooksModernist.accentDark,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: BooksModernist.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: BooksModernist.dividerThin),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 155,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BooksModernist.accent100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: BooksModernist.accent200),
                      ),
                      child: Icon(icon, color: BooksModernist.accent, size: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: BooksModernist.heading(size: 14, context: context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: BooksModernist.body(
                        size: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

/// The "Kursbücher" entry point, restyled to the Books feature's fixed
/// Modernist identity (see lib/theme/books_modernist_style.dart) — plus a
/// "Weiterlesen" resume banner once TextbookUnitScreen has persisted a last
/// read position. Kept as its own small StatefulWidget so HomeScreen itself
/// doesn't need to become stateful just for this one section's async load.
class _CourseBooksSection extends StatefulWidget {
  const _CourseBooksSection();

  @override
  State<_CourseBooksSection> createState() => _CourseBooksSectionState();
}

class _CourseBooksSectionState extends State<_CourseBooksSection> {
  String? _resumeBookTitle;
  ChapterSummary? _resumeChapter;
  String? _resumePageLabel;
  int _resumeDone = 0;
  int _resumeTotal = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final prefs = await SharedPreferences.getInstance();
    final bookTitle = prefs.getString('books_last_read_book_title');
    final chapterNumber = prefs.getInt('books_last_read_chapter_number');
    final pageIndex = prefs.getInt('books_last_read_page_index') ?? 0;
    if (bookTitle == null || chapterNumber == null || !mounted) return;

    final service = Provider.of<BookGuideService>(context, listen: false);
    BookGuide? book;
    try {
      book = service.books.firstWhere((b) => b.title == bookTitle);
    } catch (_) {
      return;
    }
    ChapterSummary? chapter;
    try {
      chapter =
          book.chapters.firstWhere((c) => c.chapterNumber == chapterNumber);
    } catch (_) {
      return;
    }

    final unit = await service.loadTextbookUnit(chapter.jsonAssetPath);
    if (unit == null || !mounted) return;
    final allIds = unit.pages.expand((p) => p.sections.map((s) => s.id)).toSet();
    final completed = (prefs.getStringList(
              'completed_sections_unit_${unit.unitNumber}',
            ) ??
            [])
        .where(allIds.contains)
        .length;
    final page = pageIndex < unit.pages.length ? unit.pages[pageIndex] : null;

    if (mounted) {
      setState(() {
        _resumeBookTitle = bookTitle;
        _resumeChapter = chapter;
        _resumePageLabel = page != null ? 'Seite ${page.pageNumber}' : null;
        _resumeDone = completed;
        _resumeTotal = allIds.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookService = Provider.of<BookGuideService>(context);
    final books = bookService.books;
    if (books.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: BooksModernist.bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Curriculum & Guides', style: BooksModernist.heading(size: 15)),
              const ModernistTag('CEFR-PFADE'),
            ],
          ),
          const SizedBox(height: 12),
          if (_resumeChapter != null) _buildResumeBanner(context),
          ...books.map((book) => _buildBookRow(context, book)),
        ],
      ),
    );
  }

  Widget _buildResumeBanner(BuildContext context) {
    final book = Provider.of<BookGuideService>(context, listen: false)
        .books
        .firstWhere((b) => b.title == _resumeBookTitle);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextbookUnitScreen(
              chapterSummary: _resumeChapter!,
              bookTitle: book.title,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        color: BooksModernist.text,
        child: Row(
          children: [
            GrayscaleCover(
              assetPath: 'assets/images/netzwerk_a2_kapitel_01.jpg',
              width: 44,
              height: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEITERLESEN',
                    style: BooksModernist.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: BooksModernist.accent200,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Kapitel ${_resumeChapter!.chapterNumber}${_resumePageLabel != null ? ' · $_resumePageLabel' : ''}',
                    style: BooksModernist.heading(size: 15, color: BooksModernist.bg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_resumeChapter!.title} — $_resumeDone / $_resumeTotal Abschnitte',
                    style: BooksModernist.body(
                      size: 12,
                      color: BooksModernist.bg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: BooksModernist.bg),
          ],
        ),
      ),
    );
  }

  Widget _buildBookRow(BuildContext context, BookGuide book) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: BooksModernist.dividerThin)),
        ),
        child: Row(
          children: [
            GrayscaleCover(
              assetPath: book.coverImage,
              width: 52,
              height: 68,
              border: Border.all(color: BooksModernist.divider),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ModernistTag(book.cefrLevel),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.title,
                          style: BooksModernist.heading(size: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.subtitle,
                    style: BooksModernist.body(
                      size: 12,
                      color: BooksModernist.text.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${book.totalChapters} Kapitel · Wortschatz, Audio & Übungen',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w600,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: BooksModernist.text.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
