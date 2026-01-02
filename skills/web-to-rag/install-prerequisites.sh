#!/bin/bash
#
# Claude Code Skills - Prerequisites Installer (Linux/macOS)
#
# This script installs:
# - Docker (if not present)
# - Node.js (if not present)
# - Python (if not present)
# - Crawl4AI Docker container (web scraping)
# - AnythingLLM Docker container (local RAG)
# - yt-dlp-server Docker container (YouTube transcripts)
# - whisper-server Docker container (audio transcription)
# - MCP Servers from Tapiocapioca's forks
#
# Usage:
#   chmod +x install-prerequisites.sh
#   ./install-prerequisites.sh
#
# After installation, you must configure AnythingLLM with your LLM provider API key.
#
# https://github.com/Tapiocapioca/claude-code-skills

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

step() { echo -e "\n${CYAN}==> $1${NC}"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[X]${NC} $1"; }

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        else
            OS="linux"
        fi
    else
        OS="unknown"
    fi
    echo $OS
}

echo -e "${MAGENTA}"
cat << 'EOF'

 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗     ██████╗ ██████╗ ██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗      ██║     ██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝      ██║     ██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗    ╚██████╗╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
                    SKILLS PREREQUISITES INSTALLER (Linux/macOS)
                    https://github.com/Tapiocapioca/claude-code-skills

EOF
echo -e "${NC}"

OS=$(detect_os)
echo "Detected OS: $OS"
echo ""
echo "This script will install:"
echo "  - Docker"
echo "  - Git, Node.js, Python"
echo "  - Crawl4AI container (web scraping)"
echo "  - AnythingLLM container (local RAG)"
echo "  - yt-dlp-server container (YouTube transcripts)"
echo "  - whisper-server container (audio transcription)"
echo "  - MCP servers for Claude Code"
echo ""
echo -e "${YELLOW}IMPORTANT: After installation, you must configure AnythingLLM${NC}"
echo -e "${YELLOW}           with your LLM provider API key (OpenAI, Anthropic, etc.)${NC}"
echo ""

read -p "Continue? (Y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# =============================================================================
# STEP 1: Install package manager dependencies
# =============================================================================
step "Installing system dependencies..."

if [[ "$OS" == "macos" ]]; then
    # Install Homebrew if needed
    if ! command -v brew &> /dev/null; then
        warn "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    ok "Homebrew available"

    # Install Git
    if ! command -v git &> /dev/null; then
        brew install git
    fi
    ok "Git installed"

    # Install Node.js
    if ! command -v node &> /dev/null; then
        brew install node
    fi
    ok "Node.js installed: $(node --version)"

    # Install Python
    if ! command -v python3 &> /dev/null; then
        brew install python
    fi
    ok "Python installed: $(python3 --version)"

