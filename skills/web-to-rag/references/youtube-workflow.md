# YouTube Workflow

Import YouTube transcripts into RAG.

## Prerequisites

### yt-dlp (required)
```bash
# Verify
which yt-dlp || command -v yt-dlp

# Install
pip install yt-dlp
# or
brew install yt-dlp  # macOS
```

### Whisper (optional - for videos without subtitles)
```bash
# Verify
which whisper || command -v whisper

# Install (~1-3GB for models)
pip install openai-whisper
```

---

## Workflow

### Step 1: Get Video Info

```bash
VIDEO_TITLE=$(yt-dlp --print "%(title)s" "YOUTUBE_URL")
DURATION=$(yt-dlp --print "%(duration)s" "YOUTUBE_URL")
VIDEO_ID=$(yt-dlp --print "%(id)s" "YOUTUBE_URL")
```

### Step 2: Check Available Subtitles

```bash
yt-dlp --list-subs "YOUTUBE_URL"
```

Output:
```
[info] Available subtitles for VIDEO_ID:
Language  formats
en        vtt, ttml, srv3, srv2, srv1
it        vtt (auto-generated)
```

### Step 3: Download Subtitles

**Priority: Manual > Auto-generated**

```bash
# Manual subtitles
yt-dlp --write-sub --skip-download --sub-langs en -o "transcript" "YOUTUBE_URL"

# Auto-generated fallback
yt-dlp --write-auto-sub --skip-download --sub-langs en -o "transcript" "YOUTUBE_URL"
```

### Step 4: Clean VTT (Remove Duplicates)

YouTube VTT files contain duplicates for typing effect.

```python
import re

def clean_vtt(vtt_file, output_file):
    seen = set()
    with open(vtt_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    clean_lines = []
    for line in lines:
        line = line.strip()
        # Skip VTT metadata
        if not line or line.startswith('WEBVTT') or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        # Skip timestamps
        if '-->' in line:
            continue
        # Remove HTML tags
        clean = re.sub('<[^>]*>', '', line)
        clean = clean.replace('&amp;', '&').replace('&gt;', '>').replace('&lt;', '<')
        # Deduplicate
        if clean and clean not in seen:
            clean_lines.append(clean)
            seen.add(clean)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(clean_lines))
```

### Step 5: Whisper Fallback

```bash
# Download audio
yt-dlp -x --audio-format mp3 -o "audio_%(id)s.%(ext)s" "YOUTUBE_URL"

# Transcribe
whisper audio_VIDEO_ID.mp3 --model base --output_format txt --language en

# Cleanup
rm audio_VIDEO_ID.mp3
```

**Whisper models:**
| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| tiny | ~39MB | Fastest | Low |
| base | ~74MB | Fast | Medium |
| small | ~244MB | Medium | Good |
| medium | ~769MB | Slow | Excellent |
| large | ~1.5GB | Slowest | Best |

Recommended: `base` for balance.

### Step 6: Embed in RAG

```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: https://youtube.com/watch?v=VIDEO_ID\ntitle: Video Title\ntype: youtube-transcript\nduration: 15 minutes\n---\n\n[transcript]"
  ]
```

---

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "No subtitles" | No subtitles available | Use Whisper |
| "Video unavailable" | Private/geo-blocked | Cannot extract |
| "yt-dlp not found" | Tool missing | `pip install yt-dlp` |
| Whisper OOM | Insufficient RAM | Use smaller model |

---

## Best Practices

1. **Always clean VTT** - Duplicates waste RAG tokens
2. **Add metadata** - source, title, duration
3. **Chunk long videos** - Split every 15 min for videos > 1h
4. **Verify language** - Specify `--sub-langs` correctly
5. **Use base model** - Best Whisper balance

---

*Last updated: January 2026*
