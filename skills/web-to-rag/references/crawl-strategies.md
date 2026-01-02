# Crawl Strategies

Strategies for different site types.

---

## Strategy 1: Documentation with Sitemap

### When to Use
- Site has accessible `/sitemap.xml`
- Structured technical documentation
- Examples: docs.python.org, fastapi.tiangolo.com

### Workflow

```
1. Fetch sitemap
   GET {base_url}/sitemap.xml

2. Parse XML
   Extract all <loc> tags

3. Filter URLs
   - Keep: /docs/, /guide/, /tutorial/, /reference/
   - Exclude: /api/, /changelog/, /blog/, /news/

4. Sort by path
   Group by section (getting-started, advanced, api-ref)

5. Crawl in batches
   - 3 URLs per batch (rate limit)
   - Wait for response
   - Next batch
```

### Sitemap Example
```xml
<urlset>
  <url><loc>https://docs.example.com/intro</loc></url>
  <url><loc>https://docs.example.com/guide/basics</loc></url>
  <url><loc>https://docs.example.com/api/reference</loc></url>
</urlset>
```

Extract: `["/intro", "/guide/basics", "/api/reference"]`

---

## Strategy 2: Structured Documentation (no sitemap)

### When to Use
- URL contains `/docs/` or `/documentation/`
- Page has sidebar/TOC with links
- No sitemap available

### Workflow

```
1. Find index page
   - /docs/
   - /docs/index
   - /documentation/

2. Extract sidebar links
   Look for: nav, aside, .sidebar, .toc

3. Filter links
   - Same domain only
   - Only /docs/* paths
   - No anchor links (#section)

4. Deduplicate
   Normalize URLs (remove trailing slash, query params)

5. Crawl in order of appearance
   Preserves logical documentation structure
```

### Common Sidebar Patterns
```html
<!-- Pattern 1: nav with list -->
<nav class="sidebar">
  <ul>
    <li><a href="/docs/intro">Intro</a></li>
    <li><a href="/docs/setup">Setup</a></li>
  </ul>
</nav>

<!-- Pattern 2: nested sections -->
<aside>
  <section>
    <h3>Getting Started</h3>
    <a href="/docs/install">Install</a>
  </section>
</aside>
```

---

## Strategy 3: Generic Sites (BFS)

### When to Use
- No sitemap
- No recognizable docs structure
- Blogs, corporate sites, wikis

### Workflow

```
1. Start from provided URL (seed)

2. Fetch page
   mcp__crawl4ai__md(url)

3. Extract internal links
   - Same domain
   - No assets (.css, .js, .png, .jpg, .svg, .pdf)
   - No mailto:, tel:, javascript:

4. Add to queue (BFS)
   - If not already visited
   - If depth < max_depth

5. Continue until:
   - Queue empty
   - max_pages reached
   - max_depth reached
```

### Recommended Parameters
| Site Type | max_depth | max_pages |
|-----------|-----------|-----------|
| Small blog | 2 | 50 |
| Corporate | 2 | 100 |
| Wiki | 3 | 200 |
| Documentation | 3 | 150 |

---

## Strategy 4: Single Page Application (SPA)

### When to Use
- Site uses React, Vue, Angular
- Content loaded via JavaScript
- Crawl4AI returns empty content

### Workflow

```
1. Use Playwright instead of Crawl4AI

2. Navigate
   browser_navigate(url)

3. Wait for rendering
   browser_wait_for(text: "expected content")
   or
   browser_wait_for(time: 3)

4. Snapshot
   browser_snapshot → get structure

5. Extract content
   Analyze snapshot for main text

6. Close
   browser_close
```

### Limitations
- Slower (5-10s per page vs 1-2s)
- Hard to parallelize
- Use for problematic sites, not default

---

## Rate Limiting

### CLAUDE.md Constraints
```
⚠️ 10 RPM (requests/minute) to AI provider
⚠️ Max 4 parallel tool calls
```

### Practical Implementation
```
Batch size: 3 URLs
Wait: complete response before next batch
Extra delay: 1s if > 30 total pages
```

### Timing Example
```
Batch 1: url1, url2, url3 → ~3 seconds
Batch 2: url4, url5, url6 → ~3 seconds
...
50 pages ≈ 17 batches ≈ 1-2 minutes
```

---

## Deduplication

### URL Normalization
```
Remove:
- Trailing slash: /page/ → /page
- Fragment: /page#section → /page
- Non-significant query params: ?ref=twitter

Keep:
- Pagination params: ?page=2
- Content params: ?id=123
```

### Content Deduplication
```
If two pages are > 90% similar:
- Keep only the first
- Log duplicate as "skipped"
```

---

## Robots.txt

### When to Respect
- Public sites with explicit robots.txt
- Mass crawling (> 100 pages)
- Sites blocking without apparent reason

### Parsing
```
User-agent: *
Disallow: /admin/
Disallow: /private/
Allow: /docs/

→ Exclude /admin/*, /private/*
→ Include /docs/*
```

### Note
Most public docs don't block crawling.
Respect robots.txt only if issues or for courtesy.

---

## Error Handling by Strategy

| Error | Action |
|-------|--------|
| 404 Not Found | Skip, log warning |
| 403 Forbidden | Try Playwright, then skip |
| 429 Rate Limit | Pause 60s, reduce batch |
| 500 Server Error | Retry 1x, then skip |
| Timeout | Retry 1x with doubled timeout |
| Empty content | Try Playwright |

---

## Complete Examples

### FastAPI docs
```
URL: https://fastapi.tiangolo.com
Type: docs-sitemap
Sitemap: https://fastapi.tiangolo.com/sitemap.xml
Pages: ~80
Estimated time: 3-4 minutes
```

### Medium blog
```
URL: https://blog.example.com
Type: generic
Strategy: BFS depth=2
Estimated pages: 30-50
Estimated time: 1-2 minutes
```

### React SPA
```
URL: https://app.example.com/docs
Type: spa
Strategy: Playwright
Pages: variable
Estimated time: 5-10 minutes (slower)
```
