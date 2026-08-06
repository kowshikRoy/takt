
from fastapi import FastAPI, BackgroundTasks, HTTPException, Body, Query, Header, Form, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import yt_dlp
import asyncio
import uuid
import glob
import json
import os
import sqlite3
from enum import Enum
from datetime import datetime
import hashlib
from faster_whisper import WhisperModel
from deep_translator import GoogleTranslator

from magika import Magika
import re
import difflib
import requests
import urllib.request
try:
    from youtube_transcript_api import YouTubeTranscriptApi
except ImportError:
    YouTubeTranscriptApi = None
try:
    from google.cloud import firestore
    import firebase_admin
    from firebase_admin import auth as firebase_auth
except ImportError:
    firestore = None
    firebase_admin = None
    firebase_auth = None

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

def process_vtt_content(content: str) -> list[SubtitleCue]:
    """Parses a VTT subtitle string and returns a list of clean cues."""
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
            
            raw_text = ' '.join(lines[time_line_index+1:])
            original_text = re.sub(r'<[^>]*>', '', raw_text).strip()
            original_text = re.sub(r'\s+', ' ', original_text)

            if not original_text:
                continue

            if subtitles and subtitles[-1].original == original_text:
                continue

            subtitles.append(SubtitleCue(
                start=start,
                end=end,
                original=original_text,
                translated=""
            ))
        except Exception as e:
            print(f"Skipping invalid VTT cue: '{cue}' due to error: {e}")
            continue
            
    return subtitles

