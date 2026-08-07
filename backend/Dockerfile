FROM python:3.12-slim
WORKDIR /app

# 1. Install system tools (ffmpeg, nodejs for yt-dlp)
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg nodejs \
    && (ln -sf /usr/bin/nodejs /usr/bin/node 2>/dev/null || true) \
    && rm -rf /var/lib/apt/lists/*

# 2. Cache Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. Pre-download Whisper model so this heavy download layer is 100% cached
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('tiny', device='cpu', compute_type='int8')"

# 4. Create cache directory with full permissions
RUN mkdir -p cache && chmod 777 cache

# 5. Copy app code LAST so code edits build in seconds
COPY . .

# Dynamically bind to $PORT for GCP Cloud Run
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
