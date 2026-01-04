# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the web-to-rag skill installation script.

## Project Overview

This repository contains a production-ready Windows PowerShell installer script (`install-prerequisites.ps1`) for the **web-to-rag** skill. The script automates the complete setup of:
- Development environment (Chocolatey, Git, Node.js v22 LTS, Python 3.12, Deno v2.1+)
- Docker Desktop with intelligent backend selection (Hyper-V for VMs, WSL2 for physical machines)
- Four Docker containers (Crawl4AI, AnythingLLM, yt-dlp-server, whisper-server)
- Four MCP servers for Claude Code integration
- Playwright automation for AnythingLLM API key generation

## Script Location

**Primary script:** `install-prerequisites.ps1` (root of web-to-rag skill)

## Running the Script

```powershell
# Requires Administrator privileges
.\install-prerequisites.ps1

# Options:
#   -SkipDocker     Skip Docker and container installation
#   -SkipMCP        Skip MCP server installation
#   -Unattended     Automated mode with auto-restart handling
#   -Verbose        Show verbose output
```

## Architecture & Design

### Installation Flow

The script follows a carefully orchestrated sequence:

```
STEP 0: Chocolatey (package manager)
   ↓
STEP 1: Hyper-V features (if in VM) → REBOOT
   ↓
STEP 2-5: Dev tools (Git, Node.js, Python, Deno, Playwright)
   ↓
STEP 6: Docker Desktop → REBOOT
   ↓
STEP 6a: Pre-pull Docker images (parallel download optimization)
   ↓
STEP 6b-c: Configure AnythingLLM + Generate API key (Playwright automation)
   ↓
STEP 7: Install 4 MCP servers
   ↓
STEP 8: Configure Claude Code MCP servers
   ↓
STEP 9: Verification
```

### State Machine for Reboot Resilience

The script uses a state machine to survive multiple reboots:

| State | Meaning | Next Action |
|-------|---------|-------------|
| `null` | Fresh installation | Start from beginning |
| `AFTER_HYPERV_REBOOT` | Hyper-V enabled, rebooted | Continue with Docker |
| `DOCKER_INSTALLED` | Docker installed, rebooted | Continue with containers |

**State persistence:**
- State file: `C:\Temp\install-prerequisites-state.txt`
- Mode file: `C:\Temp\install-prerequisites-mode.txt` (tracks Unattended/Manual mode)
- Auto-resume task: `\PrerequisitesInstallation\Install Prerequisites Auto-Resume`

### Key Design Decisions

#### 1. Chocolatey First (CRITICAL)
**Why:** Chocolatey must be installed BEFORE any reboots. If installed after a reboot, other packages may try to reinstall Chocolatey, causing conflicts.

**Implementation:** STEP 0 runs before all other checks, including Hyper-V detection.

#### 2. Hypervisor Detection
**Purpose:** Choose correct Docker backend (Hyper-V for VMs, WSL2 for physical machines)

**Function:** `Get-HypervisorType` detects:
- Hyper-V guests (via `Win32_ComputerSystem` manufacturer/model)
- VMware guests
- VirtualBox guests
- Physical machines

#### 3. Nested Virtualization Check Disabled
**Problem:** Guest OS cannot reliably detect if `ExposeVirtualizationExtensions` is set on the host.

**Solution:** Skip the `VirtualizationFirmwareEnabled` check. Let Docker Desktop handle validation when it starts. If nested virtualization is missing, Docker will fail with a clear error message.

#### 4. Docker Pull Progress Visibility
**Problem:** `docker run` downloads large images (5-10 minutes) but suppressed output made it look stuck.

**Solution:**
- **Check image exists** before `docker run`
- **Show pull progress** with visible output (no `2>&1 | Out-Null`)
- **Pre-pull optimization:** Download all images BEFORE creating containers (STEP 6a)

**Benefits:**
- User sees real-time download progress
- Container creation is instant (images already local)
- Total time reduced from ~15 minutes to ~10 minutes

#### 5. Playwright Local Installation
**Problem:** Global Playwright installation causes `node:internal/modules/cjs/loader:1386` error when executing inline scripts.

**Solution:**
- Create dedicated project directory: `$env:TEMP\playwright-automation`
- Install Playwright **locally** with `package.json`
- Execute scripts from that directory (`Push-Location`)

#### 6. AnythingLLM API Key Automation
**What:** Playwright script automates API key generation in AnythingLLM web UI.

**How:**
1. Navigate to `http://localhost:3001/settings/api-keys`
2. Click "Generate new API key" button (supports Italian/English)
3. Click "Create API Key" submit button
4. Extract key from table
5. Configure in `~/.claude.json`

**Transparency:** Multiple user-facing notices explain this automation.

#### 7. Logging with Colors Preserved
**Method:** `Start-Transcript` instead of `Tee-Object`