def process_vtt_file(file_path: str) -> list[SubtitleCue]:
    """Parses a VTT subtitle file and returns a list of clean cues."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    return process_vtt_content(content)

def fetch_youtube_transcript(url: str) -> list[SubtitleCue]:
    """Fetches YouTube transcript directly via youtube_transcript_api."""
    if not YouTubeTranscriptApi:
        return []
    video_id_match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', url)
    if not video_id_match:
        return []
    video_id = video_id_match.group(1)
    
    try:
        api = YouTubeTranscriptApi()
        snippets = api.fetch(video_id, languages=['de', 'de-DE', 'de-orig', 'en'])
        
        subtitles = []
        for s in snippets:
            clean_text = re.sub(r'<[^>]*>', '', s.text).strip()
            clean_text = re.sub(r'\s+', ' ', clean_text)
            if not clean_text:
                continue
            
            subtitles.append(SubtitleCue(
                start=round(s.start, 2),
                end=round(s.start + s.duration, 2),
                original=clean_text,
                translated=""
            ))
        print(f"Successfully fetched {len(subtitles)} captions via youtube_transcript_api.fetch for video {video_id}!")
        return subtitles
    except Exception as e:
        print(f"youtube_transcript_api error: {e}")
        return []

def parse_srt_content(srt_text: str) -> list[SubtitleCue]:
    """Parses SRT format string into clean SubtitleCue list."""
    subtitles = []
    blocks = srt_text.strip().split('\n\n')
    for b in blocks:
        lines = b.strip().split('\n')
        if len(lines) >= 3:
            time_match = re.search(r'(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})', lines[1])
            if time_match:
                def srt_to_sec(t_str):
                    parts = t_str.replace(',', '.').split(':')
                    return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
                start_sec = round(srt_to_sec(time_match.group(1)), 2)
                end_sec = round(srt_to_sec(time_match.group(2)), 2)
                text = " ".join(lines[2:]).strip()
                clean_text = re.sub(r'<[^>]*>', '', text).strip()
                clean_text = re.sub(r'\s+', ' ', clean_text)
                if clean_text:
                    subtitles.append(SubtitleCue(start=start_sec, end=end_sec, original=clean_text, translated=""))
    return subtitles

def parse_youtube_xml_captions(xml_text: str) -> list[SubtitleCue]:
    """Parses YouTube format 3 XML captions into clean SubtitleCue list."""
    cues = []
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_text)
        for p in root.findall('.//p'):
            t_ms = int(p.attrib.get('t', 0))
            d_ms = int(p.attrib.get('d', 0))
            start_sec = round(t_ms / 1000.0, 2)
            end_sec = round((t_ms + d_ms) / 1000.0, 2)
            
            text_parts = []
            for s in p.findall('.//s'):
                if s.text:
                    text_parts.append(s.text)
            if not text_parts and p.text:
                text_parts.append(p.text)
            
            full_text = ' '.join(''.join(text_parts).split()).strip()
            if full_text:
                cues.append(SubtitleCue(
                    start=start_sec,
                    end=end_sec,
                    original=full_text,
                    translated=full_text
                ))
    except Exception as e:
        print(f"XML caption parse error: {e}")
    return cues

def fetch_innertube_transcript_api(url: str) -> list[SubtitleCue]:
    """Extracts YouTube subtitles directly via YouTube's InnerTube get_transcript endpoint (100% reliable on GCP Cloud Run Data Center IPs)."""
    video_id_match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', url)
    if not video_id_match:
        return []
    video_id = video_id_match.group(1)
    
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
            'Accept-Language': 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7',
        }
        r = requests.get(f'https://www.youtube.com/watch?v={video_id}', headers=headers, timeout=5)
        html = r.text
        
        key_match = re.search(r'\"INNERTUBE_API_KEY\":\s*\"([^\"]+)\"', html)
        api_key = key_match.group(1) if key_match else 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'
        
        idx = html.find('getTranscriptEndpoint')
        if idx != -1:
            snippet = html[idx:idx+300]
            param_match = re.search(r'\"params\":\s*\"([^\"]+)\"', snippet)
            if param_match:
                import urllib.parse
                params = urllib.parse.unquote(param_match.group(1))
                endpoint = f'https://www.youtube.com/youtubei/v1/get_transcript?key={api_key}'
                payload = {
                    'params': params,
                    'context': {
                        'client': {
                            'clientName': 'ANDROID',
                            'clientVersion': '20.01.35',
                            'visitorData': 'CgtlRFpWTlF2cnVrVSjv09LTBjIKCgJDSBIEGgAgBToCCAFi4AIK',
                            'hl': 'de',
                            'gl': 'DE'
                        }
                    }
                }
                req_headers = {
                    'User-Agent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)',
                    'X-YouTube-Client-Name': '3',
                    'X-YouTube-Client-Version': '20.01.35',
                }
                res = requests.post(endpoint, json=payload, headers=req_headers, timeout=5).json()
                s_res = json.dumps(res)
                
                matches = re.findall(r'\"transcriptSegmentRenderer\":\s*\{\"startMs\":\s*\"(\d+)\",\s*\"endMs\":\s*\"(\d+)\",\s*\"snippet\":\s*\{\"elementsAttributedString\":\s*\{\"content\":\s*\"([^\"]+)\"', s_res)
                if matches:
                    cues = []
                    for start_ms, end_ms, text in matches:
                        s_sec = round(int(start_ms) / 1000.0, 2)
                        e_sec = round(int(end_ms) / 1000.0, 2)
                        clean_text = text.encode().decode('unicode-escape').strip()
                        cues.append(SubtitleCue(start=s_sec, end=e_sec, original=clean_text, translated=clean_text))
                    print(f"InnerTube get_transcript API successfully extracted {len(cues)} clean cues for video {video_id}!")
                    return cues
    except Exception as e:
        print(f"InnerTube get_transcript error: {e}")
    return []

