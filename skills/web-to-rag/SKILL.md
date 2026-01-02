---
name: web-to-rag
description: |
  Use when user wants to import content into local RAG/knowledge base. Triggers:
  "add to RAG", "scrape docs", "import YouTube", "embed PDF", "build knowledge base",
  "embedda sito", "importa video", "aggiungi PDF", "crea knowledge base".
---

# Web to RAG

Import content from websites, YouTube, and PDFs into local RAG (AnythingLLM).

## Quick Reference

| Source | Detection | Tool |
|--------|-----------|------|
| YouTube | `youtube.com`, `youtu.be` | yt-dlp-server:8501 |
| PDF | `.pdf` extension | pdftotext |
| Docs site | `/sitemap.xml` exists | Crawl4AI sitemap |
| Generic | Everything else | Crawl4AI BFS |

| MCP Tool | Purpose |
|----------|---------|
| `mcp__crawl4ai__md` | Scrape single page to markdown |
| `mcp__anythingllm__list_workspaces` | List existing workspaces |
| `mcp__anythingllm__embed_text` | Add content to workspace |
| `mcp__anythingllm__chat_with_workspace` | Query RAG (mode: "query") |

## Prerequisites

```bash
# Verify containers running
docker ps | grep -E "crawl4ai|anythingllm"

# Start if needed
docker start crawl4ai anythingllm

# Optional: YouTube/audio support
docker start yt-dlp-server whisper-server
```

If "Client not initialized" error:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

## Core Workflow

```
1. Detect content type from URL
2. Find or create workspace (derive name from domain)
3. Crawl content (max 3 parallel, respect rate limits)
4. Embed to RAG with metadata
5. Report results with test queries
```

### Rate Limiting (Critical)

- Max 3 URLs parallel per batch
- Wait for response before next batch
- Confirm with user if > 50 pages

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
| Exceeding rate limit | Max 3 parallel URLs, wait between batches |
| Embedding empty content | Skip pages with no extractable text |
| Wrong chat mode | Always use `mode: "query"` not `mode: "chat"` |
| Missing initialization | Call `initialize_anythingllm` first |
| Crawling external links | Filter to same domain only |

## Error Handling

| Error | Action |
|-------|--------|
| 403 Forbidden | Suggest Playwright fallback |
| 429 Rate Limited | Pause 60s, reduce parallelism |
| Timeout | Retry once, then skip |
| Empty content | Skip, don't embed |

## Extended Workflows

For detailed workflows, see references/:
- [youtube-workflow.md](references/youtube-workflow.md) - YouTube transcript extraction
- [pdf-workflow.md](references/pdf-workflow.md) - PDF text extraction
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
- Pages found: X
- Processed: Y
- Failed: Z

### Test Query
mcp__anythingllm__chat_with_workspace
  slug: "{workspace}"
  message: "What does this documentation cover?"
  mode: "query"
```
