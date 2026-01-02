# Interactive Mode

Select pages before crawling.

## Activation

Interactive mode activates when:

1. **User requests explicitly:**
   - "Show me pages before importing"
   - "Let me choose which pages to download"
   - "Show me what's there first"

2. **Site has many pages (> 20):**
   - Claude asks: "Found 45 pages. Want to select which to import?"

3. **User wants to exclude sections:**
   - "Import but exclude changelog"
   - "Only API documentation"

---

## Workflow

### Step 1: Crawl Links Only

Extract links before downloading content:

```bash
mcp__crawl4ai__crawl
  url: "https://example.com/docs"
  params: { "only_links": true, "max_depth": 2 }
```

### Step 2: Show Numbered List

Present a clear list:

```
Found 45 pages on docs.example.com:

 #  Path                          Section
────────────────────────────────────────────
[x]  1. /getting-started          Intro
[x]  2. /installation             Intro
[x]  3. /quickstart               Intro
[x]  4. /api/overview             API
[x]  5. /api/authentication       API
[ ]  8. /changelog                Meta
[ ] 10. /blog/announcement        Blog
...
[ ] 45. /community                Community

[x] = selected (default)
[ ] = deselected

Select (default: all):
```

### Step 3: Parse User Input

| Input | Action |
|-------|--------|
| `1,3,5` | Select pages 1, 3, 5 |
| `1-10` | Select pages 1 to 10 |
| `1-10,15,20-25` | Combine ranges and singles |
| `api/*` | Select all with /api/ in path |
| `exclude changelog` | Deselect pages with "changelog" |
| `only api` | Only pages with "api" |
| `all` | Select all pages |
| `none` | Deselect all |
| `invert` | Invert current selection |
| `Enter` (empty) | Use default (all selected) |

### Step 4: Confirm Selection

```
Selected 12 pages:
- /getting-started
- /installation
- /quickstart
- /api/overview
- /api/authentication
- /api/endpoints
- /faq
- /support

Proceed with download? (y/n)
```

### Step 5: Proceed

Only selected pages get crawled and embedded.

---

## Pattern Matching

### Implementation
```python
import re
from fnmatch import fnmatch

def match_pattern(path, pattern):
    """Check if path matches pattern."""
    if '*' in pattern:
        return fnmatch(path, pattern)
    return pattern.lower() in path.lower()

def parse_selection(input_str, total_pages):
    """Parse user input and return selected indices."""
    selected = set()

    if input_str.lower() == 'all':
        return set(range(1, total_pages + 1))
    if input_str.lower() == 'none':
        return set()

    parts = input_str.split(',')
    for part in parts:
        part = part.strip()
        if '-' in part and not part.startswith('-'):
            start, end = part.split('-')
            selected.update(range(int(start), int(end) + 1))
        elif part.isdigit():
            selected.add(int(part))

    return selected
```

### Pattern Examples

| Pattern | Match | No Match |
|---------|-------|----------|
| `api/*` | /api/auth, /api/users | /docs/api |
| `*/api/*` | /docs/api/ref | /api-docs |
| `exclude blog` | - | /blog/*, /blog-post |
| `only docs` | /docs/* | /api/*, /blog/* |

---

## Multiple Iterations

User can refine selection:

```
> exclude blog
Removed 5 pages. Selected: 40

> exclude changelog
Removed 3 pages. Selected: 37

> show api
Pages with "api":
  4. /api/overview
  5. /api/authentication
  6. /api/endpoints
  7. /api/errors

> only api
Selected: 4

> add 1-3
Added intro. Selected: 7

> ok
Proceeding with 7 pages...
```

### Available Commands

| Command | Description |
|---------|-------------|
| `show [pattern]` | Show matching pages |
| `add [selection]` | Add to selection |
| `remove [selection]` | Remove from selection |
| `reset` | Return to default (all) |
| `count` | Show current count |
| `list` | Show current selection |
| `ok` / `proceed` | Confirm and proceed |
| `cancel` | Cancel operation |

---

## Best Practices

1. **Sensible default** - Start with all selected
2. **Clear preview** - Group by section/category
3. **Confirm before proceeding** - Show final summary
4. **Allow iterations** - User can refine selection
5. **Remember preferences** - Suggest same selection for future updates

---

## Workspace Integration

If workspace exists with documents:

```
Workspace "docs-example" exists with 30 documents.

Options:
1. Add new pages (keep existing)
2. Replace all (delete and reimport)
3. Update modified only (compare dates)
4. Cancel

Choice:
```

---

*Last updated: January 2026*