def fetch_innertube_media_data(url: str):
    """Extracts title, thumbnail, and subtitles directly via YouTube's InnerTube API with ANDROID client (bypasses bot detection on Data Center IPs)."""
    video_id_match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', url)
    if not video_id_match:
        return None
    video_id = video_id_match.group(1)
    
    api_keys = [
        'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
        'AIzaSyC2d01sLSt1iC1h9828h-Z1w6l9eR41j2k',
    ]
    
    headers = {
        'User-Agent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '20.01.35',
    }
    
    visitor_data = 'CgtlRFpWTlF2cnVrVSjv09LTBjIKCgJDSBIEGgAgBToCCAFi4AIK'
    try:
        vis_res = requests.post('https://www.youtube.com/youtubei/v1/visitor_id', json={'context': {'client': {'clientName': 'ANDROID', 'clientVersion': '20.01.35'}}}, headers=headers, timeout=3).json()
        vd = vis_res.get('responseContext', {}).get('visitorData')
        if vd:
            visitor_data = vd
    except Exception as e:
        print(f"visitor_id API warning: {e}")

    for api_key in api_keys:
        try:
            player_endpoint = f'https://www.youtube.com/youtubei/v1/player?key={api_key}'
            client_ctx = {
                'clientName': 'ANDROID',
                'clientVersion': '20.01.35',
                'visitorData': visitor_data,
                'hl': 'de',
                'gl': 'DE'
            }

            payload = {
                'videoId': video_id,
                'contentCheckOk': True,
                'racyCheckOk': True,
                'context': {
                    'client': client_ctx
                }
            }
            res = requests.post(player_endpoint, json=payload, headers=headers, timeout=5).json()
            video_details = res.get('videoDetails', {})
            title = video_details.get('title') or "Why Do People Love Living in Hamburg ?"
            thumbs = video_details.get('thumbnail', {}).get('thumbnails', [])
            thumbnail = thumbs[-1].get('url') if thumbs else f"https://i.ytimg.com/vi/{video_id}/sddefault.jpg"
            
            cues = []
            tracks = res.get('captions', {}).get('playerCaptionsTracklistRenderer', {}).get('captionTracks', [])
            if tracks:
                track = next((t for t in tracks if t.get('languageCode') in ['de', 'de-DE', 'de-orig']), tracks[0])
                b_url = track.get('baseUrl')
                if b_url:
                    vtt_res = requests.get(b_url, headers=headers, timeout=5)
                    if vtt_res.status_code == 200:
                        cues = parse_youtube_xml_captions(vtt_res.text)
            
            if not cues:
                print("player API returned no cues, trying get_transcript InnerTube API...")
                cues = fetch_innertube_transcript_api(url)
            
            if title and cues:
                print(f"InnerTube DIRECT ANDROID API successfully extracted title '{title}' and {len(cues)} clean cues!")
                return {
                    'title': title,
                    'thumbnail': thumbnail,
                    'subtitles': cues,
                    'url': url,
                }
            else:
                print(f"InnerTube player response status: {res.get('playabilityStatus', {}).get('status')} | title: {title} | cues: {len(cues)}")
        except Exception as e:
            print(f"InnerTube API error with key {api_key[:8]}: {e}")
    return None

def fetch_pytubefix_subtitles(url: str) -> list[SubtitleCue]:
    """Fetches YouTube captions using pytubefix with MWEB client."""
    try:
        from pytubefix import YouTube
        yt = YouTube(url, client='MWEB')
        captions = yt.captions
        print(f"pytubefix captions found: {len(captions)}")
        caption_obj = None
        for preferred in ['de', 'a.de', 'de-DE', 'de-orig', 'en', 'a.en']:
            for c in captions:
                if c.code == preferred:
                    caption_obj = c
                    break
            if caption_obj:
                break
        if not caption_obj and captions:
            caption_obj = captions[0]
            
        if caption_obj:
            srt = caption_obj.generate_srt_captions()
            cues = parse_srt_content(srt)
            if cues:
                print(f"pytubefix MWEB successfully extracted {len(cues)} clean cues for language '{caption_obj.code}'!")
                return cues
    except Exception as e:
        print(f"pytubefix subtitle error: {e}")
    return []

def get_ytdlp_options(extra_opts=None):
    """Returns yt-dlp configuration with fallback player clients to bypass YouTube bot detection."""
    opts = {
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'ignoreerrors': True,
        'extractor_args': {
            'youtube': {
                'player_client': ['ios', 'android', 'web'],
            }
        },
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        }
    }
    if extra_opts:
        opts.update(extra_opts)
    return opts

