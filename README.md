# Takt (German Language Learning App)

Takt is a modern, privacy-first German language learning ecosystem combining immersive reading, media transcription, spaced-repetition Study Deck mastery (SRS), interactive grammar, and an on-device offline dictionary.

---

## 📚 What is the "Study Deck"?

In Takt, your **"Study Deck"** is your personal, active learning collection.

Unlike a static dictionary entry, a card in your Study Deck is an interactive flashcard powered by Spaced Repetition (SRS) that stores:

1. **Contextual Encounters**:
   * The exact sentence where you discovered the word.
   * Media & source attribution (YouTube video title & timestamp, article title, book chapter).
   * Contextual sentence translations.
2. **SM-2 Spaced Repetition (SRS) State**:
   * **Mastery Stage**: `New` $\rightarrow$ `Learning` $\rightarrow$ `Review` $\rightarrow$ `Mastered`.
   * **SRS Metrics**: `Interval` (days between reviews), `Ease Factor` (difficulty multiplier), `Repetitions`, `Due Date`, and `Last Reviewed` timestamp.
3. **Custom Annotations**:
   * Personal notes, user-edited definitions, and custom example sentences.
4. **Morphological Lemma & Grammar Links**:
   * Base form lemma link (e.g. `blieben` $\rightarrow$ `bleiben`, `kleine` $\rightarrow$ `klein`), gender for nouns (`der`, `die`, `das`), and verb strength (`Schwach`, `Stark`, `Gemischt`).

---

## 💾 Storage Architecture: What Does Takt Save?

Takt follows a **local-first, privacy-respecting** storage design. All data is saved on your device first and optionally synced to the cloud when signed in.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           TAKT STORAGE LAYERS                           │
├─────────────────────────────────────────────────────────────────────────┤
│ 1. SQLite Databases                                                     │
│    ├── german_dictionary.db (Offline Full & Lite German Lexicon)       │
│    ├── vocabulary.db        (Personal Study Deck & SRS Review Engine)  │
│    └── media_library.db     (Saved Stories, Transcripts & Articles)    │
│                                                                         │
│ 2. Key-Value Store (SharedPreferences)                                  │
│    ├── Profile & Gamification (Streaks, XP, Mastery Score, Today Stats) │
│    ├── Learning Progress (Curriculum Tree Nodes, Completed Grammar)     │
│    └── Preferences (Theme, German TTS Voice, Speech Rate, Audio)        │
│                                                                         │
│ 3. On-Device AI Models & Cache                                          │
│    ├── Apache OpenNLP / Apple NLTagger POS Model (Universal Dep. GSD)   │
│    ├── Google ML Kit On-Device German-English Translation Model         │
│    └── Word Image & Audio Cache                                         │
│                                                                         │
│ 4. Cloud Sync (Firebase Firestore & Auth - Optional)                   │
│    └── Encrypted cross-device backup for Study Deck, Stats & Progress   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1. SQLite Databases

* **`german_dictionary.db` (Offline Dictionary & Lexicon)**:
  * **`words`**: Over 255,000+ words with part-of-speech (`pos`), gender (`gender`), IPA phonetics (`ipa`), lemma (`base_form`), frequency rank (`freq_rank`), and verb classification (`verb_class`: `weak`, `strong`, `mixed`, `irregular`, `modal`).
  * **`definitions`**: Comprehensive English and German definitions.
  * **`forms`**: 1.1M+ inflections, verb conjugations, and noun/adjective declension tables.
  * **`examples`**: Curated real-world sentence examples with English translations.
  * **`relations`**: Synonyms, antonyms, and related word associations.
* **`vocabulary.db` (Study Deck Library)**:
  * Stores all Study Deck cards with full SM-2 algorithm variables, review history, and source encounters.
* **`media_library.db` (Reader & Media Library)**:
  * Imported web articles, graded reader stories, and media video transcripts with timestamped subtitle cues.

### 2. SharedPreferences (Settings & Profile)

* **Gamification & Daily Streaks**: Current streak count, best streak, active calendar streak dates, daily XP earned, today review counts, and today added Study Deck cards count.
* **Curriculum & Grammar Tree**: Unlocked curriculum nodes and completed interactive grammar lesson IDs.
* **User Preferences**: Dark mode / AMOLED theme, selected German TTS voice region (Germany, Austria, Switzerland), audio playback speed, and notification schedules.

### 3. Secure Storage & Session Credentials

* Encrypted Firebase Authentication tokens and guest session IDs.

### 4. On-Device AI & Models

* **Apache OpenNLP**: Embedded `opennlp-de-ud-gsd-pos-1.0-1.9.3.bin` for fast (<15ms) on-device German part-of-speech disambiguation.
* **Google ML Kit**: On-device neural machine translation model for instant offline sentence translations.

---

## 🛠️ Developer & CLI Tools

### Inspecting Words in the Dictionary

Takt includes CLI inspection tools to inspect word metadata, verb regularity, inflections, and examples:

```bash
# Using Dart services directly:
./scripts/inspect_word.sh kleine
./scripts/inspect_word.sh blieben
./scripts/inspect_word.sh Termin

# Using the standalone Python inspector:
python3 scripts/inspect_word.py bestimmen
```

---

## 🌐 Live Web App & Deployments

* **Live Web App**: [https://deutschapp-takt.web.app/](https://deutschapp-takt.web.app/)

### Web Deployment (Firebase Hosting)
```bash
# 1. Build release web bundle
flutter build web --release

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting:takt-web --project book-search-472921
```

### Backend Deployment (Google Cloud Run)
```bash
cd backend
gcloud run deploy omniscribe \
  --project=book-search-472921 \
  --region=europe-west4 \
  --source=. \
  --allow-unauthenticated \
  --memory=2Gi \
  --cpu=2 \
  --cpu-throttling \
  --min-instances=0 \
  --timeout=300s
```

---

## 🧪 Testing & Verification

```bash
# Run all Flutter tests sequentially
flutter test --concurrency=1

# Run analyzer
flutter analyze

# Run backend tests
cd backend && pytest test_server_integration.py
```
