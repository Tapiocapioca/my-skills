# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Architecture

This is a **plugin repository** for Claude Code containing production-ready skills. Each skill is **fully self-contained** with its own prerequisites, infrastructure, and documentation.

### Structure

```
claude-code-skills/
├── .claude-plugin/
│   └── marketplace.json      # Plugin registry (defines available skills)
├── skills/
│   └── web-to-rag/           # Each skill is independent
│       ├── SKILL.md          # Skill definition + quick reference
│       ├── README.md         # User documentation
│       ├── CLAUDE.md         # Developer guide (skill-specific)
│       ├── PREREQUISITES.md  # Installation instructions
│       ├── install-prerequisites.{ps1,sh}  # Automated installers
│       ├── infrastructure/   # Docker containers (if needed)
│       ├── references/       # Detailed workflows
│       └── scripts/          # Utilities
└── CONTRIBUTING.md
```

### Design Philosophy

**Self-Contained Skills**: Each skill under `skills/` operates independently with:
- Its own Docker containers (in `infrastructure/docker/`)
- Its own installation scripts
- Its own documentation hierarchy
- No shared dependencies between skills

## Working with Skills

### Adding a New Skill

1. **Create skill directory**: `skills/new-skill-name/`
2. **Required files**:
   - `SKILL.md` with YAML frontmatter (name, description, triggers)
   - `README.md` for user documentation
3. **Register in plugin**: Add entry to `.claude-plugin/marketplace.json`
4. **Optional files**:
   - `install-prerequisites.{ps1,sh}` for automated setup
   - `infrastructure/` for Docker containers
   - `references/` for detailed workflows
   - `scripts/` for utilities

### Skill Definition Format (SKILL.md)

```yaml
---
name: skill-name
description: |
  Brief description with trigger keywords.
  Include multilingual triggers if needed.
allowed-tools: Tool1 Tool2  # Optional
---

# Skill content follows...
```

### Marketplace Registration

Edit `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "skill-name",
      "description": "Brief description",
      "source": "./skills/skill-name",
      "strict": false
    }
  ]
}
```

## Current Skills

### web-to-rag v2.0

Imports websites, YouTube videos, and PDFs into AnythingLLM (local RAG).

**Architecture:**
- **MCP Servers**: Bridge between Claude and services (crawl4ai, anythingllm, duckduckgo, yt-dlp)
- **Docker Containers**:
  - `crawl4ai:11235` - Web scraping with JavaScript support
  - `anythingllm:3001` - Local RAG system
  - `yt-dlp-server:8501` - YouTube transcript extraction
  - `whisper-server:8502` - Audio transcription fallback

**Content Detection:**
| URL Pattern | Strategy |
|-------------|----------|
| `youtube.com/watch`, `youtu.be/` | yt-dlp transcript |
| `.pdf` extension | pdftotext extraction |
| Has `/sitemap.xml` | Sitemap-based crawl |
| Everything else | BFS crawl with Crawl4AI |

**Key Files:**
- `SKILL.md` - Quick reference for Claude (workflow, tools, limits)
- `CLAUDE.md` - Developer guide (architecture, state machine, helper functions)
- `PREREQUISITES.md` - User installation guide
- `install-prerequisites.ps1` - Windows installer (handles reboots, Docker setup, Playwright automation)

## Development Commands

### Testing Prerequisites Installation

```powershell
# Windows - Build and test in VM
cd skills/web-to-rag
.\install-prerequisites.ps1 -Unattended

# Verify installation
docker ps | findstr "crawl4ai anythingllm yt-dlp whisper"
curl http://localhost:11235/health
curl http://localhost:3001/api/ping
```

```bash
# Linux/macOS
cd skills/web-to-rag
./install-prerequisites.sh

# Verify
docker ps | grep -E "crawl4ai|anythingllm|yt-dlp|whisper"
curl http://localhost:11235/health
curl http://localhost:3001/api/ping
```

### Building Docker Containers

