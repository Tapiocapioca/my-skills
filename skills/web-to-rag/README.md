# web-to-rag v2.0

Import websites, YouTube videos, and PDFs into AnythingLLM.

---

## Prerequisites

**Run the installer before using this skill.**

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

### Components

| Component | Port | Purpose |
|-----------|------|---------|
| Docker Desktop | - | Container runtime |
| Crawl4AI | 11235 | Web scraping |
| AnythingLLM | 3001 | Local RAG |
| yt-dlp-server | 8501 | YouTube transcripts |
| whisper-server | 8502 | Audio transcription |
| MCP Servers | - | Claude-to-services bridge |
| poppler | - | PDF extraction |

### Post-Installation: Configure AnythingLLM

1. Open **http://localhost:3001**
2. Complete setup wizard
3. Configure LLM provider in **Settings → LLM Preference**
4. Create API key in **Settings → API Keys**
5. Update `~/.claude/mcp_servers.json` with your key

---

## Features

### Core
- **Multi-source**: Websites, YouTube, PDFs
- **Auto-detection**: Selects the right tool automatically
- **Dual mode**: Fast for experts, guided for beginners
- **Smart workspaces**: Auto-detect or create
- **Intelligent crawling**: Configurable depth, rate limits respected
- **Error handling**: Retry logic, Playwright fallback

### New in v2.0
- **YouTube**: yt-dlp transcripts, Whisper fallback
- **PDF**: pdftotext extraction, automatic chunking
- **Interactive selection**: Choose pages before crawling
- **Scheduled updates**: Task Scheduler (Windows) or cron (Linux/Mac)

---

## Content Detection

| URL Pattern | Type | Strategy |
|-------------|------|----------|
| `youtube.com/watch`, `youtu.be/` | YouTube | yt-dlp transcript |
| `.pdf` extension | PDF | pdftotext |
| Has `sitemap.xml` | Documentation | Sitemap crawl |
| Everything else | Generic | BFS crawl |

---

## Usage Examples

### Website Import
```
"Add FastAPI docs to RAG"
"Scrape https://example.com to knowledge base"
"Import React documentation"
```

### YouTube Import
```
"Import this YouTube video: https://youtube.com/watch?v=..."
"Add [video URL] transcript to knowledge base"
```

### PDF Import
```
"Add this PDF to RAG: https://example.com/document.pdf"
"Import [URL] to my-workspace"
```

### Interactive Selection
```
"Scrape https://docs.example.com - show pages first"
"Import documentation but let me choose pages"
```

### Scheduled Updates
```
"Schedule weekly updates for fastapi-docs"
"Keep my-workspace updated every Monday at 3am"
```

### Guided Mode
```
"Help me import a website to RAG"
"Guide me through adding documentation"
```

---

## Trigger Keywords

- **Web**: "add to RAG", "scrape website", "import documentation"
- **YouTube**: "import YouTube", "add video", "import transcript"
- **PDF**: "add PDF", "import PDF", "embed PDF"
- **Interactive**: "show pages first", "let me select"
- **Scheduling**: "schedule update", "automatic refresh"

---

## Directory Structure

```
web-to-rag/
├── SKILL.md                     # Skill instructions
├── README.md                    # This file
├── install-prerequisites.ps1   # Windows installer
├── install-prerequisites.sh    # Linux/macOS installer
├── infrastructure/
│   ├── README.md               # Docker docs
│   └── docker/
│       ├── yt-dlp/             # YouTube server
│       └── whisper/            # Transcription server
├── references/
│   ├── troubleshooting.md
│   ├── crawl-strategies.md
│   ├── youtube-workflow.md
│   ├── pdf-workflow.md
│   ├── interactive-mode.md
│   └── scheduling.md
└── scripts/
    ├── update-rag-template.ps1
    └── update-rag-template.sh
```

---

## Configuration

### AnythingLLM API Key

1. Open http://localhost:3001
2. Go to Settings → API Keys
3. Create key
4. Update `~/.claude/mcp_servers.json`

### Rate Limits

- Max 3 parallel URL fetches
- Wait before next batch
- Confirm if > 50 pages

---

## Troubleshooting

### Crawl4AI unreachable
```bash
docker start crawl4ai
```

### AnythingLLM unreachable
```bash
docker start anythingllm
```

### yt-dlp-server or whisper-server unreachable
```bash
docker start yt-dlp-server whisper-server
```

### "Client not initialized" error
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

See [references/troubleshooting.md](references/troubleshooting.md) for more.

---

## License

MIT License

---

## Credits

- [Crawl4AI](https://github.com/unclecode/crawl4ai)
- [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm)
- [Claude Code](https://claude.ai/code)

---

*Last updated: January 2026*
