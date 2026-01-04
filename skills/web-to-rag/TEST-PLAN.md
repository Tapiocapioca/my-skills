# Test Plan - VM Windows 11 Pulita

**Obiettivo:** Verificare che lo script `install-prerequisites.ps1` funzioni correttamente su una VM Windows 11 pulita (Hyper-V).

---

## 📋 Prerequisiti VM

Prima di iniziare, assicurati che la VM abbia:

- ✅ Windows 11 installato e aggiornato
- ✅ Connessione internet attiva (verificare con `ping google.com`)
- ✅ Almeno **10GB di spazio disco libero** (per Docker images)
- ✅ **8GB RAM** minimo (consigliato 16GB)
- ✅ Virtualizzazione abilitata in Hyper-V
- ✅ PowerShell 5.1+ (verificare con `$PSVersionTable`)

---

## 🎯 Baseline: Configurazione Funzionante (Sistema Host)

**Data verifica:** 2026-01-03

### ✅ Docker Containers (4/4 healthy)
```
NAMES            STATUS                 PORTS
whisper-server   Up 2 hours (healthy)   0.0.0.0:8502->8502/tcp
yt-dlp-server    Up 2 hours (healthy)   0.0.0.0:8501->8501/tcp
anythingllm      Up 2 hours (healthy)   0.0.0.0:3001->3001/tcp
crawl4ai         Up 2 hours (healthy)   0.0.0.0:11235->11235/tcp
```

### ✅ Docker Images
```
mintplexlabs/anythingllm:latest   4.02GB
unclecode/crawl4ai:latest         7.47GB
whisper-server:latest             1.55GB
yt-dlp-server:latest              306MB
```

### ✅ Docker Volumes (4/4)
```
anythingllm-storage   (RAG database, workspaces)
crawl4ai-data         (browser cache)
ytdlp-cache          (audio cache)
whisper-models       (Whisper models ~150MB)
```

### ✅ MCP Servers (3/3)
```
~/.claude/mcp-servers/anythingllm-mcp-server/  (Node.js)
~/.claude/mcp-servers/mcp-duckduckgo/          (Python)
~/.claude/mcp-servers/yt-dlp-mcp/              (Node.js)
```

### ✅ CLI Tools
```
mcp-duckduckgo    ✅ /c/Python311/Scripts/mcp-duckduckgo
deno              ✅ /c/Users/.../AppData/Local/Microsoft/WinGet/Links/deno
pdftotext         ✅ /mingw64/bin/pdftotext
```

### ✅ Health Endpoints
```bash
curl http://localhost:11235/health   # {"status":"ok","version":"0.5.1-d1"}
curl http://localhost:3001/api/health   # HTML (AnythingLLM web UI)
curl http://localhost:8501/health   # {"status":"ok","service":"yt-dlp-server"}
curl http://localhost:8502/health   # {"status":"ok","service":"whisper-server"}
```

### ✅ MCP Configuration (~/.claude.json)
```json
{
  "mcpServers": {
    "anythingllm": {
      "command": "node",
      "args": ["C:/Users/Tapiocapioca/.claude/mcp-servers/anythingllm-mcp-server/src/index.js"],
      "env": {
        "ANYTHINGLLM_API_KEY": "TZZAC6K-Q8K4DJ6-NBP90YN-DY52YAQ",
        "ANYTHINGLLM_BASE_URL": "http://localhost:3001"
      }
    },
    "duckduckgo-search": {
      "command": "mcp-duckduckgo"
    },
    "yt-dlp": {
      "command": "node",
      "args": ["C:/Users/Tapiocapioca/.claude/mcp-servers/yt-dlp-mcp/lib/index.mjs"]
    },
    "crawl4ai": {
      "type": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```

---

## 🧪 Test Steps

### **Step 1: Preparazione VM**

**Tempo stimato:** 5 minuti

1. **Avvia la VM Windows 11** in Hyper-V
2. **Verifica connessione internet:**
   ```powershell
   Test-NetConnection -ComputerName google.com -Port 443
   ```
3. **Verifica spazio disco:**
   ```powershell
   Get-PSDrive C | Select-Object Used,Free
   ```
   - Richiesto: almeno 10GB liberi
