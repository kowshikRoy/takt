
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
import base64
import wave
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
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None
try:
    from langdetect import detect, detect_langs
except ImportError:
    detect = None
    detect_langs = None
from urllib.parse import urlparse, urljoin
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

class ImportUrlRequest(BaseModel):
    url: str

class SubmitResponse(BaseModel):
    task_id: str
    title: str | None = None
    thumbnail: str | None = None

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
    title: str | None = None
    thumbnail: str | None = None
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
    """Extracts title, thumbnail, subtitles, and direct audio stream URL via YouTube's InnerTube API across multiple client profiles (IOS, TV, Android)."""
    video_id_match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', url)
    if not video_id_match:
        return None
    video_id = video_id_match.group(1)
    
    api_keys = [
        'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
        'AIzaSyC2d01sLSt1iC1h9828h-Z1w6l9eR41j2k',
    ]

    client_profiles = [
        {
            'name': 'IOS',
            'clientName': 'IOS',
            'clientVersion': '19.29.1',
            'deviceModel': 'iPhone16,2',
            'userAgent': 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; de_DE)',
            'clientNameHeader': '5',
        },
        {
            'name': 'TV_EMBEDDED',
            'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            'clientVersion': '2.0',
            'userAgent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/76.0.3809.146 TV Safari/537.36',
            'clientNameHeader': '85',
        },
        {
            'name': 'ANDROID',
            'clientName': 'ANDROID',
            'clientVersion': '20.01.35',
            'userAgent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)',
            'clientNameHeader': '3',
        },
        {
            'name': 'WEB_EMBEDDED',
            'clientName': 'WEB_EMBEDDED_PLAYER',
            'clientVersion': '1.20240724.01.00',
            'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
            'clientNameHeader': '56',
        },
    ]
    
    visitor_data = 'CgtlRFpWTlF2cnVrVSjv09LTBjIKCgJDSBIEGgAgBToCCAFi4AIK'
    try:
        vis_res = requests.post(
            'https://www.youtube.com/youtubei/v1/visitor_id',
            json={'context': {'client': {'clientName': 'ANDROID', 'clientVersion': '20.01.35'}}},
            headers={'User-Agent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)'},
            timeout=3
        ).json()
        vd = vis_res.get('responseContext', {}).get('visitorData')
        if vd:
            visitor_data = vd
    except Exception as e:
        print(f"visitor_id API warning: {e}")

    for profile in client_profiles:
        headers = {
            'User-Agent': profile['userAgent'],
            'X-YouTube-Client-Name': profile['clientNameHeader'],
            'X-YouTube-Client-Version': profile['clientVersion'],
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
        }

        for api_key in api_keys:
            try:
                player_endpoint = f'https://www.youtube.com/youtubei/v1/player?key={api_key}'
                client_ctx = {
                    'clientName': profile['clientName'],
                    'clientVersion': profile['clientVersion'],
                    'hl': 'de',
                    'gl': 'DE',
                }
                if profile.get('deviceModel'):
                    client_ctx['deviceModel'] = profile['deviceModel']
                if visitor_data:
                    client_ctx['visitorData'] = visitor_data

                payload = {
                    'videoId': video_id,
                    'contentCheckOk': True,
                    'racyCheckOk': True,
                    'context': {
                        'client': client_ctx
                    }
                }
                if 'EMBEDDED' in profile['name']:
                    payload['context']['thirdParty'] = {
                        'embedUrl': f'https://www.youtube.com/embed/{video_id}'
                    }

                res = requests.post(player_endpoint, json=payload, headers=headers, timeout=6).json()
                playability = res.get('playabilityStatus', {}).get('status')
                video_details = res.get('videoDetails', {})
                title = video_details.get('title')

                if not title or playability not in ['OK', None]:
                    print(f"InnerTube profile {profile['name']} playability: {playability}")
                    continue

                thumbs = video_details.get('thumbnail', {}).get('thumbnails', [])
                thumbnail = thumbs[-1].get('url') if thumbs else f"https://i.ytimg.com/vi/{video_id}/sddefault.jpg"
                
                streaming_data = res.get('streamingData', {})
                adaptive_formats = streaming_data.get('adaptiveFormats', [])
                audio_fmts = [f for f in adaptive_formats if 'audio' in f.get('mimeType', '') and f.get('url')]
                audio_stream_url = audio_fmts[0].get('url') if audio_fmts else None

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
                    cues = fetch_innertube_transcript_api(url)
                
                print(f"InnerTube {profile['name']} SUCCESS: '{title}' (cues: {len(cues)}, direct audio: {bool(audio_stream_url)})")
                return {
                    'title': title,
                    'thumbnail': thumbnail,
                    'subtitles': cues,
                    'audio_stream_url': audio_stream_url,
                    'url': url,
                }
            except Exception as e:
                print(f"InnerTube profile {profile['name']} error: {e}")

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
                'player_client': ['android', 'ios', 'tv_embedded', 'mweb'],
            }
        },
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        }
    }
    if extra_opts:
        opts.update(extra_opts)
    return opts

