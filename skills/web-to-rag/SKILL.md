---
name: web-to-rag
description: |
  Import content into local RAG. Triggers: "add to RAG", "scrape docs",
  "import YouTube", "embed PDF", "build knowledge base", "embedda sito",
  "importa video", "aggiungi PDF", "crea knowledge base".
---

# Web to RAG

Import websites, YouTube videos, and PDFs into AnythingLLM.

## Quick Reference

| Source | Detection | Tool |
|--------|-----------|------|
| YouTube | `youtube.com`, `youtu.be` | yt-dlp-server:8501 |
| PDF | `.pdf` extension | pdftotext |
| Docs site | `/sitemap.xml` exists | Crawl4AI sitemap |
| Generic | Everything else | Crawl4AI BFS |

| MCP Tool | Purpose |
|----------|---------|
| `mcp__crawl4ai__md` | Scrape page to markdown |
| `mcp__anythingllm__list_workspaces` | List workspaces |
| `mcp__anythingllm__embed_text` | Add content to workspace |
| `mcp__anythingllm__chat_with_workspace` | Query RAG (mode: "query") |

## Prerequisites

```bash
# Verify containers
docker ps | grep -E "crawl4ai|anythingllm"

# Start if needed
docker start crawl4ai anythingllm

# YouTube/audio support
docker start yt-dlp-server whisper-server
```

For "Client not initialized" error:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

## Core Workflow

```
1. Detect content type from URL
2. Find or create workspace (name from domain)
3. Crawl content (max 3 parallel)
4. Embed with metadata
5. Report results with test query
```

### Rate Limits

- 3 URLs maximum per batch
- Wait before next batch
- Confirm if > 50 pages

### Workspace Naming

| URL | Workspace |
|-----|-----------|
| docs.anthropic.com | anthropic-docs |
| react.dev/learn | react-dev |
| example.com/blog | example-blog |

## Embedding Format

```markdown
---
source: {url}
title: {page_title}
scraped: {timestamp}
---
{cleaned_content}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Rate limit exceeded | Max 3 parallel, wait between batches |
| Empty content embedded | Skip empty pages |
| Wrong chat mode | Use `mode: "query"` |
| Uninitialized client | Call `initialize_anythingllm` first |
| External links crawled | Filter to same domain |

## Error Handling

| Error | Action |
|-------|--------|
| 403 Forbidden | Use Playwright fallback |
| 429 Rate Limited | Pause 60s, reduce parallelism |
| Timeout | Retry once, skip |
| Empty content | Skip |

## Extended Workflows

See references/:
- [youtube-workflow.md](references/youtube-workflow.md) - YouTube transcripts
- [pdf-workflow.md](references/pdf-workflow.md) - PDF extraction
- [crawl-strategies.md](references/crawl-strategies.md) - Advanced crawling
- [interactive-mode.md](references/interactive-mode.md) - Page selection
- [scheduling.md](references/scheduling.md) - Automatic updates
- [troubleshooting.md](references/troubleshooting.md) - Problem solving

## Report Template

```markdown
## Scraping Report

**URL:** {url}
**Type:** {docs|generic|youtube|pdf}
**Workspace:** {name}

### Stats
- Found: X
- Processed: Y
- Failed: Z

### Test Query
mcp__anythingllm__chat_with_workspace
  slug: "{workspace}"
  message: "What does this documentation cover?"
  mode: "query"
```
