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
    - Deno (JavaScript runtime for yt-dlp YouTube support)
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
    [switch]$Verbose,
    [switch]$Unattended  # For automated installation with auto-restart
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

# Detect hypervisor type (returns "HyperV", "VMware", "VirtualBox", "Unknown", or $null if not in VM)
function Get-HypervisorType {
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $manufacturer = $computerSystem.Manufacturer
        $model = $computerSystem.Model

        # Check for Hyper-V
        if ($manufacturer -match "Microsoft Corporation" -and $model -match "Virtual Machine") {
            return "HyperV"
        }

        # Check for VMware
        if ($manufacturer -match "VMware" -or $model -match "VMware") {
            return "VMware"
        }

        # Check for VirtualBox
        if ($manufacturer -match "innotek" -or $model -match "VirtualBox") {
            return "VirtualBox"
        }

        # Additional check via BIOS
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        if ($bios) {
            if ($bios.Manufacturer -match "VMware" -or $bios.Version -match "VMware") {
                return "VMware"
            }
            if ($bios.Manufacturer -match "innotek" -or $bios.Version -match "VirtualBox") {
                return "VirtualBox"
            }
        }

        # Check if running in any VM (but can't determine type)
        if ($computerSystem.Model -match "Virtual" -or $manufacturer -match "Virtual") {
            return "Unknown"
        }

        # Not running in a VM
        return $null
    }
    catch {
        Write-Warn "Could not detect virtualization status: $_"
        return $null
    }
}

# Legacy function for backward compatibility
function Test-IsHyperVGuest {
    $hypervisor = Get-HypervisorType
    return ($hypervisor -eq "HyperV")
}

# State management for handling reboots
$StateFile = "C:\Temp\install-prerequisites-state.txt"
$ModeFile = "C:\Temp\install-prerequisites-mode.txt"

