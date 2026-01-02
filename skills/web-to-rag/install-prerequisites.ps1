#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs all prerequisites for claude-code-skills (web-to-rag)

.DESCRIPTION
    This script installs:
    - Chocolatey (if not present)
    - Docker Desktop
    - Git (if not present)
    - Node.js (for MCP servers)
    - Python (for utilities)
    - Crawl4AI Docker container (web scraping)
    - AnythingLLM Docker container (local RAG)
    - yt-dlp-server Docker container (YouTube transcripts)
    - whisper-server Docker container (audio transcription)
    - MCP Servers from Tapiocapioca's forks

.NOTES
    Run as Administrator!
    After installation, you must configure AnythingLLM with your LLM provider API key.

.LINK
    https://github.com/Tapiocapioca/claude-code-skills
#>

param(
    [switch]$SkipDocker,
    [switch]$SkipMCP,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }

# Environment refresh helper (more reliable than Chocolatey's refreshenv)
function Update-PathEnvironment {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    # Also try refreshenv if available (from Chocolatey)
    if (Get-Command refreshenv -ErrorAction SilentlyContinue) {
        try { refreshenv } catch { }
    }
}

# Native command helper - prevents PowerShell from treating stderr as terminating error
function Invoke-Native {
    param([scriptblock]$Command)
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command 2>&1 | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPref
    }
}

# Docker Container Helper Functions
function Test-ContainerExists {
    param([string]$Name)
    $exists = docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$Name$"
    return $null -ne $exists
}

function Test-ContainerRunning {
    param([string]$Name)
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$Name$"
    return $null -ne $running
}

function Start-ContainerIfStopped {
    param([string]$Name)
    if (-not (Test-ContainerRunning $Name)) {
        Write-Warn "Starting $Name container..."
        $result = docker start $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to start ${Name}: $result"
            return $false
        }
        return $true
    }
    return $false
}

function Test-ContainerHealth {
    param(
        [string]$Name,
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 60,
        [int]$IntervalSeconds = 5
    )

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                return $true
            }
        } catch {
            # Container not ready yet
        }
        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
    }
    return $false
}

function Install-DockerContainer {
    param(
        [string]$Name,
        [string]$Image,
        [string]$Port,
        [string]$HealthUrl,
        [hashtable]$ExtraArgs = @{},
        [string]$BuildContext = $null
    )

    Write-Step "Setting up $Name container..."

    if (Test-ContainerExists $Name) {
        Write-OK "$Name container exists"
        Start-ContainerIfStopped $Name | Out-Null
        if (-not (Test-ContainerRunning $Name)) {
            Write-Err "$Name container exists but is not running"
            return $false
        }
        return $true
    } else {
        if ($BuildContext) {
            Write-Warn "Building $Name container..."
            $exitCode = Invoke-Native { docker build -t $Name $BuildContext }
            if ($exitCode -ne 0) {
                Write-Err "Failed to build ${Name}"
                return $false
            }
            Write-OK "$Name image built"
            $Image = $Name
        } else {
            Write-Warn "Creating $Name container..."
        }

        # Build docker run command
        $runArgs = @("-d", "--name", $Name, "-p", $Port, "--restart", "unless-stopped")

        foreach ($key in $ExtraArgs.Keys) {
            $runArgs += $key
            if ($ExtraArgs[$key]) {
                $runArgs += $ExtraArgs[$key]
            }
        }

        $runArgs += $Image

        # Run container (suppress stderr progress messages)
        $oldPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $null = docker run @runArgs 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $oldPref

        if ($exitCode -ne 0) {
            Write-Err "Failed to create ${Name}"
            return $false
        }
        Write-OK "$Name container created"
    }

    # Health check
    if ($HealthUrl) {
        Write-Host "  Waiting for $Name to be healthy..."
        if (Test-ContainerHealth -Name $Name -HealthUrl $HealthUrl -TimeoutSeconds 60) {
            Write-OK "$Name is healthy"
        } else {
            Write-Warn "$Name health check failed (may still be starting)"
        }
    }

    return $true
}

