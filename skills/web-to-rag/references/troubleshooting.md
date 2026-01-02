# Troubleshooting web-to-rag

---

## Crawl4AI Unreachable

### Symptom
```
❌ Crawl4AI: unreachable
```
or timeout on `mcp__crawl4ai__md`

### Cause
Docker stopped or `crawl4ai` container halted.

### Fix

1. **Verify Docker Desktop runs**
   - Windows: Docker icon in system tray
   - Start Docker Desktop if missing

2. **Check container**
   ```bash
   docker ps | grep crawl4ai
   ```

3. **Start if stopped**
   ```bash
   docker start crawl4ai
   ```

4. **Create if missing**
   ```bash
   docker run -d --name crawl4ai -p 11235:11235 unclecode/crawl4ai
   ```

5. **Test connection**
   ```bash
   curl http://localhost:11235/health
   ```

---

## AnythingLLM Unreachable

### Symptom
```
❌ AnythingLLM: unreachable
```
or workspace operation errors

### Cause
Container `anythingllm` stopped or port 3001 occupied.

### Fix

1. **Check container**
   ```bash
   docker ps | grep anythingllm
   ```

2. **Start if stopped**
   ```bash
   docker start anythingllm
   ```

3. **Check port conflict**
   ```bash
   # Windows
   netstat -ano | findstr :3001

   # Linux/Mac
   lsof -i :3001
   ```

4. **Test connection**
   ```bash
   curl http://localhost:3001/api/health
   ```

---

## "Client not initialized" Error

### Symptom
```
Error: AnythingLLM client not initialized
```

### Cause
MCP server requires initialization each session.

### Fix
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

---

## 403 Forbidden During Scraping

### Symptom
Crawl4AI returns 403 on some pages.

### Cause
Site blocks automated scrapers.

### Fix

1. **Use Playwright fallback**
   ```
   mcp__plugin_playwright_playwright__browser_navigate
     url: "https://blocked-site.com"

   mcp__plugin_playwright_playwright__browser_snapshot
   ```

2. **Check robots.txt**
   - Verify: `https://site.com/robots.txt`

---

## Rate Limit Exceeded (429)

### Symptom
Error 429 or console flickering.

### Cause
Too many parallel requests (exceeded 10 RPM limit).

### Fix

1. **Stop immediately** - no more requests
2. **Wait 60 seconds**
3. **Reduce parallelism**
   - Max 3 URLs per batch
   - Wait for response before next batch

---

## Empty Content After Scraping

### Symptom
Crawl4AI returns empty or minimal markdown.

### Cause
- Heavy JavaScript rendering
- Dynamic content loading
- Active anti-bot measures

### Fix

1. **Use Playwright** for JavaScript rendering
   ```
   browser_navigate → browser_snapshot
   ```

2. **Wait for content**
   ```
   mcp__plugin_playwright_playwright__browser_wait_for
     text: "expected content"
   ```

---

## Workspace Not Found

### Symptom
```
Workspace 'name' not found
```

### Fix

1. **List existing workspaces**
   ```
   mcp__anythingllm__list_workspaces
   ```

2. **Check exact name** (case-sensitive, use slug)

3. **Create if missing**
   ```
   mcp__anythingllm__create_workspace
     name: "workspace-name"
   ```

---

## Docker Desktop Fails to Start

### Symptom
Docker Desktop crashes or hangs.

### Fix (Windows)

1. **Restart Docker service**
   ```powershell
   Restart-Service docker
   ```

2. **Enable virtualization** in BIOS

3. **Update WSL2**
   ```bash
   wsl --update
   ```

4. **Reset Docker Desktop**
   - Settings → Troubleshoot → Reset to factory defaults

---

## Embedding Fails Silently

### Symptom
`embed_text` completes but documents missing.

### Fix

1. **Verify workspace**
   ```
   mcp__anythingllm__list_documents
     slug: "workspace-name"
   ```

2. **Check content size**
   - Split chunks < 50KB

3. **Verify format**
   - Must be string array: `["text1", "text2"]`
