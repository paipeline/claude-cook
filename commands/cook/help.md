---
name: cook:help
description: Show available COOK commands and usage guide
---

<objective>
Display the complete COOK command reference.

Output ONLY the reference content below. Do NOT add:

- Project-specific analysis
- Git status or file context
- Next-step suggestions
- Any commentary beyond the reference
  </objective>

<reference>
# COOK Command Reference

**COOK** (Get Shit Done) creates hierarchical project plans optimized for solo agentic development with Claude Code.

## Quick Start

1. `/cook:new-project` - Initialize project (includes research, requirements, roadmap)
2. `/cook:plan-phase 1` - Create detailed plan for first phase
3. `/cook:execute-phase 1` - Execute the phase

## Staying Updated

COOK evolves fast. Update periodically:

```bash
npx claude-cook@latest
```

## Core Workflow

```
/cook:new-project → /cook:plan-phase → /cook:execute-phase → repeat
```

### Project Initialization

**`/cook:new-project`**
Initialize new project through unified flow.

One command takes you from idea to ready-for-planning:
- Deep questioning to understand what you're building
- Optional domain research (spawns 4 parallel researcher agents)
- Requirements definition with v1/v2/out-of-scope scoping
- Roadmap creation with phase breakdown and success criteria

Creates all `.planning/` artifacts:
- `PROJECT.md` — vision and requirements
- `config.json` — workflow mode (interactive/yolo)
- `research/` — domain research (if selected)
- `REQUIREMENTS.md` — scoped requirements with REQ-IDs
- `ROADMAP.md` — phases mapped to requirements
- `STATE.md` — project memory

Usage: `/cook:new-project`

**`/cook:map-codebase`**
Map an existing codebase for brownfield projects.

- Analyzes codebase with parallel Explore agents
- Creates `.planning/codebase/` with 7 focused documents
- Covers stack, architecture, structure, conventions, testing, integrations, concerns
- Use before `/cook:new-project` on existing codebases

Usage: `/cook:map-codebase`

### Phase Planning

**`/cook:discuss-phase <number>`**
Help articulate your vision for a phase before planning.

- Captures how you imagine this phase working
- Creates CONTEXT.md with your vision, essentials, and boundaries
- Use when you have ideas about how something should look/feel

Usage: `/cook:discuss-phase 2`

**`/cook:research-phase <number>`**
Comprehensive ecosystem research for niche/complex domains.

- Discovers standard stack, architecture patterns, pitfalls
- Creates RESEARCH.md with "how experts build this" knowledge
- Use for 3D, games, audio, shaders, ML, and other specialized domains
- Goes beyond "which library" to ecosystem knowledge

Usage: `/cook:research-phase 3`

**`/cook:list-phase-assumptions <number>`**
See what Claude is planning to do before it starts.

- Shows Claude's intended approach for a phase
- Lets you course-correct if Claude misunderstood your vision
- No files created - conversational output only

Usage: `/cook:list-phase-assumptions 3`

**`/cook:plan-phase <number>`**
Create detailed execution plan for a specific phase.

- Generates `.planning/phases/XX-phase-name/XX-YY-PLAN.md`
- Breaks phase into concrete, actionable tasks
- Includes verification criteria and success measures
- Multiple plans per phase supported (XX-01, XX-02, etc.)

Usage: `/cook:plan-phase 1`
Result: Creates `.planning/phases/01-foundation/01-01-PLAN.md`

### Execution

**`/cook:execute-phase <phase-number>`**
Execute all plans in a phase.

- Groups plans by wave (from frontmatter), executes waves sequentially
- Plans within each wave run in parallel via Task tool
- Verifies phase goal after all plans complete
- Updates REQUIREMENTS.md, ROADMAP.md, STATE.md

Usage: `/cook:execute-phase 5`

### Quick Mode

**`/cook:quick`**
Execute small, ad-hoc tasks with COOK guarantees but skip optional agents.

Quick mode uses the same system with a shorter path:
- Spawns planner + executor (skips researcher, checker, verifier)
- Quick tasks live in `.planning/quick/` separate from planned phases
- Updates STATE.md tracking (not ROADMAP.md)