function Get-LocalBuildContext {
    param(
        [string]$ContainerName,
        [string]$SubPath
    )

    $scriptDir = $PSScriptRoot
    $localPath = Join-Path $scriptDir $SubPath

    if (Test-Path (Join-Path $localPath "Dockerfile")) {
        return $localPath
    }

    # Clone repo if needed
    $tempDir = "$env:TEMP\claude-code-skills-temp"
    if (-not (Test-Path $tempDir)) {
        Write-Host "  Cloning repository for build..."
        $exitCode = Invoke-Native { git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git $tempDir }
        if ($exitCode -ne 0) {
            Write-Err "Failed to clone repository"
            return $null
        }
    }

    $remotePath = Join-Path $tempDir "skills\web-to-rag\$SubPath"
    if (-not (Test-Path (Join-Path $remotePath "Dockerfile"))) {
        Write-Err "Dockerfile not found at: $remotePath"
        return $null
    }

    return $remotePath
}

Write-Host @"

 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗     ██████╗ ██████╗ ██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗      ██║     ██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝      ██║     ██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗    ╚██████╗╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
                    SKILLS PREREQUISITES INSTALLER (Windows)
                    https://github.com/Tapiocapioca/claude-code-skills

"@ -ForegroundColor Magenta

Write-Host "This script will install:" -ForegroundColor White
Write-Host "  - Chocolatey (package manager)"
Write-Host "  - Docker Desktop"
Write-Host "  - Git, Node.js, Python"
Write-Host "  - Crawl4AI container (web scraping)"
Write-Host "  - AnythingLLM container (local RAG)"
Write-Host "  - yt-dlp-server container (YouTube transcripts)"
Write-Host "  - whisper-server container (audio transcription)"
Write-Host "  - MCP servers for Claude Code"
Write-Host ""
Write-Host "IMPORTANT: After installation, you must configure AnythingLLM" -ForegroundColor Yellow
Write-Host "           with your LLM provider API key (OpenAI, Anthropic, etc.)" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (Y/n)"
if ($confirm -eq "n" -or $confirm -eq "N") {
    Write-Host "Installation cancelled."
    exit 0
}

# =============================================================================
# STEP 1: Install Chocolatey
# =============================================================================
Write-Step "Checking Chocolatey..."

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-OK "Chocolatey already installed"
} else {
    Write-Warn "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-OK "Chocolatey installed successfully"
    } else {
        Write-Err "Failed to install Chocolatey"
        exit 1
    }
}

# =============================================================================
# STEP 2: Install Git
# =============================================================================
Write-Step "Checking Git..."

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-OK "Git already installed: $(git --version)"
} else {
    Write-Warn "Installing Git..."
    choco install git -y
    Update-PathEnvironment
    Write-OK "Git installed"
}

# =============================================================================
# STEP 3: Install Node.js
# =============================================================================
Write-Step "Checking Node.js..."

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-OK "Node.js already installed: $(node --version)"
} else {
    Write-Warn "Installing Node.js LTS..."
    choco install nodejs-lts -y
    Update-PathEnvironment
    Write-OK "Node.js installed"
}

# =============================================================================
# STEP 4: Install Python
# =============================================================================
Write-Step "Checking Python..."

if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-OK "Python already installed: $(python --version)"
} else {
    Write-Warn "Installing Python..."
    choco install python -y
    Update-PathEnvironment
    Write-OK "Python installed"
}

