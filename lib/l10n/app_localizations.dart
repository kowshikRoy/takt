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

  /// No description provided for @titleProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get titleProfile;
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