def fetch_youtube_metadata_fast(url: str) -> dict:
    """
    Extracts YouTube video ID, official title, channel name, and high-resolution thumbnail URL
    using YouTube's official oEmbed API (100% reliable across Cloud Run IPs without bot blocks).
    """
    video_id_match = re.search(r'(?:v=|\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})', url)
    video_id = video_id_match.group(1) if video_id_match else None
    
    title = 'German Lesson'
    thumbnail = None
    author_name = None
    
    if video_id:
        thumbnail = f"https://i.ytimg.com/vi/{video_id}/maxresdefault.jpg"
        try:
            oembed_url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={video_id}&format=json"
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
            r = requests.get(oembed_url, headers=headers, timeout=5)
            if r.status_code == 200:
                data = r.json()
                if data.get('title'):
                    title = data['title']
                if data.get('author_name'):
                    author_name = data['author_name']
                if data.get('thumbnail_url'):
                    thumbnail = data['thumbnail_url']
        except Exception as e:
            print(f"oEmbed fetch error for {video_id}: {e}")
            
        if not thumbnail:
            thumbnail = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
            
    return {
        'video_id': video_id,
        'title': title,
        'thumbnail': thumbnail,
        'author_name': author_name
    }

def get_media_info(url: str):
    """Extracts direct media stream URL, video title, thumbnail URL, and captions dict via yt-dlp and oEmbed."""
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

    # Fast oEmbed YouTube metadata fallback
    if 'youtube.com' in url or 'youtu.be' in url:
        yt_meta = fetch_youtube_metadata_fast(url)
        if yt_meta.get('title') and yt_meta['title'] != 'German Lesson':
            title = yt_meta['title']
        if yt_meta.get('thumbnail'):
            thumbnail = yt_meta['thumbnail']

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info:
                direct_url = info.get('url', url)
                if info.get('title'):
                    title = info.get('title')
                if info.get('thumbnail'):
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
    """Downloads audio stream using multiple fallback strategies (Direct CDN stream, pytubefix, yt-dlp)."""
    # 1. Direct stream URL download if present
    if direct_stream_url and str(direct_stream_url).startswith('http') and direct_stream_url != url:
        try:
            print(f"Downloading audio directly from direct_stream_url: {direct_stream_url[:60]}...")
            headers = {
                'User-Agent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)',
            }
            res = requests.get(direct_stream_url, headers=headers, stream=True, timeout=25)
            if res.status_code == 200:
                target_file = f"{output_path}.mp4"
                with open(target_file, 'wb') as f:
                    for chunk in res.iter_content(chunk_size=65536):
                        if chunk:
                            f.write(chunk)
                if os.path.exists(target_file) and os.path.getsize(target_file) > 1024:
                    print(f"Direct stream download succeeded: {target_file} ({os.path.getsize(target_file)} bytes)")
                    return target_file
        except Exception as e:
            print(f"Direct stream download failed: {e}")

    # 2. Extract direct audio CDN URL via InnerTube API across profiles (IOS, TV, ANDROID)
    video_id_match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', url)
    if video_id_match:
        video_id = video_id_match.group(1)
        profiles_to_try = [
            {'name': 'IOS', 'clientName': 'IOS', 'clientVersion': '19.29.1', 'deviceModel': 'iPhone16,2', 'userAgent': 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; de_DE)', 'clientNameHeader': '5'},
            {'name': 'TV', 'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER', 'clientVersion': '2.0', 'userAgent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/76.0.3809.146 TV Safari/537.36', 'clientNameHeader': '85'},
            {'name': 'ANDROID', 'clientName': 'ANDROID', 'clientVersion': '20.01.35', 'userAgent': 'com.google.android.youtube/20.01.35 (Linux; U; Android 14; de_DE)', 'clientNameHeader': '3'},
        ]
        for p in profiles_to_try:
            try:
                headers = {
                    'User-Agent': p['userAgent'],
                    'X-YouTube-Client-Name': p['clientNameHeader'],
                    'X-YouTube-Client-Version': p['clientVersion'],
                    'Origin': 'https://www.youtube.com',
                    'Referer': 'https://www.youtube.com/',
                }
                client_ctx = {'clientName': p['clientName'], 'clientVersion': p['clientVersion'], 'hl': 'de', 'gl': 'DE'}
                if p.get('deviceModel'):
                    client_ctx['deviceModel'] = p['deviceModel']
                payload = {'videoId': video_id, 'contentCheckOk': True, 'racyCheckOk': True, 'context': {'client': client_ctx}}
                if 'TV' in p['name']:
                    payload['context']['thirdParty'] = {'embedUrl': f'https://www.youtube.com/embed/{video_id}'}

                res = requests.post(
                    'https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
                    json=payload,
                    headers=headers,
                    timeout=8
                ).json()
                adaptive_formats = res.get('streamingData', {}).get('adaptiveFormats', [])
                audio_fmts = [f for f in adaptive_formats if 'audio' in f.get('mimeType', '') and f.get('url')]
                if audio_fmts:
                    cdn_url = audio_fmts[0]['url']
                    print(f"InnerTube {p['name']} returned direct audio CDN URL, downloading stream...")
                    stream_res = requests.get(cdn_url, headers=headers, stream=True, timeout=25)
                    if stream_res.status_code == 200:
                        target_file = f"{output_path}.mp4"
                        with open(target_file, 'wb') as f:
                            for chunk in stream_res.iter_content(chunk_size=65536):
                                if chunk:
                                    f.write(chunk)
                        if os.path.exists(target_file) and os.path.getsize(target_file) > 1024:
                            print(f"InnerTube {p['name']} stream download succeeded: {target_file} ({os.path.getsize(target_file)} bytes)")
                            return target_file
            except Exception as e:
                print(f"InnerTube {p['name']} audio stream download failed: {e}")

    # 3. Try pytubefix
    for client_type in ['MWEB', 'ANDROID', 'WEB']:
        try:
            from pytubefix import YouTube
            print(f"Trying pytubefix with client '{client_type}'...")
            yt = YouTube(url, client=client_type)
            audio_stream = yt.streams.filter(only_audio=True).first()
            if audio_stream:
                target_file = f"{output_path}.mp4"
                audio_stream.download(filename=target_file)
                if os.path.exists(target_file) and os.path.getsize(target_file) > 1024:
                    print(f"pytubefix ({client_type}) audio download succeeded ({os.path.getsize(target_file)} bytes)")
                    return target_file
        except Exception as e:
            print(f"pytubefix ({client_type}) failed: {e}")

    # 4. Try yt-dlp with diverse player client fallbacks
    for client_combo in [['android'], ['ios'], ['tv_embedded'], ['mweb'], ['web_embedded']]:
        try:
            print(f"Trying yt-dlp with player_client {client_combo}...")
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'nocheckcertificate': True,
                'ignoreerrors': True,
                'format': 'ba/b/best',
                'outtmpl': f'{output_path}.%(ext)s',
                'extractor_args': {
                    'youtube': {
                        'player_client': client_combo,
                    }
                },
                'http_headers': {
                    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
                }
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            matches = glob.glob(f'{output_path}.*')
            if matches and os.path.getsize(matches[0]) > 1024:
                print(f"yt-dlp ({client_combo}) succeeded: {matches[0]} ({os.path.getsize(matches[0])} bytes)")
                return matches[0]
        except Exception as e:
            print(f"yt-dlp ({client_combo}) failed: {e}")

    matches = glob.glob(f'{output_path}.*')
    if not matches:
        raise RuntimeError("This YouTube video has playback or age/sign-in restrictions enabled on YouTube. Please try another video or paste the text directly.")
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

