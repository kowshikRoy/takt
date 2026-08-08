# Takt

Takt is a modern German language learning app with interactive reading, vocabulary tracking with spaced repetition (SRS), grammar mastery, and AI-powered media transcription.

---

## 🌐 Live Web App

The web application is live and hosted on Firebase:
👉 **[https://deutschapp-takt.web.app/](https://deutschapp-takt.web.app/)**

### Web Deployment (Firebase Hosting)

To build and deploy the latest web version:

```bash
# 1. Build the Flutter release web bundle
flutter build web --release

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting:takt-web --project book-search-472921
```

---

## 🚀 Backend Deployment (GCP Cloud Run)

To build and deploy the backend service (`omniscribe`) to Google Cloud Run:

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

> **Note**: `GEMINI_API_KEY` is securely stored in Cloud Run service environment variables and persists automatically across future deployments without needing `--set-env-vars`.

---

## 🧪 Testing & Local Verification

### Flutter App
```bash
flutter analyze
flutter test
```

### Backend
```bash
cd backend
pytest test_server_integration.py
```
