# Prerequisites Installation Guide

This guide walks you through installing everything needed for the **web-to-rag** skill.

---

## Table of Contents

1. [Quick Start (Automated)](#quick-start-automated)
2. [What Gets Installed](#what-gets-installed)
3. [Manual Installation](#manual-installation)
4. [Configuring AnythingLLM](#configuring-anythingllm)
5. [Configuring MCP Servers](#configuring-mcp-servers)
6. [Verifying Installation](#verifying-installation)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start (Automated)

### Windows (PowerShell as Administrator)

```powershell
# If you cloned the repo, run from the skill directory:
cd skills/web-to-rag
.\install-prerequisites.ps1

# Or download and run directly:
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Tapiocapioca/claude-code-skills/master/skills/web-to-rag/install-prerequisites.ps1" -OutFile "install-prerequisites.ps1"
.\install-prerequisites.ps1
```

### Linux/macOS

```bash
# If you cloned the repo, run from the skill directory:
cd skills/web-to-rag
./install-prerequisites.sh

# Or download and run directly:
curl -fsSL https://raw.githubusercontent.com/Tapiocapioca/claude-code-skills/master/skills/web-to-rag/install-prerequisites.sh | bash
```

---

## What Gets Installed

| Component | Purpose | Port |
|-----------|---------|------|
| **Docker Desktop** | Container runtime | - |
| **Crawl4AI** | Web scraping engine | 11235 |
| **AnythingLLM** | Local RAG system | 3001 |
| **yt-dlp-server** | YouTube transcript extraction | 8501 |
| **whisper-server** | Audio transcription (Whisper) | 8502 |
| **AnythingLLM MCP Server** | Claude ↔ AnythingLLM bridge | - |
| **DuckDuckGo MCP Server** | Web search for Claude | - |
| **Crawl4AI MCP Server** | Claude ↔ Crawl4AI bridge | - |

### Docker Containers

| Container | Purpose | Port | Image Size |
|-----------|---------|------|------------|
| **crawl4ai** | Web scraping with JavaScript support | 11235 | ~1GB |
| **anythingllm** | Local RAG with LLM integration | 3001 | ~500MB |
| **yt-dlp-server** | YouTube transcript extraction | 8501 | ~200MB |
| **whisper-server** | Audio transcription with Whisper | 8502 | ~2GB |

### Local Tools

| Tool | Purpose | Auto-installed |
|------|---------|----------------|
| **poppler (pdftotext)** | PDF text extraction | ✅ Yes |

### MCP Servers Source

The MCP servers are installed from **Tapiocapioca's forks** (customized versions):

- **AnythingLLM MCP**: https://github.com/Tapiocapioca/anythingllm-mcp-server
- **DuckDuckGo MCP**: https://github.com/Tapiocapioca/mcp-duckduckgo
- **Crawl4AI MCP**: Built into Docker container (SSE endpoint)

---

## Manual Installation

If you prefer to install components manually:

### 1. Install Docker

**Windows:**
```powershell
# Using Chocolatey
choco install docker-desktop -y
```

**macOS:**
```bash
brew install --cask docker
```

**Linux (Ubuntu/Debian):**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### 2. Create Docker Containers

```bash
# Crawl4AI (web scraping)
docker run -d \
  --name crawl4ai \
  -p 11235:11235 \
  --restart unless-stopped \
  unclecode/crawl4ai:latest

# AnythingLLM (local RAG)
mkdir -p ~/.anythingllm/storage
docker run -d \
  --name anythingllm \
  -p 3001:3001 \
  -e STORAGE_DIR="/app/server/storage" \
  -v ~/.anythingllm/storage:/app/server/storage \
  --restart unless-stopped \
  mintplexlabs/anythingllm:latest

# yt-dlp-server (YouTube transcripts)
# Build from the skill's infrastructure directory
cd skills/web-to-rag/infrastructure/docker/yt-dlp
docker build -t yt-dlp-server .
docker run -d \
  --name yt-dlp-server \
  -p 8501:8501 \
  --restart unless-stopped \
  yt-dlp-server

# whisper-server (audio transcription)
cd ../whisper
docker build -t whisper-server .
docker run -d \
  --name whisper-server \
  -p 8502:8502 \
  --restart unless-stopped \
  whisper-server
```

### 3. Install MCP Servers

```bash
# Create MCP directory
mkdir -p ~/.claude/mcp-servers
cd ~/.claude/mcp-servers

# AnythingLLM MCP (from Tapiocapioca's fork - Node.js)
git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git
cd anythingllm-mcp-server && npm install && cd ..

# DuckDuckGo MCP (Python package)
pip install mcp-duckduckgo

# Crawl4AI MCP - NO INSTALLATION NEEDED!
# The Crawl4AI Docker container includes a built-in MCP server
# via SSE endpoint at http://localhost:11235/mcp/sse
```

---

## Configuring AnythingLLM

This is the **most important step**. AnythingLLM needs to be configured with an LLM provider to work.

### Step 1: Open AnythingLLM Web UI

Open your browser and go to: **http://localhost:3001**

### Step 2: Complete Initial Setup

1. Create an admin account (username/password)
2. Choose your LLM provider

### Step 3: Configure LLM Provider

Go to **Settings** (gear icon) → **LLM Preference**

Choose one of these providers:

| Provider | What You Need |
|----------|---------------|
| **OpenAI** | API Key from https://platform.openai.com/api-keys |
| **Anthropic** | API Key from https://console.anthropic.com/ |
| **Ollama** | Local Ollama installation (free, no API key) |
| **Azure OpenAI** | Azure endpoint and key |
| **OpenRouter** | API Key from https://openrouter.ai/keys |

**For Ollama (Free Option):**
1. Install Ollama: https://ollama.ai
2. Pull a model: `ollama pull llama2` or `ollama pull mistral`
3. In AnythingLLM, select "Ollama" and enter: `http://host.docker.internal:11434`

### Step 4: Configure Embedding Model

Go to **Settings** → **Embedding Preference**

- For **OpenAI**: Use `text-embedding-ada-002`
- For **Ollama**: Use `nomic-embed-text` (run `ollama pull nomic-embed-text` first)
- For **Local**: Use the built-in "AnythingLLM Embedder"

### Step 5: Create API Key

Go to **Settings** → **API Keys**

1. Click **"Create New API Key"**
2. Give it a name (e.g., "claude-code")
3. **Copy the key** - you'll need it for the MCP configuration

The key looks like: `TZZAC6K-Q8K4DJ6-NBP90YN-DY52YAQ`

---

## Configuring MCP Servers

After installing MCP servers, you need to configure them in Claude Code.

### Step 1: Find Your MCP Config File

**Windows:** `%USERPROFILE%\.claude\mcp_servers.json`
**Linux/macOS:** `~/.claude/mcp_servers.json`

### Step 2: Edit the Configuration

If the installer created it, update `YOUR_API_KEY_HERE` with your AnythingLLM API key:

```json
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["~/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
      "env": {
        "ANYTHINGLLM_API_KEY": "YOUR_API_KEY_HERE",
        "ANYTHINGLLM_BASE_URL": "http://localhost:3001"
      }
    },
    "duckduckgo-search": {
      "command": "mcp-duckduckgo"
    },
    "crawl4ai": {
      "type": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```

**Important:**
- Replace `YOUR_API_KEY_HERE` with your AnythingLLM API key
- Replace `~` with your actual home directory path:
  - **Windows:** `C:/Users/YourUsername`
  - **Linux/macOS:** `/home/YourUsername` or `/Users/YourUsername`

### Step 3: Restart Claude Code

Close and reopen Claude Code for the MCP servers to load.

---

## Verifying Installation

### Check Docker Containers

```bash
docker ps
```

You should see:
```
NAMES           STATUS
crawl4ai        Up X minutes (healthy)
anythingllm     Up X minutes (healthy)
yt-dlp-server   Up X minutes (healthy)
whisper-server  Up X minutes (healthy)
```

### Check Crawl4AI

```bash
curl http://localhost:11235/health
```

Expected: `{"status":"ok"}`

### Check AnythingLLM

```bash
curl http://localhost:3001/api/health
```

Expected: `{"ok":true}`

### Check yt-dlp-server

```bash
curl http://localhost:8501/health
```

Expected: `{"status":"ok","service":"yt-dlp-server",...}`

### Check whisper-server

```bash
curl http://localhost:8502/health
```

Expected: `{"status":"ok","service":"whisper-server",...}`

### Check in Claude Code

Ask Claude:
```
/mcp
```

You should see:
- ✅ anythingllm
- ✅ duckduckgo-search
- ✅ crawl4ai

---

## Troubleshooting

### Docker containers not starting

```bash
# Check container logs
docker logs crawl4ai
docker logs anythingllm

# Restart containers
docker restart crawl4ai anythingllm

# If still failing, recreate
docker rm -f crawl4ai anythingllm
# Then run the docker run commands again
```

### "Client not initialized" error in Claude

Initialize manually:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

### MCP server not showing in Claude

1. Check the path in `mcp_servers.json` is correct
2. Make sure `npm install` was run in each MCP directory
3. Restart Claude Code

### Port already in use

```bash
# Find what's using the port
# Windows:
netstat -ano | findstr :3001

# Linux/macOS:
lsof -i :3001

# Change port in docker run command if needed
docker run -d --name anythingllm -p 3002:3001 ...
# Then update ANYTHINGLLM_BASE_URL to http://localhost:3002
```

### AnythingLLM not embedding documents

1. Check that an embedding model is configured in Settings → Embedding Preference
2. If using Ollama, make sure the embedding model is pulled:
   ```bash
   ollama pull nomic-embed-text
   ```

---

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Claude Code   │────▶│   MCP Servers   │────▶│    Services     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                 ┌─────────────┼─────────────┐
                 │             │             │
                 ▼             ▼             ▼
        ┌───────────┐  ┌───────────┐  ┌───────────┐
        │AnythingLLM│  │  Crawl4AI │  │DuckDuckGo │
        │MCP Server │  │MCP Server │  │MCP Server │
        └─────┬─────┘  └─────┬─────┘  └───────────┘
              │              │
              ▼              ▼
        ┌───────────┐  ┌───────────┐
        │AnythingLLM│  │ Crawl4AI  │
        │ Container │  │ Container │
        │  :3001    │  │  :11235   │
        └───────────┘  └───────────┘

        ┌───────────────────────────────────────┐
        │         Media Processing              │
        │                                       │
        │  ┌─────────────┐  ┌─────────────┐    │
        │  │ yt-dlp      │  │ whisper     │    │
        │  │ server      │  │ server      │    │
        │  │ :8501       │  │ :8502       │    │
        │  │             │  │             │    │
        │  │ YouTube     │  │ Audio       │    │
        │  │ transcripts │  │ transcribe  │    │
        │  └─────────────┘  └─────────────┘    │
        └───────────────────────────────────────┘
```

---

## Next Steps

After completing the prerequisites:

1. **Install the skill:**
   ```bash
   mkdir -p ~/.claude/skills
   cd ~/.claude/skills
   git clone https://github.com/Tapiocapioca/claude-code-skills.git
   ```

2. **Test the skill:**
   Ask Claude: *"Add FastAPI documentation to RAG"*

3. **Query your knowledge base:**
   Ask Claude: *"What did I import into the RAG?"*

---

*Last updated: January 2026*
