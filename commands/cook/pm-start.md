---
name: cook:pm-start
description: Start fully autonomous PM — runs the entire lifecycle from init to milestone completion
argument-hint: "[phase] [--init] [--prd=<file>] [--manual] [--background] [--executor=CLAUDE_CODE] [--skip-plan] [--max-iterations=0] [--max-replans=3] [--calls=0]"
agent: cook-pm
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
@~/.claude/cook/references/ui-brand.md
@~/.claude/cook/references/vibe-kanban.md
@~/.claude/cook/workflows/pm-cycle.md
@~/.claude/cook/workflows/pm-sync.md
@~/.claude/cook/workflows/pm-dispatch.md
@~/.claude/agents/cook-pm.md
</execution_context>

<objective>
Start the fully autonomous PM agent. Auto-detects the current project state and picks up from the right point in the lifecycle:

```
NEEDS_INIT → NEEDS_RESEARCH → NEEDS_ROADMAP → NEEDS_PLANNING → NEEDS_SYNC → NEEDS_DISPATCH → MONITORING → NEEDS_REVIEW → PHASE_COMPLETE → ... → MILESTONE_COMPLETE
```

The PM runs the **entire lifecycle** unattended — from project init through research, planning, ticket creation, worker dispatch, code review (via VK review agent), phase advancement, and milestone completion.

Each loop cycle is a fresh Claude invocation via `/cook:pm-cycle` — no context rot.
</objective>

<context>
Phase number: $ARGUMENTS (optional — auto-detected if omitted)

**Flags:**
- `--init` — Start from scratch, create .planning/ and PROJECT.md
- `--prd=<file>` — Provide a PRD file for project initialization
- `--manual` — Don't launch the loop, manage manually with `/cook:pm-cycle`
- `--background` — Run loop detached (default: background when autonomous)
- `--executor=X` — Override default executor (CLAUDE_CODE, CURSOR_AGENT, CODEX, etc.)
- `--skip-plan` — Skip planning, assume plans already exist
- `--max-iterations=N` — Safety cap on loop cycles (default: 0 = unlimited)
- `--max-replans=N` — Auto replan attempts on repeated errors (default: 3)
- `--calls=N` — Max Claude calls per hour (default: 0 = unlimited)
- `--no-notify` — Disable desktop notifications
</context>

<process>

## 1. Auto-Detect State

Classify the current project state to determine where to start:

```bash
# Check each condition in order
test -d .planning && echo "planning_exists" || echo "no_planning"
test -f .planning/PROJECT.md && echo "project_exists" || echo "no_project"
test -f .planning/research/SUMMARY.md && echo "research_done" || echo "no_research"
test -f .planning/ROADMAP.md && echo "roadmap_exists" || echo "no_roadmap"
```

**State detection logic:**

| Condition | Detected State | Action |
|-----------|---------------|--------|
| No `.planning/` or no `PROJECT.md` | NEEDS_INIT | Scaffold project |
| No `.planning/research/SUMMARY.md` | NEEDS_RESEARCH | Run research agents |
| No `ROADMAP.md` | NEEDS_ROADMAP | Create roadmap |
| Phase has no PLAN.md files | NEEDS_PLANNING | Create plans |
| Plans exist, no TICKET-MAP | NEEDS_SYNC | Create tickets |
| TICKET-MAP has todo tickets | NEEDS_DISPATCH | Launch workers |
| Tickets inprogress/inreview | MONITORING | Poll and react |
| All tickets done | PHASE_COMPLETE | Advance phase |

**Override:** If `--init` flag is set, always start from NEEDS_INIT regardless of current state.

Present detected state:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► STATE DETECTED: {state}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Starting from: {state description}
Phase: {N or "new project"}
```

## 2. Setup Config

Read or create config:
```bash
cat .planning/config.json 2>/dev/null
```

If missing or no pm section, initialize:
```json
"pm": {
  "mode": "autonomous",
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
- `--manual` → set `pm.mode` to `"manual"`
- `--executor=X` → set `pm.default_executor`

## 3. Setup Vibe Kanban Connection

If `pm.project_id` is null:

1. Call `mcp__vibe_kanban__list_projects()` — discover available projects
2. If single project: use it. If multiple: present choice to user.
3. Call `mcp__vibe_kanban__list_repos(project_id)` — get repo details
4. Save project_id and repos to config.json

## 4. Execute First Cycle Inline

Run one cycle of the pm-cycle state machine inline (based on detected state from step 1). This ensures the first action happens immediately without waiting for the loop.

Follow the action for the detected state as defined in `pm-cycle.md`:
- NEEDS_INIT → scaffold project
- NEEDS_RESEARCH → spawn research agents
- NEEDS_ROADMAP → spawn roadmapper
- NEEDS_PLANNING → spawn planner + checker
- NEEDS_SYNC → create tickets
- NEEDS_DISPATCH → dispatch workers
- MONITORING → poll and react

## 5. Launch PM Loop (MANDATORY)

**You MUST launch pm-loop.sh unless `--manual` flag is explicitly set.** This is not optional. The loop is what makes the PM autonomous — without it, the PM does one cycle and stops.

**If `--manual` is NOT set**, launch pm-loop.sh using the Bash tool with `run_in_background=true` immediately after the first cycle completes:

```bash
~/.claude/scripts/pm-loop.sh \
  --phase={X} \
  --interval={poll_interval} \
  --max-iterations={max_iterations} \
  ${init_flag} \
  ${prd_flag}
```

**IMPORTANT:**
- Use the Bash tool with `run_in_background=true` — this runs in Claude Code's background compute so the user sees live progress in the UI.
- Do NOT use `--background` flag, `nohup`, or `&`. Let Claude Code manage the background process.
- Do NOT use `timeout` on the Bash tool — the loop runs indefinitely until milestone complete or `.pm-stop`.
- The loop runs in foreground mode within the background task, showing live progress bars and status updates.

Where:
- `${init_flag}` is `--init` if the `--init` flag was provided
- `${prd_flag}` is `--prd=<file>` if provided
- Phase is auto-detected or from arguments

After launching, confirm to user:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► LOOP STARTED (background compute)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PM loop running in background compute.
Polling every {interval}s. Progress visible in Claude Code UI.

Stop with: /cook:pm-stop
Status:    /cook:pm-status
```

Stop with: `touch .planning/.pm-stop` | `/cook:pm-stop`

**If `--manual` IS set**, do NOT launch the loop. Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► MANUAL MODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run these commands to manage:

/cook:pm-cycle    — Run one full-brain cycle (decides + acts)
/cook:pm-status   — View dashboard
/cook:pm-replan   — Modify plans with feedback
```

## 6. Update STATE.md

Update STATE.md with PM status:
- Current position: Phase X (or "initializing"), PM mode active
- Vibe Kanban Status section: project, tickets, last polled

</process>
