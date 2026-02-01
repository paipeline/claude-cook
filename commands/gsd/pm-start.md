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
- `--background` — Run loop detached (default: foreground with live output)
- `--executor=X` — Override default executor (CLAUDE_CODE, CURSOR_AGENT, CODEX, etc.)
- `--skip-plan` — Skip initial planning, assume plans already exist
- `--max-iterations=N` — Safety cap on loop cycles (default: 0 = unlimited)
- `--no-notify` — Disable desktop notifications
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

## 5. Sync Plans to Agile Tickets

Follow the pm-sync workflow — create **Agile-style tickets**, not code dumps:

1. Read all PLAN.md files in the phase directory
2. For each plan, build an Agile ticket:
   - Extract: objective, acceptance criteria (must_haves), wave, dependencies
   - Build title: `"Phase {X} Plan {Y}: {objective}"`
   - Build description: structured Agile ticket (Task, Why, Acceptance Criteria, Dependencies, Scope)
   - **No file paths, function names, or code snippets** — tickets describe WHAT to deliver
   - `create_task(project_id, title, agile_description)`
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

## 7. Launch PM Loop (default: foreground, live output)

### Autonomous Mode (default) — FOREGROUND

Launch pm-loop.sh in the **foreground** — the user sees live progress, cycle-by-cycle output, progress bars, and desktop notifications for key events. The PM actively reports what it's doing.

```bash
~/.claude/scripts/pm-loop.sh --phase={X} --interval={poll_interval} --max-iterations={max_iterations}
```

The loop runs in the current terminal. The user sees:
- Cycle headers with timestamps
- Full pm-cycle output (banners, ticket tables, decisions)
- Progress bars between cycles (done/running/todo counts)
- Countdown to next cycle
- Desktop notifications for: milestone complete, errors, phase advances

Stop with: `Ctrl+C` | `touch .planning/.pm-stop` | `/gsd:pm-stop`

**Note:** This is a blocking call — it takes over the terminal. The PM actively reports to the user rather than hiding in a log file.

### Background Mode (--background)

If the user explicitly passes `--background`, launch detached:

```bash
~/.claude/scripts/pm-loop.sh --phase={X} --interval={poll_interval} --max-iterations={max_iterations} --background
```

This re-execs with nohup and exits immediately. Output goes to `.planning/pm-loop.log`.

Desktop notifications still work in background mode (macOS/Linux).

Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► BACKGROUND MODE

PM loop running (PID: {pid})
Log: tail -f .planning/pm-loop.log
Stop: /gsd:pm-stop  or  touch .planning/.pm-stop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
