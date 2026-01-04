<#
.SYNOPSIS
    Verification script for web-to-rag skill prerequisites installation

.DESCRIPTION
    This script checks that all prerequisites are correctly installed:
    - Docker containers running and healthy
    - MCP servers installed
    - CLI tools available
    - Health endpoints responding

.EXAMPLE
    .\verify-installation.ps1
#>

$ErrorActionPreference = "Continue"

# Colors
function Write-Check { param($msg) Write-Host "[CHECK] $msg" -ForegroundColor Cyan }
function Write-Pass { param($msg) Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  ❌ $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }

$script:passCount = 0
$script:failCount = 0

function Test-Check {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$PassMessage,
        [string]$FailMessage
    )

    Write-Check $Name
    try {
        $result = & $Test
        if ($result) {
            Write-Pass $PassMessage
            $script:passCount++
            return $true
        } else {
            Write-Fail $FailMessage
            $script:failCount++
            return $false
        }
    } catch {
        Write-Fail "$FailMessage - Error: $_"
        $script:failCount++
        return $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " WEB-TO-RAG INSTALLATION VERIFICATION" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# =============================================================================
# Docker Checks
# =============================================================================
Write-Host "🐳 DOCKER CHECKS" -ForegroundColor Yellow
Write-Host ""

Test-Check -Name "Docker daemon running" -Test {
    $null = docker info 2>&1
    return $LASTEXITCODE -eq 0
} -PassMessage "Docker daemon is running" -FailMessage "Docker daemon not running"

$containers = @(
    @{ Name = "crawl4ai"; Port = "11235"; Health = "http://localhost:11235/health" }
    @{ Name = "anythingllm"; Port = "3001"; Health = "http://localhost:3001/api/health" }
    @{ Name = "yt-dlp-server"; Port = "8501"; Health = "http://localhost:8501/health" }
    @{ Name = "whisper-server"; Port = "8502"; Health = "http://localhost:8502/health" }
)

foreach ($container in $containers) {
    Test-Check -Name "$($container.Name) container running" -Test {
        $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$($container.Name)$"
        return $null -ne $running
    } -PassMessage "$($container.Name) is running" -FailMessage "$($container.Name) is NOT running"

    Test-Check -Name "$($container.Name) container healthy" -Test {
        $health = docker inspect --format='{{.State.Health.Status}}' $container.Name 2>$null
        return $health -eq "healthy"
    } -PassMessage "$($container.Name) is healthy" -FailMessage "$($container.Name) is NOT healthy"
}

# Docker volumes
$volumes = @("crawl4ai-data", "anythingllm-storage", "ytdlp-cache", "whisper-models")
foreach ($volume in $volumes) {
    Test-Check -Name "Docker volume $volume" -Test {
        $exists = docker volume ls --format '{{.Name}}' | Select-String -Pattern "^$volume$"
        return $null -ne $exists
    } -PassMessage "$volume exists" -FailMessage "$volume NOT found"
}

Write-Host ""

# =============================================================================
# Health Endpoint Checks
# =============================================================================
Write-Host "🏥 HEALTH ENDPOINT CHECKS" -ForegroundColor Yellow
Write-Host ""

foreach ($container in $containers) {
    Test-Check -Name "$($container.Name) health endpoint" -Test {
        try {
            $response = Invoke-WebRequest -Uri $container.Health -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            return $response.StatusCode -eq 200
        } catch {
            return $false
        }
    } -PassMessage "$($container.Health) responding" -FailMessage "$($container.Health) NOT responding"
}

Write-Host ""

# =============================================================================
# MCP Server Checks
# =============================================================================
Write-Host "🔌 MCP SERVER CHECKS" -ForegroundColor Yellow
Write-Host ""

$mcpServers = @(
    @{ Name = "anythingllm-mcp-server"; Path = "$env:USERPROFILE\.claude\mcp-servers\anythingllm-mcp-server\src\index.js" }
    @{ Name = "mcp-duckduckgo"; Path = "$env:USERPROFILE\.claude\mcp-servers\mcp-duckduckgo\pyproject.toml" }
    @{ Name = "yt-dlp-mcp"; Path = "$env:USERPROFILE\.claude\mcp-servers\yt-dlp-mcp\lib\index.mjs" }
)

foreach ($server in $mcpServers) {
    Test-Check -Name "$($server.Name) installed" -Test {
        return Test-Path $server.Path
    } -PassMessage "$($server.Name) found at $($server.Path)" -FailMessage "$($server.Name) NOT found"
}

# Check MCP configuration in .claude.json
Test-Check -Name ".claude.json MCP configuration" -Test {
    if (-not (Test-Path "$env:USERPROFILE\.claude.json")) {
        return $false
    }

    $config = Get-Content "$env:USERPROFILE\.claude.json" -Raw | ConvertFrom-Json
    if (-not $config.mcpServers) {
        return $false
    }

    $requiredServers = @("anythingllm", "duckduckgo-search", "yt-dlp", "crawl4ai")
    foreach ($serverName in $requiredServers) {
        if (-not $config.mcpServers.$serverName) {
            return $false
        }
    }

    return $true
} -PassMessage ".claude.json has all 4 MCP servers configured" -FailMessage ".claude.json missing or incomplete"

Write-Host ""

# =============================================================================
# CLI Tool Checks
# =============================================================================
Write-Host "🛠️ CLI TOOL CHECKS" -ForegroundColor Yellow
Write-Host ""

$tools = @(
    @{ Name = "mcp-duckduckgo"; Command = "mcp-duckduckgo" }
    @{ Name = "deno"; Command = "deno" }
    @{ Name = "pdftotext"; Command = "pdftotext" }
)

foreach ($tool in $tools) {
    Test-Check -Name "$($tool.Name) available" -Test {
        $found = Get-Command $tool.Command -ErrorAction SilentlyContinue
        return $null -ne $found
    } -PassMessage "$($tool.Name) found" -FailMessage "$($tool.Name) NOT found (may require terminal restart)"
}

Write-Host ""

# =============================================================================
# Auto-Start Configuration (Windows)
# =============================================================================
Write-Host "🚀 AUTO-START CONFIGURATION" -ForegroundColor Yellow
Write-Host ""

Test-Check -Name "Docker Desktop startup shortcut" -Test {
    return Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Docker Desktop.lnk"
} -PassMessage "Docker Desktop will start with Windows" -FailMessage "Docker Desktop startup shortcut NOT found"

Test-Check -Name "Container restart policies" -Test {
    $policies = docker inspect crawl4ai anythingllm yt-dlp-server whisper-server --format='{{.HostConfig.RestartPolicy.Name}}' 2>$null
    $allCorrect = $true
    foreach ($policy in $policies) {
        if ($policy -ne "unless-stopped") {
            $allCorrect = $false
            break
        }
    }
    return $allCorrect
} -PassMessage "All containers set to restart unless-stopped" -FailMessage "Some containers missing restart policy"

Write-Host ""

# =============================================================================
# Summary
# =============================================================================
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " SUMMARY" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$total = $script:passCount + $script:failCount
$percentage = [math]::Round(($script:passCount / $total) * 100, 1)

if ($script:failCount -eq 0) {
    Write-Host "🎉 ALL CHECKS PASSED! ($script:passCount/$total)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation is complete and working correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Configure AnythingLLM at: http://localhost:3001"
    Write-Host "2. Get your API key from Settings > API Keys"
    Write-Host "3. Update ~/.claude.json with your API key"
    Write-Host "4. Install the skill: cd ~/.claude/skills; git clone https://github.com/Tapiocapioca/claude-code-skills.git"
    Write-Host "5. Test with Claude Code: claude"
    Write-Host ""
    exit 0
} else {
    Write-Host "WARNING: SOME CHECKS FAILED ($script:passCount/$total passed, $percentage%)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please review the failed checks above and:" -ForegroundColor Yellow
    Write-Host "1. Check Docker container logs: docker logs <container-name>" -ForegroundColor Yellow
    Write-Host "2. Verify health endpoints in browser" -ForegroundColor Yellow
    Write-Host "3. Restart Docker Desktop if needed" -ForegroundColor Yellow
    Write-Host "4. Re-run this script after fixes" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For detailed troubleshooting, see:" -ForegroundColor Cyan
    Write-Host "https://github.com/Tapiocapioca/claude-code-skills/blob/master/skills/web-to-rag/PREREQUISITES.md#troubleshooting" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}