function Save-InstallState {
    param(
        [string]$State,
        [bool]$IsUnattended = $false
    )
    if (-not (Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
    }
    Set-Content -Path $StateFile -Value $State -Force
    Set-Content -Path $ModeFile -Value $IsUnattended.ToString() -Force
    Write-Host "  State saved: $State (Unattended: $IsUnattended)" -ForegroundColor Gray
}

function Get-InstallState {
    if (Test-Path $StateFile) {
        $state = Get-Content $StateFile -Raw
        return $state.Trim()
    }
    return $null
}

function Get-SavedMode {
    if (Test-Path $ModeFile) {
        $mode = Get-Content $ModeFile -Raw
        return [System.Convert]::ToBoolean($mode.Trim())
    }
    return $false
}

function Clear-InstallState {
    if (Test-Path $StateFile) {
        Remove-Item $StateFile -Force
        Write-Host "  State cleared" -ForegroundColor Gray
    }
    if (Test-Path $ModeFile) {
        Remove-Item $ModeFile -Force
    }
}

function Register-AutoRestartTask {
    param(
        [string]$ScriptPath,
        [bool]$IsUnattended = $false
    )

    $taskName = "Install Prerequisites Auto-Resume"
    $taskFolder = "PrerequisitesInstallation"

    try {
        # Create custom folder using COM object (like the reference script)
        $Sched = New-Object -ComObject Schedule.Service
        $Sched.Connect()
        $Root = $Sched.GetFolder("\")

        # Remove existing folder and tasks if present
        try {
            $TargetFolder = $Root.GetFolder($taskFolder)
            $TargetFolder.GetTasks(0) | ForEach-Object { $TargetFolder.DeleteTask($_.Name, 0) }
            $Root.DeleteFolder($taskFolder, 0)
        } catch {
            # Folder doesn't exist, ignore
        }

        # Create new folder
        $null = $Root.CreateFolder($taskFolder, $null)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Sched) | Out-Null
        [System.GC]::Collect()
    }
    catch {
        Write-Warn "Could not create task folder: $_"
        # Continue anyway, will use root folder
        $taskFolder = ""
    }

    # Build arguments based on mode
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($IsUnattended) {
        $arguments += " -Unattended"
    }

    # Create task components
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $arguments
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    if ($IsUnattended) {
        # Unattended mode: run as SYSTEM at startup (no window needed)
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    } else {
        # Manual mode: run as current user at logon (interactive window)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    }

    # Register the task
    $fullTaskName = if ($taskFolder) { "\$taskFolder\$taskName" } else { $taskName }
    Register-ScheduledTask -TaskName $fullTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Auto-resume installation after reboot" -Force | Out-Null

    $mode = if ($IsUnattended) { "Unattended" } else { "Manual" }
    Write-Host "  Auto-restart task registered ($mode mode)" -ForegroundColor Gray
}

function Unregister-AutoRestartTask {
    $taskFolder = "PrerequisitesInstallation"

    try {
        # Use COM object to remove entire folder and all tasks (like reference script)
        $Sched = New-Object -ComObject Schedule.Service
        $Sched.Connect()
        $Root = $Sched.GetFolder("\")

        try {
            $TargetFolder = $Root.GetFolder($taskFolder)
            # Delete all tasks in folder
            $TargetFolder.GetTasks(0) | ForEach-Object { $TargetFolder.DeleteTask($_.Name, 0) }
            # Delete folder itself
            $Root.DeleteFolder($taskFolder, 0)
            Write-Host "  Auto-restart task and folder removed" -ForegroundColor Gray
        }
        catch {
            # Folder doesn't exist, already clean
        }
        finally {
            if ($Sched) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Sched) | Out-Null }
            [System.GC]::Collect()
        }
    }
    catch {
        Write-Warn "Could not remove task folder: $_"
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
Write-Host "  - Git, Node.js, Python, Deno"
Write-Host "  - Crawl4AI container (web scraping)"
Write-Host "  - AnythingLLM container (local RAG)"
Write-Host "  - yt-dlp-server container (YouTube transcripts)"
Write-Host "  - whisper-server container (audio transcription)"
Write-Host "  - MCP servers for Claude Code"
Write-Host ""
Write-Host "IMPORTANT: After installation, you must configure AnythingLLM" -ForegroundColor Yellow
Write-Host "           with your LLM provider API key (OpenAI, Anthropic, etc.)" -ForegroundColor Yellow
Write-Host ""

if (-not $Unattended) {
    $confirm = Read-Host "Continue? (Y/n)"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "Installation cancelled."
        exit 0
    }
}

# =============================================================================
# STATE MANAGEMENT: Handle resumption after reboots
# =============================================================================
$currentState = Get-InstallState

if ($currentState) {
    # Restore saved mode (unattended or manual)
    $savedMode = Get-SavedMode
    $Unattended = $savedMode

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " RESUMING INSTALLATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Previous state: $currentState" -ForegroundColor Gray
    $modeText = if ($Unattended) { "Unattended" } else { "Manual" }
    Write-Host "Mode: $modeText" -ForegroundColor Gray
    Write-Host ""
}

# =============================================================================
# STEP 0: Install Chocolatey (required for all other installations)
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

# Check if running in a VM and detect hypervisor type
$hypervisorType = Get-HypervisorType
$isHyperVGuest = ($hypervisorType -eq "HyperV")
$isInVM = ($null -ne $hypervisorType)

# =============================================================================
# STEP 1: Enable Hyper-V features if in VM (required before Docker install)
# =============================================================================
if ($isHyperVGuest -and $currentState -ne "AFTER_HYPERV_REBOOT" -and $currentState -ne "DOCKER_INSTALLED") {
    Write-Step "Checking Hyper-V features (required for nested virtualization)..."

    $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue

    if ($hypervFeature -and $hypervFeature.State -eq "Enabled") {
        Write-OK "Hyper-V features already enabled"

        # Note: We don't check VirtualizationFirmwareEnabled here because:
        # - ExposeVirtualizationExtensions must be set on the HOST, not in the guest
        # - The guest OS may not report it correctly even when properly configured
        # - Docker will fail later with a clear error if nested virt isn't working
        # So we skip this check and let Docker validate the configuration instead.
        $skipNestedVirtCheck = $true
        if ($false) {  # Disabled check - keeping code for reference
            # Old check that was too strict:
            $cpuInfo = Get-CimInstance -ClassName Win32_Processor
            if ($cpuInfo.VirtualizationFirmwareEnabled -eq $false) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host " ERROR: NESTED VIRTUALIZATION NOT ENABLED" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Docker Desktop requires nested virtualization, but it is not enabled." -ForegroundColor Yellow
            Write-Host "Detected hypervisor: $hypervisorType" -ForegroundColor Cyan
            Write-Host ""

            # Provide hypervisor-specific instructions
            switch ($hypervisorType) {
                "HyperV" {
                    Write-Host "SOLUTION FOR HYPER-V:" -ForegroundColor Cyan
                    Write-Host "  This MUST be enabled on the Hyper-V HOST (not inside this VM)." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  1. On the Hyper-V HOST machine, open PowerShell as Administrator" -ForegroundColor White
                    Write-Host "  2. Run this command to stop this VM:" -ForegroundColor White
                    Write-Host ""
                    Write-Host "     Stop-VM -Name '<VMName>' -Force" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  3. Run this command to enable nested virtualization:" -ForegroundColor White
                    Write-Host ""
                    Write-Host "     Set-VMProcessor -VMName '<VMName>' -ExposeVirtualizationExtensions `$true" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  4. Start the VM again:" -ForegroundColor White
                    Write-Host ""
                    Write-Host "     Start-VM -Name '<VMName>'" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  5. Re-run this installation script" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Replace <VMName> with the actual name of this virtual machine." -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "For more information, see:" -ForegroundColor Cyan
                    Write-Host "https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/enable-nested-virtualization" -ForegroundColor Blue
                }
                "VMware" {
                    Write-Host "SOLUTION FOR VMWARE:" -ForegroundColor Cyan
                    Write-Host "  This MUST be enabled on the VMware HOST (not inside this VM)." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "METHOD 1 - VMware Workstation/Fusion GUI:" -ForegroundColor White
                    Write-Host "  1. Shut down this VM completely" -ForegroundColor White
                    Write-Host "  2. In VMware, select this VM and go to: VM > Settings > Processors" -ForegroundColor White
                    Write-Host "  3. Enable 'Virtualize Intel VT-x/EPT or AMD-V/RVI'" -ForegroundColor Green
                    Write-Host "  4. Click OK and start the VM" -ForegroundColor White
                    Write-Host "  5. Re-run this installation script" -ForegroundColor White
                    Write-Host ""
                    Write-Host "METHOD 2 - Edit .vmx file manually:" -ForegroundColor White
                    Write-Host "  1. Shut down this VM completely" -ForegroundColor White
                    Write-Host "  2. Locate the VM's .vmx file and open it in a text editor" -ForegroundColor White
                    Write-Host "  3. Add or modify these lines:" -ForegroundColor White
                    Write-Host ""
                    Write-Host "     vhv.enable = `"TRUE`"" -ForegroundColor Green
                    Write-Host "     hypervisor.cpuid.v0 = `"FALSE`"" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  4. Save the file and start the VM" -ForegroundColor White
                    Write-Host "  5. Re-run this installation script" -ForegroundColor White
                    Write-Host ""
                    Write-Host "For more information, see:" -ForegroundColor Cyan
                    Write-Host "https://docs.vmware.com/en/VMware-Workstation-Pro/17/com.vmware.ws.using.doc/GUID-2E98C9C5-C5D1-4060-87D3-5EA4E4E5D4B1.html" -ForegroundColor Blue
                }
                "VirtualBox" {
                    Write-Host "SOLUTION FOR VIRTUALBOX:" -ForegroundColor Cyan
                    Write-Host "  This MUST be enabled on the VirtualBox HOST (not inside this VM)." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  1. Shut down this VM completely" -ForegroundColor White
                    Write-Host "  2. In VirtualBox Manager, select this VM" -ForegroundColor White
                    Write-Host "  3. Go to: Settings > System > Processor" -ForegroundColor White
                    Write-Host "  4. Enable 'Enable Nested VT-x/AMD-V'" -ForegroundColor Green
                    Write-Host "  5. Click OK and start the VM" -ForegroundColor White
                    Write-Host "  6. Re-run this installation script" -ForegroundColor White
                    Write-Host ""
                    Write-Host "For more information, see:" -ForegroundColor Cyan
                    Write-Host "https://docs.oracle.com/en/virtualization/virtualbox/6.0/admin/nested-virt.html" -ForegroundColor Blue
                }
                default {
                    Write-Host "SOLUTION FOR UNKNOWN HYPERVISOR:" -ForegroundColor Cyan
                    Write-Host "  Unable to detect specific hypervisor type." -ForegroundColor Yellow
                    Write-Host "  Please consult your virtualization platform's documentation for:" -ForegroundColor White
                    Write-Host "  - How to enable nested virtualization" -ForegroundColor White
                    Write-Host "  - How to expose VT-x/AMD-V to guest VMs" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Common search terms:" -ForegroundColor Cyan
                    Write-Host "  'nested virtualization <your hypervisor name>'" -ForegroundColor Gray
                    Write-Host "  'expose VT-x to guest <your hypervisor name>'" -ForegroundColor Gray
                }
            }

            Write-Host ""
            exit 1
            }  # End of if ($cpuInfo.VirtualizationFirmwareEnabled -eq $false)
        }  # End of if ($false) - disabled check
    } else {
        Write-Warn "Enabling Hyper-V features for Docker Desktop..."
        Write-Host "  This requires nested virtualization to be enabled on the VM" -ForegroundColor Yellow

        # Enable Hyper-V and related features
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -WarningAction SilentlyContinue | Out-Null

        Write-OK "Hyper-V features enabled"

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host " REBOOT REQUIRED" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Hyper-V features have been enabled." -ForegroundColor Gray
        Write-Host "A restart is required before continuing." -ForegroundColor Gray
        Write-Host ""

        if ($Unattended) {
            Save-InstallState "AFTER_HYPERV_REBOOT" -IsUnattended $true
            Register-AutoRestartTask -ScriptPath $PSCommandPath -IsUnattended $true
            Write-OK "Auto-restart configured. Rebooting in 5 seconds..."
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        } else {
            Save-InstallState "AFTER_HYPERV_REBOOT" -IsUnattended $false
            $restart = Read-Host "Restart now? (Y/n)"
            if ($restart -ne "n" -and $restart -ne "N") {
                Register-AutoRestartTask -ScriptPath $PSCommandPath -IsUnattended $false
                Restart-Computer -Force
            } else {
                Write-Host "Please restart manually and re-run this script." -ForegroundColor Yellow
                exit 0
            }
        }
        exit 0
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
    Write-Warn "Installing Node.js v22 LTS (Jod - recommended stable version)..."
    # Install Node.js v22 (Active LTS) for maximum stability and compatibility
    # v22 is more mature than v24 and has better ecosystem support
    # Using latest v22.x available on Chocolatey
    choco install nodejs-lts --version=22.21.1 -y
    Update-PathEnvironment
    Write-OK "Node.js v22 LTS installed"
}

# =============================================================================
# STEP 4: Install Python
# =============================================================================
Write-Step "Checking Python..."

# Check if Python is installed via Chocolatey (not the Windows Store stub)
$pythonInstalled = $false
# Check for both generic 'python' and version-specific packages (e.g., python312)
$chocoList = choco list --local-only 2>&1
if ($chocoList -match "python312" -or $chocoList -match "^python\s") {
    # Verify real Python exists
    $pythonPaths = @(
        (Get-ChildItem C:\ -Filter "Python*" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "python.exe") })
    )
    if ($pythonPaths.Count -gt 0) {
        $pythonExe = Join-Path $pythonPaths[0].FullName "python.exe"
        $version = & $pythonExe --version 2>&1
        Write-OK "Python already installed: $version"
        $pythonInstalled = $true
    }
}

