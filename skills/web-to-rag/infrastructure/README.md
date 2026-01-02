# Infrastructure

Docker containers required by the **web-to-rag** skill.

## Containers

| Container | Port | Purpose |
|-----------|------|---------|
| **yt-dlp** | 8501 | YouTube transcript extraction |
| **whisper** | 8502 | Audio transcription (fallback) |

### External Containers (not in this repo)

These use official Docker images:

| Container | Port | Image |
|-----------|------|-------|
| **crawl4ai** | 11235 | `unclecode/crawl4ai:latest` |
| **anythingllm** | 3001 | `mintplexlabs/anythingllm:latest` |

## Building

```bash
# From skills/web-to-rag/infrastructure/docker/

# yt-dlp server
cd yt-dlp
docker build -t yt-dlp-server .

# whisper server
cd ../whisper
docker build -t whisper-server .
```

## Running

```bash
# yt-dlp server
docker run -d \
  --name yt-dlp-server \
  -p 8501:8501 \
  --restart unless-stopped \
  yt-dlp-server

# whisper server
docker run -d \
  --name whisper-server \
  -p 8502:8502 \
  --restart unless-stopped \
  whisper-server
```

## API Reference

### yt-dlp-server (port 8501)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/youtube/info?url=` | GET | Video metadata and available subtitles |
| `/youtube/transcript` | POST | Extract transcript (body: `{url, language, prefer_manual}`) |
| `/youtube/audio` | POST | Download audio for whisper fallback |

### whisper-server (port 8502)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/models` | GET | List available Whisper models |
| `/transcribe` | POST | Transcribe uploaded audio file |
| `/transcribe/url` | POST | Transcribe audio from URL |
| `/transcribe/file-path` | POST | Transcribe from container path |

## Health Checks

```bash
curl http://localhost:8501/health  # yt-dlp
curl http://localhost:8502/health  # whisper
curl http://localhost:11235/health # crawl4ai
curl http://localhost:3001/api/health # anythingllm
```