4. **Verifica versione PowerShell:**
   ```powershell
   $PSVersionTable.PSVersion
   ```
   - Richiesto: 5.1 o superiore

**✅ Checkpoint:** VM pronta, internet OK, spazio sufficiente

---

### **Step 2: Download e Esecuzione Script**

**Tempo stimato:** 30-45 minuti (dipende dalla velocità internet)

1. **Apri PowerShell come Amministratore** (tasto destro → "Esegui come amministratore")

2. **Crea directory di lavoro:**
   ```powershell
   New-Item -ItemType Directory -Path "C:\Temp\web-to-rag-test" -Force
   cd "C:\Temp\web-to-rag-test"
   ```

3. **Download dello script:**
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Tapiocapioca/claude-code-skills/master/skills/web-to-rag/install-prerequisites.ps1" -OutFile "install-prerequisites.ps1"
   ```

4. **Esegui lo script:**
   ```powershell
   .\install-prerequisites.ps1
   ```

5. **Interazioni richieste:**
   - Confermare installazione: `Y`
   - Configurare AnythingLLM: `Y`
     - API Base URL: `https://api.iflow.cn/v1` (o lascia vuoto per default)
     - API Key: **[inserisci la tua API key]**
     - LLM Model: `glm-4.6` (o lascia vuoto per default)
     - Context Window: `200000` (o lascia vuoto per default)
     - Max Tokens: `8192` (o lascia vuoto per default)

**⚠️ Note importanti:**
- Se Docker Desktop richiede riavvio, conferma e **riavvia la VM**
- Dopo il riavvio, **riesegui lo script** dalla Step 2.4
- L'installazione può richiedere 30-45 minuti per il download delle immagini Docker

**✅ Checkpoint:** Script completato senza errori, Docker avviato

---

### **Step 3: Verifica Installazione Docker**

**Tempo stimato:** 5 minuti

1. **Verifica Docker Desktop:**
   ```powershell
   docker --version
   docker info
   ```
   - Deve mostrare versione e informazioni senza errori

2. **Verifica containers in esecuzione:**
   ```powershell
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```
   - **Expected output:**
     ```
     NAMES            STATUS                 PORTS
     whisper-server   Up X minutes (healthy)  0.0.0.0:8502->8502/tcp
     yt-dlp-server    Up X minutes (healthy)  0.0.0.0:8501->8501/tcp
     anythingllm      Up X minutes (healthy)  0.0.0.0:3001->3001/tcp
     crawl4ai         Up X minutes (healthy)  0.0.0.0:11235->11235/tcp
     ```

3. **Verifica immagini Docker:**
   ```powershell
   docker images | Select-String -Pattern "crawl4ai|anythingllm|yt-dlp-server|whisper-server"
   ```
   - Devono essere presenti 4 immagini

4. **Verifica volumi Docker:**
   ```powershell
   docker volume ls | Select-String -Pattern "crawl4ai|anythingllm|ytdlp|whisper"
   ```
   - **Expected output:**
     ```
     anythingllm-storage
     crawl4ai-data
     ytdlp-cache
     whisper-models
     ```

**✅ Checkpoint:** 4 containers healthy, 4 volumi creati

---

### **Step 4: Test Health Endpoints**

**Tempo stimato:** 2 minuti

Esegui lo **script di verifica automatico** (creato nello Step 6):

```powershell
.\verify-installation.ps1
```

**Output atteso:**
```
✅ Crawl4AI: http://localhost:11235/health
✅ AnythingLLM: http://localhost:3001/api/health
✅ yt-dlp-server: http://localhost:8501/health
✅ whisper-server: http://localhost:8502/health
✅ mcp-duckduckgo: C:\Python311\Scripts\mcp-duckduckgo
✅ deno: C:\Users\...\AppData\Local\Microsoft\WinGet\Links\deno
✅ pdftotext: C:\Program Files\Git\mingw64\bin\pdftotext.exe

=== SUMMARY ===
7/7 checks passed
```