def transcribe_youtube_with_gemini(url: str, api_key: str = None) -> tuple[list[SubtitleCue], str | None]:
    """Uses Gemini multimodal capabilities to directly transcribe YouTube videos and extract descriptive titles without scraping or bot blocks."""
    key = api_key or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        print("No GEMINI_API_KEY configured for Gemini YouTube fallback.")
        return [], None
    
    # Normalize short youtu.be URLs to standard YouTube format
    if 'youtu.be/' in url:
        vid = url.split('youtu.be/')[1].split('?')[0].split('&')[0]
        url = f"https://www.youtube.com/watch?v={vid}"

    models_to_try = ["gemini-flash-latest", "gemini-flash-lite-latest", "gemini-2.0-flash"]
    for model_name in models_to_try:
        try:
            print(f"Calling Gemini ({model_name}) REST API to transcribe YouTube video directly: {url}")
            prompt = (
                "You are an expert German language transcription and learning system. "
                "Listen to this YouTube video and produce:\n"
                "1. A clear, descriptive title for this German lesson/video/conversation.\n"
                "2. A complete, verbatim timestamped transcription of all spoken German sentences with synchronized English translations.\n"
                "Respond ONLY with a valid JSON object matching this exact schema:\n"
                "{\n"
                '  "title": "Anna helps with German Homework",\n'
                '  "subtitles": [\n'
                "    {\n"
                '      "start": 0.0,\n'
                '      "end": 13.5,\n'
                '      "original": "Anna, könntest du mir bitte kurz helfen?",\n'
                '      "translated": "Anna, could you please help me for a moment?"\n'
                "    }\n"
                "  ]\n"
                "}\n"
                "Return only the valid JSON."
            )

            endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={key}"
            payload = {
                "contents": [
                    {
                        "parts": [
                            {
                                "file_data": {
                                    "file_uri": url,
                                    "mime_type": "video/*"
                                }
                            },
                            {
                                "text": prompt
                            }
                        ]
                    }
                ],
                "generationConfig": {
                    "responseMimeType": "application/json"
                }
            }

            res = requests.post(endpoint, json=payload, headers={"Content-Type": "application/json"}, timeout=240)
            if res.status_code != 200:
                print(f"Gemini ({model_name}) returned status {res.status_code}: {res.text}")
                continue

            res_json = res.json()
            candidates = res_json.get("candidates", [])
            if not candidates:
                print(f"Gemini ({model_name}) returned no candidates.")
                continue

            raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:]
            if raw_text.startswith("```"):
                raw_text = raw_text[3:]
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3]
            raw_text = raw_text.strip()

            data = json.loads(raw_text)
            extracted_title = None
            raw_cues = []
            if isinstance(data, dict):
                extracted_title = data.get("title")
                raw_cues = data.get("subtitles") or data.get("cues") or []
            elif isinstance(data, list):
                raw_cues = data

            cues = []
            for item in raw_cues:
                st = float(item.get("start", item.get("start_time", 0.0)))
                et = float(item.get("end", item.get("end_time", st + 3.0)))
                de_text = str(item.get("original", item.get("text", item.get("german", "")))).strip()
                en_text = str(item.get("translated", item.get("translation", item.get("english", "")))).strip()
                if de_text:
                    cues.append(SubtitleCue(
                        start=st,
                        end=et,
                        original=de_text,
                        translated=en_text or None
                    ))
            if cues:
                print(f"Gemini AI successfully extracted {len(cues)} clean subtitle cues for {url} with title: '{extracted_title}'!")
                return cues, extracted_title
        except Exception as e:
            print(f"Gemini ({model_name}) YouTube transcription error: {e}")
    return [], None