# =============================================================================
# STEP 5: Install Docker Desktop
# =============================================================================
if (-not $SkipDocker) {
    Write-Step "Checking Docker..."

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-OK "Docker already installed"

        # Check if Docker daemon is running
        $exitCode = Invoke-Native { docker info }
        if ($exitCode -eq 0) {
            Write-OK "Docker daemon is running"
        } else {
            Write-Warn "Docker is installed but not running. Starting Docker Desktop..."
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

            # Wait for Docker daemon with polling
            $maxWait = 90
            $elapsed = 0
            $interval = 5
            Write-Host "  Waiting for Docker daemon (up to ${maxWait}s)..."

            $dockerReady = $false
            while ($elapsed -lt $maxWait) {
                Start-Sleep -Seconds $interval
                $elapsed += $interval
                $exitCode = Invoke-Native { docker info }
                if ($exitCode -eq 0) {
                    Write-OK "Docker daemon is now running"
                    $dockerReady = $true
                    break
                }
                Write-Host "  Still waiting... (${elapsed}s)"
            }

            if (-not $dockerReady) {
                Write-Err "Docker daemon failed to start after ${maxWait}s"
                Write-Host "     Please start Docker Desktop manually and re-run script"
                exit 1
            }
        }
    } else {
        Write-Warn "Installing Docker Desktop..."
        choco install docker-desktop -y

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host " IMPORTANT: Docker Desktop Installed" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. You may need to RESTART your computer"
        Write-Host "2. After restart, open Docker Desktop"
        Write-Host "3. Complete the Docker setup wizard"
        Write-Host "4. Re-run this script to continue installation"
        Write-Host ""

        $restart = Read-Host "Restart now? (Y/n)"
        if ($restart -ne "n" -and $restart -ne "N") {
            Restart-Computer -Force
        }
        exit 0
    }

    # Configure Docker Desktop to start with Windows
    Write-Step "Configuring Docker Desktop to start with Windows..."

    $dockerStartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Docker Desktop.lnk"
    $dockerExePath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

    if (Test-Path $dockerExePath) {
        if (-not (Test-Path $dockerStartupPath)) {
            try {
                $WshShell = New-Object -ComObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut($dockerStartupPath)
                $Shortcut.TargetPath = $dockerExePath
                $Shortcut.Arguments = "--minimized"
                $Shortcut.WorkingDirectory = "C:\Program Files\Docker\Docker"
                $Shortcut.Description = "Docker Desktop - Auto-start"
                $Shortcut.Save()
                Write-OK "Docker Desktop configured to start with Windows (minimized)"
            } catch {
                Write-Warn "Could not create startup shortcut: $_"
            }
        } else {
            Write-OK "Docker Desktop already configured to start with Windows"
        }
    } else {
        Write-Warn "Docker Desktop executable not found, skipping auto-start configuration"
    }
}

