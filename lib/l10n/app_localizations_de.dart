// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Takt';

  @override
  String get navHome => 'Startseite';

  @override
  String get navLearn => 'Lernen';

  @override
  String get navDictionary => 'Wörterbuch';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionGrammar => 'Grammatik';

  @override
  String get actionPractice => 'Üben';

  @override
  String get actionAddAllToLearning => 'Alle zum Lernen hinzufügen';

  @override
  String get actionListen => 'Anhören';

  @override
  String get actionGrammarForms => 'Grammatik & Formen';

  @override
  String get actionShowTranslation => 'Übersetzungen anzeigen';

  @override
  String get actionHideTranslation => 'Übersetzungen verbergen';

  @override
  String get actionCheck => 'Antwort prüfen';

  @override
  String get actionNext => 'Weiter';

  @override
  String get actionFinish => 'Fertigstellen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionRefresh => 'Aktualisieren';

  @override
  String get actionContinue => 'Weiter';

  @override
  String get sectionDailySession => 'TÄGLICHE SITZUNG';

  @override
  String get sectionBooks => 'Lehrbücher';

  @override
  String get labelNewWordsToday => 'Neue Wörter heute';

  @override
  String get labelStreak => 'Strähne';

  @override
  String get titleKeyVocab => 'Schlüsselvokabular';

  @override
  String get subtitleKeyVocab =>
      'Wichtiges deutsches Vokabular aus dem Transkript';

  @override
  String get titleFullCues => 'Vollständige Cues';

  @override
  String get msgExtractingVocab => 'Vokabular wird extrahiert...';

  @override
  String get msgNoVocab => 'Noch kein Schlüsselvokabular extrahiert.';

  @override
  String get titleProcessMedia => 'Medien verarbeiten';

  @override
  String get labelMediaUrl => 'Medien-URL';

  @override
  String get labelAudioStream => 'Audio-Medienstream';

  @override
  String get labelArticleMode => 'Artikel-Modus';

  @override
  String get titleGenderPractice => 'Genus-Training';

  @override
  String get titleCompoundPractice => 'Komposita-Training';

  @override
  String get titleSentencePractice => 'Satz-Training';

  @override
  String get titleVocabPractice => 'Vokabel-Training';

  @override
  String get msgCorrect => 'Richtig!';

  @override
  String get msgTryAgain => 'Versuche es nochmal';

  @override
  String get titleSettings => 'Einstellungen';

  @override
  String get sectionAppearance => 'Erscheinungsbild';

  @override
  String get labelAppTheme => 'App-Design';

  @override
  String get labelColorPalette => 'Farbpalette';

  @override
  String get labelTypography => 'Typografie';

  @override
  String get sectionPracticeLearning => 'Training & Lernen';

  @override
  String get labelDailyGoal => 'Tägliches Wortziel';

  @override
  String get labelSoundEffects => 'Soundeffekte';

  @override
  String get titleProfile => 'Profil';

  @override
  String get titleDailyDiscovery => 'TÄGLICHE ENTDECKUNGEN';

  @override
  String get subtitleDailyDiscovery =>
      'Tippe auf ein Wort, um es zu deiner Wiederholungsliste hinzuzufügen';

  @override
  String labelSavedCount(int saved, int goal) {
    return '$saved / $goal GESPEICHERT';
  }

  @override
  String get msgAllWordsReviewed =>
      'Alle Wörter in deiner Warteschlange überprüft!';

  @override
  String actionDiscoverMoreWords(int count) {
    return '$count WEITERE WÖRTER ENTDECKEN';
  }

  @override
  String get labelLoadingEllipsis => 'LADEN...';

  @override
  String get actionDiscoverMore => 'MEHR\nENTDECKEN';

  @override
  String get titleGrammarLessons => 'Grammatik-Bausteine';

  @override
  String get subtitleGrammarLessons => 'Formeln, Tabellen und Lehrer-Tipps';

  @override
  String get sectionStructuredRoadmap => 'STRUKTURIERTER GRAMMATIK-PFAD';

  @override
  String labelLessonsCompleted(int completed, int total) {
    return '$completed von $total Lektionen abgeschlossen';
  }

  @override
  String get hintSearchGrammar => 'Suche (z.B. Modalverben, weil, Perfekt)...';

  @override
  String get labelAll => 'Alle';

  @override
  String get msgNoLessonsFound => 'Keine Lektionen gefunden';

  @override
  String get msgTryDifferentFilter =>
      'Versuche einen anderen Filter oder Suchbegriff.';

  @override
  String get labelLessonDone => 'Erledigt';

  @override
  String get labelLessonCompletedStatus => 'Abgeschlossen';

  @override
  String get actionCompleteLesson => 'Lektion verstanden & abschließen';

  @override
  String get msgLessonCompletedXp =>
      '🎉 Lektion abgeschlossen! +25 XP gutgeschrieben.';

  @override
  String get titleTeacherTip => 'Lehrer-Tipp';

  @override
  String get titleStolperfalle => 'Stolperfalle';

  @override
  String get titleExceptions => 'Achtung: Ausnahmen!';

  @override
  String get tooltipListenPronunciation => 'Aussprache anhören';

  @override
  String labelGrammarBlocksCount(int count) {
    return '$count Bausteine (Struktur, Tabellen, Regeln)';
  }

  @override
  String get sectionPracticeTools => 'TRAINING-TOOLS';

  @override
  String get actionStructuredPath => 'Strukturierter Pfad';

  @override
  String get sectionCourseBooks => 'LEHRBÜCHER';

  @override
  String get sectionTodayWords => 'HEUTIGE WÖRTER';

  @override
  String get titleGenderTrainer => 'Genus-Training';

  @override
  String get titleSentenceBuilder => 'Satzbau-Training';

  @override
  String get titleCompoundPuzzle => 'Komposita-Rätsel';

  @override
  String get subtitleCompoundPuzzle => 'Baue lange Wörter';

  @override
  String get titleVocabFlashcards => 'Vokabelkarten-Training';

  @override
  String get subtitleVocabFlashcards =>
      'Wiederhole deine gespeicherten Vokabelkarten';

  @override
  String get titleSpeakingPracticeCard => 'Aussprache-Training';

  @override
  String get subtitleSpeakingPracticeCard => 'Sprech-Shadowing';
}
