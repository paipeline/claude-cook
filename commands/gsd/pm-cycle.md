---
name: gsd:pm-cycle
description: Full-brain autonomous PM cycle — reads state, decides, acts, exits
argument-hint: "[phase]"
agent: gsd-pm
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - mcp__vibe_kanban__*
  - mcp__context7__*
---

<execution_context>
@~/.claude/get-shit-done/references/ui-brand.md
@~/.claude/get-shit-done/references/vibe-kanban.md
@~/.claude/get-shit-done/workflows/pm-cycle.md
@~/.claude/get-shit-done/workflows/pm-check.md
@~/.claude/get-shit-done/workflows/pm-sync.md
@~/.claude/get-shit-done/workflows/pm-dispatch.md
@~/.claude/get-shit-done/workflows/pm-replan.md
</execution_context>

<objective>
**The autonomous PM brain.** Each invocation is a stateless decision engine — reads all persistent state, decides the single most important action to take, executes it, updates state, and exits.

Called by `pm-loop.sh` on every cycle. Each call gets a fresh 200k context. State persists via `.planning/` files.

**This is the Ralph-style loop brain.** One command runs the entire PM lifecycle: plan → sync → dispatch → monitor → replan → advance phase → complete milestone.
</objective>

<context>
Phase hint: $ARGUMENTS (optional — auto-detected from STATE.md if not provided)
</context>

<process>

## 1. Load All State

Read these files (all reads in parallel):

```
.planning/config.json       → PM config (project_id, repos, executor, toggles)
.planning/STATE.md          → Current position (phase, status, decisions)
.planning/ROADMAP.md        → Phase structure, goals, milestone scope
.planning/PM-LOG.md         → Recent activity (tail last 20 lines)
```

If `$ARGUMENTS` provides a phase number, use it. Otherwise, detect from STATE.md.

Identify:
- `current_phase`: phase number being worked on
- `phase_dir`: `.planning/phases/{phase-dir}/`
- `pm_config`: the `pm` section from config.json

If no `.planning/` directory or no `config.json` with `pm` section:
```
No PM configuration found. Run /gsd:pm-start to initialize.
```
Exit with code 0.

## 2. Assess Phase State

Check the current phase directory:

```bash
# Count plans, tickets, summaries
ls -1 .planning/phases/{phase_dir}/*-PLAN.md 2>/dev/null | wc -l
ls -1 .planning/phases/{phase_dir}/TICKET-MAP.md 2>/dev/null | wc -l
```

Read TICKET-MAP.md if it exists. Parse ticket statuses.

Classify the phase into exactly ONE state:

| State | Condition |
|-------|-----------|
| `NEEDS_PLANNING` | No PLAN.md files in phase directory |
| `NEEDS_SYNC` | PLAN.md files exist but no TICKET-MAP.md |
| `NEEDS_DISPATCH` | TICKET-MAP.md exists with `todo` tickets in a ready wave |
| `MONITORING` | Tickets are `inprogress` — workers running |
| `PHASE_COMPLETE` | All tickets in TICKET-MAP.md are `done` |
| `MILESTONE_COMPLETE` | Current phase is the last phase AND it's complete |

State: "Phase {X} state: {STATE}"

## 3. Execute Single Action

Based on the classified state, execute ONE action per cycle. Each action updates state and exits — the shell loop handles continuation.

---

### Action: NEEDS_PLANNING

Spawn gsd-planner agent to create plans for this phase.

```
Spawning planner for Phase {X}: {name}...
```

Use Task tool to spawn gsd-planner:
- Provide phase goal from ROADMAP.md
- Provide PROJECT.md context
- Wait for plans to be written

Then spawn gsd-plan-checker to verify plan quality.

Update STATE.md: set phase status to "planned".

Log to PM-LOG.md:
```markdown
## [{TIMESTAMP}] PLANNED

- Phase {X}: {plan_count} plans created
- Plans: {list plan names}
```

**Exit code 0** — next cycle will sync.

---

### Action: NEEDS_SYNC

Run pm-sync workflow — create **Agile-style tickets** (NOT code dumps):
1. Read all PLAN.md files in phase directory
2. For each plan, extract objective, acceptance criteria (must_haves), wave, dependencies
3. Build an Agile ticket for each plan (Task, Why, Acceptance Criteria, Dependencies, Scope)
4. Call `mcp__vibe_kanban__create_task` with:
   - Title: "Phase {X} Plan {Y}: {objective}"
   - Description: Structured Agile ticket — atomic, isolated, no file paths or code specifics
