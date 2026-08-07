# Takt

Takt is a modern German language learning app with interactive reading, vocabulary tracking with spaced repetition (SRS), grammar mastery, and AI-powered media transcription.

---

## 🚀 Backend Deployment (GCP Cloud Run)

To build and deploy the backend service (`omniscribe`) to Google Cloud Run, execute:

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

> **Note**: `GEMINI_API_KEY` is securely set in the Cloud Run service environment variables and persists automatically across future deployments without needing `--set-env-vars`.

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
