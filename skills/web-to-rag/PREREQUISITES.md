# Prerequisites Installation Guide

This guide covers installing everything needed for the **web-to-rag** skill.

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

# For automated installation with auto-restart (useful for VMs):
.\install-prerequisites.ps1 -Unattended
```

**What the script does:**
- Installs all prerequisites (Chocolatey, Docker, Node.js v22, Python 3.12, Deno, ffmpeg)
- Handles multiple reboots automatically (Hyper-V and Docker require restarts)
- Downloads Docker images with progress indication
- Generates AnythingLLM API key via Playwright browser automation
- Configures 4 MCP servers in `~/.claude.json`
- Sets up Docker Desktop auto-start

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
| **Playwright** | Browser automation (for AnythingLLM API key generation) | - |
| **AnythingLLM MCP Server** | Claude ↔ AnythingLLM bridge | - |
| **DuckDuckGo MCP Server** | Web search for Claude | - |
| **yt-dlp MCP Server** | YouTube info for Claude | - |
| **Crawl4AI MCP Server** | Claude ↔ Crawl4AI bridge | - |

### Docker Containers

| Container | Purpose | Port | Image Size |
|-----------|---------|------|------------|
| **crawl4ai** | Web scraping with JavaScript support | 11235 | ~1GB |
| **anythingllm** | Local RAG with LLM integration | 3001 | ~500MB |
| **yt-dlp-server** | YouTube transcript extraction | 8501 | ~200MB |
| **whisper-server** | Audio transcription with Whisper | 8502 | ~2GB |

### Docker Volumes

All persistent data is stored in Docker named volumes (not on the filesystem):

| Volume | Container | Purpose |
|--------|-----------|---------|
| **crawl4ai-data** | crawl4ai | Browser cache and crawl data |
| **anythingllm-storage** | anythingllm | RAG database, workspaces, embeddings |
| **ytdlp-cache** | yt-dlp-server | Downloaded audio cache |
| **whisper-models** | whisper-server | Cached Whisper models (~150MB for base) |

To inspect volumes:
```bash
docker volume ls
docker volume inspect anythingllm-storage
```

To backup all volumes:
```bash
# Backup all skill volumes
for vol in crawl4ai-data anythingllm-storage ytdlp-cache whisper-models; do
  docker run --rm -v $vol:/data -v $(pwd):/backup alpine tar czf /backup/$vol.tar.gz -C /data .
done

# Restore a volume
docker run --rm -v anythingllm-storage:/data -v $(pwd):/backup alpine tar xzf /backup/anythingllm-storage.tar.gz -C /data
```

To remove all volumes (WARNING: deletes all data):
```bash
docker volume rm crawl4ai-data anythingllm-storage ytdlp-cache whisper-models
```

### Auto-Start Configuration (Windows)

The installer automatically configures:

| Component | Behavior | How to Disable |
|-----------|----------|----------------|
| **Docker Desktop** | Starts with Windows (minimized) | Remove shortcut from `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` |
| **All containers** | Auto-restart when Docker starts | `docker update --restart=no <container-name>` |

This means after a system reboot, Docker will start automatically and all containers will be available without manual intervention.

### Local Tools

| Tool | Purpose | Auto-installed |
|------|---------|----------------|
| **Deno** | JavaScript runtime for yt-dlp (YouTube support) | ✅ Yes |
| **ffmpeg** | Video/audio processing for yt-dlp | ✅ Yes |
| **poppler (pdftotext)** | PDF text extraction | ✅ Yes |
| **Playwright** | Browser automation for API key generation | ✅ Yes (local installation) |

### MCP Servers Source

The MCP servers are installed from **Tapiocapioca's forks** (customized versions):

| MCP Server | Repository | Language |
|------------|------------|----------|
| **AnythingLLM MCP** | <a href="https://github.com/Tapiocapioca/anythingllm-mcp-server" target="_blank">github.com/Tapiocapioca/anythingllm-mcp-server</a> | Node.js |
| **DuckDuckGo MCP** | <a href="https://github.com/Tapiocapioca/mcp-duckduckgo" target="_blank">github.com/Tapiocapioca/mcp-duckduckgo</a> | Python |
| **yt-dlp MCP** | <a href="https://github.com/Tapiocapioca/yt-dlp-mcp" target="_blank">github.com/Tapiocapioca/yt-dlp-mcp</a> | Node.js |
| **Crawl4AI MCP** | Built into Docker container (SSE endpoint) | - |

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
# Crawl4AI (web scraping) - uses Docker named volume
docker run -d \
  --name crawl4ai \
  -p 11235:11235 \
  -v crawl4ai-data:/app/data \
  --restart unless-stopped \
  unclecode/crawl4ai:latest

# AnythingLLM (local RAG) - uses Docker named volume
docker run -d \
  --name anythingllm \
  -p 3001:3001 \
  -e STORAGE_DIR="/app/server/storage" \
  -v anythingllm-storage:/app/server/storage \
  --restart unless-stopped \
  mintplexlabs/anythingllm:latest

# yt-dlp-server (YouTube transcripts) - uses Docker named volume
# Build from the skill's infrastructure directory
cd skills/web-to-rag/infrastructure/docker/yt-dlp
docker build -t yt-dlp-server .
docker run -d \
  --name yt-dlp-server \
  -p 8501:8501 \
  -v ytdlp-cache:/app/temp \
  --restart unless-stopped \
  yt-dlp-server

# whisper-server (audio transcription) - uses Docker named volume
cd ../whisper
docker build -t whisper-server .
docker run -d \
  --name whisper-server \
  -p 8502:8502 \
  -v whisper-models:/app/models \
  --restart unless-stopped \
  whisper-server
```