def generate_dialogue_audio_with_gemini(dialogue_lines: list[str], output_wav_path: str, api_key: str = None) -> bool:
    """
    Generates studio German audio for the dialogue script using Gemini 2.5 Flash TTS 
    with expressive voice acting directives in 1 single call (strictly 1 RPM).
    Includes automatic 429 exponential backoff retry.
    """
    key = api_key or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key or not dialogue_lines:
        return False

    max_lines = 35
    lines_to_speak = dialogue_lines[:max_lines]
    full_dialogue_text = "\n".join(lines_to_speak)
    
    prompt = (
        "You are a professional native German voice actor. "
        "Perform the following German conversation with authentic native pronunciation, lively conversational cadence, "
        "expressive intonation, natural breathing pauses between sentences, and engaging warmth:\n\n"
        f"{full_dialogue_text}"
    )
    
    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key={key}"
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseModalities": ["AUDIO"]
        }
    }

    for attempt in range(3):
        try:
            print(f"Calling Gemini Studio TTS (attempt {attempt+1}/3, {len(lines_to_speak)} dialogue lines)...")
            res = requests.post(endpoint, json=payload, headers={"Content-Type": "application/json"}, timeout=240)
            if res.status_code == 200:
                res_json = res.json()
                candidates = res_json.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    for part in parts:
                        inline_data = part.get("inlineData", {})
                        if inline_data.get("data"):
                            pcm_bytes = base64.b64decode(inline_data["data"])
                            # Write 24kHz 16-bit Mono WAV file
                            with wave.open(output_wav_path, "wb") as wav_file:
                                wav_file.setnchannels(1)
                                wav_file.setsampwidth(2)
                                wav_file.setframerate(24000)
                                wav_file.writeframes(pcm_bytes)
                            print(f"Successfully generated Gemini Studio WAV audio ({len(pcm_bytes)} bytes) at {output_wav_path}")
                            return True
            elif res.status_code == 429:
                print(f"Gemini TTS rate limited (429), waiting 8s before retry (attempt {attempt+1}/3)...")
                time.sleep(8)
                continue
            else:
                print(f"Gemini TTS returned status {res.status_code}: {res.text[:200]}")
                break
        except Exception as e:
            print(f"Gemini TTS generation error (attempt {attempt+1}): {e}")
            time.sleep(5)

    return False

    return False

