import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'practice/daily_challenge_screen.dart';
import 'practice/gender_practice_screen.dart';
import 'practice/compound_practice_screen.dart';
import 'practice/sentence_practice_screen.dart';
import 'practice/vocabulary_practice_screen.dart';
import 'practice/speaking_practice_screen.dart';
import 'grammar/grammar_lessons_list_screen.dart';
import 'phrases/phrase_catalog_screen.dart';
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
import 'package:takt/l10n/app_localizations.dart';
import 'books/book_detail_screen.dart';
import 'books/textbook_unit_screen.dart';
import '../widgets/capped_width.dart';
import '../theme/breakpoints.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenLearnTab;

  const HomeScreen({super.key, this.onOpenLearnTab});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181614) : const Color(0xFFFAF6F0);
    final rustAccent = const Color(0xFF8C2D19);

    return Container(
      color: bg,
      child: RefreshIndicator(
        onRefresh: () async {
          await SyncService().syncNow();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),

              const SizedBox(height: 20),

              CappedWidth(
                maxWidth: 1000,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Daily Session Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.sectionDailySession ?? 'DAILY SESSION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: rustAccent,
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
                      AppLocalizations.of(context)?.sectionTodayWords ??
                          "TODAY'S WORDS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: rustAccent,
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
                      AppLocalizations.of(context)?.sectionCourseBooks ??
                          'COURSE BOOKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: rustAccent,
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
                          AppLocalizations.of(context)?.sectionPracticeTools ??
                              'PRACTICE TOOLS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: rustAccent,
                          ),
                        ),
                        if (onOpenLearnTab != null)
                          GestureDetector(
                            onTap: onOpenLearnTab,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.actionStructuredPath ??
                                      'Structured Path',
                                  style: TextStyle(
                                    color: rustAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: rustAccent,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseBooksSection(BuildContext context) {
    return const _CourseBooksSection();
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final headerBg = Theme.of(context).cardColor;
    final rustAccent = const Color(0xFF8C2D19);

    // Desktop's nav rail already has its own "Sync Account" button that
    // opens this exact same dialog — showing the cloud icon here too would
    // just be a second control for the same action. Mobile has no such
    // rail, so this icon stays there as the only entry point.
    final bool isDesktop = MediaQuery.sizeOf(context).width > 700;

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Capped and centered to line up with the CappedWidth content column
      // below. The 20px horizontal inset lives inside the cap so both edges
      // land on the same x position on wide desktop screens.
      child: SafeArea(
        bottom: false,
        child: CappedWidth(
          maxWidth: 1000,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                          color: inkColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: rustAccent,
                            width: 1.5,
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
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GUTEN MORGEN!',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: inkColor,
                        ),
                      ),
                      Consumer<GamificationService>(
                        builder: (context, gamification, _) {
                          return Text(
                            'Level ${gamification.level}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inkColor.withValues(alpha: 0.7),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (!isDesktop) ...[
                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    return IconButton(
                      icon: Icon(
                        auth.isAuthenticated
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_queue_rounded,
                        color: inkColor,
                      ),
                      tooltip: 'Cloud Sync & Account',
                      onPressed: () => AuthSyncDialog.show(context),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
              Consumer<ProfileService>(
                builder: (context, profileService, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: rustAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: rustAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: rustAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profileService.currentStreak} Days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rustAccent,
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
      ),
    ),
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

        final bool warmUpDone = profileService.todayReviewsCount > 0;
        final bool storyDone = profileService.todayStoryRead;
        final bool saveDone = profileService.todayWordsSaved > 0;

        final bool isUnlocked = savedCount >= 5;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
        final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
        final rustAccent = const Color(0xFF8C2D19);

        return Card(
          elevation: 0,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: isGoalAchieved
                  ? rustAccent
                  : inkColor.withValues(alpha: 0.35),
              width: isGoalAchieved ? 1.5 : 1,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isGoalAchieved
                              ? '🎉 Daily goal achieved! Outstanding work.'
                              : '$completedTasks of 3 daily tasks completed',
                          style: TextStyle(
                            fontSize: 13,
                            color: isGoalAchieved
                                ? rustAccent
                                : inkColor.withValues(alpha: 0.7),
                            fontWeight: isGoalAchieved ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: inkColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: inkColor.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(
                          '$completedTasks/3',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isGoalAchieved ? rustAccent : inkColor,
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
                        color: warmUpDone ? inkColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: inkColor, width: 1.5),
                      ),
                      child: Icon(
                        warmUpDone ? Icons.check : Icons.school_rounded,
                        color: warmUpDone ? cardBg : inkColor,
                        size: 14,
                      ),
                    ),
                    title: warmUpDone
                        ? 'Warm-up: Vocabulary (${profileService.todayReviewsCount} reviewed today)'
                        : (dueCount > 0
                            ? 'Warm-up: $dueCount words due for review'
                            : 'Warm-up: All caught up! (Tap to practice)'),
                    isCompleted: warmUpDone,
                    inkColor: inkColor,
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
                        color: storyDone ? inkColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: inkColor, width: 1.5),
                      ),
                      child: Icon(
                        storyDone ? Icons.check : Icons.menu_book_rounded,
                        color: storyDone ? cardBg : inkColor,
                        size: 14,
                      ),
                    ),
                    title: storyDone
                        ? 'Lesson: Die Sahara (Read Today)'
                        : 'Lesson: Die Sahara (Tap to Read)',
                    isCompleted: storyDone,
                    inkColor: inkColor,
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
                      color: saveDone ? inkColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: inkColor, width: 1.5),
                    ),
                    child: Icon(
                      saveDone ? Icons.check : Icons.bookmark_add_rounded,
                      color: saveDone ? cardBg : inkColor,
                      size: 14,
                    ),
                  ),
                  title: saveDone
                      ? 'Challenge: Captured 1 word today!'
                      : 'Challenge: Save 1 word from Discover/Dictionary',
                  isCompleted: saveDone,
                  inkColor: inkColor,
                ),

                const SizedBox(height: 20),

                // Daily Review Item (Dynamic SRS Unlock)
                InkWell(
                  onTap: () {
                    if (isUnlocked) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen()),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                            side: BorderSide(color: inkColor),
                          ),
                          title: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: rustAccent),
                              const SizedBox(width: 10),
                              Text(
                                'Daily Review Locked',
                                style: TextStyle(color: inkColor),
                              ),
                            ],
                          ),
                          content: Text(
                            'Daily review unlocks after saving 5 words to your Study Deck.\n\n'
                            'You currently have $savedCount / 5 words in your Study Deck. Visit the Learn tab or Dictionary to add more words!',
                            style: TextStyle(color: inkColor),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Got it',
                                style: TextStyle(color: rustAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? inkColor.withValues(alpha: 0.08)
                          : inkColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isUnlocked
                            ? inkColor.withValues(alpha: 0.4)
                            : inkColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUnlocked ? Icons.style_rounded : Icons.lock_outline_rounded,
                          color: isUnlocked ? rustAccent : inkColor.withValues(alpha: 0.5),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: inkColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isUnlocked
                                    ? 'Review your personalized Study Deck'
                                    : '$savedCount of 5 words in Study Deck so far',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: inkColor.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: inkColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Daily Challenge — one combined session pulling from vocabulary,
                // gender, compound-word, and sentence-case practice instead of
                // requiring four separate screen visits.
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DailyChallengeScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: rustAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: rustAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: rustAccent, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Challenge',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: inkColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A mixed quiz: vocabulary, gender, compounds & grammar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: inkColor.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: inkColor.withValues(alpha: 0.6),
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
    required Color inkColor,
  }) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isCompleted
                  ? inkColor.withValues(alpha: 0.6)
                  : inkColor,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSpeakingPracticeCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGrammarGuideCard(context)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildPhrasesPracticeCard(context)),
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
              _buildPhrasesPracticeCard(context),
              const SizedBox(height: 12),
              _buildGrammarGuideCard(context),
              const SizedBox(height: 12),
              _buildCompoundPracticeCard(context),
              const SizedBox(height: 12),
              _buildSrsPracticeCard(context),
              const SizedBox(height: 12),
              _buildSpeakingPracticeCard(context),
            ],
          );
  }

  Widget _buildPhrasesPracticeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhraseCatalogScreen()),
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
                  color: rustAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: rustAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.titlePhrasesHub ??
                          'Alltagsphrasen & Redewendungen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.subtitlePhrasesHub ??
                          '1.000+ Redemittel für Gastronomie, Small Talk & Alltag',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rustAccent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrammarGuideCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GrammarLessonsListScreen()),
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
                  color: rustAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: rustAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.titleGrammarLessons ??
                          'Grammatik-Bausteine',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.subtitleGrammarLessons ??
                          'Formulas, matrices, and teacher tips',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rustAccent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSrsPracticeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
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
                  color: rustAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.style_rounded,
                  color: rustAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.titleVocabFlashcards ??
                          'Vocabulary Flashcard Practice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.subtitleVocabFlashcards ??
                          'Review your saved vocabulary cards',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rustAccent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompoundPracticeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
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
                  color: rustAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: rustAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.titleCompoundPuzzle ??
                          'Compound Puzzle',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.subtitleCompoundPuzzle ??
                          'Build massive words',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rustAccent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakingPracticeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SpeakingPracticeScreen()),
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
                  color: rustAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: rustAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.titleSpeakingPracticeCard ??
                          'Speaking Practice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.subtitleSpeakingPracticeCard ??
                          'Speech Shadowing',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rustAccent,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = const Color(0xFF8C2D19);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: inkColor.withValues(alpha: 0.35)),
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
                        color: rustAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: rustAccent, size: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.65),
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