### 3. Install MCP Servers

There are **4 MCP servers** to install:

```bash
# Create MCP directory
mkdir -p ~/.claude/mcp-servers
cd ~/.claude/mcp-servers

# 1. AnythingLLM MCP (from Tapiocapioca's fork - Node.js)
git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git
cd anythingllm-mcp-server && npm install && cd ..

# 2. DuckDuckGo MCP (from Tapiocapioca's fork - Python)
git clone https://github.com/Tapiocapioca/mcp-duckduckgo.git
cd mcp-duckduckgo && pip install -e . && cd ..

# 3. yt-dlp MCP (from Tapiocapioca's fork - Node.js)
git clone https://github.com/Tapiocapioca/yt-dlp-mcp.git
cd yt-dlp-mcp && npm install && cd ..

# 4. Crawl4AI MCP - NO INSTALLATION NEEDED!
# The Crawl4AI Docker container includes a built-in MCP server
# via SSE endpoint at http://localhost:11235/mcp/sse
```

| MCP Server | Language | Purpose |
|------------|----------|---------|
| **anythingllm-mcp-server** | Node.js | Query your RAG knowledge base |
| **mcp-duckduckgo** | Python | Web search |
| **yt-dlp-mcp** | Node.js | YouTube video info and transcripts |
| **crawl4ai** | Docker SSE | Web scraping with JS rendering |

---

## Configuring AnythingLLM

**Configure AnythingLLM with an LLM provider** — this step is essential.

### Step 1: Open AnythingLLM Web UI

Open your browser and go to: **http://localhost:3001**

### Step 2: Complete Initial Setup

1. Create an admin account (username/password)
2. Choose your LLM provider

### Step 3: Configure LLM Provider

Go to **Settings** (gear icon) → **LLM Preference**

Choose one of these providers:

| Provider | What You Need | Cost |
|----------|---------------|------|
| **iFlow Platform** ⭐ | API Key from <a href="https://platform.iflow.cn/en/models" target="_blank">platform.iflow.cn</a> | **Free tier** |
| **OpenAI** | API Key from <a href="https://platform.openai.com/api-keys" target="_blank">platform.openai.com</a> | Paid |
| **Anthropic** | API Key from <a href="https://console.anthropic.com/" target="_blank">console.anthropic.com</a> | Paid |
| **OpenRouter** | API Key from <a href="https://openrouter.ai/keys" target="_blank">openrouter.ai</a> | Pay per use |
| **Ollama** | Local Ollama installation | Free (local) |
| **Azure OpenAI** | Azure endpoint and key | Paid |