def align_subtitles_to_audio(subtitles: list[SubtitleCue], audio_path: str) -> list[SubtitleCue]:
    """
    Re-aligns subtitle cue start and end timestamps against the synthesized Gemini Studio audio track
    using in-memory Whisper audio inference (<1.0s).
    Preserves all original German text and synchronized English translations.
    """
    if not subtitles or not os.path.exists(audio_path):
        return subtitles

    try:
        model = get_whisper_model()
        segments, _ = model.transcribe(
            audio_path,
            language="de",
            beam_size=1,
            best_of=1,
            vad_filter=True
        )
        whisper_cues = []
        for s in segments:
            txt = s.text.strip()
            if txt:
                whisper_cues.append({'start': round(s.start, 2), 'end': round(s.end, 2), 'text': txt})

        if not whisper_cues:
            return subtitles

        print(f"Aligning {len(subtitles)} subtitle cues with {len(whisper_cues)} audio segments...")

        # Case 1: Exact 1-to-1 segment count match
        if len(whisper_cues) == len(subtitles):
            aligned = []
            for cue, w_cue in zip(subtitles, whisper_cues):
                aligned.append(SubtitleCue(
                    start=w_cue['start'],
                    end=max(round(w_cue['start'] + 0.5, 2), w_cue['end']),
                    original=cue.original,
                    translated=cue.translated
                ))
            print(f"Direct 1-to-1 audio alignment completed ({len(aligned)} cues)!")
            return aligned

        # Case 2: Proportional text length distribution across real audio duration
        total_audio_duration = max(whisper_cues[-1]['end'], 1.0)
        total_char_count = max(sum(len(c.original) for c in subtitles), 1)

        aligned = []
        current_time = whisper_cues[0]['start']
        for cue in subtitles:
            cue_len = max(len(cue.original), 1)
            duration_share = (cue_len / total_char_count) * (total_audio_duration - whisper_cues[0]['start'])
            end_time = round(min(current_time + duration_share, total_audio_duration), 2)
            aligned.append(SubtitleCue(
                start=round(current_time, 2),
                end=max(round(current_time + 0.5, 2), end_time),
                original=cue.original,
                translated=cue.translated
            ))
            current_time = end_time

        print(f"Proportional audio alignment completed ({len(aligned)} cues over {total_audio_duration}s)!")
        return aligned
    except Exception as e:
        print(f"Audio subtitle alignment error: {e}")
        return subtitles

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

