# CLAUDE.md — takt (DeutschApp)

## 🌟 Project Overview
**takt** (also referred to as **DeutschApp** in the UI and **OmniScribe** in the backend) is a comprehensive, cross-platform German language learning and media immersion application. It combines an adaptive **Flutter/Dart client** with a high-performance **FastAPI/Python backend** deployed on Google Cloud Run.

### Core Objectives & Features
- **Media Immersion**: Watch German YouTube videos and read articles/stories with synchronized bilingual subtitles, interactive word lookups, and instant vocabulary saving.
- **Learn & Practice**: Dedicated interactive practice hubs for Vocabulary, German Gender Rules (`der/die/das`), Compound Word decomposition, and Sentence building.
- **Offline-First Dictionary**: High-performance German-English dictionary powered by an offline SQLite database (`german_dictionary.db`) compiled from Kaikki/Wiktionary, with remote fallback translation.
- **On-Device AI & Grammar**: Uses Google ML Kit translation and custom NLP tokenization (`OnDeviceAiService`) for grammar insights and token breakdowns.
- **Cloud Processing (OmniScribe)**: Asynchronous FastAPI service handling `yt-dlp` audio extraction, `faster-whisper` speech-to-text transcription, bilingual subtitle cue generation, and user authentication/sync.

---

## 🚀 Quick Start & Development Commands

### Flutter Frontend (`lib/`, `test/`)
```bash
# Install dependencies
flutter pub get

# Run static analyzer and lint checks (flutter_lints)
flutter analyze

# Execute unit and widget test suite
flutter test

# Run the app locally (default device / Chrome / macOS)
flutter run
flutter run -d chrome
flutter run -d macos

# Build release bundles
flutter build apk --release
flutter build macos --release
flutter build web --release
```

### OmniScribe Backend (`backend/`)
```bash
# Set up Python virtual environment
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Start local FastAPI dev server with auto-reload (port 8080)
uvicorn main:app --host 0.0.0.0 --port 8080 --reload

# Build and test container locally with Docker
docker build -t omniscribe .
docker run -p 8080:8080 -e PORT=8080 omniscribe

# Run backend integration tests
pytest test_server_integration.py
```

