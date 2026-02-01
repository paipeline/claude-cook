---
name: gsd:pm-check
description: Single stateless poll+react cycle — monitor tickets, detect changes, react automatically
argument-hint: "[phase]"
agent: gsd-pm
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - mcp__vibe_kanban__*
  - mcp__context7__*
---

<execution_context>
@~/.claude/get-shit-done/references/vibe-kanban.md
@~/.claude/get-shit-done/workflows/pm-check.md
@~/.claude/get-shit-done/workflows/pm-replan.md
@~/.claude/get-shit-done/workflows/pm-dispatch.md
@~/.claude/agents/gsd-pm.md
</execution_context>

<objective>
Execute one stateless monitoring cycle: poll Vibe Kanban tickets, diff against TICKET-MAP.md, react to state changes, log decisions, update persistent state.

**This is the atomic unit of PM monitoring.** In autonomous mode, pm-loop.sh calls this once per interval. In manual mode, user calls this directly.

Each invocation is a fresh Claude context. ALL state comes from persistent files.
</objective>

<context>
Phase number: $ARGUMENTS (optional — auto-detects from STATE.md if not provided)

No flags. Behavior is fully determined by:
- `.planning/config.json` — pm section
- `.planning/phases/{phase}/TICKET-MAP.md` — ticket state
- Vibe Kanban API — current ticket status
</context>

<process>

Follow the pm-check workflow exactly:

## 1. Load Persistent State

Read config, STATE.md, and active phase TICKET-MAP.md.

If phase not specified in $ARGUMENTS, determine from STATE.md current position.

**Exit conditions:**
- No TICKET-MAP.md → "No tickets to monitor. Run /gsd:pm-start first."
- Phase status is `complete` → "Phase already complete."

## 2. Poll Vibe Kanban

```
mcp__vibe_kanban__list_tasks(project_id)
```

## 3. Diff Against TICKET-MAP

Compare current VK status vs TICKET-MAP last-known status.
Classify events: COMPLETED, FAILED, STUCK, WAVE_COMPLETE, PHASE_COMPLETE, NO_CHANGE.

## 4. React to Events

Follow the reaction logic from the pm-check workflow:
- PHASE_COMPLETE → mark done, suggest next phase
- WAVE_COMPLETE → auto-dispatch next wave (if config allows)
- COMPLETED → update TICKET-MAP, check wave status
- FAILED → auto-replan (if config allows) or alert user
- STUCK → warn or re-dispatch
- NO_CHANGE → brief log only

**For auto-replan:** Follow pm-replan workflow (targeted scope).
**For auto-dispatch:** Follow pm-dispatch workflow.

## 5. Log to PM-LOG.md

Append timestamped entry with events and actions taken.

## 6. Update Persistent State

Update TICKET-MAP.md and STATE.md with current ticket statuses.

## 7. Present Summary

If changes detected:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► CHECK CYCLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Events:
- {ticket_title}: {old_status} → {new_status}
- ...

Actions taken:
- {description}
- ...

## Current State
| Wave | Done | Running | Todo |
| ---- | ---- | ------- | ---- |
| ...  | ...  | ...     | ...  |
```

If no changes:
```
PM ► No changes detected. {N} tickets monitored. Next check in {interval}s.
```

</process>
