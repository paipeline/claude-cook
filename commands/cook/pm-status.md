---
name: cook:pm-status
description: Dashboard showing all tickets, plan health, and recent PM decisions
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - mcp__vibe_kanban__*
---

<execution_context>
@~/.claude/cook/references/ui-brand.md
@~/.claude/cook/references/vibe-kanban.md
</execution_context>

<objective>
Display a comprehensive PM dashboard: ticket status matrix, wave progress, recent PM-LOG entries, and suggested next actions.

Read-only — does not modify any state.
</objective>

<context>
Phase number: $ARGUMENTS (optional — shows all phases if not specified)
</context>

<process>

## 1. Load Context

```bash
cat .planning/config.json
cat .planning/STATE.md
```

If phase specified: read that phase's TICKET-MAP.md
If not: read all TICKET-MAP.md files across phases

## 2. Poll Current Status

Call `mcp__vibe_kanban__list_tasks(project_id)` for live ticket status.

Cross-reference with TICKET-MAP.md entries.

## 3. Build Dashboard

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► PROJECT STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: {name}
Executor: {default_executor}
Mode: {autonomous|manual}
PM Loop: {running (PID: X)|stopped}

## Phase {X}: {name}  [{progress_bar}] {percent}%

| Wave | Plan | Ticket | Status | Executor | Duration |
| ---- | ---- | ------ | ------ | -------- | -------- |
| 1    | 01   | {id}   | done   | CLAUDE_CODE | 12m   |
| 1    | 02   | {id}   | done   | CURSOR  | 8m       |
| 2    | 03   | {id}   | inprogress | CLAUDE_CODE | 5m... |
| 2    | 04   | {id}   | todo   | —       | —        |

### Wave Summary
| Wave | Total | Done | Running | Todo | Failed |
| ---- | ----- | ---- | ------- | ---- | ------ |
| 1    | 2     | 2    | 0       | 0    | 0      |
| 2    | 2     | 0    | 1       | 1    | 0      |

### Replans: {count}
### Failed tickets: {count}
```

## 4. Recent PM-LOG

Read last 10 entries from PM-LOG.md:
```bash
tail -50 .planning/PM-LOG.md
```

Present the last 3-5 significant events:
```
## Recent Activity

- [{time}] Wave 1 complete — auto-dispatched wave 2
- [{time}] VK-{id} (Plan 03): todo → inprogress
- [{time}] VK-{id} (Plan 01): inprogress → done (12m)
```

## 5. Suggested Actions

Based on current state, suggest relevant commands:

```
## Actions

/cook:pm-check    — Poll for latest ticket updates
/cook:pm-replan 3 — Modify plans if issues found
/cook:pm-stop     — Stop autonomous monitoring
```

If all tickets done:
```
Phase {X} complete! Run /cook:pm-start {X+1} for next phase.
```

If tickets stuck:
```
⚠ {N} tickets have been running for >{threshold}min.
Consider /cook:pm-check to diagnose.
```

</process>
