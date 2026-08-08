// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Takt';

  @override
  String get navHome => 'Home';

  @override
  String get navLearn => 'Learn';

  @override
  String get navDictionary => 'Dictionary';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionGrammar => 'Grammar';

  @override
  String get actionPractice => 'Practice';

  @override
  String get actionAddAllToLearning => 'Add all to Learning';

  @override
  String get actionListen => 'Listen';

  @override
  String get actionGrammarForms => 'Grammar & Forms';

  @override
  String get actionShowTranslation => 'Show Translations';

  @override
  String get actionHideTranslation => 'Hide Translations';

  @override
  String get actionCheck => 'Check Answer';

  @override
  String get actionNext => 'Next';

  @override
  String get actionFinish => 'Finish';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionContinue => 'Continue';

  @override
  String get sectionDailySession => 'DAILY SESSION';

  @override
  String get sectionBooks => 'Course Books';

  @override
  String get labelNewWordsToday => 'New Words Today';

  @override
  String get labelStreak => 'Streak';

  @override
  String get titleKeyVocab => 'Key Vocabulary';

  @override
  String get subtitleKeyVocab => 'Important German vocabulary from transcript';

  @override
  String get titleFullCues => 'Full Cues';

  @override
  String get msgExtractingVocab => 'Extracting key vocabulary...';

  @override
  String get msgNoVocab => 'No key vocabulary extracted yet.';

  @override
  String get titleProcessMedia => 'Process Media';

  @override
  String get labelMediaUrl => 'Media URL';

  @override
  String get labelAudioStream => 'Audio Media Stream';

  @override
  String get labelArticleMode => 'Article Mode';

  @override
  String get titleGenderPractice => 'Gender Practice';

  @override
  String get titleCompoundPractice => 'Compound Practice';

  @override
  String get titleSentencePractice => 'Sentence Building';

  @override
  String get titleVocabPractice => 'Vocabulary Deck';

  @override
  String get msgCorrect => 'Correct!';

  @override
  String get msgTryAgain => 'Try Again';

  @override
  String get titleSettings => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get labelAppTheme => 'App Theme';

  @override
  String get labelColorPalette => 'Color Palette';

  @override
  String get labelTypography => 'Typography';

  @override
  String get sectionPracticeLearning => 'Practice & Learning';

  @override
  String get labelDailyGoal => 'Daily Word Goal';

  @override
  String get labelSoundEffects => 'Sound Effects';

  @override
  String get labelGermanVoice => 'German Voice (TTS)';

  @override
  String get subtitleGermanVoice => 'Voice used for spoken German audio';

  @override
  String get labelSystemDefaultVoice => 'System Default';

  @override
  String get subtitleSystemDefaultVoice => 'Default speech engine';

  @override
  String get titleSelectGermanVoice => 'Select German Voice';

  @override
  String get labelSpeechRate => 'Speech Speed';

  @override
  String get msgNoVoicesDetected =>
      'Using system default voice. No additional voices found on this device.';

  @override
  String get titleProfile => 'Profile';

  @override
  String get titleDailyDiscovery => 'DAILY DISCOVERY';

  @override
  String get subtitleDailyDiscovery =>
      'Tap a word to add it to your Study Deck';

  @override
  String labelSavedCount(int saved, int goal) {
    return '$saved / $goal IN DECK';
  }

  @override
  String get msgAllWordsReviewed => 'All words in your queue reviewed!';

  @override
  String actionDiscoverMoreWords(int count) {
    return 'DISCOVER $count MORE WORDS';
  }

  @override
  String get labelLoadingEllipsis => 'LOADING...';

  @override
  String get actionDiscoverMore => 'DISCOVER\nMORE';

  @override
  String get titleGrammarLessons => 'Grammar Guides';

  @override
  String get subtitleGrammarLessons => 'Formulas, matrices, and teacher tips';

  @override
  String get sectionStructuredRoadmap => 'STRUCTURED GRAMMAR ROADMAP';

  @override
  String labelLessonsCompleted(int completed, int total) {
    return '$completed of $total Lessons Completed';
  }

  @override
  String get hintSearchGrammar => 'Search (e.g. Modalverben, weil, Perfekt)...';

  @override
  String get labelAll => 'All';

  @override
  String get msgNoLessonsFound => 'No lessons found';

  @override
  String get msgTryDifferentFilter => 'Try a different filter or search term.';

  @override
  String get labelLessonDone => 'Done';

  @override
  String get labelLessonCompletedStatus => 'Completed';

  @override
  String get actionCompleteLesson => 'Mark as Understood & Complete';

  @override
  String get msgLessonCompletedXp => '🎉 Lesson completed successfully!';

  @override
  String get titleTeacherTip => 'Teacher\'s Tip';

  @override
  String get titleStolperfalle => 'Pitfall Trap';

  @override
  String get titleExceptions => 'Attention: Exceptions!';

  @override
  String get tooltipListenPronunciation => 'Listen to pronunciation';

  @override
  String labelGrammarBlocksCount(int count) {
    return '$count Blocks (Structure, Tables, Rules)';
  }

  @override
  String get sectionPracticeTools => 'PRACTICE TOOLS';

  @override
  String get actionStructuredPath => 'Structured Path';

  @override
  String get sectionCourseBooks => 'COURSE BOOKS';

  @override
  String get sectionTodayWords => 'TODAY\'S WORDS';

  @override
  String get titleGenderTrainer => 'Gender Trainer';

  @override
  String get titleSentenceBuilder => 'Sentence Builder';

  @override
  String get titleCompoundPuzzle => 'Compound Puzzle';

  @override
  String get subtitleCompoundPuzzle => 'Build massive words';

  @override
  String get titleVocabFlashcards => 'Study Deck Flashcards';

  @override
  String get subtitleVocabFlashcards => 'Review your Study Deck cards';

  @override
  String get titleSpeakingPracticeCard => 'Speaking Practice';

  @override
  String get subtitleSpeakingPracticeCard => 'Speech Shadowing';

  @override
  String get titleVocabGrowth => 'VOCABULARY GROWTH';

  @override
  String get labelTimeframe7D => '7D';

  @override
  String get labelTimeframe30D => '30D';

  @override
  String get labelTimeframe12W => '12W';

  @override
  String get labelTimeframeAll => 'All';

  @override
  String get labelWordsSaved => 'Study Deck';

  @override
  String get labelMastered => 'Mastered';

  @override
  String get titleMemoryRetention => 'MEMORY RETENTION (SRS)';

  @override
  String get labelStageLearning => 'Learning';

  @override
  String get labelStageApprentice => 'Apprentice';

  @override
  String get labelStageFamiliar => 'Familiar';

  @override
  String get labelStageProficient => 'Proficient';

  @override
  String get labelStageMastered => 'Mastered';

  @override
  String get title12WeekActivity => '12-WEEK ACTIVITY';

  @override
  String get sectionAccountSync => 'ACCOUNT & SYNC';

  @override
  String get sectionLearningPreferences => 'LEARNING PREFERENCES';

  @override
  String get sectionDataStorage => 'DATA & STORAGE';

  @override
  String get sectionAbout => 'ABOUT';

  @override
  String get actionSyncNow => 'Sync Now';

  @override
  String get labelLastSynced => 'Last synced';

  @override
  String get labelJustNow => 'just now';

  @override
  String labelMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get labelOfflineDictionary => 'Offline Dictionary';

  @override
  String get labelBackupExport => 'Backup & Export';

  @override
  String get labelStreakReminders => 'Streak Reminders';

  @override
  String get labelDailyReminderSubtitle =>
      'A daily nudge if you haven\'t practiced yet';

  @override
  String get labelTargetLevel => 'Target Level (CEFR)';

  @override
  String labelWordsPerDay(int count) {
    return '$count words/day';
  }
}