5. Write TICKET-MAP.md with all mappings

Update STATE.md: set phase status to "synced".

Log to PM-LOG.md:
```markdown
## [{TIMESTAMP}] SYNCED

- Phase {X}: {ticket_count} tickets created
- Project: {project_id}
```

**Exit code 0** — next cycle will dispatch.

---

### Action: NEEDS_DISPATCH

Run pm-dispatch workflow:
1. Identify the next ready wave (all prior waves complete)
2. For each `todo` ticket in this wave:
   - Call `mcp__vibe_kanban__start_workspace_session` with:
     - task_id, executor, repos (from config)
   - Update TICKET-MAP.md: status → inprogress, dispatched timestamp
3. Log dispatch to PM-LOG.md

Update STATE.md: set phase status to "dispatched, wave {N}".

Log to PM-LOG.md:
```markdown
## [{TIMESTAMP}] DISPATCHED

- Wave {N}: {count} workers launched
- Executor: {executor}
- Tickets: {list ticket IDs}
```

**Exit code 0** — next cycle will monitor.

---

### Action: MONITORING

Run pm-check workflow:
1. Poll VK: `mcp__vibe_kanban__list_tasks(project_id)`
2. Diff against TICKET-MAP.md
3. Classify events and react:

**For each completed ticket:**
- Update TICKET-MAP.md: status → done, completed timestamp
- Log completion

**For each failed/cancelled ticket:**
- If `auto_replan_on_failure` is true in config:
  - Run pm-replan workflow (TARGETED scope)
  - Create fix ticket, dispatch it
- Else: log failure, continue monitoring

**If wave complete (all tickets in current wave done):**
- If `auto_dispatch_next_wave` is true AND more waves exist:
  - Run pm-dispatch for next wave
- Else: log wave completion

**If all tickets done:**
- This is actually PHASE_COMPLETE — will be caught next cycle

**If no changes detected:**
- Brief log only: "No changes. {N} tickets inprogress."

Update STATE.md + TICKET-MAP.md + PM-LOG.md.

**Exit code 0** — next cycle continues monitoring or advances.

---

### Action: PHASE_COMPLETE

1. Read ROADMAP.md
2. Identify next phase number
3. If next phase exists:
   - Update STATE.md: advance to next phase, status "pending"
   - Log phase completion

```markdown
## [{TIMESTAMP}] PHASE_COMPLETE

- Phase {X}: all {N} tickets done
- Duration: {start} → {end}
- Advancing to Phase {X+1}: {name}
```

**Exit code 0** — next cycle will plan the new phase.

4. If no next phase → this is MILESTONE_COMPLETE.

---

### Action: MILESTONE_COMPLETE

1. Log milestone completion:

```markdown
## [{TIMESTAMP}] MILESTONE_COMPLETE

- All {N} phases complete
- Total tickets: {count}
- Duration: {start} → {end}
```

2. Create stop signal:
```bash
touch .planning/.pm-stop
```

3. Update STATE.md: milestone status "complete"

4. Present:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► MILESTONE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All phases complete. PM loop will stop on next cycle.

Run /gsd:complete-milestone to archive and plan next.
```

**Exit with code 42** — signals shell loop to stop.

---

## 4. Cycle Summary

After executing the action, output a **rich cycle report** — the user sees this live in their terminal (pm-loop.sh runs foreground by default). Be informative, not terse.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► {ACTION} — Phase {X}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{What happened this cycle — 2-3 sentences describing the action taken,
any decisions made, and what changed.}

Tickets: {done}/{total} done | {inprogress} running | {todo} queued
Wave: {current_wave}/{total_waves}
Next: {What the PM will do on the next cycle}
```

**This is live user-facing output.** The PM loop runs in the foreground — the user is watching. Report progress actively: what you did, what's happening, what's next. Don't be silent.

</process>

<constraints>
- **One action per cycle.** Never do two lifecycle steps in one invocation. Let the loop handle progression.
- **Never write code.** You are a PM. You plan, delegate, monitor, replan. Workers write code.
- **Trust the files.** All truth is in .planning/ files. Don't assume or remember across cycles.
- **Exit codes matter.** 0 = continue, 42 = milestone done (stop loop), 1 = error.
- **Log everything.** Every action gets a PM-LOG.md entry with timestamp.
- **Respect wave discipline.** Never dispatch wave N+1 until all wave N tickets are done.
- **Replan, don't panic.** Failed tickets get auto-replanned, not abandoned.
- **Report actively.** The user sees your output live. Tell them what's happening — don't be a silent background process.
</constraints>
