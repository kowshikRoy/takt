
from fastapi import FastAPI, BackgroundTasks, HTTPException, Body, Query, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import yt_dlp
import asyncio
import uuid
import glob
import json
import os
import sqlite3
import base64
from enum import Enum
from datetime import datetime, timedelta
import hashlib
from faster_whisper import WhisperModel
from deep_translator import GoogleTranslator

from magika import Magika
import re
import requests
import urllib.request

CACHE_DIR = "cache"
os.makedirs(CACHE_DIR, exist_ok=True)

def get_picsum_thumbnail(url_seed: str = None) -> str:
    """Generates a random Picsum image URL and follows HTTP 302 redirects to return the direct static image URL."""
    try:
        if url_seed:
            seed_hash = hashlib.md5(url_seed.encode()).hexdigest()[:8]
            picsum_url = f"https://picsum.photos/seed/{seed_hash}/400/225"
        else:
            picsum_url = "https://picsum.photos/400/225"
            
        res = requests.head(picsum_url, allow_redirects=True, timeout=5)
        if res.url and res.url.startswith("http"):
            return res.url
        res2 = requests.get(picsum_url, allow_redirects=True, timeout=5)
        return res2.url
    except Exception as e:
        print(f"Error resolving Picsum redirect: {e}")
        return "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop"

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TaskStatus(str, Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

tasks = {}

class MediaRequest(BaseModel):
    url: str

class SubmitResponse(BaseModel):
    task_id: str

class SubtitleCue(BaseModel):
    start: float
    end: float
    original: str
    translated: str

class MediaResponse(BaseModel):
    video_url: str
    media_type: str
    subtitles: list[SubtitleCue]
    title: str | None = None
    thumbnail: str | None = None

class StatusResponse(BaseModel):
    status: TaskStatus
    stage_message: str | None = None
    progress_percentage: int | None = None
    result: MediaResponse | None = None
    error: str | None = None


def get_cache_key(url: str) -> str:
    """Generates a unique, filesystem-safe key for a URL."""
    return hashlib.md5(url.encode()).hexdigest()

def read_from_cache(key: str) -> MediaResponse | None:
    """Reads a MediaResponse from the cache if it exists."""
    cache_file = os.path.join(CACHE_DIR, f"{key}.json")
    if os.path.exists(cache_file):
        print(f"Cache hit for key: {key}")
        with open(cache_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return MediaResponse(**data)
    print(f"Cache miss for key: {key}")
    return None

def write_to_cache(key: str, data: MediaResponse):
    """Writes a MediaResponse to the cache."""
    cache_file = os.path.join(CACHE_DIR, f"{key}.json")
    with open(cache_file, 'w', encoding='utf-8') as f:
        json.dump(data.dict(), f, indent=2)
    print(f"Wrote to cache for key: {key}")

def parse_vtt_timestamp(ts: str) -> float:
    """Converts a VTT timestamp string (HH:MM:SS.fff or MM:SS.fff) to seconds."""
    parts = ts.split(':')
    try:
        if len(parts) == 3:
            h, m, s_ms = parts
            s, ms = (s_ms.split('.') + ['0'])[:2]
            return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000.0
        elif len(parts) == 2:
            m, s_ms = parts
            s, ms = (s_ms.split('.') + ['0'])[:2]
            return int(m) * 60 + int(s) + int(ms) / 1000.0
    except ValueError:
        return 0.0
    return 0.0

def process_vtt_file(file_path: str) -> list[SubtitleCue]:
    """Parses a VTT subtitle file, translates the content, and returns a list of cues."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    translator = GoogleTranslator(source='de', target='en')
    subtitles = []
    cues = content.strip().replace('\r\n', '\n').split('\n\n')

    for cue in cues:
        if '-->' not in cue:
            continue

        lines = cue.split('\n')
        try:
            time_line_index = next(i for i, line in enumerate(lines) if '-->' in line)
            
            start_str, end_str = lines[time_line_index].split(' --> ')
            start = parse_vtt_timestamp(start_str.strip())
            end = parse_vtt_timestamp(end_str.strip())
            
            original_text = ' '.join(lines[time_line_index+1:]).strip()

            if not original_text:
                continue

            translated_text = translator.translate(original_text)

            subtitles.append(SubtitleCue(
                start=start,
                end=end,
                original=original_text,
                translated=translated_text
            ))
        except Exception as e:
            print(f"Skipping invalid VTT cue: '{cue}' due to error: {e}")
            continue
            
    return subtitles

def get_media_info(url: str):
    """Extracts direct media stream URL, video title, and thumbnail URL via yt-dlp, falling back to resolved Picsum random photo."""
    ydl_opts = {'format': 'best', 'skip_download': True}
    direct_url = url
    title = 'Media'
    thumbnail = None
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            direct_url = info.get('url', url)
            title = info.get('title', 'Media')
            thumbnail = info.get('thumbnail')
    except Exception as e:
        print(f"Error extracting metadata from yt-dlp: {e}")

    if not thumbnail or not str(thumbnail).startswith('http'):
        thumbnail = get_picsum_thumbnail(url)

    return {
        'url': direct_url,
        'title': title,
        'thumbnail': thumbnail,
    }

magika = Magika()

def get_media_type(file_path: str) -> str:
    """Identifies the media type of a file using magika."""
    result = magika.identify_path(file_path)
    if result.output.group == 'audio':
        return 'audio'
    elif result.output.group == 'video':
        return 'video'
    else:
        return 'unknown'

def download_media(url: str, output_path: str):
    ydl_opts = {
        'format': 'best',
        'outtmpl': output_path
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

_whisper_model = None

def get_whisper_model():
    """Lazy loads global WhisperModel singleton with 2 CPU threads."""
    global _whisper_model
    if _whisper_model is None:
        print("Initializing global WhisperModel ('tiny', int8, cpu_threads=2)...")
        _whisper_model = WhisperModel("tiny", device="cpu", compute_type="int8", cpu_threads=2)
    return _whisper_model

def transcribe_and_translate(audio_path: str):
    """Transcribes German audio stream with Whisper using high-performance settings."""
    model = get_whisper_model()
    segments, _ = model.transcribe(
        audio_path,
        beam_size=1,
        best_of=1,
        language="de",
        vad_filter=True,
    )
    
    subtitles = []
    for segment in segments:
        original_text = segment.text.strip()
        if not original_text:
            continue
        
        subtitles.append(SubtitleCue(
            start=segment.start,
            end=segment.end,
            original=original_text,
            translated=""  # Client device translates locally via Google ML Kit
        ))
        
    return subtitles

def update_task_stage(task_id: str, stage_msg: str, progress_pct: int):
    """Helper to record granular task progress."""
    tasks[task_id] = {
        "status": TaskStatus.PROCESSING,
        "stage_message": stage_msg,
        "progress_percentage": progress_pct,
        "result": None,
        "error": None,
    }

async def process_media_task(task_id: str, url: str):
    """The actual media processing logic with granular stage updates."""
    update_task_stage(task_id, "Checking cache...", 5)
    
    cache_key = get_cache_key(url)
    cached_response = await asyncio.to_thread(read_from_cache, cache_key)
    if cached_response:
        tasks[task_id] = {
            "status": TaskStatus.COMPLETED,
            "stage_message": "Loaded from cache ⚡",
            "progress_percentage": 100,
            "result": cached_response,
            "error": None,
        }
        return

    job_id = str(uuid.uuid4())
    media_filename = f"{job_id}.media"
    try:
        update_task_stage(task_id, "Extracting video title & thumbnail...", 15)
        media_info = await asyncio.to_thread(get_media_info, url)
        media_url = media_info['url']
        title = media_info['title']
        thumbnail = media_info['thumbnail']

        update_task_stage(task_id, "Downloading audio stream...", 35)
        await asyncio.to_thread(download_media, url, media_filename)

        update_task_stage(task_id, "Analyzing media format...", 50)
        media_type = await asyncio.to_thread(get_media_type, media_filename)
        
        subtitles = []

        try:
            update_task_stage(task_id, "Checking for official subtitles...", 65)
            ydl_opts = {
                'writesubtitles': True,
                'subtitleslangs': ['de'],
                'skip_download': True,
                'outtmpl': job_id
            }
            
            def download_subs():
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    ydl.download([url])

            await asyncio.to_thread(download_subs)

            subtitle_files = glob.glob(f'{job_id}.*.vtt')
            if subtitle_files:
                subtitle_path = subtitle_files[0]
                print(f"Found existing subtitle file: {subtitle_path}")
                subtitles = await asyncio.to_thread(process_vtt_file, subtitle_path)
        except Exception as e:
            print(f"Could not download subtitles, falling back to transcription. Error: {e}")

        if not subtitles:
            update_task_stage(task_id, "Transcribing German speech with Whisper AI...", 80)
            subtitles = await asyncio.to_thread(transcribe_and_translate, media_filename)
        
        update_task_stage(task_id, "Finalizing media lesson...", 95)
        response_data = MediaResponse(
            video_url=media_url,
            media_type=media_type,
            subtitles=subtitles,
            title=title,
            thumbnail=thumbnail,
        )
        await asyncio.to_thread(write_to_cache, cache_key, response_data)
        
        tasks[task_id] = {
            "status": TaskStatus.COMPLETED,
            "stage_message": "Ready 🎬",
            "progress_percentage": 100,
            "result": response_data,
            "error": None,
        }
        
    except Exception as e:
        print(f"Task {task_id} failed: {e}")
        tasks[task_id] = {
            "status": TaskStatus.FAILED,
            "stage_message": "Processing failed",
            "progress_percentage": 0,
            "result": None,
            "error": str(e),
        }
    finally:
        for f in glob.glob(f'{job_id}.*'):
            os.remove(f)
        if os.path.exists(media_filename):
            os.remove(media_filename)

@app.post("/submit-media", response_model=SubmitResponse)
async def submit_media(request: MediaRequest, background_tasks: BackgroundTasks):
    task_id = str(uuid.uuid4())
    tasks[task_id] = {"status": TaskStatus.PENDING, "result": None}
    background_tasks.add_task(process_media_task, task_id, request.url)
    return SubmitResponse(task_id=task_id)

@app.get("/status/{task_id}", response_model=StatusResponse)
async def get_status(task_id: str):
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return StatusResponse(**task)

@app.get("/word-info/{word}")
async def get_word_info(word: str):
    try:
        # Use the Free Dictionary API for German
        response = await asyncio.to_thread(
            lambda: requests.get(f"https://api.dictionaryapi.dev/api/v2/entries/de/{word}")
        )

        if response.status_code != 200:
            # If the German lookup fails, fall back to an English lookup for the translated word
            translator = GoogleTranslator(source='de', target='en')
            translated_word = translator.translate(word)
            response = await asyncio.to_thread(
                lambda: requests.get(f"https://api.dictionaryapi.dev/api/v2/entries/en/{translated_word}")
            )
            if response.status_code != 200:
                 raise HTTPException(status_code=404, detail=f"Word not found in German or English dictionaries: {response.text}")

        word_data = response.json()
        
        # Extract relevant information from the new API structure
        info = {
            "word": word,
            "phonetic": word_data[0].get('phonetic', 'N/A'),
            "definitions": [],
        }

        for entry in word_data:
            for meaning in entry.get('meanings', []):
                part_of_speech = meaning.get('partOfSpeech', 'N/A')
                for definition in meaning.get('definitions', []):
                    info['definitions'].append({
                        "part_of_speech": part_of_speech,
                        "definition": definition.get('definition', 'N/A'),
                        "example": definition.get('example', None),
                    })

        return info

    except Exception as e:
        # Log the exception for debugging
        print(f"An error occurred while fetching word info: {e}")
        raise HTTPException(status_code=500, detail=f"An error occurred: {e}")

# German Dictionary Database endpoints
DICT_DB_PATHS = [
    os.path.join(os.path.dirname(__file__), "assets", "german_dictionary_v16_lite.db"),
    os.path.join(os.path.dirname(__file__), "german_dictionary_v16_lite.db"),
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "german_dictionary_v16_lite.db"),
    os.path.join(CACHE_DIR, "german_dictionary_v16_lite.db"),
]

def get_dict_db_path():
    for p in DICT_DB_PATHS:
        if os.path.exists(p) and os.path.getsize(p) > 1000:
            return p
    return None

@app.get("/api/dictionary/search")
def dictionary_search(q: str = Query(...)):
    db_path = get_dict_db_path()
    if not db_path:
        raise HTTPException(status_code=533, detail="Dictionary database unavailable on server")
    
    query_str = q.strip()
    if not query_str:
        return {"results": []}
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    sql_like = f"{query_str}%"
    try:
        rows = cursor.execute("""
            SELECT w.id, w.word, w.pos, w.gender, w.ipa, w.base_form,
                   COALESCE(d.definition, d_base.definition) as definition 
            FROM words w
            LEFT JOIN definitions d ON w.id = d.word_id
            LEFT JOIN words w_base ON w.base_form = w_base.word
            LEFT JOIN definitions d_base ON w_base.id = d_base.word_id
            WHERE w.word LIKE ?
            ORDER BY LENGTH(w.word) ASC, w.word ASC, w.id ASC
        """, (sql_like,)).fetchall()

        grouped = {}
        lowest_id_for_key = {}

        for r in rows:
            w_id = r["id"]
            w_str = (r["word"] or "").lower()
            pos_str = (r["pos"] or "").lower()
            key = f"{w_str}_{pos_str}"

            if key not in lowest_id_for_key:
                lowest_id_for_key[key] = w_id
                grouped[key] = dict(r)

        results = list(grouped.values())[:20]
        conn.close()
        return {"results": results}
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Dictionary search error: {e}")

@app.get("/api/dictionary/word/{word_id}")
def dictionary_word_details(word_id: int):
    db_path = get_dict_db_path()
    if not db_path:
        raise HTTPException(status_code=533, detail="Dictionary database unavailable on server")
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        w_row = cursor.execute("SELECT * FROM words WHERE id = ?", (word_id,)).fetchone()
        if not w_row:
            conn.close()
            raise HTTPException(status_code=404, detail="Word not found")
        
        word_data = dict(w_row)

        def_rows = cursor.execute("SELECT definition FROM definitions WHERE word_id = ?", (word_id,)).fetchall()
        defs = [r["definition"] for r in def_rows if r["definition"]]
        word_data["definitions"] = defs

        try:
            form_rows = cursor.execute("SELECT form FROM forms WHERE word_id = ?", (word_id,)).fetchall()
            word_data["forms"] = [{"form": r["form"]} for r in form_rows if r["form"]]
        except Exception:
            word_data["forms"] = []

        word_data["synonyms"] = []
        word_data["antonyms"] = []
        word_data["related"] = []

        conn.close()
        return word_data
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Word detail error: {e}")

@app.get("/api/dictionary/frequency")
def dictionary_frequency(
    pos: str = "all",
    limit: int = 30,
    learned_count: int = 0,
    random: bool = True
):
    db_path = get_dict_db_path()
    if not db_path:
        raise HTTPException(status_code=533, detail="Dictionary database unavailable on server")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        has_pos = False
        try:
            cols = [info[1] for info in cursor.execute("PRAGMA table_info(words)").fetchall()]
            if "pos" in cols:
                has_pos = True
        except Exception:
            pass

        pos_filter = ""
        max_rank = 500 + (learned_count * 50)
        params = [max_rank]

        if pos != "all" and pos and has_pos:
            pos_filter = "AND w.pos LIKE ?"
            params.append(f"%{pos}%")

        params.append(limit)

        order_clause = "RANDOM()" if random else "w.freq_rank ASC"
        pos_column = "w.pos" if has_pos else "'' as pos"

        rows = cursor.execute(f"""
            SELECT w.id, w.word, {pos_column}, w.gender, w.ipa, d.definition, w.freq_rank
            FROM words w
            JOIN definitions d ON w.id = d.word_id
            WHERE w.freq_rank IS NOT NULL AND w.freq_rank <= ? {pos_filter} AND d.definition IS NOT NULL
            GROUP BY w.id
            ORDER BY {order_clause}
            LIMIT ?
        """, params).fetchall()

        results = [dict(r) for r in rows]
        conn.close()
        return {"results": results}
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Frequency error: {e}")

# Database setup for Auth & User Sync
DB_PATH = os.path.join(CACHE_DIR, "takt_app.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_sync (
            user_id TEXT PRIMARY KEY,
            vocabulary_json TEXT NOT NULL DEFAULT '[]',
            articles_json TEXT NOT NULL DEFAULT '[]',
            stats_json TEXT NOT NULL DEFAULT '{}',
            updated_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)
    conn.commit()
    conn.close()

init_db()

def hash_pw(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def get_current_user_id(authorization: str = Header(None), x_auth_token: str = Header(None)) -> str:
    token = x_auth_token
    if not token and authorization:
        if authorization.startswith("Bearer "):
            token = authorization[7:]
        elif authorization.startswith("Basic "):
            try:
                decoded = base64.b64decode(authorization[6:]).decode("utf-8")
                username, password = decoded.split(":", 1)
                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                cursor.execute("SELECT id, password_hash FROM users WHERE username = ?", (username.strip().lower(),))
                row = cursor.fetchone()
                conn.close()
                if row and row[1] == hash_pw(password):
                    return row[0]
            except Exception:
                pass

    if token:
        user_id_part = token.replace("token_", "").split("_")[0]
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM users WHERE id = ?", (user_id_part,))
        row = cursor.fetchone()
        conn.close()
        if row:
            return row[0]
            
    raise HTTPException(status_code=401, detail="Invalid or missing authentication credentials")

class AuthRequest(BaseModel):
    username: str
    password: str

class SyncPayload(BaseModel):
    vocabulary: list[dict] | None = None
    articles: list[dict] | None = None
    stats: dict | None = None

@app.post("/api/auth/register")
def register_user(auth: AuthRequest):
    username = auth.username.strip().lower()
    if not username or len(auth.password) < 4:
        raise HTTPException(status_code=400, detail="Username cannot be empty and password must be at least 4 characters.")
    
    user_id = str(uuid.uuid4())
    pw_hash = hash_pw(auth.password)
    now = datetime.utcnow().isoformat()
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO users (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)",
                       (user_id, username, pw_hash, now))
        cursor.execute("INSERT INTO user_sync (user_id, vocabulary_json, articles_json, stats_json, updated_at) VALUES (?, '[]', '[]', '{}', ?)",
                       (user_id, now))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="Username already exists. Please login instead.")
    conn.close()

    token = f"token_{user_id}_{hash_pw(username + now)[:10]}"
    return {"token": token, "user": {"id": user_id, "username": username}}

@app.post("/api/auth/login")
def login_user(auth: AuthRequest):
    username = auth.username.strip().lower()
    pw_hash = hash_pw(auth.password)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, password_hash FROM users WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()

    if not row or row[1] != pw_hash:
        raise HTTPException(status_code=401, detail="Invalid username or password.")
    
    user_id = row[0]
    token = f"token_{user_id}_{hash_pw(username)[:10]}"
    return {"token": token, "user": {"id": user_id, "username": username}}

@app.get("/api/auth/me")
def get_me(authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, created_at FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return {"id": row[0], "username": row[1], "created_at": row[2]}

@app.get("/api/sync")
def get_sync(authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT vocabulary_json, articles_json, stats_json, updated_at FROM user_sync WHERE user_id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        return {"vocabulary": [], "articles": [], "stats": {}, "updated_at": ""}
    return {
        "vocabulary": json.loads(row[0]),
        "articles": json.loads(row[1]),
        "stats": json.loads(row[2]),
        "updated_at": row[3]
    }

@app.post("/api/sync")
def post_sync(payload: SyncPayload, authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    now = datetime.utcnow().isoformat()
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT vocabulary_json, articles_json, stats_json FROM user_sync WHERE user_id = ?", (user_id,))
    row = cursor.fetchone()
    
    existing_vocab = json.loads(row[0]) if row and row[0] else []
    existing_articles = json.loads(row[1]) if row and row[1] else []
    existing_stats = json.loads(row[2]) if row and row[2] else {}

    if payload.vocabulary is not None:
        vocab_map = {item.get('id', item.get('word')): item for item in existing_vocab}
        for item in payload.vocabulary:
            k = item.get('id', item.get('word'))
            if k:
                vocab_map[k] = item
        existing_vocab = list(vocab_map.values())

    if payload.articles is not None:
        article_map = {item.get('id', item.get('title')): item for item in existing_articles}
        for item in payload.articles:
            k = item.get('id', item.get('title'))
            if k:
                article_map[k] = item
        existing_articles = list(article_map.values())

    if payload.stats is not None:
        existing_stats.update(payload.stats)

    cursor.execute("""
        INSERT INTO user_sync (user_id, vocabulary_json, articles_json, stats_json, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            vocabulary_json = excluded.vocabulary_json,
            articles_json = excluded.articles_json,
            stats_json = excluded.stats_json,
            updated_at = excluded.updated_at
    """, (user_id, json.dumps(existing_vocab), json.dumps(existing_articles), json.dumps(existing_stats), now))
    
    conn.commit()
    conn.close()
    return {"status": "success", "updated_at": now, "count_vocab": len(existing_vocab)}

# Mount static web app if available
web_build_dir = os.path.join(os.path.dirname(__file__), "web_build")
if os.path.exists(web_build_dir):
    app.mount("/app", StaticFiles(directory=web_build_dir, html=True), name="web_app")
    app.mount("/", StaticFiles(directory=web_build_dir, html=True), name="web_root")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

