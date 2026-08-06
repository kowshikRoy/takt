FROM python:3.12-slim
# Cache bust 2026-08-06-v2
WORKDIR /app

# Install ffmpeg for yt-dlp and faster-whisper
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p cache && chmod 777 cache

# Dynamically bind to $PORT for GCP Cloud Run
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