```bash
cd skills/web-to-rag/infrastructure/docker/

# yt-dlp server (YouTube transcripts)
cd yt-dlp
docker build -t yt-dlp-server .
docker run -d --name yt-dlp-server -p 8501:8501 --restart unless-stopped yt-dlp-server

# whisper server (audio transcription)
cd ../whisper
docker build -t whisper-server .
docker run -d --name whisper-server -p 8502:8502 --restart unless-stopped whisper-server
```

### Plugin Installation

```bash
# Via marketplace (recommended)
/plugin marketplace add Tapiocapioca/claude-code-skills

# Manual clone
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/Tapiocapioca/claude-code-skills.git
```

## Important Patterns

### Installation Scripts

**Windows (`install-prerequisites.ps1`):**
- **State machine**: Survives multiple reboots (Hyper-V + Docker require restarts)
- **State files**: `C:\Temp\install-prerequisites-{state,mode}.txt`
- **Auto-resume**: Scheduled task in `\PrerequisitesInstallation\`
- **Hypervisor detection**: Chooses correct Docker backend (Hyper-V for VMs, WSL2 for physical)
- **Playwright automation**: Generates AnythingLLM API key automatically
- **Progress indication**: Visible Docker pull progress, colored output with `Start-Transcript`

**Key design decisions:**
1. **Chocolatey first** - Install before any reboots to avoid reinstall loops
2. **Nested virt check disabled** - Guest OS can't reliably detect host config
3. **Pre-pull optimization** - Download all Docker images before container creation
4. **Local Playwright** - Install in temp project dir to avoid module resolution errors

### MCP Configuration

MCP servers are configured in `~/.claude.json` (root level `mcpServers`), NOT `~/.claude/mcp_servers.json`.

Example:
```json
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["~/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
      "env": {
        "ANYTHINGLLM_API_KEY": "generated-by-playwright",
        "ANYTHINGLLM_BASE_URL": "http://localhost:3001"
      }
    },
    "crawl4ai": {
      "type": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```

## Testing in Virtual Machines

### Hyper-V Testing

**Requirements:**
- Nested virtualization MUST be enabled on HOST: `Set-VMProcessor -VMName 'VM' -ExposeVirtualizationExtensions $true`
- Guest Service Interface enabled for file copy

**Copy script to VM:**
```powershell
Copy-VMFile -VMName "Windows11-Test" `
    -SourcePath "C:\path\to\install-prerequisites.ps1" `
    -DestinationPath "C:\Temp\install-prerequisites.ps1" `
    -FileSource Host `
    -CreateFullPath
```

**Run remotely:**
```powershell
$cred = Get-Credential  # VM credentials
Invoke-Command -VMName "Windows11-Test" -Credential $cred -ScriptBlock {
    & "C:\Temp\install-prerequisites.ps1" -Unattended
}
```

## Troubleshooting

### Docker Won't Start in VM
**Cause:** Nested virtualization not enabled on host
**Fix:** Run on Hyper-V HOST:
```powershell
Stop-VM -Name 'VM' -Force
Set-VMProcessor -VMName 'VM' -ExposeVirtualizationExtensions $true
Start-VM -Name 'VM'
```

### MCP Server Not Loading
1. Check `~/.claude.json` paths (use forward slashes on Windows)
2. Verify containers running: `docker ps`
3. Restart Claude Code to reload MCP config

### Playwright API Key Generation Failed
Fallback: Generate manually at `http://localhost:3001/settings/api-keys`

## Documentation Hierarchy

Each skill has multiple documentation layers:

1. **SKILL.md** - Quick reference for Claude during skill execution (triggers, tools, limits)
2. **README.md** - User-facing getting started guide
3. **CLAUDE.md** (skill-level) - Developer guide for modifying the skill
4. **PREREQUISITES.md** - Detailed installation instructions
5. **references/** - Deep-dive workflows (YouTube, PDF, crawling, scheduling)

When modifying documentation:
- **User changes** → Update README.md and PREREQUISITES.md
- **Workflow changes** → Update SKILL.md and references/
- **Architecture changes** → Update CLAUDE.md (skill-level)
- **Repository changes** → Update this file (root CLAUDE.md)

---

*Last updated: January 2026*