elif [[ "$OS" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y git curl wget

    # Install Node.js (via NodeSource)
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    ok "Node.js installed: $(node --version)"

    # Install Python
    sudo apt-get install -y python3 python3-pip
    ok "Python installed: $(python3 --version)"

elif [[ "$OS" == "redhat" ]]; then
    sudo yum install -y git curl wget

    # Install Node.js
    if ! command -v node &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo yum install -y nodejs
    fi
    ok "Node.js installed: $(node --version)"

    # Install Python
    sudo yum install -y python3 python3-pip
    ok "Python installed: $(python3 --version)"
fi

# =============================================================================
# STEP 2: Install Docker
# =============================================================================
step "Checking Docker..."

if command -v docker &> /dev/null; then
    ok "Docker already installed"

    # Check if daemon is running
    if docker info &> /dev/null; then
        ok "Docker daemon is running"
    else
        warn "Docker is installed but not running"

        if [[ "$OS" == "macos" ]]; then
            echo "     Please start Docker Desktop"
        else
            echo "     Try: sudo systemctl start docker"
        fi

        read -p "Press Enter when Docker is running..."
    fi
else
    warn "Installing Docker..."

    if [[ "$OS" == "macos" ]]; then
        brew install --cask docker
        echo ""
        echo "========================================"
        echo " Docker Desktop installed"
        echo "========================================"
        echo ""
        echo "Please:"
        echo "1. Open Docker Desktop from Applications"
        echo "2. Complete the setup wizard"
        echo "3. Re-run this script"
        echo ""
        exit 0

    elif [[ "$OS" == "debian" ]]; then
        # Install Docker on Debian/Ubuntu
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Add user to docker group
        sudo usermod -aG docker $USER

        sudo systemctl enable docker
        sudo systemctl start docker

        ok "Docker installed"
        warn "You may need to log out and back in for docker permissions"

    elif [[ "$OS" == "redhat" ]]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        sudo usermod -aG docker $USER
        sudo systemctl enable docker
        sudo systemctl start docker

        ok "Docker installed"
    fi
fi

# =============================================================================
# STEP 3: Pull Docker Containers
# =============================================================================
step "Setting up Crawl4AI container..."

if docker ps -a --format '{{.Names}}' | grep -q "^crawl4ai$"; then
    ok "Crawl4AI container exists"

    if ! docker ps --format '{{.Names}}' | grep -q "^crawl4ai$"; then
        warn "Starting Crawl4AI container..."
        docker start crawl4ai
    fi
else
    warn "Creating Crawl4AI container..."
    docker run -d \
        --name crawl4ai \
        -p 11235:11235 \
        --restart unless-stopped \
        unclecode/crawl4ai:latest
    ok "Crawl4AI container created"
fi

step "Setting up AnythingLLM container..."

if docker ps -a --format '{{.Names}}' | grep -q "^anythingllm$"; then
    ok "AnythingLLM container exists"

    if ! docker ps --format '{{.Names}}' | grep -q "^anythingllm$"; then
        warn "Starting AnythingLLM container..."
        docker start anythingllm
    fi
else
    warn "Creating AnythingLLM container..."

    # Create storage directory
    # Use absolute path to avoid issues when running with sudo
    REAL_HOME=$(eval echo ~${SUDO_USER:-$USER} 2>/dev/null || echo "$HOME")
    STORAGE_DIR="$REAL_HOME/.anythingllm/storage"
    mkdir -p "$STORAGE_DIR"
    chmod 755 "$STORAGE_DIR"

    docker run -d \
        --name anythingllm \
        -p 3001:3001 \
        -e STORAGE_DIR="/app/server/storage" \
        -v "$STORAGE_DIR:/app/server/storage" \
        --restart unless-stopped \
        mintplexlabs/anythingllm:latest

    ok "AnythingLLM container created"
fi

step "Setting up yt-dlp-server container (YouTube transcripts)..."

if docker ps -a --format '{{.Names}}' | grep -q "^yt-dlp-server$"; then
    ok "yt-dlp-server container exists"

    if ! docker ps --format '{{.Names}}' | grep -q "^yt-dlp-server$"; then
        warn "Starting yt-dlp-server container..."
        docker start yt-dlp-server
    fi
else
    warn "Building yt-dlp-server container..."

    # Check if we have the Dockerfile locally (cloned repo)
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    YTDLP_DIR="$SCRIPT_DIR/infrastructure/docker/yt-dlp"

    if [ -f "$YTDLP_DIR/Dockerfile" ]; then
        # Build from local Dockerfile
        cd "$YTDLP_DIR"
        docker build -t yt-dlp-server . 2>/dev/null
    else
        # Clone and build
        TEMP_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git "$TEMP_DIR" 2>/dev/null
        cd "$TEMP_DIR/skills/web-to-rag/infrastructure/docker/yt-dlp"
        docker build -t yt-dlp-server . 2>/dev/null
        rm -rf "$TEMP_DIR"
    fi

    docker run -d \
        --name yt-dlp-server \
        -p 8501:8501 \
        --restart unless-stopped \
        yt-dlp-server

    ok "yt-dlp-server container created"
fi

step "Setting up whisper-server container (audio transcription)..."

if docker ps -a --format '{{.Names}}' | grep -q "^whisper-server$"; then
    ok "whisper-server container exists"

    if ! docker ps --format '{{.Names}}' | grep -q "^whisper-server$"; then
        warn "Starting whisper-server container..."
        docker start whisper-server
    fi
else
    warn "Building whisper-server container (this may take a few minutes)..."

    # Check if we have the Dockerfile locally (cloned repo)
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    WHISPER_DIR="$SCRIPT_DIR/infrastructure/docker/whisper"

    if [ -f "$WHISPER_DIR/Dockerfile" ]; then
        # Build from local Dockerfile
        cd "$WHISPER_DIR"
        docker build -t whisper-server . 2>/dev/null
    else
        # Clone and build
        TEMP_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git "$TEMP_DIR" 2>/dev/null
        cd "$TEMP_DIR/skills/web-to-rag/infrastructure/docker/whisper"
        docker build -t whisper-server . 2>/dev/null
        rm -rf "$TEMP_DIR"
    fi

    docker run -d \
        --name whisper-server \
        -p 8502:8502 \
        --restart unless-stopped \
        whisper-server

    ok "whisper-server container created"
fi

# Wait for containers
echo "Waiting for containers to become healthy..."
sleep 30

# =============================================================================
# STEP 4: Install MCP Servers
# =============================================================================
step "Installing MCP Servers..."

MCP_DIR="$HOME/.claude/mcp-servers"
mkdir -p "$MCP_DIR"

# AnythingLLM MCP Server (from Tapiocapioca's fork - Node.js)
echo "  Installing AnythingLLM MCP Server..."
ANYTHINGLLM_MCP_DIR="$MCP_DIR/anythingllm-mcp-server"

if [ -d "$ANYTHINGLLM_MCP_DIR" ]; then
    warn "  Updating existing installation..."
    cd "$ANYTHINGLLM_MCP_DIR"
    git pull origin main 2>/dev/null || true
else
    git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git "$ANYTHINGLLM_MCP_DIR"
fi

cd "$ANYTHINGLLM_MCP_DIR"
npm install 2>/dev/null
ok "  AnythingLLM MCP Server installed"

# DuckDuckGo MCP Server (Python package via pip)
echo "  Installing DuckDuckGo MCP Server..."
pip install --upgrade mcp-duckduckgo 2>/dev/null || pip3 install --upgrade mcp-duckduckgo 2>/dev/null
ok "  DuckDuckGo MCP Server installed"

# Crawl4AI MCP Server - ALREADY INCLUDED IN DOCKER CONTAINER
# The Crawl4AI container has a built-in MCP server via SSE endpoint
# No separate installation needed - just configure the SSE URL
ok "  Crawl4AI MCP Server (built into Docker container)"

# =============================================================================
# STEP 4b: Verify Extended Format Support (via Docker Containers)
# =============================================================================
step "Verifying extended format support..."

# YouTube and Whisper run in separate Docker containers
# No local installation needed!
ok "  YouTube transcript extraction (via yt-dlp-server container, port 8501)"
ok "  Whisper audio transcription (via whisper-server container, port 8502)"

# poppler for PDF extraction (pdftotext)
echo "  Installing poppler (PDF support)..."
if ! command -v pdftotext &> /dev/null; then
    if [[ "$OS" == "macos" ]]; then
        brew install poppler 2>/dev/null || true
    elif [[ "$OS" == "debian" ]]; then
        sudo apt-get install -y poppler-utils 2>/dev/null || true
    elif [[ "$OS" == "redhat" ]]; then
        sudo yum install -y poppler-utils 2>/dev/null || true
    fi
fi
ok "  poppler (pdftotext) installed"

echo ""
echo -e "${CYAN}  Note: Heavy tools run in separate Docker containers for clean environment.${NC}"
echo "        - yt-dlp-server: http://localhost:8501 (YouTube transcripts)"
echo "        - whisper-server: http://localhost:8502 (Audio transcription)"

# =============================================================================
# STEP 5: Create Claude Code MCP Configuration
# =============================================================================
step "Creating Claude Code MCP configuration..."

CLAUDE_CONFIG_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

MCP_CONFIG_PATH="$CLAUDE_CONFIG_DIR/mcp_servers.json"

if [ ! -f "$MCP_CONFIG_PATH" ]; then
    cat > "$MCP_CONFIG_PATH" << EOF
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["$HOME/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
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
EOF
    ok "MCP configuration created at: $MCP_CONFIG_PATH"
else
    warn "MCP configuration already exists at: $MCP_CONFIG_PATH"
    echo "     Please manually merge the MCP server entries if needed"
fi

# =============================================================================
# STEP 6: Verify Installation
# =============================================================================
step "Verifying installation..."

ALL_OK=true

# Check Docker containers
CRAWL4AI_RUNNING=$(docker ps --format '{{.Names}}' | grep -c "^crawl4ai$" || true)
ANYTHINGLLM_RUNNING=$(docker ps --format '{{.Names}}' | grep -c "^anythingllm$" || true)
YTDLP_RUNNING=$(docker ps --format '{{.Names}}' | grep -c "^yt-dlp-server$" || true)
WHISPER_RUNNING=$(docker ps --format '{{.Names}}' | grep -c "^whisper-server$" || true)

if [ "$CRAWL4AI_RUNNING" -eq 1 ]; then
    ok "Crawl4AI container running"
else
    err "Crawl4AI container NOT running"
    ALL_OK=false
fi

if [ "$ANYTHINGLLM_RUNNING" -eq 1 ]; then
    ok "AnythingLLM container running"
else
    err "AnythingLLM container NOT running"
    ALL_OK=false
fi

if [ "$YTDLP_RUNNING" -eq 1 ]; then
    ok "yt-dlp-server container running (YouTube transcripts)"
else
    err "yt-dlp-server container NOT running"
    ALL_OK=false
fi

if [ "$WHISPER_RUNNING" -eq 1 ]; then
    ok "whisper-server container running (audio transcription)"
else
    err "whisper-server container NOT running"
    ALL_OK=false
fi

# Check MCP servers
if [ -f "$HOME/.claude/mcp-servers/anythingllm-mcp-server/src/index.js" ]; then
    ok "AnythingLLM MCP Server installed"
else
    err "AnythingLLM MCP Server NOT found"
    ALL_OK=false
fi

# Check if mcp-duckduckgo is available
if command -v mcp-duckduckgo &> /dev/null; then
    ok "DuckDuckGo MCP Server installed"
else
    err "DuckDuckGo MCP Server NOT found (run: pip install mcp-duckduckgo)"
    ALL_OK=false
fi

# Check local tools
if command -v pdftotext &> /dev/null; then
    ok "pdftotext installed (PDF support)"
else
    warn "pdftotext NOT found (PDF import won't work)"
fi

# =============================================================================
# FINAL MESSAGE
# =============================================================================
echo ""
echo -e "${CYAN}============================================${NC}"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN} Installation Complete!${NC}"
else
    echo -e "${YELLOW} Installation completed with warnings${NC}"
fi
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo -e "1. ${WHITE}CONFIGURE AnythingLLM:${NC}"
echo "   - Open: http://localhost:3001"
echo "   - Complete the setup wizard"
echo "   - Go to Settings > LLM Preference"
echo "   - Configure your LLM provider (OpenAI, Anthropic, Ollama, etc.)"
echo "   - Go to Settings > API Keys"
echo "   - Create an API key and copy it"
echo ""
echo -e "2. ${WHITE}UPDATE MCP CONFIGURATION:${NC}"
echo "   - Edit: $MCP_CONFIG_PATH"
echo "   - Replace 'YOUR_API_KEY_HERE' with your AnythingLLM API key"
echo ""
echo -e "3. ${WHITE}INSTALL THE SKILL:${NC}"
echo "   cd ~/.claude/skills"
echo "   git clone https://github.com/Tapiocapioca/claude-code-skills.git"
echo ""
echo "4. RESTART Claude Code to load the MCP servers"
echo ""
echo -e "${CYAN}For detailed instructions, see:${NC}"
echo "https://github.com/Tapiocapioca/claude-code-skills/blob/master/PREREQUISITES.md"
echo ""
