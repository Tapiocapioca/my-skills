# PDF Workflow

Extract PDF text and import into RAG.

## Prerequisites

### pdftotext (from poppler)

**Windows:**
```powershell
choco install poppler -y
```

**macOS:**
```bash
brew install poppler
```

**Linux:**
```bash
sudo apt install poppler-utils
```

Verify:
```bash
which pdftotext || command -v pdftotext
pdftotext -v
```

---

## Workflow

### Step 1: Download PDF (if remote)

```bash
curl -L -o document.pdf "https://example.com/file.pdf"
# or
wget -O document.pdf "https://example.com/file.pdf"
```

### Step 2: Extract Text

```bash
# Basic extraction
pdftotext document.pdf output.txt

# Preserve layout (better for tables)
pdftotext -layout document.pdf output.txt

# Specific pages
pdftotext -f 1 -l 10 document.pdf output.txt  # Pages 1-10
```

### Step 3: Verify Content

```bash
wc -l output.txt
# If 0 or near-empty, likely a scanned image
```

### Step 4: Chunk Large PDFs

For PDFs > 50KB, split into chunks:

```python
def chunk_text(text, chunk_size=10000, overlap=500):
    """Split text into chunks with overlap."""
    chunks = []
    start = 0

    while start < len(text):
        end = start + chunk_size

        # Find nearest sentence end
        if end < len(text):
            for i in range(end, max(start, end - 500), -1):
                if text[i] in '.?!\n':
                    end = i + 1
                    break

        chunks.append(text[start:end])
        start = end - overlap

    return chunks
```

### Step 5: Embed in RAG

**Single document:**
```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: https://example.com/doc.pdf\ntitle: Document Title\ntype: pdf\n---\n\n[content]"
  ]
```

**Chunked document:**
```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: doc.pdf\ntitle: Doc Title\ntype: pdf\nchunk: 1/5\npages: 1-20\n---\n\n[chunk 1]",
    "---\nsource: doc.pdf\ntitle: Doc Title\ntype: pdf\nchunk: 2/5\npages: 21-40\n---\n\n[chunk 2]"
  ]
```

---

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "No text extracted" | Scanned PDF | Use OCR (Tesseract) |
| "Encoding error" | Special characters | Use `errors='ignore'` |
| "pdftotext not found" | Poppler missing | Install poppler |
| "Permission denied" | Password protected | Requires password |

### Protected PDFs

```bash
# With read password
pdftotext -upw "password" document.pdf output.txt

# Copy-protection only (often bypassed)
pdftotext document.pdf output.txt  # May work anyway
```

### Scanned PDFs (OCR)

```bash
# Install Tesseract
# Windows: choco install tesseract
# macOS: brew install tesseract
# Linux: apt install tesseract-ocr

# Convert to images and OCR
pdftoppm -png document.pdf page
for img in page-*.png; do
    tesseract "$img" "${img%.png}" -l ita+eng
done
cat page-*.txt > document.txt
```

---

## Best Practices

1. **Verify extraction** - Check text readability
2. **Use `-layout` for tables** - Preserves structure
3. **Chunk long documents** - Keep < 50KB per chunk
4. **Add metadata** - source, title, pages
5. **Clean whitespace** - Remove excessive blank lines
6. **Specify pages** - Extract only relevant sections

---

## Recommended Metadata

```yaml
---
source: https://example.com/whitepaper.pdf
title: Company Whitepaper 2024
type: pdf
pages: 1-50
chunk: 1/3  # if chunked
extracted: 2026-01-01
---
```

---

*Last updated: January 2026*
