---
name: gsd:pm-stop
description: Stop the autonomous PM monitoring loop gracefully
allowed-tools:
  - Read
  - Write
  - Bash
---

<objective>
Signal the autonomous PM loop (pm-loop.sh) to stop gracefully by creating the stop file.
The shell script checks for this file at the start of each cycle and exits cleanly.
</objective>

<process>

## 1. Create Stop Signal

```bash
touch .planning/.pm-stop
echo "PM stop signal created."
```

## 2. Check Loop Status

```bash
# Check if pm-loop.sh is running
if [ -f .planning/.pm-loop-pid ]; then
  PID=$(cat .planning/.pm-loop-pid)
  if ps -p "$PID" > /dev/null 2>&1; then
    echo "PM loop (PID: $PID) will stop after current cycle completes."
  else
    echo "PM loop process not found (may have already stopped)."
    rm -f .planning/.pm-loop-pid
  fi
else
  echo "No PM loop PID file found."
fi
```

## 3. Update Config

Read config.json and set `pm.mode` to `"manual"`.
Write updated config.json.

## 4. Present

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► STOPPING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stop signal sent. The PM loop will exit after the current cycle.
Mode switched to: manual

Workers already dispatched will continue running.
Use /gsd:pm-check to manually poll ticket status.
Use /gsd:pm-status to view dashboard.
```

## 5. Log to PM-LOG.md

Append:
```markdown
## [{TIMESTAMP}] STOP

- PM loop stop signal created
- Mode switched to manual
- Active workers: {count} (will continue running)
```

</process>