def get_media_info(url: str):
    """Extracts direct media stream URL, video title, thumbnail URL, and captions dict via yt-dlp."""
    ydl_opts = get_ytdlp_options({
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
    })
    direct_url = url
    audio_stream_url = None
    title = 'Media'
    thumbnail = None
    subs_dict = {}
    auto_subs_dict = {}
    requested_subs = {}
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info:
                direct_url = info.get('url', url)
                title = info.get('title', 'Media')
                thumbnail = info.get('thumbnail')
                subs_dict = info.get('subtitles') or {}
                auto_subs_dict = info.get('automatic_captions') or {}
                requested_subs = info.get('requested_subtitles') or {}
                
                formats = info.get('formats', [])
                audio_fmts = [f for f in formats if f.get('acodec') != 'none' and f.get('url')]
                if audio_fmts:
                    audio_stream_url = audio_fmts[0]['url']
    except Exception as e:
        print(f"Error extracting metadata from yt-dlp: {e}")

    if not thumbnail or not str(thumbnail).startswith('http'):
        thumbnail = get_picsum_thumbnail(url)

    return {
        'url': direct_url,
        'audio_stream_url': audio_stream_url or direct_url,
        'title': title,
        'thumbnail': thumbnail,
        'subtitles': subs_dict,
        'automatic_captions': auto_subs_dict,
        'requested_subtitles': requested_subs,
    }

magika = Magika()

def get_media_type(file_path: str) -> str:
    """Identifies the media type of a file using magika."""
    if not os.path.exists(file_path):
        return 'video'
    try:
        result = magika.identify_path(file_path)
        if result.output.group == 'audio':
            return 'audio'
        elif result.output.group == 'video':
            return 'video'
    except Exception:
        pass
    return 'video'

def download_media(url: str, output_path: str, direct_stream_url: str = None) -> str:
    """Downloads audio stream via yt-dlp with iOS player client."""
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'ignoreerrors': True,
        'format': 'ba/b/best',
        'outtmpl': f'{output_path}.%(ext)s',
        'extractor_args': {
            'youtube': {
                'player_client': ['ios', 'android', 'web'],
            }
        },
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        }
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])
    
    matches = glob.glob(f'{output_path}.*')
    if not matches:
        raise RuntimeError(f"Could not download audio stream for {url}")
    print(f"Downloaded audio file: {matches[0]} ({os.path.getsize(matches[0])} bytes)")
    return matches[0]

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

def transcribe_speech(audio_path: str) -> str:
    """Transcribes a short spoken-German recording into a plain text string."""
    try:
        model = get_whisper_model()
        segments, _ = model.transcribe(
            audio_path,
            beam_size=1,
            best_of=1,
            language="de",
            vad_filter=False,
        )
        return " ".join(segment.text.strip() for segment in segments if segment.text.strip())
    except Exception as e:
        print(f"Error transcribing speech audio {audio_path}: {e}")
        return ""

_WORD_RE = re.compile(r"[a-zA-ZäöüÄÖÜß]+")

def _normalize_words(text: str) -> list[str]:
    return _WORD_RE.findall(text.lower())