**In caso di errori:**
- Se un container non è healthy, controlla i log: `docker logs <container-name>`
- Se un health endpoint non risponde, attendi 1-2 minuti (containers potrebbero essere ancora in startup)
- Se `deno` non è trovato, chiudi e riapri PowerShell (PATH potrebbe non essere aggiornato)

**✅ Checkpoint:** Tutti gli health check passano

---

### **Step 5: Verifica MCP Servers**

**Tempo stimato:** 3 minuti

1. **Verifica directory MCP servers:**
   ```powershell
   ls "$env:USERPROFILE\.claude\mcp-servers"
   ```
   - **Expected output:**
     ```
     anythingllm-mcp-server
     mcp-duckduckgo
     yt-dlp-mcp
     ```

2. **Verifica comandi installati:**
   ```powershell
   # DuckDuckGo MCP
   where.exe mcp-duckduckgo

   # Deno (richiesto per yt-dlp)
   where.exe deno

   # pdftotext (per PDF)
   where.exe pdftotext
   ```
   - Tutti devono essere trovati

3. **Verifica configurazione MCP:**
   ```powershell
   Get-Content "$env:USERPROFILE\.claude.json" | ConvertFrom-Json | Select-Object -ExpandProperty mcpServers
   ```
   - Deve mostrare configurazione per: `anythingllm`, `duckduckgo-search`, `yt-dlp`, `crawl4ai`

4. **Sostituisci API key AnythingLLM:**
   ```powershell
   notepad "$env:USERPROFILE\.claude.json"
   ```
   - Cerca: `"ANYTHINGLLM_API_KEY": "YOUR_API_KEY_HERE"`
   - Sostituisci con la tua API key da http://localhost:3001 → Settings → API Keys

**✅ Checkpoint:** MCP servers installati, configurazione completa

---

### **Step 6: Verifica Auto-Start (Windows)**

**Tempo stimato:** 2 minuti

1. **Verifica shortcut Docker Desktop in Startup:**
   ```powershell
   Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Docker Desktop.lnk"
   ```
   - Deve restituire `True`

2. **Verifica restart policy containers:**
   ```powershell
   docker inspect crawl4ai anythingllm yt-dlp-server whisper-server --format='{{.Name}}: {{.HostConfig.RestartPolicy.Name}}'
   ```
   - **Expected output:**
     ```
     /crawl4ai: unless-stopped
     /anythingllm: unless-stopped
     /yt-dlp-server: unless-stopped
     /whisper-server: unless-stopped
     ```

3. **Test riavvio VM (opzionale):**
   - Riavvia la VM
   - Attendi 2-3 minuti per l'avvio di Docker Desktop
   - Verifica che i containers si riavvino automaticamente:
     ```powershell
     docker ps
     ```

**✅ Checkpoint:** Auto-start configurato correttamente

---

### **Step 7: Test End-to-End con Claude Code**

**Tempo stimato:** 10 minuti

1. **Installa Claude Code (se non già installato):**
   ```powershell
   npm install -g claude-code
   ```

2. **Installa la skill web-to-rag:**
   ```powershell
   cd "$env:USERPROFILE\.claude\skills"
   git clone https://github.com/Tapiocapioca/claude-code-skills.git
   ```

3. **Avvia Claude Code:**
   ```powershell
   claude
   ```

4. **Test MCP servers:**
   ```
   /mcp
   ```
   - Deve mostrare: `anythingllm`, `duckduckgo-search`, `yt-dlp`, `crawl4ai` (tutti ✅)

5. **Test skill web-to-rag:**
   ```
   Add FastAPI documentation to RAG
   ```
   - Claude dovrebbe:
     1. Usare Crawl4AI per scrapare la documentazione
     2. Usare AnythingLLM per salvare nel RAG
     3. Confermare l'importazione

6. **Query RAG:**
   ```
   What did I import into the RAG?
   ```
   - Claude dovrebbe interrogare AnythingLLM e rispondere con i documenti importati

**✅ Checkpoint:** Skill funzionante end-to-end

---

## 📊 Checklist Finale

Spunta ogni voce se il test è passato:

### Software Base
- [ ] Chocolatey installato
- [ ] Docker Desktop installato e funzionante
- [ ] Git installato
- [ ] Node.js installato
- [ ] Python installato
- [ ] Deno installato
- [ ] poppler (pdftotext) installato