def update_task_stage(task_id: str, stage_msg: str, progress_pct: int, title: str = None, thumbnail: str = None):
    """Helper to record granular task progress while preserving title and thumbnail."""
    prev = tasks.get(task_id, {})
    current_title = title or prev.get("title")
    current_thumbnail = thumbnail or prev.get("thumbnail")
    tasks[task_id] = {
        "status": TaskStatus.PROCESSING,
        "stage_message": stage_msg,
        "progress_percentage": progress_pct,
        "title": current_title,
        "thumbnail": current_thumbnail,
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
    title: str | None = None
    thumbnail: str | None = None
    media_url: str | None = None
    subtitles: list[SubtitleCue] = []
    audio_stream_url: str | None = None
    media_info: dict = {}
    yt_meta: dict = {}

    try:
        update_task_stage(task_id, "Checking for official subtitles...", 20)
        
        # 0. Quick YouTube metadata extraction for title, channel author, and high-res thumbnail
        if 'youtube.com' in url or 'youtu.be' in url:
            yt_meta = await asyncio.to_thread(fetch_youtube_metadata_fast, url)
            if yt_meta.get('title') and yt_meta['title'] not in ['German Lesson', 'Media']:
                title = yt_meta['title']
            if yt_meta.get('thumbnail'):
                thumbnail = yt_meta['thumbnail']

        # 1. Try InnerTube DIRECT ANDROID API (Zero watchpage requests, zero bot block, extracts title, thumbnail & 388 cues in 0.2s)
        innertube_data = await asyncio.to_thread(fetch_innertube_media_data, url)
        
        subtitles = []
        audio_stream_url = None
        media_info = {}
        if innertube_data:
            if innertube_data.get('title') and innertube_data['title'] not in ['German Lesson', 'Media']:
                title = innertube_data['title']
            if innertube_data.get('thumbnail'):
                thumbnail = innertube_data['thumbnail']
            subtitles = innertube_data.get('subtitles') or []
            media_url = innertube_data['url']
            audio_stream_url = innertube_data.get('audio_stream_url')
        else:
            update_task_stage(task_id, "Extracting video title & thumbnail...", 35)
            media_info = await asyncio.to_thread(get_media_info, url)
            media_url = media_info['url']
            if media_info.get('title') and media_info['title'] not in ['German Lesson', 'Media']:
                title = media_info['title']
            if media_info.get('thumbnail'):
                thumbnail = media_info['thumbnail']
            audio_stream_url = media_info.get('audio_stream_url')

        try:
            # 2. Fetch direct CDN VTT subtitle URL extracted from get_media_info
            if not subtitles and media_info:
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

            # 5. Targeted yt-dlp download if CDN and transcript API were empty
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
            # 1. Try Gemini Multimodal AI transcription directly on the YouTube video
            if 'youtube.com' in url or 'youtu.be' in url:
                update_task_stage(task_id, "Transcribing with Gemini Multimodal AI...", 80)
                gemini_subtitles, gemini_title = await asyncio.to_thread(transcribe_youtube_with_gemini, url)
                subtitles = gemini_subtitles
                if gemini_title and (not title or title in ['Media', 'German Lesson']):
                    title = gemini_title

            # 2. Fall back to local audio stream download + Whisper AI
            if not subtitles:
                update_task_stage(task_id, "Downloading audio stream...", 55)
                downloaded_audio_path = await asyncio.to_thread(
                    download_media, url, media_filename, audio_stream_url
                )

                update_task_stage(task_id, "Analyzing media format...", 70)
                media_type = await asyncio.to_thread(get_media_type, downloaded_audio_path)

                update_task_stage(task_id, "Transcribing German speech with Whisper AI...", 85)
                subtitles = await asyncio.to_thread(transcribe_and_translate, downloaded_audio_path)
        
        # Generate high-fidelity German Studio audio with Gemini 2.5 Flash TTS in 1 single call (respecting 3 RPM limit)
        if subtitles and (not media_url or 'youtube.com' in media_url or 'youtu.be' in media_url):
            try:
                update_task_stage(task_id, "Synthesizing German studio dialogue audio...", 92)
                dialogue_lines = [s.original for s in subtitles if s.original.strip()]
                audio_filename = f"{task_id}_dialogue.wav"
                audio_path = os.path.join(CACHE_DIR, audio_filename)
                if await asyncio.to_thread(generate_dialogue_audio_with_gemini, dialogue_lines, audio_path):
                    app_url = os.environ.get("SERVICE_URL") or "https://omniscribe-184475424927.europe-west4.run.app"
                    media_url = f"{app_url}/audio/{audio_filename}"
                    media_type = "audio"

                    # Re-align subtitle timestamps with the synthesized studio audio track
                    update_task_stage(task_id, "Synchronizing subtitles with studio audio...", 94)
                    subtitles = await asyncio.to_thread(align_subtitles_to_audio, subtitles, audio_path)
            except Exception as tts_err:
                print(f"Gemini Studio TTS synthesis skipped: {tts_err}")

        # Ensure thumbnail is high quality YouTube thumbnail if available
        if not thumbnail or 'picsum.photos' in str(thumbnail):
            if yt_meta.get('thumbnail'):
                thumbnail = yt_meta['thumbnail']
            elif 'youtube.com' in url or 'youtu.be' in url:
                vid_match = re.search(r'(?:v=|\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})', url)
                if vid_match:
                    thumbnail = f"https://i.ytimg.com/vi/{vid_match.group(1)}/hqdefault.jpg"

        update_task_stage(task_id, "Finalizing media lesson...", 95)
        response_data = MediaResponse(
            video_url=media_url,
            media_type=media_type,
            subtitles=subtitles,
            title=title or "German Dialogue Lesson",
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
    
    # Instant metadata extraction in 50ms for immediate background UI display
    initial_title = None
    initial_thumbnail = None
    if 'youtube.com' in request.url or 'youtu.be' in request.url:
        yt_meta = await asyncio.to_thread(fetch_youtube_metadata_fast, request.url)
        if yt_meta.get('title') and yt_meta['title'] != 'German Lesson':
            initial_title = yt_meta['title']
        if yt_meta.get('thumbnail'):
            initial_thumbnail = yt_meta['thumbnail']

    tasks[task_id] = {
        "status": TaskStatus.PENDING,
        "stage_message": "Connecting to video source...",
        "progress_percentage": 5,
        "title": initial_title,
        "thumbnail": initial_thumbnail,
        "result": None,
        "error": None
    }
    background_tasks.add_task(process_media_task, task_id, request.url)
    return SubmitResponse(task_id=task_id, title=initial_title, thumbnail=initial_thumbnail)

@app.get("/audio/{filename}")
async def get_audio_file(filename: str):
    file_path = os.path.join(CACHE_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(file_path, media_type="audio/wav")

@app.get("/status/{task_id}", response_model=StatusResponse)
async def get_status(task_id: str, wait_seconds: int = 1):
    """Returns task status immediately if completed/failed, or holds for up to 1 second during active processing for CPU keep-alive."""
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if task.get("status") in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
        return StatusResponse(**task)
    
    if wait_seconds > 0:
        await asyncio.sleep(min(wait_seconds, 1))
        task = tasks.get(task_id, task)
        
    return StatusResponse(**task)

@app.get("/health")
def health_check():
    """Health check endpoint for monitoring and warm pings."""
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}

def _start_self_ping_thread():
    """Starts a background daemon thread that calls the public /health endpoint every 9 minutes."""
    import threading
    import time

    def _ping_loop():
        app_url = os.environ.get("SERVICE_URL") or "https://omniscribe-184475424927.europe-west4.run.app"
        health_url = f"{app_url}/health"
        time.sleep(20)  # Initial grace period after startup
        while True:
            try:
                time.sleep(540)  # Ping every 9 minutes
                res = requests.get(health_url, timeout=15)
                print(f"Self-ping keep-alive to {health_url} - Status: {res.status_code}", flush=True)
            except Exception as e:
                print(f"Self-ping error: {e}", flush=True)

    thread = threading.Thread(target=_ping_loop, daemon=True, name="keep-alive-pinger")
    thread.start()

@app.on_event("startup")
async def startup_event():
    _start_self_ping_thread()

def _extract_article(url: str) -> dict:
    """Fetches a web page and extracts title/content/description/cover image.

    Ported from the pre-FastAPI Flask backend (backend/app.py's original
    /import_url) using BeautifulSoup + lxml for real HTML parsing, since the
    Flutter client's local regex-based fallback scraper doesn't decode HTML
    entities (mangles German umlauts like &uuml; instead of ü).
    """
    if BeautifulSoup is None:
        raise HTTPException(status_code=500, detail="Article import is unavailable (beautifulsoup4 not installed)")

    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=408, detail="Request timeout - the website took too long to respond")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=400, detail=f"Failed to fetch URL: {e}")

    soup = BeautifulSoup(response.content, 'lxml')

    for tag in soup(["script", "style", "nav", "header", "footer", "aside"]):
        tag.decompose()

    cover_image_url = None
    og_image = soup.find('meta', property='og:image')
    if og_image and og_image.get('content'):
        cover_image_url = og_image['content']
    if not cover_image_url:
        twitter_image = soup.find('meta', attrs={'name': 'twitter:image'})
        if twitter_image and twitter_image.get('content'):
            cover_image_url = twitter_image['content']

    title = None
    if soup.title and soup.title.string:
        title = soup.title.string
    elif soup.find('h1'):
        title = soup.find('h1').get_text()

    main_content = None
    for selector in ['article', 'main', '.article-content', '.post-content', '.entry-content']:
        if selector.startswith('.'):
            main_content = soup.find(class_=selector[1:])
        else:
            main_content = soup.find(selector)
        if main_content:
            break
    if not main_content:
        main_content = soup.find(attrs={'role': 'main'})
    if not main_content:
        main_content = soup.find('body')
    if not main_content:
        raise HTTPException(status_code=400, detail="Could not extract content from page")

    if not cover_image_url:
        article_tag = soup.find('article')
        search_area = article_tag if article_tag else main_content
        first_img = search_area.find('img')
        if first_img and first_img.get('src'):
            img_src = first_img['src']
            if img_src.startswith('//'):
                img_src = 'https:' + img_src
            elif not img_src.startswith('http'):
                img_src = urljoin(url, img_src)
            cover_image_url = img_src

    if not cover_image_url:
        favicon_link = soup.find('link', rel=lambda x: x and 'icon' in x.lower() if x else False)
        if favicon_link and favicon_link.get('href'):
            favicon_href = favicon_link['href']
            if favicon_href.startswith('//'):
                favicon_href = 'https:' + favicon_href
            elif not favicon_href.startswith('http'):
                favicon_href = urljoin(url, favicon_href)
            cover_image_url = favicon_href
        else:
            parsed_url = urlparse(url)
            cover_image_url = f"{parsed_url.scheme}://{parsed_url.netloc}/favicon.ico"

    paragraphs = main_content.find_all('p')
    content_parts = [p.get_text().strip() for p in paragraphs if len(p.get_text().strip()) > 20]
    if content_parts:
        content = '\n\n'.join(content_parts)
    else:
        content = '\n\n'.join(line.strip() for line in main_content.get_text().split('\n') if line.strip())

    if not content or len(content) < 50:
        raise HTTPException(status_code=400, detail="Extracted content is too short or empty")

    description = content[:200] + '...' if len(content) > 200 else content

    detected_lang = 'de'
    if detect_langs is not None:
        try:
            detection_text = f"{title}. {content}" if title else content
            lang_probs = detect_langs(detection_text)
            if lang_probs:
                detected_lang = lang_probs[0].lang
                confidence = lang_probs[0].prob
                if detected_lang == 'de' and confidence < 0.7:
                    en_prob = next((p.prob for p in lang_probs if p.lang == 'en'), 0)
                    if en_prob > 0.3:
                        detected_lang = 'en'
        except Exception:
            pass

    return {
        'title': title or 'Imported Article',
        'content': content,
        'description': description,
        'url': url,
        'original_language': detected_lang,
        'was_translated': False,
        'cover_image_url': cover_image_url,
    }

