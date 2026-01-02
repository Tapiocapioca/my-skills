"""
yt-dlp Server - REST API for YouTube transcript extraction.

Endpoints:
- GET /health - Health check
- GET /youtube/info - Get video metadata and available subtitles
- POST /youtube/transcript - Extract transcript from YouTube video
"""

import os
import re
import json
import tempfile
import subprocess
from typing import Optional, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from utils.vtt_cleaner import clean_vtt_content


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan handler for startup/shutdown."""
    os.makedirs("/app/temp", exist_ok=True)
    yield
    import shutil
    shutil.rmtree("/app/temp", ignore_errors=True)


app = FastAPI(
    title="yt-dlp Server",
    description="REST API for YouTube transcript extraction",
    version="1.0.0",
    lifespan=lifespan
)


# ============================================================================
# Models
# ============================================================================

class YouTubeRequest(BaseModel):
    url: str
    language: str = "en"
    prefer_manual: bool = True


class YouTubeResponse(BaseModel):
    success: bool
    video_id: str
    title: Optional[str] = None
    transcript: Optional[str] = None
    source: Optional[str] = None  # "manual", "auto-generated"
    language: str
    duration: Optional[int] = None
    error: Optional[str] = None


class VideoInfo(BaseModel):
    video_id: str
    title: str
    duration: int
    channel: str
    upload_date: Optional[str] = None
    has_manual_subs: bool
    has_auto_subs: bool
    available_languages: List[str]


# ============================================================================
# Helper Functions
# ============================================================================

def extract_video_id(url: str) -> str:
    """Extract YouTube video ID from various URL formats."""
    patterns = [
        r'(?:v=|/v/|youtu\.be/)([a-zA-Z0-9_-]{11})',
        r'(?:embed/)([a-zA-Z0-9_-]{11})',
        r'^([a-zA-Z0-9_-]{11})$'
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    raise ValueError(f"Could not extract video ID from: {url}")


# ============================================================================
# Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    # Verify yt-dlp is available
    try:
        result = subprocess.run(["yt-dlp", "--version"], capture_output=True, text=True, timeout=10)
        ytdlp_version = result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        ytdlp_version = "error"

    return {
        "status": "ok",
        "service": "yt-dlp-server",
        "version": "1.0.0",
        "yt_dlp_version": ytdlp_version
    }


@app.get("/youtube/info", response_model=VideoInfo)
async def get_video_info(url: str):
    """Get YouTube video metadata including available subtitles."""
    try:
        video_id = extract_video_id(url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    cmd = [
        "yt-dlp",
        "--dump-json",
        "--no-download",
        f"https://www.youtube.com/watch?v={video_id}"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"yt-dlp error: {result.stderr}")

        info = json.loads(result.stdout)
        subtitles = info.get("subtitles", {})
        auto_captions = info.get("automatic_captions", {})

        return VideoInfo(
            video_id=video_id,
            title=info.get("title", "Unknown"),
            duration=info.get("duration", 0),
            channel=info.get("channel", "Unknown"),
            upload_date=info.get("upload_date"),
            has_manual_subs=len(subtitles) > 0,
            has_auto_subs=len(auto_captions) > 0,
            available_languages=list(set(list(subtitles.keys()) + list(auto_captions.keys())))
        )

    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Timeout getting video info")
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Failed to parse video info")


@app.post("/youtube/transcript", response_model=YouTubeResponse)
async def extract_youtube_transcript(request: YouTubeRequest):
    """
    Extract transcript from YouTube video.

    Tries in order:
    1. Manual subtitles (if prefer_manual=True and available)
    2. Auto-generated subtitles
    3. Returns error with suggestion to use Whisper
    """
    try:
        video_id = extract_video_id(request.url)
    except ValueError as e:
        return YouTubeResponse(
            success=False,
            video_id="",
            language=request.language,
            error=str(e)
        )

    video_url = f"https://www.youtube.com/watch?v={video_id}"

    # Get video title and duration
    title = None
    duration = None
    try:
        info_cmd = ["yt-dlp", "--dump-json", "--no-download", video_url]
        info_result = subprocess.run(info_cmd, capture_output=True, text=True, timeout=30)
        if info_result.returncode == 0:
            info = json.loads(info_result.stdout)
            title = info.get("title")
            duration = info.get("duration")
    except Exception:
        pass

    with tempfile.TemporaryDirectory() as temp_dir:
        output_template = os.path.join(temp_dir, "subs")

        # Try manual subtitles first if preferred
        if request.prefer_manual:
            cmd_manual = [
                "yt-dlp",
                "--write-sub",
                "--sub-lang", request.language,
                "--sub-format", "vtt",
                "--skip-download",
                "-o", output_template,
                video_url
            ]

            subprocess.run(cmd_manual, capture_output=True, text=True, timeout=120)
            vtt_file = f"{output_template}.{request.language}.vtt"

            if os.path.exists(vtt_file):
                with open(vtt_file, 'r', encoding='utf-8') as f:
                    vtt_content = f.read()

                transcript = clean_vtt_content(vtt_content)

                return YouTubeResponse(
                    success=True,
                    video_id=video_id,
                    title=title,
                    transcript=transcript,
                    source="manual",
                    language=request.language,
                    duration=duration
                )

        # Try auto-generated subtitles
        cmd_auto = [
            "yt-dlp",
            "--write-auto-sub",
            "--sub-lang", request.language,
            "--sub-format", "vtt",
            "--skip-download",
            "-o", output_template,
            video_url
        ]

        subprocess.run(cmd_auto, capture_output=True, text=True, timeout=120)
        vtt_file = f"{output_template}.{request.language}.vtt"

        if os.path.exists(vtt_file):
            with open(vtt_file, 'r', encoding='utf-8') as f:
                vtt_content = f.read()

            transcript = clean_vtt_content(vtt_content)

            return YouTubeResponse(
                success=True,
                video_id=video_id,
                title=title,
                transcript=transcript,
                source="auto-generated",
                language=request.language,
                duration=duration
            )

        # No subtitles available
        return YouTubeResponse(
            success=False,
            video_id=video_id,
            title=title,
            language=request.language,
            duration=duration,
            error="No subtitles available. Use whisper-server for audio transcription."
        )


@app.post("/youtube/audio")
async def download_youtube_audio(url: str):
    """
    Download audio from YouTube video.
    Returns the audio file path for use with whisper-server.
    """
    try:
        video_id = extract_video_id(url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    video_url = f"https://www.youtube.com/watch?v={video_id}"
    output_path = f"/app/temp/{video_id}.mp3"

    # Check cache
    if os.path.exists(output_path):
        return {"success": True, "audio_path": output_path, "video_id": video_id, "cached": True}

    cmd = [
        "yt-dlp",
        "-x",
        "--audio-format", "mp3",
        "-o", output_path.replace(".mp3", ".%(ext)s"),
        video_url
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"yt-dlp error: {result.stderr}")

        if os.path.exists(output_path):
            return {"success": True, "audio_path": output_path, "video_id": video_id, "cached": False}
        else:
            raise HTTPException(status_code=500, detail="Audio file not created")

    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Timeout downloading audio")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8501)