Use when you know exactly what to do and the task is small enough to not need research or verification.

Usage: `/cook:quick`
Result: Creates `.planning/quick/NNN-slug/PLAN.md`, `.planning/quick/NNN-slug/SUMMARY.md`

### Roadmap Management

**`/cook:add-phase <description>`**
Add new phase to end of current milestone.

- Appends to ROADMAP.md
- Uses next sequential number
- Updates phase directory structure

Usage: `/cook:add-phase "Add admin dashboard"`

**`/cook:insert-phase <after> <description>`**
Insert urgent work as decimal phase between existing phases.

- Creates intermediate phase (e.g., 7.1 between 7 and 8)
- Useful for discovered work that must happen mid-milestone
- Maintains phase ordering

Usage: `/cook:insert-phase 7 "Fix critical auth bug"`
Result: Creates Phase 7.1

**`/cook:remove-phase <number>`**
Remove a future phase and renumber subsequent phases.

- Deletes phase directory and all references
- Renumbers all subsequent phases to close the gap
- Only works on future (unstarted) phases
- Git commit preserves historical record

Usage: `/cook:remove-phase 17`
Result: Phase 17 deleted, phases 18-20 become 17-19

### Milestone Management

**`/cook:new-milestone <name>`**
Start a new milestone through unified flow.

- Deep questioning to understand what you're building next
- Optional domain research (spawns 4 parallel researcher agents)
- Requirements definition with scoping
- Roadmap creation with phase breakdown

Mirrors `/cook:new-project` flow for brownfield projects (existing PROJECT.md).

Usage: `/cook:new-milestone "v2.0 Features"`

**`/cook:complete-milestone <version>`**
Archive completed milestone and prepare for next version.

- Creates MILESTONES.md entry with stats
- Archives full details to milestones/ directory
- Creates git tag for the release
- Prepares workspace for next version

Usage: `/cook:complete-milestone 1.0.0`

### Progress Tracking

**`/cook:progress`**
Check project status and intelligently route to next action.

- Shows visual progress bar and completion percentage
- Summarizes recent work from SUMMARY files
- Displays current position and what's next
- Lists key decisions and open issues
- Offers to execute next plan or create it if missing
- Detects 100% milestone completion

Usage: `/cook:progress`

### Session Management

**`/cook:resume-work`**
Resume work from previous session with full context restoration.

- Reads STATE.md for project context
- Shows current position and recent progress
- Offers next actions based on project state

Usage: `/cook:resume-work`

**`/cook:pause-work`**
Create context handoff when pausing work mid-phase.

- Creates .continue-here file with current state
- Updates STATE.md session continuity section
- Captures in-progress work context

Usage: `/cook:pause-work`

### Debugging

**`/cook:debug [issue description]`**
Systematic debugging with persistent state across context resets.

- Gathers symptoms through adaptive questioning
- Creates `.planning/debug/[slug].md` to track investigation
- Investigates using scientific method (evidence → hypothesis → test)
- Survives `/clear` — run `/cook:debug` with no args to resume
- Archives resolved issues to `.planning/debug/resolved/`

Usage: `/cook:debug "login button doesn't work"`
Usage: `/cook:debug` (resume active session)

### Todo Management

**`/cook:add-todo [description]`**
Capture idea or task as todo from current conversation.

- Extracts context from conversation (or uses provided description)
- Creates structured todo file in `.planning/todos/pending/`
- Infers area from file paths for grouping
- Checks for duplicates before creating
- Updates STATE.md todo count

Usage: `/cook:add-todo` (infers from conversation)
Usage: `/cook:add-todo Add auth token refresh`

**`/cook:check-todos [area]`**
List pending todos and select one to work on.

- Lists all pending todos with title, area, age
- Optional area filter (e.g., `/cook:check-todos api`)
- Loads full context for selected todo
- Routes to appropriate action (work now, add to phase, brainstorm)
- Moves todo to done/ when work begins

Usage: `/cook:check-todos`
Usage: `/cook:check-todos api`