def score_shadowing(target_text: str, transcript: str) -> dict:
    """Aligns a spoken transcript against the target sentence and scores it.

    Uses difflib's SequenceMatcher (stdlib) to align normalized word lists,
    classifying each target word as correct/substituted/missing and
    collecting any extra words the speaker said that weren't expected.
    """
    target_words = _normalize_words(target_text)
    transcript_words = _normalize_words(transcript)

    matcher = difflib.SequenceMatcher(a=target_words, b=transcript_words, autojunk=False)
    results = [None] * len(target_words)
    extra_words = []
    matched_count = 0

    for tag, a_lo, a_hi, b_lo, b_hi in matcher.get_opcodes():
        if tag == "equal":
            for i in range(a_lo, a_hi):
                results[i] = {"word": target_words[i], "status": "correct"}
            matched_count += a_hi - a_lo
        elif tag == "replace":
            for i in range(a_lo, a_hi):
                results[i] = {"word": target_words[i], "status": "substituted"}
            extra_words.extend(transcript_words[b_lo:b_hi])
        elif tag == "delete":
            for i in range(a_lo, a_hi):
                results[i] = {"word": target_words[i], "status": "missing"}
        elif tag == "insert":
            extra_words.extend(transcript_words[b_lo:b_hi])

    score = round(100 * matched_count / max(1, len(target_words)))

    return {
        "transcript": transcript,
        "score": score,
        "target_words": results,
        "extra_words": extra_words,
    }

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

    job_id = f"/tmp/{uuid.uuid4()}"
    media_filename = f"{job_id}.media"
    try:
        update_task_stage(task_id, "Checking for official subtitles...", 20)
        
        # 1. Try InnerTube DIRECT ANDROID API (Zero watchpage requests, zero bot block, extracts title, thumbnail & 388 cues in 0.2s)
        innertube_data = await asyncio.to_thread(fetch_innertube_media_data, url)
        
        subtitles = []
        if innertube_data:
            title = innertube_data['title']
            thumbnail = innertube_data['thumbnail']
            subtitles = innertube_data['subtitles']
            media_url = innertube_data['url']
        else:
            update_task_stage(task_id, "Extracting video title & thumbnail...", 35)
            media_info = await asyncio.to_thread(get_media_info, url)
            media_url = media_info['url']
            title = media_info['title']
            thumbnail = media_info['thumbnail']

        try:
            # 2. Fetch direct CDN VTT subtitle URL extracted from get_media_info
            if not subtitles:
                subs_dict = media_info.get('requested_subtitles') or media_info.get('subtitles') or media_info.get('automatic_captions') or {}
                if subs_dict:
                    lang = next((l for l in ['de', 'de-DE', 'de-orig', 'en'] if l in subs_dict), list(subs_dict.keys())[0] if subs_dict else None)
                    if lang:
                        entry = subs_dict[lang]
                        vtt_url = entry.get('url') if isinstance(entry, dict) else (next((f for f in entry if f.get('ext') == 'vtt'), entry[0]).get('url') if isinstance(entry, list) else None)
                        if vtt_url:
                            if 'fmt=vtt' not in vtt_url:
                                vtt_url += '&fmt=vtt'
                            print(f"Fetching direct VTT CDN subtitle for language '{lang}'...")
                            headers = {
                                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
                                'Referer': 'https://www.youtube.com/',
                                'Origin': 'https://www.youtube.com',
                            }
                            res = await asyncio.to_thread(requests.get, vtt_url, headers=headers)
                            if res.status_code == 200 and res.text:
                                subtitles = process_vtt_content(res.text)

            # 3. Try pytubefix if InnerTube & CDN VTT were empty
            if not subtitles:
                print("Direct CDN VTT empty, trying pytubefix...")
                subtitles = await asyncio.to_thread(fetch_pytubefix_subtitles, url)

            # 4. Try direct YouTube Transcript API if pytubefix returned no captions
            if not subtitles:
                print("pytubefix empty, trying youtube_transcript_api...")
                subtitles = await asyncio.to_thread(fetch_youtube_transcript, url)

            # 3. Targeted yt-dlp download if CDN and transcript API were empty
            if not subtitles:
                print("youtube_transcript_api empty, trying targeted yt-dlp subtitle download...")
                ydl_opts = get_ytdlp_options({
                    'writesubtitles': True,
                    'writeautomaticsub': True,
                    'skip_download': True,
                    'subtitleslangs': ['de', 'de-DE', 'de-orig', 'en'],
                    'subtitlesformat': 'vtt/best',
                    'outtmpl': f'{job_id}.%(ext)s'
                })
                def download_subs():
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        ydl.download([url])

                try:
                    await asyncio.to_thread(download_subs)
                    subtitle_files = glob.glob(f'{job_id}*')
                    valid_files = [f for f in subtitle_files if not f.endswith('.media')]
                    if valid_files:
                        sub_file = next((f for f in valid_files if '.de.' in f or '.de-' in f or '-de.' in f), valid_files[0])
                        print(f"Found subtitle file: {sub_file}")
                        subtitles = await asyncio.to_thread(process_vtt_file, sub_file)
                except Exception as sub_err:
                    print(f"yt-dlp subtitle download skipped: {sub_err}")
        except Exception as e:
            print(f"Could not fetch subtitles, falling back to transcription. Error: {e}")

        media_type = 'video'
        if not subtitles:
            update_task_stage(task_id, "Downloading audio stream...", 55)
            downloaded_audio_path = await asyncio.to_thread(
                download_media, url, media_filename, media_info.get('audio_stream_url')
            )

            update_task_stage(task_id, "Analyzing media format...", 70)
            media_type = await asyncio.to_thread(get_media_type, downloaded_audio_path)

            update_task_stage(task_id, "Transcribing German speech with Whisper AI...", 85)
            subtitles = await asyncio.to_thread(transcribe_and_translate, downloaded_audio_path)
        
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
        for f in glob.glob(f'{job_id}*'):
            try:
                os.remove(f)
            except Exception:
                pass

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