**Benefits:**
- Colors (Cyan, Green, Yellow, Red) visible in console
- Full transcript saved to `C:\Temp\install-prerequisites-transcript.log`
- Better user experience

### Helper Functions

| Function | Purpose |
|----------|---------|
| `Get-HypervisorType` | Detect VM environment (HyperV/VMware/VirtualBox/null) |
| `Save-InstallState` / `Get-InstallState` | Persist state across reboots |
| `Register-AutoRestartTask` | Create scheduled task for auto-resume |
| `Invoke-Native` | Wrap native commands to prevent stderr causing PowerShell errors |
| `Update-PathEnvironment` | Refresh PATH without terminal restart |
| `Install-DockerContainer` | Unified container creation with health checks |
| `Test-ContainerHealth` | Poll health endpoints with timeout |

## Docker Containers

| Container | Port | Health Endpoint | Purpose | Image Size |
|-----------|------|-----------------|---------|------------|
| crawl4ai | 11235 | /health | Web scraping with MCP SSE endpoint | ~1GB |
| anythingllm | 3001 | /api/ping | Local RAG system | ~500MB |
| yt-dlp-server | 8501 | /health | YouTube transcript extraction | ~200MB |
| whisper-server | 8502 | /health | Audio transcription | ~2GB |

**Volumes (Docker named volumes):**
- `crawl4ai-data` - Browser cache
- `anythingllm-storage` - RAG database, workspaces, embeddings
- `ytdlp-cache` - Downloaded audio cache
- `whisper-models` - Cached Whisper models

## MCP Servers

| MCP Server | Repository | Language | Purpose |
|------------|------------|----------|---------|
| **anythingllm** | <a href="https://github.com/Tapiocapioca/anythingllm-mcp-server">github.com/Tapiocapioca/anythingllm-mcp-server</a> | Node.js | Query RAG knowledge base |
| **duckduckgo-search** | <a href="https://github.com/Tapiocapioca/mcp-duckduckgo">github.com/Tapiocapioca/mcp-duckduckgo</a> | Python | Web search |
| **yt-dlp** | <a href="https://github.com/Tapiocapioca/yt-dlp-mcp">github.com/Tapiocapioca/yt-dlp-mcp</a> | Node.js | YouTube video info |
| **crawl4ai** | Built into Docker container | SSE | Web scraping |

**Configuration location:** `~/.claude.json` (root level `mcpServers` section)

## Verification Commands

```powershell
# Check installed software
choco list --local-only
node --version    # Should be v22.21.1
python --version  # Should be 3.12.x
deno --version    # Should be 2.1.4+
ffmpeg -version   # Should be 8.0.x

# Check Docker
docker info
docker ps -a

# Test container health
Invoke-WebRequest http://localhost:11235/health  # Crawl4AI
Invoke-WebRequest http://localhost:3001/api/ping # AnythingLLM
Invoke-WebRequest http://localhost:8501/health   # yt-dlp-server
Invoke-WebRequest http://localhost:8502/health   # whisper-server

# Check MCP configuration
$config = Get-Content "$env:USERPROFILE\.claude.json" | ConvertFrom-Json
$config.mcpServers | ConvertTo-Json -Depth 10

# Verify API key is configured (not placeholder)
$apiKey = $config.mcpServers.anythingllm.env.ANYTHINGLLM_API_KEY
if ($apiKey -eq "YOUR_API_KEY_HERE") {
    Write-Host "WARNING: API key is still placeholder!" -ForegroundColor Red
} else {
    Write-Host "API key configured: $($apiKey.Substring(0,8))..." -ForegroundColor Green
}

# Check Playwright installation
Test-Path "$env:TEMP\playwright-automation\node_modules\playwright"
```

## Troubleshooting

### Docker Won't Start in Hyper-V VM

**Cause:** Nested virtualization not enabled on the HOST.

**Solution (run on Hyper-V HOST):**
```powershell
Stop-VM -Name '<VMName>' -Force
Set-VMProcessor -VMName '<VMName>' -ExposeVirtualizationExtensions $true
Start-VM -Name '<VMName>'
```

### Docker Desktop Shows "Access Denied"

**Cause:** User not in `docker-users` group.

**Solution:**
```powershell
net localgroup docker-users Users /add
# Then restart or log out/in
```

### Script Gets Stuck After Reboot

**Check scheduled task:**
```powershell
Get-ScheduledTask -TaskPath "\PrerequisitesInstallation\"

# If task exists but didn't run, check state file:
Get-Content "C:\Temp\install-prerequisites-state.txt"

# Manually resume by running script again
.\install-prerequisites.ps1
```

### Docker Pull Fails with Network Error

**Symptoms:** `docker pull` times out or shows connection errors.

