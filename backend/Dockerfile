FROM python:3.12-slim
# Cache bust 2026-08-06-v2
WORKDIR /app

# Install ffmpeg and nodejs for yt-dlp EJS JS challenge solver
RUN apt-get update && apt-get install -y ffmpeg nodejs && (ln -sf /usr/bin/nodejs /usr/bin/node 2>/dev/null || true) && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p cache && chmod 777 cache

# Pre-download Whisper model so Cloud Run runtime never hits HuggingFace rate limits
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('tiny', device='cpu', compute_type='int8')"

# Dynamically bind to $PORT for GCP Cloud Run
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
