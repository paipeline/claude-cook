---
name: gsd:pm-start
description: Start fully autonomous PM — plans, syncs, dispatches, monitors, and advances phases automatically
argument-hint: "<phase> [--manual] [--executor=CLAUDE_CODE] [--skip-plan] [--max-iterations=0]"
agent: gsd-pm
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - WebFetch
  - mcp__context7__*
  - mcp__vibe_kanban__*
---

<execution_context>
@~/.claude/get-shit-done/references/ui-brand.md
@~/.claude/get-shit-done/references/vibe-kanban.md
@~/.claude/get-shit-done/workflows/pm-sync.md
@~/.claude/get-shit-done/workflows/pm-dispatch.md
@~/.claude/agents/gsd-pm.md
</execution_context>

<objective>
Start the fully autonomous PM agent. Validates environment, sets up VK connection, and launches `pm-loop.sh` — the Ralph-style infinite loop that handles the ENTIRE lifecycle:

**plan → sync tickets → dispatch workers → monitor → replan on failure → advance phases → complete milestone**

After this command, the PM runs unattended. Each loop cycle is a fresh Claude invocation via `/gsd:pm-cycle` — no context rot.

Use `--manual` to skip the loop and manage phases manually with `/gsd:pm-cycle`.
</objective>

<context>
Phase number: $ARGUMENTS (required — starting phase)

**Flags:**
- `--manual` — Don't launch the loop, manage manually with `/gsd:pm-cycle`
- `--executor=X` — Override default executor (CLAUDE_CODE, CURSOR_AGENT, CODEX, etc.)
- `--skip-plan` — Skip initial planning, assume plans already exist
- `--max-iterations=N` — Safety cap on loop cycles (default: 0 = unlimited)
</context>

<process>

## 1. Validate Environment

```bash
test -d .planning && echo "exists" || echo "missing"
```

If no `.planning/`: Error — run `/gsd:new-project` first.

Read config:
```bash
cat .planning/config.json 2>/dev/null
```

Check for pm section. If missing, initialize it:
```json
"pm": {
  "mode": "manual",
  "poll_interval_seconds": 60,
  "project_id": null,
  "repos": [],
  "default_executor": "CLAUDE_CODE",
  "auto_replan_on_failure": true,
  "auto_dispatch_next_wave": true,
  "max_replan_attempts": 3
}
```

Apply flag overrides:
- `--autonomous` → set `pm.mode` to `"autonomous"`
- `--manual` → set `pm.mode` to `"manual"`
- `--executor=X` → set `pm.default_executor`

Write updated config.json.

## 2. Parse Phase Number

Extract phase number from $ARGUMENTS. Validate it exists in ROADMAP.md.

Find or create phase directory:
```bash
ls .planning/phases/ | grep "^{phase_num}"
```

## 3. Setup Vibe Kanban Connection

If `pm.project_id` is null:

1. Call `mcp__vibe_kanban__list_projects()` — discover available projects
2. If single project: use it. If multiple: present choice to user.
3. Call `mcp__vibe_kanban__list_repos(project_id)` — get repo details
4. Save project_id and repos to config.json

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► CONNECTED TO VIBE KANBAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: {name} ({project_id})
Repos: {repo_list}
Executor: {default_executor}
```

## 4. Plan Phase (unless --skip-plan)

If plans already exist for this phase AND --skip-plan not specified:
- Ask user: "Plans already exist. Re-plan or use existing?"

If no plans exist OR user wants to re-plan:
- Follow the same planning pipeline as `/gsd:plan-phase`:
  1. Resolve model profile
  2. Optionally run phase researcher
  3. Spawn gsd-planner via Task tool
  4. Spawn gsd-plan-checker to verify
  5. Iterate planner ↔ checker until plans pass (max 3)

**Key difference from /gsd:plan-phase:** After planning, continue to sync+dispatch instead of stopping.

## 5. Sync Plans to Vibe Kanban Tickets

Follow the pm-sync workflow:

1. Read all PLAN.md files in the phase directory
2. For each plan:
   - Build title: `"Phase {X} Plan {Y}: {objective}"`
   - Build description: full PLAN.md content
   - `create_task(project_id, title, description)`
3. Write TICKET-MAP.md with all mappings

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► TICKETS SYNCED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{N} plans → {N} tickets created

| Wave | Plan | Ticket | Title |
| ---- | ---- | ------ | ----- |
| ...  | ...  | ...    | ...   |
```

## 6. Dispatch Wave 1

Follow the pm-dispatch workflow:

1. Collect all wave 1 tickets from TICKET-MAP
2. For each:
   - `start_workspace_session(task_id, executor, repos)`
   - Update TICKET-MAP: status=inprogress, dispatched=now
3. Log dispatches to PM-LOG.md

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► WAVE 1 DISPATCHED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{N} workers launched:

| Ticket | Plan | Executor | Status |
| ------ | ---- | -------- | ------ |
| ...    | ...  | ...      | launched |
```

## 7. Launch PM Loop (default: autonomous)

### Autonomous Mode (default)

Launch pm-loop.sh — the Ralph-style infinite loop that calls `/gsd:pm-cycle` each iteration. The brain handles everything from here: monitoring, wave advancement, replanning, phase progression.

```bash
nohup ~/.claude/scripts/pm-loop.sh --phase={X} --interval={poll_interval} --max-iterations={max_iterations} > .planning/pm-loop.log 2>&1 &
echo $! > .planning/.pm-loop-pid
```

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► AUTONOMOUS MODE ACTIVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PM loop running (PID: {pid})
Brain: /gsd:pm-cycle (full lifecycle per iteration)
Polling every {interval}s
Log: .planning/PM-LOG.md

The PM will autonomously:
  plan → sync → dispatch → monitor → replan → advance phases

Stop with: /gsd:pm-stop  or  touch .planning/.pm-stop
Status: /gsd:pm-status
```

### Manual Mode (--manual)

Don't launch the loop. User runs `/gsd:pm-cycle` manually for each step.

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► MANUAL MODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Workers dispatched. Run these commands to manage:

/gsd:pm-cycle    — Run one full-brain cycle (decides + acts)
/gsd:pm-status   — View dashboard
/gsd:pm-replan   — Modify plans with feedback
```

## 8. Update STATE.md

Update STATE.md with PM status:
- Current position: Phase X, PM mode active
- Vibe Kanban Status section: project, tickets, last polled

</process>
