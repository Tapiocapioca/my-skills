# web-to-rag v2.0

A Claude Code skill that imports content from multiple sources into a local RAG (AnythingLLM).

**Supported sources:** Websites, YouTube videos, PDFs

---

## Prerequisites

**Before using this skill**, you must install the required services.

### Automated Installation

**Windows (PowerShell as Administrator):**
```powershell
cd skills/web-to-rag
.\install-prerequisites.ps1
```

**Linux/macOS:**
```bash
cd skills/web-to-rag
./install-prerequisites.sh
```

### What Gets Installed

| Component | Port | Purpose |
|-----------|------|---------|
| Docker Desktop | - | Container runtime |
| Crawl4AI | 11235 | Web scraping engine |
| AnythingLLM | 3001 | Local RAG system |
| yt-dlp-server | 8501 | YouTube transcript extraction |
| whisper-server | 8502 | Audio transcription (fallback) |
| MCP Servers | - | Claude ↔ Services bridge |
| poppler | - | PDF text extraction |

### Post-Installation: Configure AnythingLLM

1. Open **http://localhost:3001**
2. Complete the setup wizard
3. Go to **Settings → LLM Preference** and configure your LLM provider
4. Go to **Settings → API Keys** and create a key for Claude Code
5. Update `~/.claude/mcp_servers.json` with your API key

---

## Features

### Core Features
- **Multi-source import**: Websites, YouTube transcripts, PDFs
- **Auto-detect content type**: Automatically selects the right tool
- **Dual Mode**: Fast mode for experts, guided mode for beginners
- **Smart Workspace Management**: Auto-detect existing workspace or create new
- **Intelligent Crawling**: Configurable depth, respects rate limits
- **Error Handling**: Retry logic, Playwright fallback for protected sites

### New in v2.0
- **YouTube Import**: Extract transcripts with yt-dlp, Whisper fallback for videos without subtitles
- **PDF Import**: Extract text with pdftotext, automatic chunking for large documents
- **Interactive Selection**: Choose which pages to import before crawling
- **Scheduled Updates**: Automatic RAG refresh via Task Scheduler (Windows) or cron (Linux/Mac)

---

## Content Type Detection

| URL Pattern | Type | Strategy |
|-------------|------|----------|
| `youtube.com/watch`, `youtu.be/` | YouTube | yt-dlp transcript extraction |
| `.pdf` extension | PDF | pdftotext extraction |
| Has `sitemap.xml` | Documentation | Sitemap-based crawl |
| Everything else | Generic Web | BFS crawl with Crawl4AI |

---

## Usage Examples

### Website Import (Fast Mode)
```
"Add FastAPI docs to RAG"
"Scrape https://example.com and add to knowledge base"
"Import React documentation"
```

### YouTube Import
```
"Import this YouTube video to RAG: https://youtube.com/watch?v=..."
"Add the transcript of [video URL] to knowledge base"
```

### PDF Import
```
"Add this PDF to RAG: https://example.com/document.pdf"
"Import the PDF at [URL] to my-workspace"
```

### Interactive Selection
```
"Scrape https://docs.example.com - show me the pages first"
"Import documentation but let me choose which pages"
```

### Scheduled Updates
```
"Schedule weekly updates for the fastapi-docs workspace"
"Keep my-workspace updated every Monday at 3am"
```

### Guided Mode
```
"Help me import a website to RAG"
"Guide me through adding documentation to knowledge base"
```

---

## Trigger Keywords

The skill activates when you mention:
- **Web**: "add to RAG", "scrape website", "import documentation", "embed site"
- **YouTube**: "import YouTube", "add video", "import transcript"
- **PDF**: "add PDF", "import PDF", "embed PDF"
- **Interactive**: "show pages first", "let me select", "choose pages"
- **Scheduling**: "schedule update", "automatic refresh", "keep updated"

---

## Directory Structure

```
web-to-rag/
├── SKILL.md                     # Main skill instructions (v2.0)
├── README.md                    # This file
├── install-prerequisites.ps1   # Windows installer
├── install-prerequisites.sh    # Linux/macOS installer
├── infrastructure/
│   ├── README.md               # Docker documentation
│   └── docker/
│       ├── yt-dlp/             # YouTube transcript server
│       └── whisper/            # Audio transcription server
├── references/
│   ├── troubleshooting.md      # Problem solving guide
│   ├── crawl-strategies.md     # Crawling strategies
│   ├── youtube-workflow.md     # YouTube import details
│   ├── pdf-workflow.md         # PDF import details
│   ├── interactive-mode.md     # Interactive selection guide
│   └── scheduling.md           # Scheduling configuration
└── scripts/
    ├── update-rag-template.ps1 # Windows update script template
    └── update-rag-template.sh  # Linux/Mac update script template
```

---

## Configuration

### AnythingLLM API Key

1. Open AnythingLLM web UI: http://localhost:3001
2. Go to Settings → API Keys
3. Create a new key
4. Update your `~/.claude/mcp_servers.json`

### Rate Limiting

The skill respects API limits:
- Max 3 parallel URL fetches
- Waits for response before next batch
- Confirms if > 50 pages

---

## Troubleshooting

### Crawl4AI not reachable

```bash
docker start crawl4ai
```

### AnythingLLM not reachable

```bash
docker start anythingllm
```

### yt-dlp-server or whisper-server not reachable

```bash
docker start yt-dlp-server whisper-server
```

### "Client not initialized" error

In Claude, initialize AnythingLLM:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

See [references/troubleshooting.md](references/troubleshooting.md) for more.

---

## License

MIT License - Feel free to use and modify.

---

## Credits

- [Crawl4AI](https://github.com/unclecode/crawl4ai) for web scraping
- [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) for RAG
- [Claude Code](https://claude.ai/code) for the skill platform

---

*Last updated: January 2026*
