import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Takt'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get navDictionary;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get actionGrammar;

  /// No description provided for @actionPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get actionPractice;

  /// No description provided for @actionAddAllToLearning.
  ///
  /// In en, this message translates to:
  /// **'Add all to Learning'**
  String get actionAddAllToLearning;

  /// No description provided for @actionListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get actionListen;

  /// No description provided for @actionGrammarForms.
  ///
  /// In en, this message translates to:
  /// **'Grammar & Forms'**
  String get actionGrammarForms;

  /// No description provided for @actionShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show Translations'**
  String get actionShowTranslation;

  /// No description provided for @actionHideTranslation.
  ///
  /// In en, this message translates to:
  /// **'Hide Translations'**
  String get actionHideTranslation;

  /// No description provided for @actionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check Answer'**
  String get actionCheck;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get actionFinish;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @sectionDailySession.
  ///
  /// In en, this message translates to:
  /// **'DAILY SESSION'**
  String get sectionDailySession;

  /// No description provided for @sectionBooks.
  ///
  /// In en, this message translates to:
  /// **'Course Books'**
  String get sectionBooks;

  /// No description provided for @labelNewWordsToday.
  ///
  /// In en, this message translates to:
  /// **'New Words Today'**
  String get labelNewWordsToday;

  /// No description provided for @labelStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get labelStreak;

  /// No description provided for @titleKeyVocab.
  ///
  /// In en, this message translates to:
  /// **'Key Vocabulary'**
  String get titleKeyVocab;

  /// No description provided for @subtitleKeyVocab.
  ///
  /// In en, this message translates to:
  /// **'Important German vocabulary from transcript'**
  String get subtitleKeyVocab;

  /// No description provided for @titleFullCues.
  ///
  /// In en, this message translates to:
  /// **'Full Cues'**
  String get titleFullCues;

  /// No description provided for @msgExtractingVocab.
  ///
  /// In en, this message translates to:
  /// **'Extracting key vocabulary...'**
  String get msgExtractingVocab;

  /// No description provided for @msgNoVocab.
  ///
  /// In en, this message translates to:
  /// **'No key vocabulary extracted yet.'**
  String get msgNoVocab;

  /// No description provided for @titleProcessMedia.
  ///
  /// In en, this message translates to:
  /// **'Process Media'**
  String get titleProcessMedia;

  /// No description provided for @labelMediaUrl.
  ///
  /// In en, this message translates to:
  /// **'Media URL'**
  String get labelMediaUrl;

  /// No description provided for @labelAudioStream.
  ///
  /// In en, this message translates to:
  /// **'Audio Media Stream'**
  String get labelAudioStream;

  /// No description provided for @labelArticleMode.
  ///
  /// In en, this message translates to:
  /// **'Article Mode'**
  String get labelArticleMode;

  /// No description provided for @titleGenderPractice.
  ///
  /// In en, this message translates to:
  /// **'Gender Practice'**
  String get titleGenderPractice;

  /// No description provided for @titleCompoundPractice.
  ///
  /// In en, this message translates to:
  /// **'Compound Practice'**
  String get titleCompoundPractice;

  /// No description provided for @titleSentencePractice.
  ///
  /// In en, this message translates to:
  /// **'Sentence Building'**
  String get titleSentencePractice;

  /// No description provided for @titleVocabPractice.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary Deck'**
  String get titleVocabPractice;

  /// No description provided for @titlePhrasesHub.
  ///
  /// In en, this message translates to:
  /// **'Everyday Phrases & Idioms'**
  String get titlePhrasesHub;

  /// No description provided for @subtitlePhrasesHub.
  ///
  /// In en, this message translates to:
  /// **'1,000+ dining, small talk, travel & cultural expressions'**
  String get subtitlePhrasesHub;

  /// No description provided for @msgCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get msgCorrect;

  /// No description provided for @msgTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get msgTryAgain;

  /// No description provided for @titleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get titleSettings;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @labelAppTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get labelAppTheme;

  /// No description provided for @labelColorPalette.
  ///
  /// In en, this message translates to:
  /// **'Color Palette'**
  String get labelColorPalette;

  /// No description provided for @labelTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get labelTypography;

  /// No description provided for @sectionPracticeLearning.
  ///
  /// In en, this message translates to:
  /// **'Practice & Learning'**
  String get sectionPracticeLearning;

  /// No description provided for @labelDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily Word Goal'**
  String get labelDailyGoal;

  /// No description provided for @labelSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get labelSoundEffects;

  /// No description provided for @labelGermanVoice.
  ///
  /// In en, this message translates to:
  /// **'German Voice (TTS)'**
  String get labelGermanVoice;

  /// No description provided for @subtitleGermanVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice used for spoken German audio'**
  String get subtitleGermanVoice;

  /// No description provided for @labelSystemDefaultVoice.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get labelSystemDefaultVoice;

  /// No description provided for @subtitleSystemDefaultVoice.
  ///
  /// In en, this message translates to:
  /// **'Default speech engine'**
  String get subtitleSystemDefaultVoice;

  /// No description provided for @titleSelectGermanVoice.
  ///
  /// In en, this message translates to:
  /// **'Select German Voice'**
  String get titleSelectGermanVoice;

  /// No description provided for @labelSpeechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech Speed'**
  String get labelSpeechRate;

  /// No description provided for @msgNoVoicesDetected.
  ///
  /// In en, this message translates to:
  /// **'Using system default voice. No additional voices found on this device.'**
  String get msgNoVoicesDetected;

  /// No description provided for @titleProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get titleProfile;

  /// No description provided for @titleDailyDiscovery.
  ///
  /// In en, this message translates to:
  /// **'DAILY DISCOVERY'**
  String get titleDailyDiscovery;

  /// No description provided for @subtitleDailyDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Tap a word to add it to your Study Deck'**
  String get subtitleDailyDiscovery;

  /// Progress of Study Deck words added today against daily goal
  ///
  /// In en, this message translates to:
  /// **'{saved} / {goal} IN DECK'**
  String labelSavedCount(int saved, int goal);

  /// No description provided for @msgAllWordsReviewed.
  ///
  /// In en, this message translates to:
  /// **'All words in your queue reviewed!'**
  String get msgAllWordsReviewed;

  /// Button label to fetch more words into discovery queue
  ///
  /// In en, this message translates to:
  /// **'DISCOVER {count} MORE WORDS'**
  String actionDiscoverMoreWords(int count);

  /// No description provided for @labelLoadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'LOADING...'**
  String get labelLoadingEllipsis;

  /// No description provided for @actionDiscoverMore.
  ///
  /// In en, this message translates to:
  /// **'DISCOVER\nMORE'**
  String get actionDiscoverMore;

  /// No description provided for @titleGrammarLessons.
  ///
  /// In en, this message translates to:
  /// **'Grammar Guides'**
  String get titleGrammarLessons;

  /// No description provided for @subtitleGrammarLessons.
  ///
  /// In en, this message translates to:
  /// **'Formulas, matrices, and teacher tips'**
  String get subtitleGrammarLessons;

  /// No description provided for @sectionStructuredRoadmap.
  ///
  /// In en, this message translates to:
  /// **'STRUCTURED GRAMMAR ROADMAP'**
  String get sectionStructuredRoadmap;

  /// Progress of completed grammar lessons
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} Lessons Completed'**
  String labelLessonsCompleted(int completed, int total);

  /// No description provided for @hintSearchGrammar.
  ///
  /// In en, this message translates to:
  /// **'Search (e.g. Modalverben, weil, Perfekt)...'**
  String get hintSearchGrammar;

  /// No description provided for @labelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labelAll;

  /// No description provided for @msgNoLessonsFound.
  ///
  /// In en, this message translates to:
  /// **'No lessons found'**
  String get msgNoLessonsFound;

  /// No description provided for @msgTryDifferentFilter.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter or search term.'**
  String get msgTryDifferentFilter;

  /// No description provided for @labelLessonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get labelLessonDone;

  /// No description provided for @labelLessonCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get labelLessonCompletedStatus;

  /// No description provided for @actionCompleteLesson.
  ///
  /// In en, this message translates to:
  /// **'Mark as Understood & Complete'**
  String get actionCompleteLesson;

  /// No description provided for @msgLessonCompletedXp.
  ///
  /// In en, this message translates to:
  /// **'🎉 Lesson completed successfully!'**
  String get msgLessonCompletedXp;

  /// No description provided for @titleTeacherTip.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s Tip'**
  String get titleTeacherTip;

  /// No description provided for @titleStolperfalle.
  ///
  /// In en, this message translates to:
  /// **'Pitfall Trap'**
  String get titleStolperfalle;

  /// No description provided for @titleExceptions.
  ///
  /// In en, this message translates to:
  /// **'Attention: Exceptions!'**
  String get titleExceptions;

  /// No description provided for @tooltipListenPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Listen to pronunciation'**
  String get tooltipListenPronunciation;

  /// Count of grammar blocks in a lesson
  ///
  /// In en, this message translates to:
  /// **'{count} Blocks (Structure, Tables, Rules)'**
  String labelGrammarBlocksCount(int count);

  /// No description provided for @sectionPracticeTools.
  ///
  /// In en, this message translates to:
  /// **'PRACTICE TOOLS'**
  String get sectionPracticeTools;

  /// No description provided for @actionStructuredPath.
  ///
  /// In en, this message translates to:
  /// **'Structured Path'**
  String get actionStructuredPath;

  /// No description provided for @sectionCourseBooks.
  ///
  /// In en, this message translates to:
  /// **'COURSE BOOKS'**
  String get sectionCourseBooks;

  /// No description provided for @sectionTodayWords.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S WORDS'**
  String get sectionTodayWords;

  /// No description provided for @titleGenderTrainer.
  ///
  /// In en, this message translates to:
  /// **'Gender Trainer'**
  String get titleGenderTrainer;

  /// No description provided for @titleSentenceBuilder.
  ///
  /// In en, this message translates to:
  /// **'Sentence Builder'**
  String get titleSentenceBuilder;

  /// No description provided for @titleCompoundPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Compound Puzzle'**
  String get titleCompoundPuzzle;

  /// No description provided for @subtitleCompoundPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Build massive words'**
  String get subtitleCompoundPuzzle;

  /// No description provided for @titleVocabFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Study Deck Flashcards'**
  String get titleVocabFlashcards;

  /// No description provided for @subtitleVocabFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Review your Study Deck cards'**
  String get subtitleVocabFlashcards;

  /// No description provided for @titleSpeakingPracticeCard.
  ///
  /// In en, this message translates to:
  /// **'Speaking Practice'**
  String get titleSpeakingPracticeCard;

  /// No description provided for @subtitleSpeakingPracticeCard.
  ///
  /// In en, this message translates to:
  /// **'Speech Shadowing'**
  String get subtitleSpeakingPracticeCard;

  /// No description provided for @titleVocabGrowth.
  ///
  /// In en, this message translates to:
  /// **'VOCABULARY GROWTH'**
  String get titleVocabGrowth;

  /// No description provided for @labelTimeframe7D.
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get labelTimeframe7D;

  /// No description provided for @labelTimeframe30D.
  ///
  /// In en, this message translates to:
  /// **'30D'**
  String get labelTimeframe30D;

  /// No description provided for @labelTimeframe12W.
  ///
  /// In en, this message translates to:
  /// **'12W'**
  String get labelTimeframe12W;

  /// No description provided for @labelTimeframeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labelTimeframeAll;

  /// No description provided for @labelWordsSaved.
  ///
  /// In en, this message translates to:
  /// **'Study Deck'**
  String get labelWordsSaved;

  /// No description provided for @labelMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get labelMastered;

  /// No description provided for @titleMemoryRetention.
  ///
  /// In en, this message translates to:
  /// **'MEMORY RETENTION (SRS)'**
  String get titleMemoryRetention;

  /// No description provided for @labelStageLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get labelStageLearning;

  /// No description provided for @labelStageApprentice.
  ///
  /// In en, this message translates to:
  /// **'Apprentice'**
  String get labelStageApprentice;

  /// No description provided for @labelStageFamiliar.
  ///
  /// In en, this message translates to:
  /// **'Familiar'**
  String get labelStageFamiliar;

  /// No description provided for @labelStageProficient.
  ///
  /// In en, this message translates to:
  /// **'Proficient'**
  String get labelStageProficient;

  /// No description provided for @labelStageMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get labelStageMastered;

  /// No description provided for @title12WeekActivity.
  ///
  /// In en, this message translates to:
  /// **'12-WEEK ACTIVITY'**
  String get title12WeekActivity;

  /// No description provided for @sectionAccountSync.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & SYNC'**
  String get sectionAccountSync;

  /// No description provided for @sectionLearningPreferences.
  ///
  /// In en, this message translates to:
  /// **'LEARNING PREFERENCES'**
  String get sectionLearningPreferences;

  /// No description provided for @sectionDataStorage.
  ///
  /// In en, this message translates to:
  /// **'DATA & STORAGE'**
  String get sectionDataStorage;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get sectionAbout;

  /// No description provided for @actionSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get actionSyncNow;

  /// No description provided for @labelLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get labelLastSynced;

  /// No description provided for @labelJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get labelJustNow;

  /// No description provided for @labelMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String labelMinutesAgo(int minutes);

  /// No description provided for @labelOfflineDictionary.
  ///
  /// In en, this message translates to:
  /// **'Offline Dictionary'**
  String get labelOfflineDictionary;

  /// No description provided for @labelBackupExport.
  ///
  /// In en, this message translates to:
  /// **'Backup & Export'**
  String get labelBackupExport;

  /// No description provided for @labelStreakReminders.
  ///
  /// In en, this message translates to:
  /// **'Streak Reminders'**
  String get labelStreakReminders;

  /// No description provided for @labelDailyReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A daily nudge if you haven\'t practiced yet'**
  String get labelDailyReminderSubtitle;

  /// No description provided for @labelTargetLevel.
  ///
  /// In en, this message translates to:
  /// **'Target Level (CEFR)'**
  String get labelTargetLevel;

  /// No description provided for @labelWordsPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count} words/day'**
  String labelWordsPerDay(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