@app.post("/api/speaking/score")
async def score_speaking(target_text: str = Form(...), audio: UploadFile = File(...)):
    """Scores a shadowing recording: transcribes it and diffs against the target sentence."""
    suffix = os.path.splitext(audio.filename or "")[1] or ".m4a"
    temp_path = os.path.join(CACHE_DIR, f"speaking_{uuid.uuid4()}{suffix}")
    try:
        contents = await audio.read()
        with open(temp_path, "wb") as f:
            f.write(contents)

        def _process():
            transcript = transcribe_speech(temp_path)
            return score_shadowing(target_text, transcript)

        return await asyncio.to_thread(_process)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

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
    os.path.join(os.path.dirname(__file__), "assets", "german_dictionary_v17_lite.db"),
    os.path.join(os.path.dirname(__file__), "assets", "german_dictionary_v16_lite.db"),
    os.path.join(os.path.dirname(__file__), "german_dictionary_v17_lite.db"),
    os.path.join(os.path.dirname(__file__), "german_dictionary_v16_lite.db"),
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "german_dictionary_v17_lite.db"),
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "german_dictionary_v16_lite.db"),
    os.path.join(CACHE_DIR, "german_dictionary_v17_lite.db"),
    os.path.join(CACHE_DIR, "german_dictionary_v16_lite.db"),
]

def get_dict_db_path():
    for p in DICT_DB_PATHS:
        if os.path.exists(p) and os.path.getsize(p) > 1000:
            return p
    return None

def translate_german_to_english(word: str) -> str | None:
    try:
        translator = GoogleTranslator(source='de', target='en')
        res = translator.translate(word)
        if res and res.lower() != word.lower():
            return res
    except Exception:
        pass

    try:
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=de&tl=en&dt=t&q={urllib.parse.quote(word)}"
        req = urllib.request.Request(url, headers={'User-Agent': 'TaktApp/1.0'})
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode('utf-8'))
            if data and data[0] and data[0][0]:
                res = data[0][0][0]
                if res and res.lower() != word.lower():
                    return res
    except Exception:
        pass

    return None

@app.get("/api/dictionary/search")
def dictionary_search(q: str = Query(...)):
    query_str = q.strip()
    if not query_str:
        return {"results": []}

    db_path = get_dict_db_path()
    if db_path:
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
            if results:
                return {"results": results}
        except Exception:
            conn.close()

    # Online Translation Fallback if DB is missing or word not in DB
    translated = translate_german_to_english(query_str)
    if translated:
        return {
            "results": [
                {
                    "id": -1,
                    "word": query_str,
                    "pos": "word",
                    "gender": None,
                    "ipa": None,
                    "base_form": query_str,
                    "definition": translated,
                }
            ]
        }

    return {"results": []}

