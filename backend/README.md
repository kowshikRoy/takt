# OmniScribe Media Processing Backend

FastAPI service for German YouTube & Media audio extraction, Whisper transcription, dual subtitle generation, and dictionary lookups.

Hosted on **Google Cloud Run** in 🇪🇺 **Amsterdam, Europe (`europe-west4`)**:
`https://omniscribe-184475424927.europe-west4.run.app`

---

## 🌟 Architecture Overview

- 🎥 **Media Processing (`/submit-media`)**: Downloads YouTube / Web media audio via `yt-dlp` and `ffmpeg`, transcribes German speech with `faster-whisper`, and generates synchronized bilingual subtitles.
- ⏱️ **Task Status (`/status/{task_id}`)**: Asynchronous status polling endpoint for long-running media processing tasks.
- 📖 **Dictionary Lookup (`/word-info/{word}`)**: Fallback word lookup and definition provider.
- 🔐 **Auth & Cross-Device Sync (`/api/auth/*`, `/api/sync`)**: Username/password accounts (bcrypt) with session tokens, backed by a dedicated **Firestore Native-mode database (`takt`)** in `europe-west4` — separate from Cloud Run's ephemeral container disk, so accounts and synced vocabulary/XP/progress survive redeploys and scale-to-zero. Delete protection is enabled on the database.
- 🎨 **Gradio Demo Interface (`/demo`)**: Web UI for testing media transcription and translation endpoints interactively.

---

## 🚀 Deployment to Google Cloud Run

### **1. Local Build & Run with Docker**

```bash
# Build Docker image
docker build -t omniscribe .

# Run container locally
docker run -p 8080:8080 -e PORT=8080 omniscribe
```

Auth/sync endpoints talk to the `takt` Firestore database, so local runs need
Application Default Credentials with access to the `book-search-472921`
project: `gcloud auth application-default login`. On Cloud Run this is
automatic via the service's default compute service account (already
`roles/editor` on the project).

### **2. Deploying to GCP Cloud Run (Europe - `europe-west4`)**

```bash
gcloud run deploy omniscribe \
  --project=book-search-472921 \
  --region=europe-west4 \
  --source=. \
  --allow-unauthenticated \
  --memory=2Gi \
  --cpu=2 \
  --timeout=300s
```

---

## 📡 API Endpoints

### `POST /submit-media`
Submits a YouTube video URL or media link for asynchronous audio transcription and translation.
- **Request Body**: `{"url": "https://www.youtube.com/watch?v=..."}`
- **Response**: `{"task_id": "12345", "status": "processing"}`

### `GET /status/{task_id}`
Checks the processing status of a submitted media task.
- **Response**: `{"status": "completed", "result": {...}}`

### `GET /health`
Returns service status and health.

---

## 📦 Tech Stack & Dependencies
- **Python**: 3.12-slim
- **FastAPI / Uvicorn**: High-performance async web framework
- **yt-dlp & ffmpeg**: Media & audio extraction
- **faster-whisper**: High-speed Whisper speech recognition
- **Gradio**: Interactive web UI at `/demo`