# =============================================================================
# STEP 6: Pull Docker Containers
# =============================================================================
if (-not $SkipDocker) {
    # Crawl4AI
    Install-DockerContainer `
        -Name "crawl4ai" `
        -Image "unclecode/crawl4ai:latest" `
        -Port "11235:11235" `
        -HealthUrl "http://localhost:11235/health"

    # AnythingLLM - needs storage volume
    $storageDir = "$env:USERPROFILE\.anythingllm\storage"
    if (-not (Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }

    Install-DockerContainer `
        -Name "anythingllm" `
        -Image "mintplexlabs/anythingllm:latest" `
        -Port "3001:3001" `
        -HealthUrl "http://localhost:3001/api/health" `
        -ExtraArgs @{
            "-e" = "STORAGE_DIR=/app/server/storage"
            "-v" = "${storageDir}:/app/server/storage"
        }

    # yt-dlp-server
    $ytdlpContext = Get-LocalBuildContext -ContainerName "yt-dlp-server" -SubPath "infrastructure\docker\yt-dlp"
    Install-DockerContainer `
        -Name "yt-dlp-server" `
        -Image "yt-dlp-server" `
        -Port "8501:8501" `
        -HealthUrl "http://localhost:8501/health" `
        -BuildContext $ytdlpContext

    # whisper-server
    $whisperContext = Get-LocalBuildContext -ContainerName "whisper-server" -SubPath "infrastructure\docker\whisper"
    Install-DockerContainer `
        -Name "whisper-server" `
        -Image "whisper-server" `
        -Port "8502:8502" `
        -HealthUrl "http://localhost:8502/health" `
        -BuildContext $whisperContext

    # Cleanup temp clone
    $tempDir = "$env:TEMP\claude-code-skills-temp"
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
}

# =============================================================================
# STEP 7: Install MCP Servers
# =============================================================================
if (-not $SkipMCP) {
    Write-Step "Installing MCP Servers..."

    $mcpDir = "$env:USERPROFILE\.claude\mcp-servers"
    if (-not (Test-Path $mcpDir)) {
        New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
    }

    # AnythingLLM MCP Server (from Tapiocapioca's fork - Node.js)
    Write-Host "  Installing AnythingLLM MCP Server..."
    $anythingllmMcpDir = "$mcpDir\anythingllm-mcp-server"

    if (Test-Path $anythingllmMcpDir) {
        Write-Warn "  Updating existing installation..."
        Push-Location $anythingllmMcpDir
        $null = Invoke-Native { git pull origin main }
        Pop-Location
    } else {
        $null = Invoke-Native { git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git $anythingllmMcpDir }
    }

    Push-Location $anythingllmMcpDir
    $null = Invoke-Native { npm install }
    Pop-Location
    Write-OK "  AnythingLLM MCP Server installed"

    # DuckDuckGo MCP Server (Python package via pip)
    Write-Host "  Installing DuckDuckGo MCP Server..."
    $null = Invoke-Native { pip install --upgrade mcp-duckduckgo }
    Write-OK "  DuckDuckGo MCP Server installed"

    # Crawl4AI MCP Server - ALREADY INCLUDED IN DOCKER CONTAINER
    # The Crawl4AI container has a built-in MCP server via SSE endpoint
    # No separate installation needed - just configure the SSE URL
    Write-OK "  Crawl4AI MCP Server (built into Docker container)"
}

# =============================================================================
# STEP 7b: Extended Format Support (via Docker Containers)
# =============================================================================
Write-Step "Verifying extended format support..."

# YouTube and Whisper run in separate Docker containers
# No local installation needed!
Write-OK "  YouTube transcript extraction (via yt-dlp-server container, port 8501)"
Write-OK "  Whisper audio transcription (via whisper-server container, port 8502)"

# poppler for local PDF extraction (lightweight, still useful)
Write-Host "  Installing poppler (PDF support)..."
$pdftotext = Get-Command pdftotext -ErrorAction SilentlyContinue
if (-not $pdftotext) {
    $null = Invoke-Native { choco install poppler -y }
}
Write-OK "  poppler (pdftotext) installed"

Write-Host ""
Write-Host "  Note: Heavy tools run in separate Docker containers for clean environment." -ForegroundColor Cyan
Write-Host "        - yt-dlp-server: http://localhost:8501 (YouTube transcripts)" -ForegroundColor Cyan
Write-Host "        - whisper-server: http://localhost:8502 (Audio transcription)" -ForegroundColor Cyan

# =============================================================================
# STEP 8: Create Claude Code MCP Configuration
# =============================================================================
Write-Step "Creating Claude Code MCP configuration..."

$claudeConfigDir = "$env:USERPROFILE\.claude"
if (-not (Test-Path $claudeConfigDir)) {
    New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
}

$mcpConfigPath = "$claudeConfigDir\mcp_servers.json"
$userProfile = $env:USERPROFILE -replace '\\', '/'
$mcpConfig = @"
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["$userProfile/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
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
"@

# Only create if doesn't exist (don't overwrite user config)
if (-not (Test-Path $mcpConfigPath)) {
    $mcpConfig | Out-File -FilePath $mcpConfigPath -Encoding utf8
    Write-OK "MCP configuration created at: $mcpConfigPath"
} else {
    Write-Warn "MCP configuration already exists at: $mcpConfigPath"
    Write-Host "     Please manually merge the MCP server entries if needed"
}

# =============================================================================
# STEP 9: Verify Installation
# =============================================================================
Write-Step "Verifying installation..."

$allOK = $true

# Check Docker containers with health endpoints
if (-not $SkipDocker) {
    $containers = @(
        @{ Name = "crawl4ai"; Url = "http://localhost:11235/health"; Desc = "Crawl4AI" }
        @{ Name = "anythingllm"; Url = "http://localhost:3001/api/health"; Desc = "AnythingLLM" }
        @{ Name = "yt-dlp-server"; Url = "http://localhost:8501/health"; Desc = "yt-dlp-server (YouTube)" }
        @{ Name = "whisper-server"; Url = "http://localhost:8502/health"; Desc = "whisper-server (audio)" }
    )

    foreach ($container in $containers) {
        if (Test-ContainerRunning $container.Name) {
            try {
                $response = Invoke-WebRequest -Uri $container.Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-OK "$($container.Desc) running and healthy"
                } else {
                    Write-Warn "$($container.Desc) running but health check returned $($response.StatusCode)"
                }
            } catch {
                Write-Warn "$($container.Desc) running but health endpoint not responding"
            }
        } else {
            Write-Err "$($container.Desc) NOT running"
            $allOK = $false
        }
    }
}

# Check MCP servers
if (-not $SkipMCP) {
    if (Test-Path "$env:USERPROFILE\.claude\mcp-servers\anythingllm-mcp-server\src\index.js") {
        Write-OK "AnythingLLM MCP Server installed"
    } else {
        Write-Err "AnythingLLM MCP Server NOT found"
        $allOK = $false
    }

    # Check if mcp-duckduckgo is in PATH
    $duckduckgo = Get-Command mcp-duckduckgo -ErrorAction SilentlyContinue
    if ($duckduckgo) {
        Write-OK "DuckDuckGo MCP Server installed"
    } else {
        Write-Err "DuckDuckGo MCP Server NOT found (run: pip install mcp-duckduckgo)"
        $allOK = $false
    }
}

# Check local tools
$pdftotext = Get-Command pdftotext -ErrorAction SilentlyContinue
if ($pdftotext) {
    Write-OK "pdftotext installed (PDF support)"
} else {
    Write-Warn "pdftotext NOT found (PDF import won't work)"
}

# =============================================================================
# FINAL MESSAGE
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
if ($allOK) {
    Write-Host " Installation Complete!" -ForegroundColor Green
} else {
    Write-Host " Installation completed with warnings" -ForegroundColor Yellow
}
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. CONFIGURE AnythingLLM:" -ForegroundColor White
Write-Host "   - Open: http://localhost:3001"
Write-Host "   - Complete the setup wizard"
Write-Host "   - Go to Settings > LLM Preference"
Write-Host "   - Configure your LLM provider (OpenAI, Anthropic, Ollama, etc.)"
Write-Host "   - Go to Settings > API Keys"
Write-Host "   - Create an API key and copy it"
Write-Host ""
Write-Host "2. UPDATE MCP CONFIGURATION:" -ForegroundColor White
Write-Host "   - Edit: $mcpConfigPath"
Write-Host "   - Replace 'YOUR_API_KEY_HERE' with your AnythingLLM API key"
Write-Host ""
Write-Host "3. INSTALL THE SKILL:" -ForegroundColor White
Write-Host "   cd $env:USERPROFILE\.claude\skills"
Write-Host "   git clone https://github.com/Tapiocapioca/claude-code-skills.git"
Write-Host "   # Or copy the web-to-rag folder manually"
Write-Host ""
Write-Host "4. RESTART Claude Code to load the MCP servers"
Write-Host ""
Write-Host "AUTO-START CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   - Docker Desktop: starts automatically with Windows (minimized)"
Write-Host "   - All containers: restart automatically when Docker starts"
Write-Host "   - To disable: remove shortcut from Startup folder"
Write-Host ""
Write-Host "For detailed instructions, see:" -ForegroundColor Cyan
Write-Host "https://github.com/Tapiocapioca/claude-code-skills/blob/master/skills/web-to-rag/PREREQUISITES.md"
Write-Host ""