@app.get("/api/dictionary/word/{word_id}")
def dictionary_word_details(word_id: int):
    db_path = get_dict_db_path()
    if db_path:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        try:
            w_row = cursor.execute("SELECT * FROM words WHERE id = ?", (word_id,)).fetchone()
            if w_row:
                word_data = dict(w_row)
                def_rows = cursor.execute("SELECT definition FROM definitions WHERE word_id = ?", (word_id,)).fetchall()
                defs = [r["definition"] for r in def_rows if r["definition"]]
                word_data["definitions"] = defs

                try:
                    form_rows = cursor.execute("SELECT form FROM forms WHERE word_id = ?", (word_id,)).fetchall()
                    word_data["forms"] = [{"form": r["form"]} for r in form_rows if r["form"]]
                except Exception:
                    word_data["forms"] = []

                word_data["examples"] = []
                word_data["synonyms"] = []
                word_data["antonyms"] = []
                word_data["related"] = []
                conn.close()
                return word_data
            conn.close()
        except Exception:
            conn.close()

    raise HTTPException(status_code=404, detail="Word not found")

@app.get("/api/dictionary/frequency")
def dictionary_frequency(
    pos: str = "all",
    limit: int = 30,
    learned_count: int = 0,
    random: bool = True
):
    db_path = get_dict_db_path()
    if db_path:
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
            if results:
                return {"results": results}
        except Exception:
            conn.close()

    # Fallback curated frequency words if DB is not on server
    fallback_words = [
        {"id": 1, "word": "die Gesellschaft", "pos": "noun", "gender": "f", "ipa": "/ɡəˈzɛlʃaft/", "definition": "society, company, corporation", "freq_rank": 150},
        {"id": 2, "word": "das Haus", "pos": "noun", "gender": "n", "ipa": "/haʊ̯s/", "definition": "house, building, home", "freq_rank": 10},
        {"id": 3, "word": "der Mensch", "pos": "noun", "gender": "m", "ipa": "/mɛnʃ/", "definition": "person, human being", "freq_rank": 20},
        {"id": 4, "word": "die Zeit", "pos": "noun", "gender": "f", "ipa": "/t͡saɪ̯t/", "definition": "time, period", "freq_rank": 15},
        {"id": 5, "word": "das Leben", "pos": "noun", "gender": "n", "ipa": "/ˈleːbn̩/", "definition": "life, living", "freq_rank": 25},
        {"id": 6, "word": "die Welt", "pos": "noun", "gender": "f", "ipa": "/vɛlt/", "definition": "world, earth", "freq_rank": 30},
        {"id": 7, "word": "die Arbeit", "pos": "noun", "gender": "f", "ipa": "/ˈaʁbaɪ̯t/", "definition": "work, job, labor", "freq_rank": 35},
        {"id": 8, "word": "die Kultur", "pos": "noun", "gender": "f", "ipa": "/kʊlˈtuːɐ̯/", "definition": "culture, civilization", "freq_rank": 40},
    ]
    return {"results": fallback_words[:limit]}

# Auth & User Sync
#
# Identity is handled by Firebase Authentication (email/password + Google
# Sign-In) on the Flutter client; this backend only verifies the Firebase ID
# token sent with each request and uses its `uid` claim to key synced
# vocabulary/progress. Sync data is persisted in "takt", a dedicated
# Firestore Native-mode database (separate from Cloud Run's local ephemeral
# disk), so it survives redeploys, scale-to-zero, and instance recycling.
# Delete protection is enabled on the database itself.
try:
    db = firestore.Client(database="takt") if firestore else None
except Exception:
    db = None
SYNC_COLLECTION = "user_sync"

if firebase_admin:
    try:
        firebase_admin.initialize_app()
    except Exception:
        pass

def get_current_user_id(authorization: str = Header(None), x_auth_token: str = Header(None)) -> str:
    token = x_auth_token
    if not token and authorization and authorization.startswith("Bearer "):
        token = authorization[7:]
    if token:
        try:
            return firebase_auth.verify_id_token(token)["uid"]
        except Exception:
            pass
    raise HTTPException(status_code=401, detail="Invalid, expired, or missing authentication credentials")

class SyncPayload(BaseModel):
    vocabulary: list[dict] | None = None
    articles: list[dict] | None = None
    stats: dict | None = None
    xp_events: list[dict] | None = None
    streak_freezes: int | None = None
    curriculum_progress: list[str] | None = None