### User Acceptance Testing

**`/cook:verify-work [phase]`**
Validate built features through conversational UAT.

- Extracts testable deliverables from SUMMARY.md files
- Presents tests one at a time (yes/no responses)
- Automatically diagnoses failures and creates fix plans
- Ready for re-execution if issues found

Usage: `/cook:verify-work 3`

### Milestone Auditing

**`/cook:audit-milestone [version]`**
Audit milestone completion against original intent.

- Reads all phase VERIFICATION.md files
- Checks requirements coverage
- Spawns integration checker for cross-phase wiring
- Creates MILESTONE-AUDIT.md with gaps and tech debt

Usage: `/cook:audit-milestone`

**`/cook:plan-milestone-gaps`**
Create phases to close gaps identified by audit.

- Reads MILESTONE-AUDIT.md and groups gaps into phases
- Prioritizes by requirement priority (must/should/nice)
- Adds gap closure phases to ROADMAP.md
- Ready for `/cook:plan-phase` on new phases

Usage: `/cook:plan-milestone-gaps`

### Configuration

**`/cook:settings`**
Configure workflow toggles and model profile interactively.

- Toggle researcher, plan checker, verifier agents
- Select model profile (quality/balanced/budget)
- Updates `.planning/config.json`

Usage: `/cook:settings`

**`/cook:set-profile <profile>`**
Quick switch model profile for COOK agents.

- `quality` — Opus everywhere except verification
- `balanced` — Opus for planning, Sonnet for execution (default)
- `budget` — Sonnet for writing, Haiku for research/verification

Usage: `/cook:set-profile budget`

### Utility Commands

**`/cook:help`**
Show this command reference.

**`/cook:update`**
Update COOK to latest version with changelog preview.

- Shows installed vs latest version comparison
- Displays changelog entries for versions you've missed
- Highlights breaking changes
- Confirms before running install
- Better than raw `npx claude-cook`

Usage: `/cook:update`

**`/cook:join-discord`**
Join the COOK Discord community.

- Get help, share what you're building, stay updated
- Connect with other COOK users

Usage: `/cook:join-discord`

## Files & Structure

```
.planning/
├── PROJECT.md            # Project vision
├── ROADMAP.md            # Current phase breakdown
├── STATE.md              # Project memory & context
├── config.json           # Workflow mode & gates
├── todos/                # Captured ideas and tasks
│   ├── pending/          # Todos waiting to be worked on
│   └── done/             # Completed todos
├── debug/                # Active debug sessions
│   └── resolved/         # Archived resolved issues
├── codebase/             # Codebase map (brownfield projects)
│   ├── STACK.md          # Languages, frameworks, dependencies
│   ├── ARCHITECTURE.md   # Patterns, layers, data flow
│   ├── STRUCTURE.md      # Directory layout, key files
│   ├── CONVENTIONS.md    # Coding standards, naming
│   ├── TESTING.md        # Test setup, patterns
│   ├── INTEGRATIONS.md   # External services, APIs
│   └── CONCERNS.md       # Tech debt, known issues
└── phases/
    ├── 01-foundation/
    │   ├── 01-01-PLAN.md
    │   └── 01-01-SUMMARY.md
    └── 02-core-features/
        ├── 02-01-PLAN.md
        └── 02-01-SUMMARY.md
```

## Workflow Modes

Set during `/cook:new-project`:

**Interactive Mode**

- Confirms each major decision
- Pauses at checkpoints for approval
- More guidance throughout

**YOLO Mode**

- Auto-approves most decisions
- Executes plans without confirmation
- Only stops for critical checkpoints

Change anytime by editing `.planning/config.json`

## Planning Configuration

Configure how planning artifacts are managed in `.planning/config.json`:

**`planning.commit_docs`** (default: `true`)
- `true`: Planning artifacts committed to git (standard workflow)
- `false`: Planning artifacts kept local-only, not committed

When `commit_docs: false`:
- Add `.planning/` to your `.gitignore`
- Useful for OSS contributions, client projects, or keeping planning private
- All planning files still work normally, just not tracked in git