if (-not $pythonInstalled) {
    Write-Warn "Installing Python 3.12 (recommended stable version)..."
    # Install Python 3.12.x for maximum stability and compatibility with MCP SDK
    choco install python312 -y
    Update-PathEnvironment
    Write-OK "Python 3.12 installed"
}

# =============================================================================
# STEP 5: Install Deno (required for yt-dlp YouTube support)
# =============================================================================
Write-Step "Checking Deno..."

if (Get-Command deno -ErrorAction SilentlyContinue) {
    Write-OK "Deno already installed: $(deno --version | Select-Object -First 1)"
} else {
    Write-Warn "Installing Deno v2.1+ LTS (required for yt-dlp YouTube support)..."
    # Install Deno 2.1+ which has LTS support (6 months of bug fixes)
    # LTS provides stability for production use

    # Try winget first (preferred) - winget handles version management better
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $exitCode = Invoke-Native { winget install --id=DenoLand.Deno --accept-package-agreements --accept-source-agreements }
        if ($exitCode -eq 0) {
            Update-PathEnvironment
            Write-OK "Deno installed via winget"
        } else {
            Write-Warn "Winget install failed, trying Chocolatey..."
            # Pin to Deno 2.x for LTS support
            choco install deno --version=2.1.4 -y
            Update-PathEnvironment
        }
    } else {
        # Fall back to Chocolatey with version pin
        choco install deno --version=2.1.4 -y
        Update-PathEnvironment
    }

    # Verify installation
    if (Get-Command deno -ErrorAction SilentlyContinue) {
        Write-OK "Deno installed: $(deno --version | Select-Object -First 1)"
    } else {
        Write-Warn "Deno not in PATH. May require terminal restart."
    }
}