**Solutions:**
1. Check internet connectivity
2. Check Docker Desktop proxy settings (if behind corporate proxy)
3. Try pulling manually: `docker pull unclecode/crawl4ai:latest`
4. Check Windows Firewall settings for Docker

### Playwright API Key Generation Fails

**Symptoms:** Script shows "Could not extract API key" or "Playwright automation failed"

**Fallback:** Generate API key manually:
1. Open `http://localhost:3001/settings/api-keys`
2. Click "Generate new API key"
3. Copy the key
4. Edit `~/.claude.json` and replace `YOUR_API_KEY_HERE` with your key

### Claude Code Overwrites .claude.json

**Problem:** Claude Code overwrites `.claude.json` when it exits, losing MCP configuration.

**Solution:** Close Claude Code BEFORE running the installer. The script checks for running Claude processes and warns you.

## Testing in Virtual Machines

### Hyper-V Test VM Setup

**Requirements:**
- **Nested virtualization enabled** on the HOST (not in the guest):
  ```powershell
  Set-VMProcessor -VMName '<VMName>' -ExposeVirtualizationExtensions $true
  ```
- **Integration Services** enabled in VM settings
- **Guest Service Interface** enabled for `Copy-VMFile`

**Copying script to VM:**
```powershell
# From HOST (PowerShell Admin)
Copy-VMFile -VMName "Windows11-Test" `
    -SourcePath "C:\path\to\install-prerequisites.ps1" `
    -DestinationPath "C:\Temp\install-prerequisites.ps1" `
    -FileSource Host `
    -CreateFullPath
```

**Running commands in VM remotely:**
```powershell
# From HOST (PowerShell Admin)
$username = "Administrator"  # VM's username
$securePassword = ConvertTo-SecureString 'password' -AsPlainText -Force
$cred = New-Object PSCredential($username, $securePassword)

Invoke-Command -VMName "Windows11-Test" -Credential $cred -ScriptBlock {
    # Commands to run in VM
    & "C:\Temp\install-prerequisites.ps1" -Unattended
}
```

**Monitoring installation:**
```powershell
Invoke-Command -VMName "Windows11-Test" -Credential $cred -ScriptBlock {
    # Check state
    Get-Content C:\Temp\install-prerequisites-state.txt -ErrorAction SilentlyContinue

    # Check running processes
    Get-Process | Where-Object { $_.ProcessName -match 'docker|choco' }

    # Check containers
    docker ps -a
}
```

## Known Issues & Limitations

### Docker Desktop Welcome Screen
Docker Desktop shows a welcome screen on first launch requiring:
1. Accept Docker Subscription Service Agreement
2. Click "Skip" on welcome tutorial

**Decision:** Not automated. User must interact manually.

### AnythingLLM Configuration Required
After installation, user MUST:
1. Open `http://localhost:3001`
2. Configure LLM provider (OpenAI, Anthropic, iFlow, etc.)
3. Configure embedding model (recommended: built-in AnythingLLM Embedder)

The script cannot automate this because it requires user's API keys.

### Windows Firewall Prompts
Docker Desktop may trigger Windows Firewall prompts. User must allow access.

## Development Guidelines

### Modifying the Script

**Important principles:**
1. **Chocolatey must stay as STEP 0** (before any reboots)
2. **Use specific version numbers** (not "latest") for reproducible installs
3. **Verify versions exist** on Chocolatey before using:
   ```powershell
   choco search <package> --exact --all-versions
   ```
4. **Test in clean VM** before committing changes
5. **Update TESTING_CONTEXT.md** with any new fixes

### Adding New Components

**Template for new Docker container:**
```powershell
Install-DockerContainer `
    -Name "container-name" `
    -Image "image:tag" `
    -Port "external:internal" `
    -HealthUrl "http://localhost:port/health" `
    -ExtraArgs @{
        "-v" = "volume-name:/path/in/container"
        "-e" = "ENV_VAR=value"
    }
```

**Template for new MCP server:**
1. Clone in `~/.claude/mcp-servers/`
2. Run `npm install` or `pip install -e .`
3. Add to `.claude.json` mcpServers section
4. Document in PREREQUISITES.md

## File Organization

```
skills/web-to-rag/
├── install-prerequisites.ps1    # Main installer (Windows)
├── install-prerequisites.sh     # Installer (Linux/macOS)
├── PREREQUISITES.md            # User-facing installation guide
├── CLAUDE.md                   # This file (developer guide)
├── TESTING_CONTEXT.md          # Testing session notes and fixes
├── infrastructure/
│   └── docker/
│       ├── yt-dlp/            # YouTube transcript server
│       └── whisper/           # Audio transcription server
└── references/                # Supporting documentation
```

## Version History

- **v1.0** (January 2026): Initial automated installer
- **v2.0** (January 2026): Added Playwright API key automation, optimized Docker pull, fixed nested virt check

---

*Last updated: January 2026*