### Cloud Run Deployment (`europe-west4` - Amsterdam)
Prerequisites: `gcloud` CLI installed and authenticated (`gcloud auth login`) with access to
project `book-search-472921` (`gcloud config get-value project` should already show it — if not,
`gcloud config set project book-search-472921`). No manual `docker build`/`push` step needed —
`--source=.` has Cloud Build do it server-side.
```bash
cd backend   # --source=. deploys the current working directory — must run from backend/
gcloud run deploy omniscribe \
  --project=book-search-472921 \
  --region=europe-west4 \
  --source=. \
  --allow-unauthenticated \
  --memory=2Gi \
  --cpu=2 \
  --timeout=300s
```
On success, `gcloud` prints `Service URL: https://omniscribe-184475424927.europe-west4.run.app`
(same URL as `lib/config.dart`'s `backendUrl` — this command redeploys the existing service, it
doesn't mint a new URL) and reports the new revision (e.g. `omniscribe-00038-sg6`) serving 100%
of traffic. The whole rollout (Cloud Build + Cloud Run revision + traffic switch) typically takes
several minutes — run it in the background and poll/tail rather than blocking on it.

### Web App Deployment (Firebase Hosting)
The Flutter **web app** (`flutter build web`) is a separate deploy target from the omniscribe
Cloud Run service above — the omniscribe URL is API-only (no `/` route, so it 404s if opened in
a browser). The web app is hosted on a dedicated Firebase Hosting **site** (not the project's
default `book-search-472921.web.app`, since that project hosts multiple unrelated services):
site ID `deutschapp-takt`, hosting target `takt-web` (mapping lives in `.firebaserc`, target
config in `firebase.json`'s `hosting.target`).
```bash
flutter build web --release
firebase deploy --only hosting:takt-web --project book-search-472921
```
Live at: **https://deutschapp-takt.web.app**
Note: on web, `sqflite` (offline dictionary) and Google ML Kit (on-device translation) are
unavailable per the platform guards in `dictionary_service.dart`/`ondevice_ai_service.dart` —
the web build automatically falls back to the online dictionary/translation APIs instead.

### Data Curation & Database Scripts (`scripts/`)
```bash
# Build full SQLite dictionary database from Kaikki/Wiktionary JSONL dump
python3 scripts/build_dictionary.py

# Create lightweight ~30K word frequency-filtered SQLite dictionary DB
python3 scripts/create_lite_db.py

# Inject word frequency rankings into SQLite dictionary tables
python3 scripts/add_freq_to_db.py
```

---

## 🏗️ Architecture & Core Components

### 1. Frontend Architecture (Flutter)
- **Application Entrypoint (`lib/main.dart`)**: Initializes Flutter bindings and wraps the application in a `MultiProvider` that exposes 6 core reactive services to the widget tree.
- **Adaptive Responsive Layout (`lib/screens/main_scaffold.dart`)**:
  - Dynamically adapts based on viewport width (`screenWidth`).
  - Mobile (< 800px): Uses a bottom navigation bar (`BottomNavigationBar`).
  - Desktop / Tablet (>= 800px): Uses a Google Photos–style sidebar / navigation rail (`NavigationRail`).
- **Primary Tabs**:
  1. **Home (`lib/screens/home_screen.dart`)**: Interactive story reader (`story_reader_screen.dart`), article cards (`article_card.dart`), video player with bilingual subtitles (`video_screen.dart`), and word glance sheets (`glance_word_sheet.dart`).
  2. **Learn/Discover (`lib/screens/discover_screen.dart`)**: Hub for practice modules:
     - Vocabulary practice (`vocabulary_practice_screen.dart`)
     - German Gender Rules Guide & Quizzes (`gender_rules_guide_screen.dart`, `gender_practice_screen.dart`)
     - Compound Words practice (`compound_practice_screen.dart`)
     - Sentence building exercises (`sentence_practice_screen.dart`)
  3. **Dictionary (`lib/screens/dictionary_screen.dart`)**: Offline-first German dictionary lookup with instant search, definitions, and word forms.
  4. **Profile (`lib/screens/profile_screen.dart`)**: User activity heatmap, daily streaks, daily learning goals (reviews, story reading, words saved), cloud sync, and authentication.

### 2. State Management Pattern
The Flutter app uses the **Provider** pattern (`ChangeNotifierProvider` via `MultiProvider`).  
Core reactive services in `lib/services/`:
- `ThemeProvider`: Light/dark themes, custom font families (`Inter`, `Roboto`, etc.), and color schemes.
- `LessonService`: Lesson progress, exercises, and completion states.
- `VocabularyService`: Saved word collections, flashcards, and review scheduling.
- `AuthService`: User credentials, authentication tokens, and login/register flows.
- `SyncService`: Synchronizes local user progress and vocabulary with the OmniScribe backend.
- `ProfileService`: Daily streaks, activity dates, join date, and daily target counters.

### 3. Data Persistence & Storage
- **Offline SQLite Dictionary (`lib/services/dictionary_service.dart`)**:
  - Uses `sqflite` to query `german_dictionary.db` in the application documents directory.
  - Supports version checking, on-demand download from backend/assets, and schema migration.
  - Guarded against web execution (`if (kIsWeb) return null;`).
- **Local Settings & Progress**: Uses `SharedPreferences` to persist user authentication tokens (`auth_token`), display name, streaks, and activity heatmap dates.
- **On-Device NLP (`lib/services/ondevice_ai_service.dart`)**: Integrates `google_mlkit_translation` for offline German-to-English translation and grammar token analysis.

### 4. OmniScribe Backend (`backend/`)
- **FastAPI / Uvicorn**: High-concurrency async API server.
- **Media Extraction & Transcription**:
  - `POST /submit-media`: Accepts YouTube or web media URLs. Uses `yt-dlp` to download audio and `ffmpeg` for transcoding, followed by `faster-whisper` for German speech recognition and timestamp alignment.
  - `GET /status/{task_id}`: Asynchronous task polling endpoint returning processing status and synchronized bilingual subtitle cues.
- **Authentication & Synchronization**:
  - `POST /api/auth/register` & `POST /api/auth/login`: Issues and validates authentication tokens.
  - Cloud storage and sync endpoints for vocabulary and progress backing up `SyncService`.

---

## 📂 Directory & File Structure

```text
takt/
├── lib/
│   ├── main.dart                      # Application entrypoint & MultiProvider setup
│   ├── config.dart                    # API endpoints & backend configuration (GCP Cloud Run)
│   ├── models/                        # Data models (article, saved_word, subtitle_cue, compound_word)
│   ├── screens/
│   │   ├── main_scaffold.dart         # Adaptive root navigation (BottomNav on mobile / Rail on desktop)
│   │   ├── home_screen.dart           # Stories, articles, video imports, glance vocabulary
│   │   ├── discover_screen.dart       # Practice modules hub ('Learn' tab)
│   │   ├── dictionary_screen.dart     # Offline SQLite dictionary lookup UI
│   │   ├── profile_screen.dart        # Heatmap, streak counter, daily goals, auth/sync
│   │   ├── story_reader_screen.dart   # Interactive German story reader with token lookups
│   │   ├── video_screen.dart          # Video player with synchronized bilingual subtitles
│   │   ├── settings_screen.dart       # App preferences, theme, font, and database management
│   │   ├── create/                    # Text input & URL import screens
│   │   └── practice/                  # Vocabulary, gender rules, compound words, & sentence practice
│   ├── services/                      # Core reactive ChangeNotifier services & API clients
│   │   ├── auth_service.dart          # Auth token management & API authentication
│   │   ├── dictionary_service.dart    # SQLite dictionary database manager & lookup engine
│   │   ├── ondevice_ai_service.dart   # Google ML Kit translation & grammar token analysis
│   │   ├── profile_service.dart       # Streaks, heatmap dates, and goal tracking
│   │   ├── sync_service.dart          # Cloud synchronization for vocabulary and progress
│   │   ├── lesson_service.dart        # Lesson progression and exercise validation
│   │   └── vocabulary_service.dart    # Saved words and review scheduling
│   ├── theme/                         # Light/dark themes and ThemeProvider
│   └── widgets/                       # Reusable UI components (article cards, word glance sheet, dialogs)
├── backend/                           # OmniScribe FastAPI Python service
│   ├── main.py                        # Core FastAPI endpoints & async task queue
│   ├── Dockerfile                     # Cloud Run container definition (Python 3.12 + ffmpeg + yt-dlp)
│   ├── requirements.txt               # Backend dependencies (fastapi, yt-dlp, faster-whisper, etc.)
│   └── test_server_integration.py     # pytest integration test suite
├── scripts/                           # Python data pipeline & dictionary building scripts
│   ├── build_dictionary.py            # Converts Kaikki/Wiktionary JSONL into SQLite DB
│   ├── create_lite_db.py              # Filters dictionary to ~30K common words
│   └── add_freq_to_db.py              # Populates word frequency rankings
├── assets/                            # Static images and bundled resources
├── test/                              # Flutter unit and widget tests
├── pubspec.yaml                       # Dart/Flutter package configuration
└── analysis_options.yaml              # Flutter lint rules (flutter_lints)
```

---

## 🎨 Code Style & Development Conventions

### Dart / Flutter
- **Linting**: Obey rules configured in `analysis_options.yaml` (`flutter_lints`). Always resolve analyzer warnings before committing.
- **Naming Conventions**:
  - `PascalCase` for classes, typedefs, enums, and widgets (e.g., `DictionaryService`, `MainScaffold`).
  - `camelCase` for variables, methods, properties, and parameter names.
  - `snake_case.dart` for files and directory names.
- **State Management**:
  - Use `ChangeNotifier` services registered in `MultiProvider`.
  - Call `notifyListeners()` when state updates mutate data needed by UI widgets.
  - Avoid global mutable variables outside service providers.
- **UI & Theming**:
  - Never hardcode color hex codes or typography styles in widgets; use `Theme.of(context)` and tokens defined in `AppTheme`.
  - Ensure UI components render cleanly in both **Light Mode** and **Dark Mode**.
  - Respect responsive layouts: test against both small mobile viewports (`< 800px`) and wide desktop viewports (`>= 800px`).
- **Platform Guards**:
  - SQLite (`sqflite`) and direct file I/O do not work on web browsers. Always protect database access and local file storage with `kIsWeb` guards:
    ```dart
    if (kIsWeb) return null;
    ```

### Python (Backend & Scripts)
- **FastAPI / Async**:
  - Use `async def` for API endpoints.
  - Long-running media operations (`yt-dlp` download, `faster-whisper` transcription) must be executed asynchronously or dispatched via FastAPI `BackgroundTasks` to prevent thread blocking.
- **Type Annotations**: Provide Python type hints on function signatures and use Pydantic `BaseModel` for all request/response serialization.
- **Error Handling**: Raise standard `HTTPException(status_code=..., detail=...)` for API errors.

---

## 🧪 Testing & Verification Workflow

1. **Static Analysis (Flutter)**:
   ```bash
   flutter analyze
   ```
   Ensure `No issues found!` before submitting changes.
2. **Flutter Test Suite**:
   ```bash
   flutter test
   ```
   When adding new features or screens, add accompanying unit or widget tests inside `test/`.
3. **Backend Integration Verification**:
   ```bash
   cd backend
   pytest test_server_integration.py
   ```
   Verify that FastAPI routes, task submission, and polling respond correctly.

---

## ⚠️ Key Gotchas & Domain Know-How

- **Offline SQLite Dictionary Migration**:
  `DictionaryService` automatically renames older database filenames (e.g., `german_dictionary_v3.db` → `german_dictionary.db`) in the user's application document directory. Do not alter `_dbFileName` without updating the migration logic in `_getDatabasePath()`.
- **GCP Cloud Run Endpoint**:
  The backend URL is centrally defined in `lib/config.dart` as `https://omniscribe-184475424927.europe-west4.run.app`. If deploying a new Cloud Run instance or working against a local backend, override `backendUrl` in `config.dart`.
- **System Dependencies for Backend Processing**:
  Running `backend/main.py` locally for media extraction requires `ffmpeg` and `yt-dlp` installed and available in `$PATH`.
- **Web vs. Native Feature Degradation**:
  When compiling for `flutter build web`, SQLite dictionary lookup and ML Kit offline translation are automatically bypassed in favor of fallback online dictionary and translation APIs. Ensure web-safe fallback paths are maintained when modifying dictionary or translation code.