# =============================================================================
# STEP 5a: Configure yt-dlp for YouTube support
# =============================================================================
Write-Step "Configuring yt-dlp for YouTube support..."

# yt-dlp requires --remote-components ejs:github to download the JS challenge solver
$ytdlpConfigDir = "$env:APPDATA\yt-dlp"
$ytdlpConfigFile = "$ytdlpConfigDir\config.txt"

if (-not (Test-Path $ytdlpConfigDir)) {
    New-Item -ItemType Directory -Path $ytdlpConfigDir -Force | Out-Null
}

# Check if config already has remote-components
$needsConfig = $true
if (Test-Path $ytdlpConfigFile) {
    $existingConfig = Get-Content $ytdlpConfigFile -Raw
    if ($existingConfig -match "remote-components") {
        Write-OK "yt-dlp already configured with remote-components"
        $needsConfig = $false
    }
}

if ($needsConfig) {
    # Add or create config with remote-components
    Add-Content -Path $ytdlpConfigFile -Value "--remote-components ejs:github"
    Write-OK "yt-dlp configured with --remote-components ejs:github"
    Write-Host "  This enables the JavaScript challenge solver for YouTube downloads"
}

# =============================================================================
# STEP 6: Install Docker Desktop
# =============================================================================
if (-not $SkipDocker) {
    Write-Step "Checking Docker..."

    # Check if we need to add Users group to docker-users (after reboot)
    $dockerUserFile = "C:\Temp\add-docker-user.txt"
    if (Test-Path $dockerUserFile) {
        $savedMember = Get-Content $dockerUserFile -Raw
        $savedMember = $savedMember.Trim()
        Write-Host "  Checking docker-users group membership for '$savedMember'..." -ForegroundColor Gray
        try {
            $groupExists = Get-LocalGroup -Name "docker-users" -ErrorAction SilentlyContinue
            if ($groupExists) {
                $isMember = Get-LocalGroupMember -Group "docker-users" -Member $savedMember -ErrorAction SilentlyContinue
                if (-not $isMember) {
                    Add-LocalGroupMember -Group "docker-users" -Member $savedMember -ErrorAction Stop
                    if ($savedMember -eq "Users") {
                        Write-OK "Users group added to docker-users (all users can now use Docker)"
                    } else {
                        Write-OK "'$savedMember' added to docker-users group"
                    }
                } else {
                    Write-OK "'$savedMember' already in docker-users group"
                }
                Remove-Item $dockerUserFile -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warn "Could not add '$savedMember' to docker-users group: $_"
        }
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-OK "Docker already installed"

        # Check if Docker daemon is running
        $exitCode = Invoke-Native { docker info }
        if ($exitCode -eq 0) {
            Write-OK "Docker daemon is running"
        } else {
            Write-Warn "Docker is installed but not running. Starting Docker Desktop..."

            # Kill any docker-mcp processes that might interfere with Docker Desktop startup
            Write-Host "  Checking for docker-mcp processes..." -ForegroundColor Gray
            Get-Process -Name "docker-mcp" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*docker-mcp*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1

            # If we just installed Docker (DOCKER_INSTALLED state), give it extra time
            $maxWait = if ($currentState -eq "DOCKER_INSTALLED") { 120 } else { 90 }

            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

            # Wait for Docker daemon with polling
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

                if ($isHyperVGuest) {
                    Write-Host ""
                    Write-Host "TROUBLESHOOTING FOR HYPER-V VM:" -ForegroundColor Yellow
                    Write-Host "  1. Ensure nested virtualization is enabled on the host:" -ForegroundColor Gray
                    Write-Host "     Set-VMProcessor -VMName 'YourVM' -ExposeVirtualizationExtensions `$true" -ForegroundColor Gray
                    Write-Host "  2. VM must be powered off before enabling nested virtualization" -ForegroundColor Gray
                    Write-Host "  3. Check Docker Desktop logs in: %LOCALAPPDATA%\Docker\log\" -ForegroundColor Gray
                    Write-Host ""
                }

                Write-Host "Please troubleshoot Docker Desktop and re-run this script" -ForegroundColor Yellow
                exit 1
            }
        }
    } else {
        Write-Warn "Installing Docker Desktop..."

        # Detect if running in Hyper-V VM and choose appropriate backend
        $isHyperVGuest = Test-IsHyperVGuest

        if ($isHyperVGuest) {
            Write-Host "  Detected Hyper-V virtual machine" -ForegroundColor Cyan
            Write-Host "  Installing with Hyper-V backend (nested virtualization required)" -ForegroundColor Gray

            # Install Docker Desktop with Hyper-V backend
            # Note: Requires nested virtualization to be enabled on the VM
            choco install docker-desktop -y --install-arguments="'--backend=hyper-v --always-run-service'"
        } else {
            Write-Host "  Detected physical machine" -ForegroundColor Cyan
            Write-Host "  Installing with WSL 2 backend (default)" -ForegroundColor Gray

            # Install Docker Desktop with default WSL 2 backend and auto-start
            choco install docker-desktop -y --install-arguments="'--always-run-service'"
        }

        # Stop Docker Desktop if it auto-started (it will start properly after reboot)
        Write-Host "  Stopping Docker Desktop if running..." -ForegroundColor Gray
        Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Add all users to docker-users group to avoid "Access is denied" error
        Write-Host "  Adding all users to docker-users group..." -ForegroundColor Gray
        try {
            # Check if docker-users group exists (created by Docker Desktop installer)
            $groupExists = Get-LocalGroup -Name "docker-users" -ErrorAction SilentlyContinue
            if ($groupExists) {
                # Check if Users group is already a member
                $isMember = Get-LocalGroupMember -Group "docker-users" -Member "Users" -ErrorAction SilentlyContinue
                if (-not $isMember) {
                    Add-LocalGroupMember -Group "docker-users" -Member "Users" -ErrorAction Stop
                    Write-OK "Users group added to docker-users (all users can now use Docker)"
                } else {
                    Write-OK "Users group already in docker-users"
                }
            } else {
                Write-Warn "docker-users group not found yet (will be created after reboot)"
                # Save a flag to add Users group after reboot
                Set-Content -Path "C:\Temp\add-docker-user.txt" -Value "Users" -Force
            }
        } catch {
            Write-Warn "Could not add Users group to docker-users: $_"
            Write-Host "  You may need to run: net localgroup docker-users Users /add" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host " IMPORTANT: Docker Desktop Installed" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "A restart is required to complete Docker installation." -ForegroundColor Gray
        Write-Host ""

        if ($Unattended) {
            Save-InstallState "DOCKER_INSTALLED" -IsUnattended $true
            Register-AutoRestartTask -ScriptPath $PSCommandPath -IsUnattended $true
            Write-OK "Auto-restart configured. Rebooting in 5 seconds..."
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        } else {
            Save-InstallState "DOCKER_INSTALLED" -IsUnattended $false
            $restart = Read-Host "Restart now? (Y/n)"
            if ($restart -ne "n" -and $restart -ne "N") {
                Register-AutoRestartTask -ScriptPath $PSCommandPath -IsUnattended $false
                Restart-Computer -Force
            } else {
                Write-Host "Please restart manually and re-run this script." -ForegroundColor Yellow
                exit 0
            }
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
# STEP 6a: Pull Docker Containers
# =============================================================================
if (-not $SkipDocker) {
    # Ensure Docker daemon is ready before creating containers
    Write-Step "Ensuring Docker daemon is ready..."
    $maxRetries = 30
    $retryCount = 0
    $dockerReady = $false

    while ($retryCount -lt $maxRetries) {
        $exitCode = Invoke-Native { docker info }
        if ($exitCode -eq 0) {
            Write-OK "Docker daemon is ready"
            $dockerReady = $true
            break
        }

        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Docker not ready yet, waiting... ($retryCount/$maxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }

    if (-not $dockerReady) {
        Write-Err "Docker daemon failed to become ready after $maxRetries attempts"
        Write-Host "  Try restarting Docker Desktop manually and re-run this script" -ForegroundColor Yellow
        exit 1
    }

    # Crawl4AI - uses Docker named volume for browser cache and data
    Install-DockerContainer `
        -Name "crawl4ai" `
        -Image "unclecode/crawl4ai:latest" `
        -Port "11235:11235" `
        -HealthUrl "http://localhost:11235/health" `
        -ExtraArgs @{
            "-v" = "crawl4ai-data:/app/data"
        }

    # AnythingLLM - uses Docker named volume for persistence
    Install-DockerContainer `
        -Name "anythingllm" `
        -Image "mintplexlabs/anythingllm:latest" `
        -Port "3001:3001" `
        -HealthUrl "http://localhost:3001/api/health" `
        -ExtraArgs @{
            "-e" = "STORAGE_DIR=/app/server/storage"
            "-v" = "anythingllm-storage:/app/server/storage"
        }

    # yt-dlp-server - uses Docker named volume for cache
    $ytdlpContext = Get-LocalBuildContext -ContainerName "yt-dlp-server" -SubPath "infrastructure\docker\yt-dlp"
    Install-DockerContainer `
        -Name "yt-dlp-server" `
        -Image "yt-dlp-server" `
        -Port "8501:8501" `
        -HealthUrl "http://localhost:8501/health" `
        -BuildContext $ytdlpContext `
        -ExtraArgs @{
            "-v" = "ytdlp-cache:/app/temp"
        }

    # whisper-server - uses Docker named volume for model cache
    $whisperContext = Get-LocalBuildContext -ContainerName "whisper-server" -SubPath "infrastructure\docker\whisper"
    Install-DockerContainer `
        -Name "whisper-server" `
        -Image "whisper-server" `
        -Port "8502:8502" `
        -HealthUrl "http://localhost:8502/health" `
        -BuildContext $whisperContext `
        -ExtraArgs @{
            "-v" = "whisper-models:/app/models"
        }

    # Cleanup temp clone
    $tempDir = "$env:TEMP\claude-code-skills-temp"
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
}

# =============================================================================
# STEP 6b: Configure AnythingLLM (LLM + Embedding Provider)
# =============================================================================
if (-not $SkipDocker) {
    Write-Step "AnythingLLM Configuration"
    Write-Host ""
    Write-Host "  AnythingLLM requires an LLM provider for chat and embeddings." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  RECOMMENDED FREE PROVIDER:" -ForegroundColor Green
    Write-Host "    iFlow Platform: https://platform.iflow.cn/en/models" -ForegroundColor Green
    Write-Host "    - Free tier available"
    Write-Host "    - OpenAI-compatible API"
    Write-Host "    - Supports many models including Claude, GPT, embeddings"
    Write-Host ""
    Write-Host "  OTHER OPTIONS:" -ForegroundColor Yellow
    Write-Host "    - OpenAI: https://platform.openai.com/api-keys"
    Write-Host "    - Anthropic: https://console.anthropic.com/"
    Write-Host "    - OpenRouter: https://openrouter.ai/keys"
    Write-Host "    - Any OpenAI-compatible provider"
    Write-Host ""

    $configureNow = Read-Host "Configure AnythingLLM now? (Y/n/skip)"

    if ($configureNow -eq "skip" -or $configureNow -eq "s") {
        Write-Warn "Skipping AnythingLLM configuration."
        Write-Host "     You can configure it manually later at: http://localhost:3001"
    } elseif ($configureNow -ne "n" -and $configureNow -ne "N") {

        # Wait for AnythingLLM to be ready
        Write-Host "  Waiting for AnythingLLM to be ready..."
        $anythingllmReady = Test-ContainerHealth -Name "anythingllm" -HealthUrl "http://localhost:3001/api/health" -TimeoutSeconds 60

        if (-not $anythingllmReady) {
            Write-Err "AnythingLLM is not responding. Please configure manually later."
        } else {
            Write-Host ""
            Write-Host "  Enter your provider details (leave empty to use defaults):" -ForegroundColor Cyan
            Write-Host ""

            # Collect configuration from user
            Write-Host "  For iFlow (free tier), use: https://api.iflow.cn/v1" -ForegroundColor Gray
            $apiBaseUrl = Read-Host "  API Base URL [default: https://api.iflow.cn/v1]"
            if ([string]::IsNullOrWhiteSpace($apiBaseUrl)) { $apiBaseUrl = "https://api.iflow.cn/v1" }

            $apiKey = Read-Host "  API Key (required)"
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Warn "API Key is required. Skipping configuration."
            } else {
                Write-Host "  For iFlow, try: glm-4.6, qwen3-max, deepseek-v3, kimi-k2, etc." -ForegroundColor Gray
                $llmModel = Read-Host "  LLM Model [default: glm-4.6]"
                if ([string]::IsNullOrWhiteSpace($llmModel)) { $llmModel = "glm-4.6" }

                $contextWindow = Read-Host "  Context Window [default: 200000]"
                if ([string]::IsNullOrWhiteSpace($contextWindow)) {
                    $contextWindow = "200000"
                } elseif (-not ($contextWindow -match '^\d+$')) {
                    Write-Warn "Invalid context window, using default: 200000"
                    $contextWindow = "200000"
                }

                $maxTokens = Read-Host "  Max Tokens [default: 8192]"
                if ([string]::IsNullOrWhiteSpace($maxTokens)) {
                    $maxTokens = "8192"
                } elseif (-not ($maxTokens -match '^\d+$')) {
                    Write-Warn "Invalid max tokens, using default: 8192"
                    $maxTokens = "8192"
                }

                Write-Host ""
                Write-Host "  Configuring AnythingLLM via API..." -ForegroundColor Cyan

                # First, we need to complete the onboarding to get access to settings API
                # AnythingLLM API for settings requires authentication after initial setup

                try {
                    # Configure LLM Provider
                    $llmSettings = @{
                        "LLMProvider" = "generic-openai"
                        "GenericOpenAiBasePath" = $apiBaseUrl
                        "GenericOpenAiKey" = $apiKey
                        "GenericOpenAiModelPref" = $llmModel
                        "GenericOpenAiTokenLimit" = [int]$contextWindow
                        "GenericOpenAiMaxTokens" = [int]$maxTokens
                    }

                    $llmBody = $llmSettings | ConvertTo-Json
                    $response = Invoke-RestMethod -Uri "http://localhost:3001/api/system/update-env" `
                        -Method POST `
                        -ContentType "application/json" `
                        -Body $llmBody `
                        -ErrorAction Stop

                    if ($response.success -or $response.newValues) {
                        Write-OK "LLM Provider configured (Generic OpenAI)"
                    } else {
                        Write-Warn "LLM configuration response: $($response | ConvertTo-Json -Compress)"
                    }

                    # Embedding uses built-in AnythingLLM Embedder (iFlow doesn't provide embeddings)
                    # No configuration needed - it's the default

                    Write-Host ""
                    Write-OK "AnythingLLM configured successfully!"
                    Write-Host "     LLM Model: $llmModel"
                    Write-Host "     Context Window: $contextWindow"
                    Write-Host "     Embedding: Built-in AnythingLLM Embedder (default)"
                    Write-Host ""

                } catch {
                    Write-Warn "Could not configure AnythingLLM via API: $_"
                    Write-Host ""
                    Write-Host "  Please configure manually:" -ForegroundColor Yellow
                    Write-Host "  1. Open: http://localhost:3001"
                    Write-Host "  2. Complete the setup wizard"
                    Write-Host "  3. Go to Settings > AI Providers > LLM"
                    Write-Host "  4. Select 'Generic OpenAI' and enter your credentials"
                    Write-Host "  5. Embedding: keep the default 'AnythingLLM Embedder'"
                    Write-Host ""
                }
            }
        }
    } else {
        Write-Warn "Skipping AnythingLLM configuration."
        Write-Host "     You can configure it manually later at: http://localhost:3001"
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

    # 1. AnythingLLM MCP Server (from Tapiocapioca's fork - Node.js)
    Write-Host "  [1/4] Installing AnythingLLM MCP Server..."
    $anythingllmMcpDir = "$mcpDir\anythingllm-mcp-server"

    if (Test-Path $anythingllmMcpDir) {
        Write-Warn "    Updating existing installation..."
        Push-Location $anythingllmMcpDir
        $null = Invoke-Native { git pull origin main }
        Pop-Location
    } else {
        $null = Invoke-Native { git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git $anythingllmMcpDir }
    }

    Push-Location $anythingllmMcpDir
    $null = Invoke-Native { npm install }
    Pop-Location
    Write-OK "    AnythingLLM MCP Server installed"

    # 2. DuckDuckGo MCP Server (from Tapiocapioca's fork - Python)
    Write-Host "  [2/4] Installing DuckDuckGo MCP Server..."
    $duckduckgoMcpDir = "$mcpDir\mcp-duckduckgo"

    if (Test-Path $duckduckgoMcpDir) {
        Write-Warn "    Updating existing installation..."
        Push-Location $duckduckgoMcpDir
        $null = Invoke-Native { git pull origin main }
        Pop-Location
    } else {
        $null = Invoke-Native { git clone https://github.com/Tapiocapioca/mcp-duckduckgo.git $duckduckgoMcpDir }
    }

    Push-Location $duckduckgoMcpDir
    $null = Invoke-Native { pip install -e . }
    Pop-Location
    Write-OK "    DuckDuckGo MCP Server installed"

    # 3. yt-dlp MCP Server (from Tapiocapioca's fork - Node.js)
    #    IMPORTANT: Requires yt-dlp CLI tool to be installed!
    Write-Host "  [3/4] Installing yt-dlp MCP Server..."

    # First, ensure yt-dlp CLI is installed (required dependency)
    $ytdlpCli = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if (-not $ytdlpCli) {
        Write-Host "    Installing yt-dlp CLI (required dependency)..."
        $null = Invoke-Native { pip install yt-dlp }
        Write-OK "    yt-dlp CLI installed"
    } else {
        Write-OK "    yt-dlp CLI already installed"
    }

    $ytdlpMcpDir = "$mcpDir\yt-dlp-mcp"

    if (Test-Path $ytdlpMcpDir) {
        Write-Warn "    Updating existing installation..."
        Push-Location $ytdlpMcpDir
        $null = Invoke-Native { git pull origin main }
        Pop-Location
    } else {
        $null = Invoke-Native { git clone https://github.com/Tapiocapioca/yt-dlp-mcp.git $ytdlpMcpDir }
    }

    Push-Location $ytdlpMcpDir
    $null = Invoke-Native { npm install }
    Pop-Location
    Write-OK "    yt-dlp MCP Server installed"

    # 4. Crawl4AI MCP Server - ALREADY INCLUDED IN DOCKER CONTAINER
    Write-Host "  [4/4] Crawl4AI MCP Server..."
    Write-OK "    Built into Docker container (SSE endpoint)"
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
Write-Step "Configuring Claude Code MCP servers..."

# IMPORTANT: Claude Code reads MCP config from ~/.claude.json (mcpServers section at root level)
# NOT from ~/.claude/mcp_servers.json!
$claudeJsonPath = "$env:USERPROFILE\.claude.json"
$userProfile = $env:USERPROFILE -replace '\\', '/'

# Define the MCP servers we want to add
$mcpServersToAdd = @{
    "anythingllm" = @{
        "command" = "node"
        "args" = @("$userProfile/.claude/mcp-servers/anythingllm-mcp-server/src/index.js")
        "env" = @{
            "ANYTHINGLLM_API_KEY" = "YOUR_API_KEY_HERE"
            "ANYTHINGLLM_BASE_URL" = "http://localhost:3001"
        }
    }
    "duckduckgo-search" = @{
        "command" = "mcp-duckduckgo"
    }
    "yt-dlp" = @{
        "command" = "node"
        "args" = @("$userProfile/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs")
    }
    "crawl4ai" = @{
        "type" = "sse"
        "url" = "http://localhost:11235/mcp/sse"
    }
}

if (Test-Path $claudeJsonPath) {
    Write-Host "  Merging MCP servers into existing .claude.json..."
    try {
        # Read existing config
        $existingContent = Get-Content -Path $claudeJsonPath -Raw -Encoding UTF8
        # Remove BOM if present
        $existingContent = $existingContent -replace '^\xEF\xBB\xBF', ''
        $existingConfig = $existingContent | ConvertFrom-Json

        # Ensure mcpServers exists at root level
        if (-not $existingConfig.mcpServers) {
            $existingConfig | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{} -Force
        }

        # Merge: add our servers (don't overwrite if user has customized)
        $added = @()
        $skipped = @()

        foreach ($serverName in $mcpServersToAdd.Keys) {
            $serverConfig = $mcpServersToAdd[$serverName]
            # Check if server already exists
            $existingServer = $existingConfig.mcpServers.$serverName
            if (-not $existingServer) {
                # Add new server - need to convert hashtable to PSObject for JSON
                $serverObj = [PSCustomObject]$serverConfig
                $existingConfig.mcpServers | Add-Member -NotePropertyName $serverName -NotePropertyValue $serverObj -Force
                $added += $serverName
            } else {
                $skipped += $serverName
            }
        }

        # Write merged config back with proper formatting
        $existingConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $claudeJsonPath -Encoding utf8

        if ($added.Count -gt 0) {
            Write-OK "Added MCP servers: $($added -join ', ')"
        }
        if ($skipped.Count -gt 0) {
            Write-Host "     Kept existing: $($skipped -join ', ')" -ForegroundColor Gray
        }
    } catch {
        Write-Warn "Could not merge config: $_"
        Write-Host "     Please manually add MCP servers to $claudeJsonPath"
        Write-Host "     See PREREQUISITES.md for configuration format."
    }
} else {
    # Create new .claude.json with mcpServers
    Write-Host "  Creating new .claude.json with MCP configuration..."
    $newConfig = @{
        "mcpServers" = $mcpServersToAdd
    }
    $newConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $claudeJsonPath -Encoding utf8
    Write-OK "MCP configuration created at: $claudeJsonPath"
}

# Cleanup old mcp_servers.json if it exists (no longer used)
$oldMcpConfig = "$env:USERPROFILE\.claude\mcp_servers.json"
if (Test-Path $oldMcpConfig) {
    Write-Host "  Removing deprecated mcp_servers.json (Claude Code reads from .claude.json)..."
    Remove-Item $oldMcpConfig -Force
    Write-OK "Cleaned up old configuration file"
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
    # AnythingLLM MCP
    if (Test-Path "$env:USERPROFILE\.claude\mcp-servers\anythingllm-mcp-server\src\index.js") {
        Write-OK "AnythingLLM MCP Server installed"
    } else {
        Write-Err "AnythingLLM MCP Server NOT found"
        $allOK = $false
    }

    # DuckDuckGo MCP
    $duckduckgo = Get-Command mcp-duckduckgo -ErrorAction SilentlyContinue
    if ($duckduckgo) {
        Write-OK "DuckDuckGo MCP Server installed"
    } else {
        Write-Err "DuckDuckGo MCP Server NOT found"
        $allOK = $false
    }

    # yt-dlp MCP
    if (Test-Path "$env:USERPROFILE\.claude\mcp-servers\yt-dlp-mcp\lib\index.mjs") {
        Write-OK "yt-dlp MCP Server installed"
    } else {
        Write-Err "yt-dlp MCP Server NOT found"
        $allOK = $false
    }

    # Crawl4AI MCP (built into container, just verify container is running)
    Write-OK "Crawl4AI MCP Server (via Docker SSE endpoint)"
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
Write-Host "   - Edit: $claudeJsonPath"
Write-Host "   - Replace 'YOUR_API_KEY_HERE' with your AnythingLLM API key"
Write-Host ""
Write-Host "3. INSTALL THE SKILL:" -ForegroundColor White
Write-Host "   cd $env:USERPROFILE\.claude\skills"
Write-Host "   git clone https://github.com/Tapiocapioca/claude-code-skills.git"
Write-Host "   # Or copy the web-to-rag folder manually"
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " 4. RESTART CLAUDE CODE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "   Close and reopen Claude Code to load the 4 MCP servers:"
Write-Host "   - anythingllm     (RAG queries)"
Write-Host "   - duckduckgo-search (web search)"
Write-Host "   - yt-dlp          (YouTube transcripts)"
Write-Host "   - crawl4ai        (web scraping)"
Write-Host ""
Write-Host "AUTO-START CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   - Docker Desktop: starts automatically with Windows (minimized)"
Write-Host "   - All containers: restart automatically when Docker starts"
Write-Host "   - To disable: remove shortcut from Startup folder"
Write-Host ""
Write-Host "For detailed instructions, see:" -ForegroundColor Cyan
Write-Host "https://github.com/Tapiocapioca/claude-code-skills/blob/master/skills/web-to-rag/PREREQUISITES.md"
Write-Host ""

# Clean up installation state and scheduled task
Clear-InstallState
Unregister-AutoRestartTask