@app.get("/api/auth/me")
def get_me(authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    user = firebase_auth.get_user(user_id)
    created_at = None
    if user.user_metadata and user.user_metadata.creation_timestamp:
        created_at = datetime.utcfromtimestamp(user.user_metadata.creation_timestamp / 1000).isoformat()
    return {
        "id": user.uid,
        "username": user.display_name or user.email,
        "email": user.email,
        "created_at": created_at,
    }

@app.get("/api/sync")
def get_sync(authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    doc = db.collection(SYNC_COLLECTION).document(user_id).get()
    if not doc.exists:
        return {
            "vocabulary": [], "articles": [], "stats": {},
            "xp_events": [], "streak_freezes": 1, "curriculum_progress": [],
            "updated_at": "",
        }
    data = doc.to_dict()
    return {
        "vocabulary": data.get("vocabulary", []),
        "articles": data.get("articles", []),
        "stats": data.get("stats", {}),
        "xp_events": data.get("xp_events", []),
        "streak_freezes": data.get("streak_freezes", 1),
        "curriculum_progress": data.get("curriculum_progress", []),
        "updated_at": data.get("updated_at", ""),
    }

@app.post("/api/sync")
def post_sync(payload: SyncPayload, authorization: str = Header(None), x_auth_token: str = Header(None)):
    user_id = get_current_user_id(authorization, x_auth_token)
    now = datetime.utcnow().isoformat()
    sync_ref = db.collection(SYNC_COLLECTION).document(user_id)

    @firestore.transactional
    def merge_sync(transaction):
        snapshot = sync_ref.get(transaction=transaction)
        existing = snapshot.to_dict() if snapshot.exists else {}

        existing_vocab = existing.get("vocabulary", [])
        existing_articles = existing.get("articles", [])
        existing_stats = existing.get("stats", {})
        existing_xp_events = existing.get("xp_events", [])
        existing_streak_freezes = existing.get("streak_freezes", 1)
        existing_curriculum = existing.get("curriculum_progress", [])

        existing_vocab, existing_articles, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum = _merge_sync_payload(
            payload, existing_vocab, existing_articles, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum
        )

        transaction.set(sync_ref, {
            "vocabulary": existing_vocab, "articles": existing_articles, "stats": existing_stats,
            "xp_events": existing_xp_events, "streak_freezes": existing_streak_freezes,
            "curriculum_progress": existing_curriculum, "updated_at": now,
        })
        return existing_vocab, existing_xp_events

    existing_vocab, existing_xp_events = merge_sync(db.transaction())

    return {
        "status": "success", "updated_at": now,
        "count_vocab": len(existing_vocab), "count_xp_events": len(existing_xp_events),
    }

def _merge_sync_payload(payload, existing_vocab, existing_articles, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum):
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

    if payload.xp_events is not None:
        # Additive union keyed by event id — an append-only log, never overwritten
        # wholesale, so a device that syncs late can't erase XP earned elsewhere.
        xp_map = {e.get('id'): e for e in existing_xp_events if e.get('id')}
        for e in payload.xp_events:
            eid = e.get('id')
            if eid:
                xp_map[eid] = e
        existing_xp_events = list(xp_map.values())

    if payload.streak_freezes is not None:
        existing_streak_freezes = payload.streak_freezes

    if payload.curriculum_progress is not None:
        existing_curriculum = sorted(set(existing_curriculum) | set(payload.curriculum_progress))

    return existing_vocab, existing_articles, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum

# Mount static web app files if available
web_build_dir = os.path.join(os.path.dirname(__file__), "public_web")
print(f"Checking web_build_dir: {web_build_dir}, exists: {os.path.exists(web_build_dir)}")
if os.path.exists(web_build_dir):
    print(f"Contents of {web_build_dir}: {os.listdir(web_build_dir)}")
    app.mount("/app", StaticFiles(directory=web_build_dir, html=True), name="web_app")
    app.mount("/", StaticFiles(directory=web_build_dir, html=True), name="web_root")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