**`planning.search_gitignored`** (default: `false`)
- `true`: Add `--no-ignore` to broad ripgrep searches
- Only needed when `.planning/` is gitignored and you want project-wide searches to include it

Example config:
```json
{
  "planning": {
    "commit_docs": false,
    "search_gitignored": true
  }
}
```

### Product Manager Mode

**`/cook:pm-start <phase>`**
Start fully autonomous PM — plans, syncs, dispatches, monitors, and advances phases.

- Runs **foreground by default** — live progress, desktop notifications, progress bars
- Plans phase, syncs to Agile tickets (atomic, code-agnostic), dispatches workers
- Autonomously monitors, replans on failure, advances phases, completes milestone
- `--background`: detach to run silently (logs to pm-loop.log, still sends desktop notifications)
- `--manual`: don't launch loop, manage with `/cook:pm-cycle` manually
- `--executor=X`: override default executor (CLAUDE_CODE, CURSOR_AGENT, etc.)
- `--no-notify`: disable desktop notifications

Usage: `/cook:pm-start 1`

**`/cook:pm-check [phase]`**
Single monitoring cycle — poll tickets, detect changes, react.

- Polls Vibe Kanban for ticket status changes
- Diffs against TICKET-MAP.md to detect events
- Auto-reacts: advance waves, replan on failure, alert on stuck
- Stateless — called by pm-loop.sh or manually

Usage: `/cook:pm-check`

**`/cook:pm-replan <phase> [feedback]`**
Replan based on feedback or failures.

- Classifies scope: targeted fix, revision, or full replan
- Spawns planner with feedback context
- Cancels old tickets, creates new ones, dispatches

Usage: `/cook:pm-replan 3 "switch to Redis for caching"`

**`/cook:pm-status [phase]`**
Dashboard showing tickets, plan health, recent PM decisions.

- Live ticket status from Vibe Kanban
- Wave progress and completion
- Recent PM-LOG entries
- Suggested next actions

Usage: `/cook:pm-status`

**`/cook:pm-stop`**
Stop the autonomous PM monitoring loop.

- Creates stop signal file (`.planning/.pm-stop`)
- Loop exits gracefully on next cycle
- Workers already dispatched continue running

Usage: `/cook:pm-stop`

## Common Workflows

**Starting a new project:**

```
/cook:new-project        # Unified flow: questioning → research → requirements → roadmap
/clear
/cook:plan-phase 1       # Create plans for first phase
/clear
/cook:execute-phase 1    # Execute all plans in phase
```

**Resuming work after a break:**

```
/cook:progress  # See where you left off and continue
```

**Adding urgent mid-milestone work:**

```
/cook:insert-phase 5 "Critical security fix"
/cook:plan-phase 5.1
/cook:execute-phase 5.1
```

**Completing a milestone:**

```
/cook:complete-milestone 1.0.0
/clear
/cook:new-milestone  # Start next milestone (questioning → research → requirements → roadmap)
```

**Capturing ideas during work:**

```
/cook:add-todo                    # Capture from conversation context
/cook:add-todo Fix modal z-index  # Capture with explicit description
/cook:check-todos                 # Review and work on todos
/cook:check-todos api             # Filter by area
```

**Using PM mode (external agents):**

```
/cook:new-project                          # Initialize project
/cook:pm-start 1                           # Starts PM — live progress in terminal
# PM runs foreground: you see every cycle, progress bars, notifications
# It plans → syncs tickets → dispatches → monitors → replans → advances phases
# Stop with Ctrl+C or /cook:pm-stop from another terminal
/cook:pm-replan 1 "use Redis instead"      # Change plans mid-flight (from another terminal)
```

**Debugging an issue:**

```
/cook:debug "form submission fails silently"  # Start debug session
# ... investigation happens, context fills up ...
/clear
/cook:debug                                    # Resume from where you left off
```

## Getting Help

- Read `.planning/PROJECT.md` for project vision
- Read `.planning/STATE.md` for current context
- Check `.planning/ROADMAP.md` for phase status
- Run `/cook:progress` to check where you're up to
  </reference>