class _CourseBooksSection extends StatefulWidget {
  const _CourseBooksSection();

  @override
  State<_CourseBooksSection> createState() => _CourseBooksSectionState();
}

class _CourseBooksSectionState extends State<_CourseBooksSection> {
  String? _resumeBookTitle;
  ChapterSummary? _resumeChapter;
  int _resumeDone = 0;
  int _resumeTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadResumePoint();
  }

  Future<void> _loadResumePoint() async {
    final books =
        Provider.of<BookGuideService>(context, listen: false).books;
    final prefVal = await SharedPreferences.getInstance();
    for (final b in books) {
      for (final ch in b.chapters) {
        final key = 'progress_${b.title}_${ch.chapterNumber}';
        final done = prefVal.getInt(key);
        if (done != null && done > 0) {
          if (mounted) {
            setState(() {
              _resumeBookTitle = b.title;
              _resumeChapter = ch;
              _resumeDone = done;
              _resumeTotal = ch.wordCount;
            });
          }
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = Provider.of<BookGuideService>(context).books;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);

    // At Medium+, lay book rows out side-by-side instead of one very wide
    // banner row each. Each row's height is content-driven (truncated
    // title/subtitle text), so a width-aware Wrap fits better than a
    // fixed-aspect-ratio GridView here.
    final windowClass = WindowClass.of(context);
    final columns = windowClass.isAtLeastLarge
        ? 3
        : windowClass.isAtLeastExpanded
            ? 2
            : 1;

    return Column(
      children: [
        if (_resumeChapter != null && _resumeBookTitle != null)
          _buildResumeBanner(context),
        if (columns == 1)
          ...books.map((book) => _buildBookRow(context, book, inkColor))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 4,
                children: books
                    .map((book) => SizedBox(
                          width: itemWidth,
                          child: _buildBookRow(context, book, inkColor),
                        ))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildResumeBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final bannerBg = isDark ? const Color(0xFF2B2622) : const Color(0xFF1E1B18);
    final bannerText = const Color(0xFFFAF6F0);
    final rustAccent = const Color(0xFF8C2D19);

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
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: inkColor.withValues(alpha: 0.4)),
        ),
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
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: rustAccent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Kapitel ${_resumeChapter!.chapterNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: bannerText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_resumeChapter!.title} — $_resumeDone / $_resumeTotal Abschnitte',
                    style: TextStyle(
                      fontSize: 12,
                      color: bannerText.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: bannerText),
          ],
        ),
      ),
    );
  }

  Widget _buildBookRow(BuildContext context, BookGuide book, Color inkColor) {
    final rustAccent = const Color(0xFF8C2D19);

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
          border: Border(bottom: BorderSide(color: inkColor.withValues(alpha: 0.18))),
        ),
        child: Row(
          children: [
            GrayscaleCover(
              assetPath: book.coverImage,
              width: 52,
              height: 68,
              border: Border.all(color: inkColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final cefrColors = AppTheme.getCefrColors(book.cefrLevel, isDark: isDark);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cefrColors.background,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: cefrColors.border, width: 0.8),
                            ),
                            child: Text(
                              book.cefrLevel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cefrColors.foreground,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: inkColor.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${book.totalChapters} Kapitel · Wortschatz, Audio & Übungen',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rustAccent,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: inkColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
