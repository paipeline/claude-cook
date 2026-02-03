# PM Cycle Workflow — Full-Brain Autonomous Decision Engine

## Overview

This workflow powers `/cook:pm-cycle` — the autonomous PM brain. Each invocation reads all state, classifies the situation, executes one action, updates state, and exits. The shell loop (`pm-loop.sh`) handles repetition.

## State Classification

Read phase directory and TICKET-MAP.md to classify into exactly one state:

```
NEEDS_PLANNING    → No PLAN.md files
NEEDS_SYNC        → Plans exist, no TICKET-MAP.md
NEEDS_DISPATCH    → TICKET-MAP has todo tickets in ready wave
MONITORING        → Tickets inprogress
PHASE_COMPLETE    → All tickets done, more phases in roadmap
MILESTONE_COMPLETE → All tickets done, last phase in roadmap
```

## State Machine

```
NEEDS_PLANNING ──spawn planner──→ NEEDS_SYNC
NEEDS_SYNC ──create tickets──→ NEEDS_DISPATCH
NEEDS_DISPATCH ──launch workers──→ MONITORING
MONITORING ──poll + react──→ MONITORING (loop)
                          ──→ NEEDS_DISPATCH (wave complete, next wave ready)
                          ──→ PHASE_COMPLETE (all done)
                          ──→ MONITORING + replan (ticket failed)
PHASE_COMPLETE ──advance phase──→ NEEDS_PLANNING (next phase)
                              ──→ MILESTONE_COMPLETE (last phase)
MILESTONE_COMPLETE ──stop signal──→ EXIT
```

## Action Details

### NEEDS_PLANNING

**Goal:** Create PLAN.md files for the current phase.

1. Read ROADMAP.md for phase goal and scope
2. Read PROJECT.md for project context
3. Spawn cook-planner agent via Task tool:
   - Provide: phase number, goal, project context, any prior learnings from PM-LOG
   - Agent writes PLAN.md files to phase directory
4. Spawn cook-plan-checker agent via Task tool:
   - Verify plans against phase goal
   - Max 3 planner↔checker iterations
5. Update STATE.md: phase status → "planned"
6. Log to PM-LOG.md

### NEEDS_SYNC

**Goal:** Create Agile-style Vibe Kanban tickets for each plan.

Follow `pm-sync.md` workflow:
1. Read all PLAN.md files in phase directory
2. For each plan, build an **Agile ticket** (atomic, isolated, code-agnostic):
   - Extract objective, acceptance criteria (must_haves), wave, dependencies
   - Create VK ticket: `mcp__vibe_kanban__create_task(project_id, title, description)`
   - Description = structured Agile ticket (Task, Why, Acceptance Criteria, Dependencies, Scope)
   - **Do NOT dump PLAN.md content** — tickets describe WHAT to deliver, not HOW to code it
3. Write TICKET-MAP.md with mapping table
4. Update STATE.md: phase status → "synced"
5. Log to PM-LOG.md

### NEEDS_DISPATCH

**Goal:** Launch worker agents for the next ready wave.

Follow `pm-dispatch.md` workflow:
1. Parse TICKET-MAP.md for wave structure
2. Identify next undispatched wave where all prior waves are done
3. For each `todo` ticket in target wave:
   - Call `mcp__vibe_kanban__start_workspace_session`:
     - task_id: from TICKET-MAP
     - executor: from config (default: CLAUDE_CODE)
     - repos: from config (repo_id + base_branch)
   - Update TICKET-MAP: status → inprogress, dispatched timestamp
4. Update STATE.md: phase status → "dispatched, wave {N}"
5. Log to PM-LOG.md

### MONITORING

**Goal:** Poll ticket status, react to changes.

Follow `pm-check.md` workflow:
1. Call `mcp__vibe_kanban__list_tasks(project_id)`
2. Diff current status against TICKET-MAP.md last-known status
3. For each change:

| Event | Reaction |
|-------|----------|
| Ticket: todo → inprogress | Update TICKET-MAP (worker started) |
| Ticket: inprogress → done | Update TICKET-MAP, check wave completion |
| Ticket: inprogress → inreview | Update TICKET-MAP (awaiting review) |
| Ticket: any → cancelled | If auto_replan: run pm-replan (TARGETED). Else: log warning |
| Wave complete | If auto_dispatch_next_wave: dispatch next wave. Else: log |
| All tickets done | Mark as PHASE_COMPLETE (caught next cycle) |
| No changes | Log: "No changes. {N} inprogress, {M} todo." |

4. Update TICKET-MAP.md + STATE.md + PM-LOG.md

**Stuck detection:** If a ticket has been `inprogress` for longer than 30 minutes (configurable), log a warning. After 60 minutes, consider re-dispatching with a different executor.

### PHASE_COMPLETE

**Goal:** Advance to next phase in roadmap.

1. Read ROADMAP.md
2. Find next phase after current
3. If next phase exists:
   - Update STATE.md: current_phase → next phase, status → "pending"
   - Log: "Phase {X} complete. Advancing to Phase {X+1}: {name}"
4. If no next phase:
   - This is MILESTONE_COMPLETE

### MILESTONE_COMPLETE

**Goal:** Signal completion, stop loop.

1. Log: "Milestone complete. All {N} phases done."
2. Write `.planning/.pm-stop` file (signals pm-loop.sh to exit)
3. Update STATE.md: milestone_status → "complete"
4. Exit with code 42

## PM-LOG Entry Format

Every action writes a timestamped entry:

```markdown
## [{YYYY-MM-DD HH:MM:SS}] {ACTION}

- {detail 1}
- {detail 2}
- State: {previous} → {new}
```

## Error Handling

- VK API errors: Log error, exit with code 1 (shell loop retries next cycle)
- Planner spawn failure: Log error, exit with code 1
- Dispatch failure (single ticket): Skip that ticket, continue with others, log
- All dispatches fail: Log error, exit with code 1
- State file missing: Log error, suggest `/cook:pm-start`
