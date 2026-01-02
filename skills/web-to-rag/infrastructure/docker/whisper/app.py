"""
Whisper Server - REST API for audio transcription.

Endpoints:
- GET /health - Health check
- POST /transcribe - Transcribe audio file
- POST /transcribe/url - Transcribe audio from URL
- GET /models - List available models
"""

import os
import tempfile
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
import httpx


# Global Whisper model (lazy loaded)
whisper_model = None
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL", "base")


def get_whisper_model(model_size: Optional[str] = None):
    """Lazy load Whisper model."""
    global whisper_model
    size = model_size or WHISPER_MODEL_SIZE

    # If requesting different model, reload
    if whisper_model is not None and model_size and model_size != WHISPER_MODEL_SIZE:
        from faster_whisper import WhisperModel
        return WhisperModel(size, device="cpu", compute_type="int8")

    if whisper_model is None:
        from faster_whisper import WhisperModel
        whisper_model = WhisperModel(size, device="cpu", compute_type="int8")

    return whisper_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan handler for startup/shutdown."""
    os.makedirs("/app/temp", exist_ok=True)
    yield
    import shutil
    shutil.rmtree("/app/temp", ignore_errors=True)


app = FastAPI(
    title="Whisper Server",
    description="REST API for audio transcription using faster-whisper",
    version="1.0.0",
    lifespan=lifespan
)


# ============================================================================
# Models
# ============================================================================

class TranscribeResponse(BaseModel):
    success: bool
    transcript: Optional[str] = None
    language: Optional[str] = None
    language_probability: Optional[float] = None
    duration: Optional[float] = None
    model_used: str
    error: Optional[str] = None


class TranscribeUrlRequest(BaseModel):
    url: str
    language: Optional[str] = None
    model: str = "base"


# ============================================================================
# Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "whisper-server",
        "version": "1.0.0",
        "default_model": WHISPER_MODEL_SIZE,
        "model_loaded": whisper_model is not None
    }


@app.get("/models")
async def list_models():
    """List available Whisper models."""
    return {
        "models": [
            {"name": "tiny", "size": "~75MB", "speed": "fastest", "quality": "lowest"},
            {"name": "base", "size": "~150MB", "speed": "fast", "quality": "good"},
            {"name": "small", "size": "~500MB", "speed": "medium", "quality": "better"},
            {"name": "medium", "size": "~1.5GB", "speed": "slow", "quality": "high"},
            {"name": "large", "size": "~3GB", "speed": "slowest", "quality": "highest"}
        ],
        "default": WHISPER_MODEL_SIZE,
        "note": "Models are downloaded on first use"
    }


@app.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    model: str = Form("base")
):
    """
    Transcribe an uploaded audio file.

    Supports: mp3, wav, m4a, ogg, flac, webm
    """
    temp_file = None
    try:
        # Save uploaded file
        suffix = os.path.splitext(file.filename)[1] if file.filename else ".mp3"
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir="/app/temp")
        content = await file.read()
        temp_file.write(content)
        temp_file.close()

        # Transcribe
        whisper = get_whisper_model(model)
        segments, info = whisper.transcribe(
            temp_file.name,
            language=language,
            beam_size=5
        )

        # Collect transcript
        transcript_parts = []
        for segment in segments:
            transcript_parts.append(segment.text.strip())

        transcript = " ".join(transcript_parts)

        return TranscribeResponse(
            success=True,
            transcript=transcript,
            language=info.language,
            language_probability=info.language_probability,
            duration=info.duration,
            model_used=model
        )

    except Exception as e:
        return TranscribeResponse(
            success=False,
            error=str(e),
            model_used=model
        )

    finally:
        if temp_file and os.path.exists(temp_file.name):
            os.unlink(temp_file.name)


@app.post("/transcribe/url", response_model=TranscribeResponse)
async def transcribe_from_url(request: TranscribeUrlRequest):
    """
    Transcribe audio from a URL.

    The URL should point directly to an audio file.
    For YouTube videos, use yt-dlp-server first to get the audio.
    """
    temp_file = None
    try:
        # Download audio from URL
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.get(request.url, follow_redirects=True)
            response.raise_for_status()

        # Determine file extension
        content_type = response.headers.get("content-type", "")
        if "mp3" in content_type or request.url.endswith(".mp3"):
            suffix = ".mp3"
        elif "wav" in content_type or request.url.endswith(".wav"):
            suffix = ".wav"
        elif "m4a" in content_type or request.url.endswith(".m4a"):
            suffix = ".m4a"
        else:
            suffix = ".mp3"  # Default

        # Save to temp file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir="/app/temp")
        temp_file.write(response.content)
        temp_file.close()

        # Transcribe
        whisper = get_whisper_model(request.model)
        segments, info = whisper.transcribe(
            temp_file.name,
            language=request.language,
            beam_size=5
        )

        # Collect transcript
        transcript_parts = []
        for segment in segments:
            transcript_parts.append(segment.text.strip())

        transcript = " ".join(transcript_parts)

        return TranscribeResponse(
            success=True,
            transcript=transcript,
            language=info.language,
            language_probability=info.language_probability,
            duration=info.duration,
            model_used=request.model
        )

    except httpx.HTTPError as e:
        return TranscribeResponse(
            success=False,
            error=f"Failed to download audio: {str(e)}",
            model_used=request.model
        )

    except Exception as e:
        return TranscribeResponse(
            success=False,
            error=str(e),
            model_used=request.model
        )

    finally:
        if temp_file and os.path.exists(temp_file.name):
            os.unlink(temp_file.name)


@app.post("/transcribe/file-path", response_model=TranscribeResponse)
async def transcribe_from_path(
    file_path: str = Form(...),
    language: Optional[str] = Form(None),
    model: str = Form("base")
):
    """
    Transcribe audio from a file path.

    Used internally when yt-dlp-server downloads audio.
    The file_path should be accessible within the container or via shared volume.
    """
    try:
        if not os.path.exists(file_path):
            return TranscribeResponse(
                success=False,
                error=f"File not found: {file_path}",
                model_used=model
            )

        # Transcribe
        whisper = get_whisper_model(model)
        segments, info = whisper.transcribe(
            file_path,
            language=language,
            beam_size=5
        )

        # Collect transcript
        transcript_parts = []
        for segment in segments:
            transcript_parts.append(segment.text.strip())

        transcript = " ".join(transcript_parts)

        return TranscribeResponse(
            success=True,
            transcript=transcript,
            language=info.language,
            language_probability=info.language_probability,
            duration=info.duration,
            model_used=model
        )

    except Exception as e:
        return TranscribeResponse(
            success=False,
            error=str(e),
            model_used=model
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8502)
