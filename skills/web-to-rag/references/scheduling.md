# Automatic Scheduling

Configure automatic RAG updates.

## Concept

Scheduling keeps RAG updated automatically.
Claude creates scripts and configures the OS to run them periodically.

---

## Guided Workflow

When user requests scheduled updates:

### Step 1: Gather Information

Claude asks:

```
To create automatic schedule, I need:

1. Which workspace to update?
   [List existing workspaces or new name]

2. Source URL?
   [URL to scrape]

3. Update frequency?
   - Daily
   - Weekly (which day?)
   - Monthly (which day?)

4. Preferred time?
   [Default: 3:00 AM]
```

### Step 2: Create Script

Claude creates a script in the skill directory:

**Windows:** `~/.claude/skills/web-to-rag/scripts/update-rag-{workspace}.ps1`
**Linux/macOS:** `~/.claude/skills/web-to-rag/scripts/update-rag-{workspace}.sh`

### Step 3: Configure Scheduler

**Windows:** Task Scheduler via PowerShell
**Linux/macOS:** crontab

### Step 4: Confirm

```
✅ Schedule created!

Details:
- Workspace: fastapi-docs
- Source: https://fastapi.tiangolo.com
- Frequency: Every Monday at 3:00 AM
- Script: ~/.claude/skills/web-to-rag/scripts/update-rag-fastapi-docs.ps1
- Task ID: UpdateRAG-fastapi-docs

Logs: ~/.claude/logs/rag-updates.log

Manage:
- "show active schedules"
- "pause schedule fastapi-docs"
- "delete schedule fastapi-docs"
```

---

## Windows Task Scheduler Commands

### Create Task
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File `"$scriptPath`""

# Weekly
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 3am

# Daily
$trigger = New-ScheduledTaskTrigger -Daily -At 3am

Register-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE" -Action $action -Trigger $trigger
```

### Manage Tasks
```powershell
# List RAG tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "UpdateRAG-*" }

# Pause task
Disable-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Resume task
Enable-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Delete task
Unregister-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE" -Confirm:$false

# Run manually
Start-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Check last run
Get-ScheduledTaskInfo -TaskName "UpdateRAG-$WORKSPACE"
```

---

## Linux/macOS crontab Commands

### Create Entry
```bash
# Weekly (Monday 3:00)
(crontab -l 2>/dev/null; echo "0 3 * * 1 $SCRIPT_PATH") | crontab -

# Daily (3:00)
(crontab -l 2>/dev/null; echo "0 3 * * * $SCRIPT_PATH") | crontab -

# Monthly (1st at 3:00)
(crontab -l 2>/dev/null; echo "0 3 1 * * $SCRIPT_PATH") | crontab -
```

### Manage Entries
```bash
# List crontab
crontab -l

# Remove specific entry
crontab -l | grep -v "$WORKSPACE" | crontab -

# Edit crontab manually
crontab -e
```

---

## Management from Claude

### List Active Schedules

```
User: "show active schedules"

Claude runs:
- Windows: Get-ScheduledTask | Where-Object { $_.TaskName -like "UpdateRAG-*" }
- Linux: crontab -l | grep update-rag

Output:
Active RAG schedules:

1. fastapi-docs
   - Frequency: Weekly (Monday 3:00)
   - Last run: 2026-01-06 03:00
   - Status: Active

2. react-docs
   - Frequency: Daily (3:00)
   - Last run: 2026-01-10 03:00
   - Status: Paused
```

### Delete Schedule

```
User: "delete schedule fastapi-docs"

Claude:
1. Removes task scheduler/crontab
2. Deletes script
3. Confirms: "Schedule fastapi-docs deleted"
```

### Change Frequency

```
User: "change fastapi-docs frequency to daily"

Claude:
1. Removes old trigger
2. Creates daily trigger
3. Confirms: "Frequency updated to daily at 3:00"
```

---

## Limitations

1. **Docker must be running** - Script tries to start but may fail
2. **Direct API calls** - No interactive Claude Code
3. **No feedback** - Log file only
4. **Single URL** - One script per source URL
5. **Credentials** - API key stored in script (consider secrets manager)

---

## Best Practices

1. **Night hours** - Schedule at 3:00 AM to avoid interference
2. **Monitor logs** - Check ~/.claude/logs/ periodically
3. **Backup workspace** - Before major updates
4. **Manual test** - Run script once before scheduling
5. **Rate limiting** - Don't schedule too many simultaneous updates

---

*Last updated: January 2026*
