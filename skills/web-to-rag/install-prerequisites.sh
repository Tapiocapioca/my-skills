#!/bin/bash
#
# Claude Code Skills - Prerequisites Installer (Linux/macOS)
#
# This script installs:
# - Docker (if not present)
# - Node.js (if not present)
# - Python (if not present)
# - Deno (JavaScript runtime for yt-dlp YouTube support)
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
WHITE='\033[1;37m'
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

# =============================================================================
# Docker Container Helper Functions
# =============================================================================

# Check if container exists (created, running or stopped)
container_exists() {
    local name=$1
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Check if container is currently running
container_running() {
    local name=$1
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Start container if stopped (idempotent)
start_container_if_stopped() {
    local name=$1
    if container_exists "$name" && ! container_running "$name"; then
        warn "Starting $name container..."
        docker start "$name" >/dev/null 2>&1
    fi
}

# Poll container health endpoint with timeout
test_container_health() {
    local name=$1
    local url=$2
    local max_attempts=${3:-30}
    local interval=${4:-2}

    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep $interval
        attempt=$((attempt + 1))
    done
    return 1
}

# Pull Docker image with visible progress
pull_docker_image() {
    local image=$1
    local image_name=$(echo "$image" | cut -d: -f1)

    # Check if image already exists locally
    if docker images -q "$image" 2>/dev/null | grep -q .; then
        ok "Image $image already available locally"
        return 0
    fi

    warn "Pulling $image from Docker Hub (this may take 5-10 minutes)..."
    echo "  Progress will be shown below. Please wait..."

    # Pull with visible progress (don't suppress output)
    if docker pull "$image"; then
        ok "$image pulled successfully"
        return 0
    else
        err "Failed to pull image $image"
        return 1
    fi
}

# Unified container installation function
install_docker_container() {
    local name=$1
    local image=$2
    local port_mapping=$3
    local health_url=$4
    shift 4
    local extra_args=("$@")

    # Check if container exists
    if container_exists "$name"; then
        ok "$name container exists"
        start_container_if_stopped "$name"
        return 0
    fi

    warn "Creating $name container..."

    # Create container with provided arguments
    if docker run -d \
        --name "$name" \
        -p "$port_mapping" \
        --restart unless-stopped \
        "${extra_args[@]}" \
        "$image" >/dev/null 2>&1; then

        ok "$name container created"

        # Test health if URL provided
        if [ -n "$health_url" ]; then
            echo "  Waiting for $name to become healthy..."
            if test_container_health "$name" "$health_url" 30 2; then
                ok "$name is healthy"
            else
                warn "$name may not be fully ready yet"
            fi
        fi

        return 0
    else
        err "Failed to create $name container"
        return 1
    fi
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
echo "  - Git, Node.js, Python, Deno"
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
    sudo apt-get install -y git curl wget unzip

    # Install Node.js (via NodeSource)
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    ok "Node.js installed: $(node --version)"

    # Install Python
    sudo apt-get install -y python3 python3-pip python3-venv
    ok "Python installed: $(python3 --version)"

elif [[ "$OS" == "redhat" ]]; then
    sudo yum install -y git curl wget unzip

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
# STEP 1b: Install Deno (required for yt-dlp YouTube support)
# =============================================================================
step "Checking Deno..."

if command -v deno &> /dev/null; then
    ok "Deno already installed: $(deno --version | head -1)"
else
    warn "Installing Deno (required for yt-dlp YouTube support)..."
    curl -fsSL https://deno.land/install.sh | sh

    # Add to PATH for current session
    export DENO_INSTALL="$HOME/.deno"
    export PATH="$DENO_INSTALL/bin:$PATH"

    if command -v deno &> /dev/null; then
        ok "Deno installed: $(deno --version | head -1)"
    else
        warn "Deno installed but not in PATH. Add to your shell profile:"
        echo '     export DENO_INSTALL="$HOME/.deno"'
        echo '     export PATH="$DENO_INSTALL/bin:$PATH"'
    fi
fi

# =============================================================================
# STEP 1c: Configure yt-dlp for YouTube support
# =============================================================================
step "Configuring yt-dlp for YouTube support..."

YTDLP_CONFIG_DIR="$HOME/.config/yt-dlp"
YTDLP_CONFIG_FILE="$YTDLP_CONFIG_DIR/config"

mkdir -p "$YTDLP_CONFIG_DIR"

if [ -f "$YTDLP_CONFIG_FILE" ] && grep -q "remote-components" "$YTDLP_CONFIG_FILE"; then
    ok "yt-dlp already configured with remote-components"
else
    echo "--remote-components ejs:github" >> "$YTDLP_CONFIG_FILE"
    ok "yt-dlp configured with --remote-components ejs:github"
    echo "     This enables the JavaScript challenge solver for YouTube downloads"
fi

# =============================================================================
# STEP 2: Install Docker
# =============================================================================
step "Checking Docker..."

if command -v docker &> /dev/null; then
    ok "Docker already installed"

    # Check if daemon is running with timeout
    echo "  Checking Docker daemon..."
    MAX_WAIT=90
    WAIT_INTERVAL=5
    elapsed=0

    while [ $elapsed -lt $MAX_WAIT ]; do
        if docker info &> /dev/null; then
            ok "Docker daemon is running"
            break
        fi

        if [ $elapsed -eq 0 ]; then
            warn "Docker daemon not responding, attempting to start..."

            if [[ "$OS" == "macos" ]]; then
                echo "  Opening Docker Desktop..."
                open -a Docker 2>/dev/null || true
            else
                echo "  Starting Docker service..."
                sudo systemctl start docker 2>/dev/null || true
            fi
        fi

        echo "  Still waiting for Docker daemon... (${elapsed}s/${MAX_WAIT}s)"
        sleep $WAIT_INTERVAL
        elapsed=$((elapsed + WAIT_INTERVAL))
    done

    # Final check
    if ! docker info &> /dev/null; then
        err "Docker daemon failed to start after ${MAX_WAIT}s"
        echo ""
        echo "Troubleshooting:"
        if [[ "$OS" == "macos" ]]; then
            echo "  1. Manually open Docker Desktop from Applications"
            echo "  2. Wait for Docker to fully start (whale icon in menu bar)"
            echo "  3. Re-run this script"
        else
            echo "  1. Check Docker service: sudo systemctl status docker"
            echo "  2. View logs: sudo journalctl -xeu docker"
            echo "  3. Try: sudo systemctl restart docker"
        fi
        exit 1
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
# STEP 3: Pre-pull Docker Images (Optimization)
# =============================================================================
step "Pre-downloading Docker images (speeds up container creation)..."

# Pre-pull all images in parallel for faster installation
pull_docker_image "unclecode/crawl4ai:latest" &
pull_docker_image "mintplexlabs/anythingllm:latest" &

# Wait for both pulls to complete
wait

ok "All Docker images downloaded"

# =============================================================================
# STEP 4: Create Docker Containers
# =============================================================================
step "Setting up Crawl4AI container..."
install_docker_container "crawl4ai" \
    "unclecode/crawl4ai:latest" \
    "11235:11235" \
    "http://localhost:11235/health" \
    -v crawl4ai-data:/app/data

step "Setting up AnythingLLM container..."

# Create storage directory with correct permissions before creating container
REAL_HOME=$(eval echo ~${SUDO_USER:-$USER} 2>/dev/null || echo "$HOME")
STORAGE_DIR="$REAL_HOME/.anythingllm/storage"

if ! container_exists "anythingllm"; then
    mkdir -p "$STORAGE_DIR"
    chmod 755 "$STORAGE_DIR"
    # AnythingLLM container runs as UID 1000, not root
    chown -R 1000:1000 "$REAL_HOME/.anythingllm" 2>/dev/null || true
fi

install_docker_container "anythingllm" \
    "mintplexlabs/anythingllm:latest" \
    "3001:3001" \
    "http://localhost:3001/api/ping" \
    -e STORAGE_DIR="/app/server/storage" \
    -v "$STORAGE_DIR:/app/server/storage"

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
        docker build -t yt-dlp-server "$YTDLP_DIR" 2>/dev/null
    else
        # Clone and build (stay in current directory to avoid getcwd issues)
        TEMP_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git "$TEMP_DIR" 2>/dev/null
        docker build -t yt-dlp-server "$TEMP_DIR/skills/web-to-rag/infrastructure/docker/yt-dlp" 2>/dev/null
        rm -rf "$TEMP_DIR"
    fi

    docker run -d \
        --name yt-dlp-server \
        -p 8501:8501 \
        -v ytdlp-cache:/app/temp \
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
        docker build -t whisper-server "$WHISPER_DIR" 2>/dev/null
    else
        # Clone and build (stay in current directory to avoid getcwd issues)
        TEMP_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git "$TEMP_DIR" 2>/dev/null
        docker build -t whisper-server "$TEMP_DIR/skills/web-to-rag/infrastructure/docker/whisper" 2>/dev/null
        rm -rf "$TEMP_DIR"
    fi

    docker run -d \
        --name whisper-server \
        -p 8502:8502 \
        -v whisper-models:/app/models \
        --restart unless-stopped \
        whisper-server

    ok "whisper-server container created"
fi

# Wait for containers to become healthy
step "Verifying container health..."

echo "  Checking Crawl4AI..."
if test_container_health "crawl4ai" "http://localhost:11235/health" 30 2; then
    ok "Crawl4AI is healthy"
else
    warn "Crawl4AI may not be fully ready yet"
fi

echo "  Checking AnythingLLM..."
if test_container_health "anythingllm" "http://localhost:3001/api/ping" 30 2; then
    ok "AnythingLLM is healthy"
else
    warn "AnythingLLM may not be fully ready yet"
fi

echo "  Checking yt-dlp-server..."
if test_container_health "yt-dlp-server" "http://localhost:8501/health" 30 2; then
    ok "yt-dlp-server is healthy"
else
    warn "yt-dlp-server may not be fully ready yet"
fi

echo "  Checking whisper-server..."
if test_container_health "whisper-server" "http://localhost:8502/health" 30 2; then
    ok "whisper-server is healthy"
else
    warn "whisper-server may not be fully ready yet"
fi

# =============================================================================
# STEP 4: Install MCP Servers
# =============================================================================
step "Installing MCP Servers..."

MCP_DIR="$HOME/.claude/mcp-servers"
mkdir -p "$MCP_DIR"

# 1. AnythingLLM MCP Server (from Tapiocapioca's fork - Node.js)
echo "  [1/4] Installing AnythingLLM MCP Server..."
ANYTHINGLLM_MCP_DIR="$MCP_DIR/anythingllm-mcp-server"

if [ -d "$ANYTHINGLLM_MCP_DIR" ]; then
    warn "    Updating existing installation..."
    cd "$ANYTHINGLLM_MCP_DIR"
    git pull origin main 2>/dev/null || true
else
    git clone https://github.com/Tapiocapioca/anythingllm-mcp-server.git "$ANYTHINGLLM_MCP_DIR"
fi

cd "$ANYTHINGLLM_MCP_DIR"
npm install 2>/dev/null
ok "    AnythingLLM MCP Server installed"

# 2. DuckDuckGo MCP Server (from Tapiocapioca's fork - Python)
echo "  [2/4] Installing DuckDuckGo MCP Server..."
DUCKDUCKGO_MCP_DIR="$MCP_DIR/mcp-duckduckgo"

if [ -d "$DUCKDUCKGO_MCP_DIR" ]; then
    warn "    Updating existing installation..."
    cd "$DUCKDUCKGO_MCP_DIR"
    git pull origin main 2>/dev/null || true
else
    git clone https://github.com/Tapiocapioca/mcp-duckduckgo.git "$DUCKDUCKGO_MCP_DIR"
fi

cd "$DUCKDUCKGO_MCP_DIR"
pip install -e . 2>/dev/null || pip3 install -e . 2>/dev/null
ok "    DuckDuckGo MCP Server installed"

# 3. yt-dlp MCP Server (from Tapiocapioca's fork - Node.js)
echo "  [3/4] Installing yt-dlp MCP Server..."

# First, ensure yt-dlp CLI is installed (required dependency)
if ! command -v yt-dlp &> /dev/null; then
    echo "    Installing yt-dlp CLI (required dependency)..."
    pip install yt-dlp 2>/dev/null || pip3 install yt-dlp 2>/dev/null
    ok "    yt-dlp CLI installed"
else
    ok "    yt-dlp CLI already installed"
fi

YTDLP_MCP_DIR="$MCP_DIR/yt-dlp-mcp"

if [ -d "$YTDLP_MCP_DIR" ]; then
    warn "    Updating existing installation..."
    cd "$YTDLP_MCP_DIR"
    git pull origin main 2>/dev/null || true
else
    git clone https://github.com/Tapiocapioca/yt-dlp-mcp.git "$YTDLP_MCP_DIR"
fi

cd "$YTDLP_MCP_DIR"
npm install 2>/dev/null
ok "    yt-dlp MCP Server installed"

# 4. Crawl4AI MCP Server - ALREADY INCLUDED IN DOCKER CONTAINER
echo "  [4/4] Crawl4AI MCP Server..."
ok "    Built into Docker container (SSE endpoint)"

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
# STEP 5: Configure AnythingLLM (LLM + Embedding Provider)
# =============================================================================
step "AnythingLLM Configuration"
echo ""
echo -e "  AnythingLLM requires an LLM provider for chat and embeddings."
echo ""
echo -e "  ${GREEN}RECOMMENDED FREE PROVIDER:${NC}"
echo -e "    iFlow Platform: https://platform.iflow.cn/en/models"
echo "    - Free tier available"
echo "    - OpenAI-compatible API"
echo "    - Supports many models including Claude, GPT, embeddings"
echo ""
echo -e "  ${YELLOW}OTHER OPTIONS:${NC}"
echo "    - OpenAI: https://platform.openai.com/api-keys"
echo "    - Anthropic: https://console.anthropic.com/"
echo "    - OpenRouter: https://openrouter.ai/keys"
echo "    - Any OpenAI-compatible provider"
echo ""

read -p "Configure AnythingLLM now? (Y/n/skip) " CONFIG_CHOICE

if [[ "$CONFIG_CHOICE" == "skip" ]] || [[ "$CONFIG_CHOICE" == "s" ]]; then
    warn "Skipping AnythingLLM configuration."
    echo "     You can configure it manually later at: http://localhost:3001"
elif [[ ! "$CONFIG_CHOICE" =~ ^[Nn]$ ]]; then
    # Wait for AnythingLLM to be ready
    echo "  Waiting for AnythingLLM to be ready..."
    ANYTHINGLLM_READY=false
    for i in {1..12}; do
        if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
            ANYTHINGLLM_READY=true
            break
        fi
        sleep 5
    done

    if [ "$ANYTHINGLLM_READY" = false ]; then
        err "AnythingLLM is not responding. Please configure manually later."
    else
        echo ""
        echo -e "  Enter your provider details (leave empty to use defaults):"
        echo ""
        echo -e "  ${CYAN}For iFlow (free tier), use: https://api.iflow.cn/v1${NC}"
        read -p "  API Base URL [default: https://api.iflow.cn/v1]: " API_BASE_URL
        API_BASE_URL=${API_BASE_URL:-"https://api.iflow.cn/v1"}

        read -p "  API Key (required): " API_KEY

        if [ -z "$API_KEY" ]; then
            warn "API Key is required. Skipping configuration."
        else
            echo -e "  ${CYAN}For iFlow, try: glm-4.6, qwen3-max, deepseek-v3, kimi-k2, etc.${NC}"
            read -p "  LLM Model [default: glm-4.6]: " LLM_MODEL
            LLM_MODEL=${LLM_MODEL:-"glm-4.6"}

            read -p "  Context Window [default: 200000]: " CONTEXT_WINDOW
            CONTEXT_WINDOW=${CONTEXT_WINDOW:-"200000"}

            read -p "  Max Tokens [default: 8192]: " MAX_TOKENS
            MAX_TOKENS=${MAX_TOKENS:-"8192"}

            echo ""
            echo -e "  Configuring AnythingLLM via API..."

            # Configure LLM Provider
            CONFIG_PAYLOAD=$(cat <<EOJSON
{
    "LLMProvider": "generic-openai",
    "GenericOpenAiBasePath": "$API_BASE_URL",
    "GenericOpenAiKey": "$API_KEY",
    "GenericOpenAiModelPref": "$LLM_MODEL",
    "GenericOpenAiTokenLimit": $CONTEXT_WINDOW,
    "GenericOpenAiMaxTokens": $MAX_TOKENS
}
EOJSON
)
            RESPONSE=$(curl -s -X POST http://localhost:3001/api/system/update-env \
                -H "Content-Type: application/json" \
                -d "$CONFIG_PAYLOAD")

            if echo "$RESPONSE" | grep -q "success\|newValues"; then
                ok "LLM Provider configured (Generic OpenAI)"
                echo ""
                ok "AnythingLLM configured successfully!"
                echo "     LLM Model: $LLM_MODEL"
                echo "     Context Window: $CONTEXT_WINDOW"
                echo "     Embedding: Built-in AnythingLLM Embedder (default)"
                echo ""
            else
                warn "Could not configure AnythingLLM via API."
                echo ""
                echo -e "  ${YELLOW}Please configure manually:${NC}"
                echo "  1. Open: http://localhost:3001"
                echo "  2. Complete the setup wizard"
                echo "  3. Go to Settings > AI Providers > LLM"
                echo "  4. Select 'Generic OpenAI' and enter your credentials"
                echo "  5. Embedding: keep the default 'AnythingLLM Embedder'"
                echo ""
            fi
        fi
    fi
else
    warn "Skipping AnythingLLM configuration."
    echo "     You can configure it manually later at: http://localhost:3001"
fi

# =============================================================================
# STEP 6: Create/Merge Claude Code MCP Configuration
# =============================================================================
step "Configuring Claude Code MCP servers..."

# IMPORTANT: Claude Code reads MCP config from ~/.claude.json (mcpServers section at root level)
CLAUDE_JSON_PATH="$HOME/.claude.json"

# Define MCP servers to add
declare -A MCP_SERVERS=(
    ["anythingllm"]='{"command":"node","args":["'$HOME'/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],"env":{"ANYTHINGLLM_API_KEY":"YOUR_API_KEY_HERE","ANYTHINGLLM_BASE_URL":"http://localhost:3001"}}'
    ["duckduckgo-search"]='{"command":"mcp-duckduckgo"}'
    ["yt-dlp"]='{"command":"node","args":["'$HOME'/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs"]}'
    ["crawl4ai"]='{"type":"sse","url":"http://localhost:11235/mcp/sse"}'
)

if [ -f "$CLAUDE_JSON_PATH" ]; then
    warn "MCP configuration file exists, merging new servers..."

    # Check if file has mcpServers section
    if ! grep -q '"mcpServers"' "$CLAUDE_JSON_PATH"; then
        # Add mcpServers section to existing file
        echo "  Adding mcpServers section..."

        # Use jq if available, otherwise manual JSON manipulation
        if command -v jq &> /dev/null; then
            jq '. + {"mcpServers": {}}' "$CLAUDE_JSON_PATH" > "$CLAUDE_JSON_PATH.tmp"
            mv "$CLAUDE_JSON_PATH.tmp" "$CLAUDE_JSON_PATH"
        else
            # Manual insertion before last }
            sed -i.bak '$s/}$/,"mcpServers":{}}/' "$CLAUDE_JSON_PATH"
        fi
    fi

    # Merge each server
    SERVERS_ADDED=0
    SERVERS_SKIPPED=0

    for server_name in "${!MCP_SERVERS[@]}"; do
        if grep -q "\"$server_name\"" "$CLAUDE_JSON_PATH"; then
            echo "  - $server_name: already configured (skipped)"
            SERVERS_SKIPPED=$((SERVERS_SKIPPED + 1))
        else
            echo "  - $server_name: adding..."

            if command -v jq &> /dev/null; then
                # Use jq for clean JSON manipulation
                jq ".mcpServers.\"$server_name\" = ${MCP_SERVERS[$server_name]}" "$CLAUDE_JSON_PATH" > "$CLAUDE_JSON_PATH.tmp"
                mv "$CLAUDE_JSON_PATH.tmp" "$CLAUDE_JSON_PATH"
            else
                # Manual JSON insertion (more fragile but works without jq)
                # Insert before closing } of mcpServers
                SERVER_JSON="${MCP_SERVERS[$server_name]}"
                sed -i.bak "/\"mcpServers\".*{/a\\
    \"$server_name\": $SERVER_JSON," "$CLAUDE_JSON_PATH"
            fi

            SERVERS_ADDED=$((SERVERS_ADDED + 1))
        fi
    done

    ok "MCP configuration updated: $SERVERS_ADDED added, $SERVERS_SKIPPED skipped"

else
    # Create new file
    echo "  Creating new MCP configuration file..."

    cat > "$CLAUDE_JSON_PATH" << 'EOF'
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
    "yt-dlp": {
      "command": "node",
      "args": ["$HOME/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs"]
    },
    "crawl4ai": {
      "type": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
EOF

    # Replace $HOME placeholder with actual path
    sed -i.bak "s|\$HOME|$HOME|g" "$CLAUDE_JSON_PATH"
    rm -f "$CLAUDE_JSON_PATH.bak"

    ok "MCP configuration created at: $CLAUDE_JSON_PATH"
fi

# Cleanup old mcp_servers.json if it exists (no longer used)
OLD_MCP_CONFIG="$HOME/.claude/mcp_servers.json"
if [ -f "$OLD_MCP_CONFIG" ]; then
    echo "  Removing deprecated mcp_servers.json (Claude Code reads from .claude.json)..."
    rm -f "$OLD_MCP_CONFIG"
    ok "Cleaned up old configuration file"
fi

# =============================================================================
# STEP 7: Verify Installation
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

if command -v mcp-duckduckgo &> /dev/null; then
    ok "DuckDuckGo MCP Server installed"
else
    err "DuckDuckGo MCP Server NOT found"
    ALL_OK=false
fi

if [ -f "$HOME/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs" ]; then
    ok "yt-dlp MCP Server installed"
else
    err "yt-dlp MCP Server NOT found"
    ALL_OK=false
fi

# Check Deno
if command -v deno &> /dev/null; then
    ok "Deno installed (yt-dlp YouTube support)"
else
    warn "Deno NOT found (yt-dlp YouTube may not work)"
fi

# Check yt-dlp CLI
if command -v yt-dlp &> /dev/null; then
    ok "yt-dlp CLI installed"
else
    warn "yt-dlp CLI NOT found"
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
echo "   - Edit: $CLAUDE_JSON_PATH"
echo "   - Replace 'YOUR_API_KEY_HERE' with your AnythingLLM API key"
echo ""
echo -e "3. ${WHITE}INSTALL THE SKILL:${NC}"
echo "   cd ~/.claude/skills"
echo "   git clone https://github.com/Tapiocapioca/claude-code-skills.git"
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW} 4. RESTART CLAUDE CODE${NC}"
echo -e "${YELLOW}========================================${NC}"
echo "   Close and reopen Claude Code to load the 4 MCP servers:"
echo "   - anythingllm     (RAG queries)"
echo "   - duckduckgo-search (web search)"
echo "   - yt-dlp          (YouTube transcripts)"
echo "   - crawl4ai        (web scraping)"
echo ""
echo -e "${CYAN}For detailed instructions, see:${NC}"
echo "https://github.com/Tapiocapioca/claude-code-skills/blob/master/skills/web-to-rag/PREREQUISITES.md"
echo ""
