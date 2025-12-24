# Takt Backend Service

Context-aware Part-of-Speech detection, Bi-directional Translation, and Analysis service for the Takt German learning app.

## Features

- 🧠 **Unified Analysis**: Single endpoint `/process` to translate and analyze text in one go.
- 🌍 **Bi-directional Translation**: 
  - German → English
  - English → German
- 🎯 **Smart POS Tagging**: Automatically provides POS tags for the German text (whether input or output).
- 🚀 **Performance**: Lazy loading of Translation models (~300MB each) to save resources.
- 🔄 **Auto-Detection**: Automatically detects input language if not specified.

## Quick Start

### 1. Setup

```bash
cd backend
./setup.sh
```

### 2. Run Server

```bash
source venv/bin/activate
# Default port is 5001 (to avoid AirPlay conflict on macOS)
python app.py
```

### 3. Usage

#### Unified Processing (Recommended)
Translate and analyze text in one step.

**German Input (De -> En + Analysis):**
```bash
curl -X POST http://localhost:5001/process \
  -H "Content-Type: application/json" \
  -d '{"text": "Das ist ein Beispiel"}'
```

**English Input (En -> De + Analysis):**
```bash
curl -X POST http://localhost:5001/process \
  -H "Content-Type: application/json" \
  -d '{"text": "This is an example"}'
```

Response format:
```json
{
  "source_lang": "en",
  "target_lang": "de",
  "original_text": "This is an example",
  "translated_text": "Dies ist ein Beispiel",
  "german_analysis": [
    {
      "word": "Dies",
      "pos": "pron",
      "lemma": "dieser"
    },
    ...
  ]
}
```

## API Endpoints

### `POST /process`
Main endpoint.
- `text`: Input text
- `lang`: (Optional) 'en', 'de', or 'auto' (default)

### `GET /health`
Returns system status.

### `POST /analyze` (Legacy)
POS analysis only.

### `POST /translate` (Legacy)
Simple translation only.

## Deployment

### Docker

```bash
docker build -t takt-backend .
docker run -p 5000:5000 -e PORT=5000 takt-backend
```

## Requirements
- Python 3.10+
- ~1GB RAM recommended (if using both translation directions)