#### ⭐ Recommended: iFlow Platform (Free Tier)

**iFlow** offers a free tier with access to many powerful LLM models. Perfect for getting started!

**Available models include:**
- `glm-4.6` - GLM-4.6 (200K context, 128K output) ⭐ Recommended
- `qwen3-max` - Qwen3 Max (256K context)
- `deepseek-v3` - DeepSeek V3 (128K context)
- `kimi-k2` - Kimi K2 (128K context)
- `deepseek-r1` - DeepSeek R1 reasoning model

**Setup:**
1. **Sign up without Chinese phone number:**
   - Use this direct link: <a href="https://iflow.cn/oauth?redirect=https%3A%2F%2Fvibex.iflow.cn%2Fsession%2Fsso_login" target="_blank">iflow.cn signup</a>
   - This bypasses the Chinese phone verification requirement

2. **Get your API key:**
   - Direct link: <a href="https://platform.iflow.cn/profile?tab=apiKey" target="_blank">platform.iflow.cn/profile</a>
   - ⚠️ **Tip:** If the site displays in English, the user menu may be hidden. Use the direct link above to access API key settings.

3. In AnythingLLM, select **"Generic OpenAI"**

4. Configure:
   - **Base URL**: `https://api.iflow.cn/v1`
   - **API Key**: Your iFlow API key
   - **Model**: `glm-4.6` (or another model from the list)
   - **Context Window**: `200000` (for GLM-4.6)
   - **Max Tokens**: `8192`

> **Note:** iFlow provides LLM models only (no embeddings). Use the built-in "AnythingLLM Embedder" for embeddings.

**For Ollama (Free, Local Option):**
1. Install Ollama: <a href="https://ollama.ai" target="_blank">ollama.ai</a>
2. Pull a model: `ollama pull llama2` or `ollama pull mistral`
3. In AnythingLLM, select "Ollama" and enter: `http://host.docker.internal:11434`

### Step 4: Configure Embedding Model

Go to **Settings** → **Embedding Preference**

| Provider | Model | Notes |
|----------|-------|-------|
| **AnythingLLM Embedder** ⭐ | `all-MiniLM-L6-v2` | Built-in, no API key needed, works with any LLM |
| **OpenAI** | `text-embedding-3-small` or `text-embedding-3-large` | Requires OpenAI API key |
| **Ollama** | `nomic-embed-text` | Run `ollama pull nomic-embed-text` first |

**Recommended: Use the built-in AnythingLLM Embedder**

If you're using iFlow or another provider that doesn't offer embeddings, keep the default **"AnythingLLM Embedder"**. It works well and requires no additional configuration.

**For OpenAI users:**
1. Select **"OpenAI"** as embedding provider
2. Enter your OpenAI API Key
3. Model: `text-embedding-3-small` (faster) or `text-embedding-3-large` (better quality)

### Step 5: Create API Key

Go to **Settings** → **API Keys**

1. Click **"Create New API Key"**
2. Give it a name (e.g., "claude-code")
3. **Copy the key** - you'll need it for the MCP configuration

The key looks like: `XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX`

> **Note:** The `install-prerequisites.ps1` script automatically generates an API key using Playwright browser automation. If the automation succeeds, the key will already be configured in `~/.claude.json`. Check your configuration file before generating a key manually.

---

## Configuring MCP Servers

After installing MCP servers, you need to configure them in Claude Code.

### Step 1: Find Your MCP Config File

**IMPORTANT:** Claude Code reads MCP configuration from `~/.claude.json` (at the root level `mcpServers` section), NOT from `~/.claude/mcp_servers.json`.

**Windows:** `%USERPROFILE%\.claude.json`
**Linux/macOS:** `~/.claude.json`

### Step 2: Edit the Configuration

Open your `.claude.json` file and add/merge the `mcpServers` section. Replace `YOUR_API_KEY_HERE` with your AnythingLLM API key:

```json
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["C:/Users/YourUsername/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
      "env": {
        "ANYTHINGLLM_API_KEY": "YOUR_API_KEY_HERE",
        "ANYTHINGLLM_BASE_URL": "http://localhost:3001"
      }
    },
    "duckduckgo-search": {
      "command": "mcp-duckduckgo"
    },
    "yt-dlp": {
      "command": "node",
      "args": ["C:/Users/YourUsername/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs"]
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
- Replace `YourUsername` with your actual username:
  - **Windows:** Use forward slashes `C:/Users/YourUsername/...`
  - **Linux/macOS:** `/home/YourUsername` or `/Users/YourUsername`

### Step 3: Restart Claude Code

**Close and reopen Claude Code** for the 4 MCP servers to load:
- `anythingllm` - RAG queries
- `duckduckgo-search` - Web search
- `yt-dlp` - YouTube transcripts
- `crawl4ai` - Web scraping

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
curl http://localhost:3001/api/ping
```

Expected: `{"online":true}`

> **Note:** AnythingLLM uses `/api/ping` for health checks, not `/api/health`.

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
- ✅ yt-dlp
- ✅ crawl4ai

### Initialize AnythingLLM MCP

Initialize the AnythingLLM MCP server on first use. Claude Code does this automatically, but you can also initialize manually:

```
Ask Claude: "Initialize AnythingLLM with my API key"
```

Or use the MCP tool directly:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "YOUR_API_KEY"
  baseUrl: "http://localhost:3001"
```

**Note:** The API key is configured in `~/.claude.json` (see [Configuring MCP Servers](#configuring-mcp-servers)), so initialization should happen automatically. Manual initialization is only needed if you see a "Client not initialized" error.

---

## Troubleshooting

### Docker Desktop Won't Start in Hyper-V VM

**Symptom:** Docker Desktop fails to start with errors like "WSL 2 installation is incomplete" or hangs during startup.

**Cause:** Nested virtualization is not enabled on the Hyper-V HOST.

**Solution:**

1. **Shut down the VM** (from Hyper-V HOST):
   ```powershell
   Stop-VM -Name '<VMName>' -Force
   ```

2. **Enable nested virtualization** (from Hyper-V HOST):
   ```powershell
   Set-VMProcessor -VMName '<VMName>' -ExposeVirtualizationExtensions $true
   ```

3. **Start the VM**:
   ```powershell
   Start-VM -Name '<VMName>'
   ```

4. **Re-run the installer** inside the VM

> **Note:** The `install-prerequisites.ps1` script automatically detects Hyper-V VMs and installs Docker with the correct backend. However, it cannot enable nested virtualization from inside the VM - this MUST be done on the HOST.

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

1. Check the path in `.claude.json` is correct
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

### yt-dlp JavaScript runtime warnings

If you see warnings like:
```
WARNING: [youtube] No supported JavaScript runtime could be found
WARNING: [youtube] [jsc] Remote components challenge solver script (deno) ... were skipped
WARNING: [youtube] n challenge solving failed: Some formats may be missing
```

**This requires two things:**
1. **Deno** must be installed (JavaScript runtime)
2. **yt-dlp config** must enable the remote challenge solver

Since November 2025, yt-dlp requires a JavaScript runtime (Deno) AND a challenge solver script to fully support YouTube downloads.

**Fix Step 1 - Install Deno:**
```powershell
# Windows (PowerShell)
winget install --id=DenoLand.Deno

# Linux/macOS
curl -fsSL https://deno.land/install.sh | sh
```

**Fix Step 2 - Configure yt-dlp:**
```powershell
# Windows - Create/update yt-dlp config
mkdir "$env:APPDATA\yt-dlp" -Force
Add-Content "$env:APPDATA\yt-dlp\config.txt" "--remote-components ejs:github"
```

```bash
# Linux/macOS - Create/update yt-dlp config
mkdir -p ~/.config/yt-dlp
echo "--remote-components ejs:github" >> ~/.config/yt-dlp/config
```

After configuration, **restart your terminal** for changes to take effect.

**Verify the fix:**
```bash
# Should show no warnings
yt-dlp "ytsearch1:test" --print title --no-download
```

**Note:** The `install-prerequisites.ps1` script automatically installs Deno and configures yt-dlp.

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
