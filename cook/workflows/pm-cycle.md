# PM Cycle Workflow — Full-Brain Autonomous Decision Engine

## Overview

This workflow powers `/cook:pm-cycle` — the autonomous PM brain. Each invocation reads all state, classifies the situation, executes one action, updates state, and exits. The shell loop (`pm-loop.sh`) handles repetition.

The PM runs the **entire project lifecycle** end-to-end: from project initialization through research, roadmapping, planning, ticket creation, worker dispatch, monitoring, code review, phase advancement, and milestone completion — all without stopping.

## State Classification

Read `.planning/` directory and state files to classify into exactly one state:

```
NEEDS_INIT        → No .planning/ directory or no PROJECT.md
NEEDS_RESEARCH    → PROJECT.md exists but no .planning/research/SUMMARY.md
NEEDS_ROADMAP     → Research done but no ROADMAP.md
NEEDS_PLANNING    → Phase has no PLAN.md files
NEEDS_SYNC        → Plans exist, no TICKET-MAP.md
NEEDS_DISPATCH    → TICKET-MAP has todo tickets in ready wave
MONITORING        → Tickets inprogress
NEEDS_REVIEW      → Tickets inreview (awaiting VK review agent)
PHASE_COMPLETE    → All tickets done, more phases in roadmap
MILESTONE_COMPLETE → All tickets done, last phase in roadmap
```

## State Machine

```
NEEDS_INIT ──scaffold project──→ NEEDS_RESEARCH
NEEDS_RESEARCH ──spawn researchers──→ NEEDS_ROADMAP
NEEDS_ROADMAP ──spawn roadmapper──→ NEEDS_PLANNING
NEEDS_PLANNING ──spawn planner──→ NEEDS_SYNC
NEEDS_SYNC ──create tickets──→ NEEDS_DISPATCH
NEEDS_DISPATCH ──launch workers──→ MONITORING
MONITORING ──poll + react──→ MONITORING (loop)
                          ──→ NEEDS_REVIEW (worker completed, tickets inreview)
                          ──→ NEEDS_DISPATCH (wave complete, next wave ready)
                          ──→ PHASE_COMPLETE (all done)
                          ──→ MONITORING + replan (ticket failed)
NEEDS_REVIEW ──VK review agent──→ MONITORING (review passed → done, check wave)
                                ──→ MONITORING (review failed → re-dispatch)
PHASE_COMPLETE ──advance phase──→ NEEDS_PLANNING (next phase)
                              ──→ MILESTONE_COMPLETE (last phase)
MILESTONE_COMPLETE ──stop signal──→ EXIT
```

## Action Details

### NEEDS_INIT

**Goal:** Scaffold the project structure so the PM can operate.

1. Check if `.planning/` directory exists. If not, create it.
2. Check for PRD or project description:
   - If `--prd <file>` was passed via pm-loop.sh: read that file as the project description
   - If a `PRD.md` or `prd.md` exists in the repo root: use it
   - Otherwise: read any README.md or project files to infer scope
3. Create `PROJECT.md` from template (follow @~/.claude/cook/templates/project.md):
   - Fill in: project name, description, goals, tech stack (from existing code or PRD)
4. Create `config.json` from template (follow @~/.claude/cook/templates/config.json):
   - Set `pm.project_id` to null (will be discovered during NEEDS_SYNC)
   - Set defaults for model profile, executor, intervals
5. Create initial `STATE.md` from template (follow @~/.claude/cook/templates/state.md)
6. Log to PM-LOG.md:
   ```markdown
   ## [{timestamp}] INIT

   - Project scaffolded from {source: PRD/README/description}
   - Created: PROJECT.md, config.json, STATE.md
   - Next: Research phase
   ```

### NEEDS_RESEARCH

**Goal:** Gather domain knowledge and technical context before roadmapping.

1. Read PROJECT.md for project scope and goals
2. Spawn 4 research agents in parallel via Task tool (run_in_background=true):
   - **cook-project-researcher** (focus: "architecture") — evaluate architecture patterns
   - **cook-project-researcher** (focus: "stack") — evaluate tech stack choices
   - **cook-project-researcher** (focus: "features") — break down feature requirements
   - **cook-project-researcher** (focus: "pitfalls") — identify risks and common pitfalls
3. Each researcher writes to `.planning/research/`:
   - `ARCHITECTURE.md`, `STACK.md`, `FEATURES.md`, `PITFALLS.md`
4. After all 4 complete, spawn **cook-research-synthesizer**:
   - Reads all 4 research files
   - Writes `.planning/research/SUMMARY.md`
5. Update STATE.md: status → "researched"
6. Log to PM-LOG.md

### NEEDS_ROADMAP

**Goal:** Create a phased roadmap from research findings.

1. Read `.planning/research/SUMMARY.md` for synthesized findings
2. Read PROJECT.md for goals and constraints
3. Spawn **cook-roadmapper** agent via Task tool:
   - Provide: project context, research summary, milestone goals
   - Agent writes `ROADMAP.md` to `.planning/`
   - Roadmap contains: phases with goals, scope, dependencies, success criteria
4. Create phase directories: `.planning/phases/phase-{N}-{slug}/`
5. Update STATE.md: current_phase → phase 1, status → "roadmapped"
6. Log to PM-LOG.md

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
| Ticket: inprogress → inreview | Update TICKET-MAP, transition to NEEDS_REVIEW |
| Ticket: inprogress → done | Update TICKET-MAP (review skipped), check wave completion |
| Ticket: any → cancelled | If auto_replan: run pm-replan (TARGETED). Else: log warning |
| Wave complete | If auto_dispatch_next_wave: dispatch next wave. Else: log |
| All tickets done | Mark as PHASE_COMPLETE (caught next cycle) |
| No changes | Log: "No changes. {N} inprogress, {M} inreview, {O} todo." |

4. Update TICKET-MAP.md + STATE.md + PM-LOG.md

**Stuck detection:** If a ticket has been `inprogress` for longer than 30 minutes (configurable), log a warning. After 60 minutes, consider re-dispatching with a different executor.

### NEEDS_REVIEW

**Goal:** Delegate code review to Vibe Kanban's review agent.

The PM does **not** run its own code reviewer. Instead, it delegates review to the Vibe Kanban platform's review capabilities:

1. Find all tickets with status `inreview` in TICKET-MAP.md
2. For each `inreview` ticket:
   a. Read ticket details via `mcp__vibe_kanban__get_task(task_id)`
   b. Dispatch review via Vibe Kanban:
      - Call `mcp__vibe_kanban__start_workspace_session(task_id, executor="REVIEW_AGENT", repos=[...])`
      - This launches VK's review agent on the worker's changes
   c. Update TICKET-MAP: review_dispatched=timestamp
3. After dispatching reviews, transition back to MONITORING:
   - PM polls `list_tasks()` to detect review outcomes
   - When VK review agent completes: ticket → `done` (passed) or → `inprogress` (failed with feedback)
   - PM reacts to these transitions in the normal MONITORING flow
4. Log review dispatch to PM-LOG.md:
   ```markdown
   ## [{timestamp}] REVIEW_DISPATCH

   - Dispatched VK review for {N} tickets
   - Tickets: {list}
   - Next: Monitoring for review outcomes
   ```

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
- Research agent failure: Log error, retry next cycle (partial research is ok)
- Dispatch failure (single ticket): Skip that ticket, continue with others, log
- All dispatches fail: Log error, exit with code 1
- State file missing: Auto-detect correct state from filesystem and recover