### Docker Containers
- [ ] crawl4ai: running e healthy
- [ ] anythingllm: running e healthy
- [ ] yt-dlp-server: running e healthy
- [ ] whisper-server: running e healthy

### Docker Volumes
- [ ] crawl4ai-data creato
- [ ] anythingllm-storage creato
- [ ] ytdlp-cache creato
- [ ] whisper-models creato

### MCP Servers
- [ ] anythingllm-mcp-server: installato e configurato
- [ ] mcp-duckduckgo: installato e funzionante
- [ ] yt-dlp-mcp: installato e configurato
- [ ] crawl4ai: SSE endpoint configurato

### Health Checks
- [ ] http://localhost:11235/health (Crawl4AI)
- [ ] http://localhost:3001/api/health (AnythingLLM)
- [ ] http://localhost:8501/health (yt-dlp-server)
- [ ] http://localhost:8502/health (whisper-server)

### Configurazione
- [ ] ~/.claude.json creato con mcpServers
- [ ] AnythingLLM API key configurata
- [ ] AnythingLLM LLM provider configurato
- [ ] Docker Desktop auto-start abilitato
- [ ] Containers restart policy: unless-stopped

### Test Funzionali
- [ ] Skill web-to-rag caricata in Claude Code
- [ ] Import documentazione in RAG funzionante
- [ ] Query RAG funzionante

---

## 🐛 Troubleshooting

### Problema: Docker Desktop non si avvia
**Soluzione:**
1. Controlla se WSL 2 è abilitato: `wsl --list --verbose`
2. Se manca, installa con: `wsl --install`
3. Riavvia la VM
4. Riprova Docker Desktop

### Problema: Container non diventa healthy
**Soluzione:**
1. Controlla i log: `docker logs <container-name>`
2. Verifica porte non occupate: `netstat -ano | findstr :<porta>`
3. Ricrea il container:
   ```powershell
   docker rm -f <container-name>
   docker run ... # (comando dal PREREQUISITES.md)
   ```

### Problema: MCP server non viene caricato in Claude Code
**Soluzione:**
1. Verifica path in .claude.json: `Get-Content ~/.claude.json`
2. Verifica che npm/pip install sia completato:
   ```powershell
   cd ~/.claude/mcp-servers/anythingllm-mcp-server && npm list
   cd ~/.claude/mcp-servers/yt-dlp-mcp && npm list
   pip show duckduckgo-mcp
   ```
3. Riavvia Claude Code

### Problema: "Client not initialized" per AnythingLLM
**Soluzione:**
1. Verifica API key in .claude.json
2. Testa manualmente:
   ```powershell
   curl -H "Authorization: Bearer <API_KEY>" http://localhost:3001/api/v1/workspaces
   ```
3. Inizializza manualmente in Claude Code:
   ```
   mcp__anythingllm__initialize_anythingllm
     apiKey: "YOUR_API_KEY"
     baseUrl: "http://localhost:3001"
   ```

### Problema: yt-dlp warnings su JavaScript runtime
**Soluzione:**
1. Verifica Deno: `deno --version`
2. Verifica config yt-dlp:
   ```powershell
   Get-Content "$env:APPDATA\yt-dlp\config.txt"
   ```
   - Deve contenere: `--remote-components ejs:github`
3. Se manca, aggiungi:
   ```powershell
   New-Item -ItemType Directory -Path "$env:APPDATA\yt-dlp" -Force
   Add-Content "$env:APPDATA\yt-dlp\config.txt" "--remote-components ejs:github"
   ```

---

## 📝 Note per il Tester

**Tempo totale stimato:** 60-90 minuti

**Documenta eventuali problemi:**
- Screenshot degli errori
- Output completo dei comandi falliti
- Log dei containers: `docker logs <container-name>`
- Versioni installate: `docker --version`, `node --version`, `python --version`

**Feedback utile:**
- L'installazione è stata fluida?
- Ci sono stati passaggi poco chiari?
- Quanto tempo ha richiesto ogni step?
- Suggerimenti per migliorare lo script o la documentazione

---

*Ultima modifica: 2026-01-03*