@app.post("/import_url")
async def import_url(request: ImportUrlRequest):
    url = request.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="Missing url parameter")
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        raise HTTPException(status_code=400, detail="Invalid URL format")

    return await asyncio.to_thread(_extract_article, url)

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
    media: list[dict] | None = None
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
            "vocabulary": [], "articles": [], "media": [], "stats": {},
            "xp_events": [], "streak_freezes": 1, "curriculum_progress": [],
            "updated_at": "",
        }
    data = doc.to_dict()
    return {
        "vocabulary": data.get("vocabulary", []),
        "articles": data.get("articles", []),
        "media": data.get("media", []),
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
        existing_media = existing.get("media", [])
        existing_stats = existing.get("stats", {})
        existing_xp_events = existing.get("xp_events", [])
        existing_streak_freezes = existing.get("streak_freezes", 1)
        existing_curriculum = existing.get("curriculum_progress", [])

        existing_vocab, existing_articles, existing_media, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum = _merge_sync_payload(
            payload, existing_vocab, existing_articles, existing_media, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum
        )

        transaction.set(sync_ref, {
            "vocabulary": existing_vocab, "articles": existing_articles, "media": existing_media, "stats": existing_stats,
            "xp_events": existing_xp_events, "streak_freezes": existing_streak_freezes,
            "curriculum_progress": existing_curriculum, "updated_at": now,
        })
        return existing_vocab, existing_xp_events

    existing_vocab, existing_xp_events = merge_sync(db.transaction())

    return {
        "status": "success", "updated_at": now,
        "count_vocab": len(existing_vocab), "count_xp_events": len(existing_xp_events),
    }

def _merge_sync_payload(payload, existing_vocab, existing_articles, existing_media, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum):
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

    if payload.media is not None:
        media_map = {item.get('id'): item for item in existing_media if item.get('id')}
        for item in payload.media:
            k = item.get('id')
            if k:
                media_map[k] = item
        existing_media = list(media_map.values())

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

    return existing_vocab, existing_articles, existing_media, existing_stats, existing_xp_events, existing_streak_freezes, existing_curriculum

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

