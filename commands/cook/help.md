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

**COOK** is an autonomous PM terminal assistant that runs the entire project lifecycle end-to-end — from project init through research, planning, ticket creation, worker dispatch, code review, phase advancement, and milestone completion.

## Quick Start

```bash
/cook:pm-start --init --prd=PRD.md   # Start from scratch with a PRD
/cook:pm-start                        # Resume from current state
```

One command runs everything. The PM auto-detects state and picks up from the right point.

## Staying Updated

```bash
npx claude-cook@latest
```

## Core Lifecycle

```
NEEDS_INIT → NEEDS_RESEARCH → NEEDS_ROADMAP → NEEDS_PLANNING
     ↓            ↓               ↓                ↓
Create .planning  Research     Roadmap          PLAN.md files
     ↓            ↓               ↓                ↓
NEEDS_SYNC → NEEDS_DISPATCH → MONITORING → NEEDS_REVIEW
     ↓            ↓               ↓              ↓
Create tickets  Launch workers  Poll VK     VK review agent
     ↓                                          ↓
PHASE_COMPLETE ──→ (back to NEEDS_PLANNING for next phase)
     ↓
MILESTONE_COMPLETE ──→ EXIT
```

## PM Commands (Primary)

**`/cook:pm-start [phase] [flags]`**
Start the fully autonomous PM. Auto-detects state and runs the entire lifecycle.

Flags:
- `--init` — Start from scratch (create .planning/)
- `--prd=<file>` — Provide PRD file for project init (implies --init)
- `--manual` — Don't launch loop, manage with `/cook:pm-cycle`
- `--background` — Run loop detached (logs to pm-loop.log)
- `--executor=X` — Override default executor (CLAUDE_CODE, CURSOR_AGENT, etc.)
- `--skip-plan` — Skip planning, assume plans exist
- `--no-notify` — Disable desktop notifications

Usage: `/cook:pm-start --init --prd=PRD.md`
Usage: `/cook:pm-start 1`

**`/cook:pm-check`**
Single monitoring cycle — poll tickets, detect changes, react.

Usage: `/cook:pm-check`

**`/cook:pm-status`**
Dashboard showing tickets, plan health, recent PM decisions.

Usage: `/cook:pm-status`

**`/cook:pm-replan [phase] [feedback]`**
Replan based on feedback or failures.

Usage: `/cook:pm-replan 3 "switch to Redis for caching"`

**`/cook:pm-stop`**
Stop the autonomous PM loop gracefully.

Usage: `/cook:pm-stop`

## Project Initialization

**`/cook:new-project`**
Initialize project through the unified flow (questioning, research, requirements, roadmap).

Usage: `/cook:new-project`

**`/cook:new-milestone <name>`**
Start a new milestone cycle.

Usage: `/cook:new-milestone "v2.0 Features"`

**`/cook:complete-milestone <version>`**
Archive completed milestone and prepare for next version.

Usage: `/cook:complete-milestone 1.0.0`

## Planning

**`/cook:plan-phase <number>`**
Create detailed execution plan for a specific phase (manual override).

Usage: `/cook:plan-phase 1`

## Roadmap Management

**`/cook:add-phase <description>`**
Add new phase to end of current milestone.

Usage: `/cook:add-phase "Add admin dashboard"`

**`/cook:insert-phase <after> <description>`**
Insert urgent work as decimal phase between existing phases.

Usage: `/cook:insert-phase 7 "Fix critical auth bug"`

**`/cook:remove-phase <number>`**
Remove a future phase and renumber subsequent phases.

Usage: `/cook:remove-phase 17`

## Progress & Status

**`/cook:progress`**
Check project status and route to next action.

Usage: `/cook:progress`

## Codebase Analysis

**`/cook:map-codebase`**
Map an existing codebase for brownfield projects.

Usage: `/cook:map-codebase`

## Configuration

**`/cook:settings`**
Configure workflow toggles and model profile.

Usage: `/cook:settings`

**`/cook:set-profile <profile>`**
Quick switch model profile (quality/balanced/budget).

Usage: `/cook:set-profile budget`

## Utility

**`/cook:help`** — Show this command reference.
**`/cook:update`** — Update COOK to latest version.
**`/cook:join-discord`** — Join the COOK Discord community.

## Common Workflows

**Starting a brand new project:**

```
/cook:pm-start --init --prd=PRD.md    # Everything runs automatically
```

**Starting from an existing codebase:**

```
/cook:map-codebase                     # Analyze codebase first
/cook:pm-start --init                  # Then start PM
```

**Resuming work:**

```
/cook:pm-start                         # Auto-detects state and continues
```

**Adding urgent mid-milestone work:**

```
/cook:insert-phase 5 "Critical security fix"
/cook:pm-start 5.1                     # PM plans + dispatches the fix
```

**Completing a milestone:**

```
/cook:complete-milestone 1.0.0
/cook:new-milestone "v2.0"
/cook:pm-start                         # New milestone lifecycle begins
```

**Manual PM mode:**

```
/cook:pm-start --manual                # Setup but don't loop
/cook:pm-cycle                         # Run cycles manually
/cook:pm-status                        # Check dashboard
/cook:pm-replan 1 "use Redis"          # Change plans
```

## Files & Structure

```
.planning/
├── PROJECT.md            # Project vision
├── ROADMAP.md            # Current phase breakdown
├── STATE.md              # Project memory & context
├── config.json           # Workflow mode & PM config
├── PM-LOG.md             # PM decision history
├── research/             # Domain research
│   ├── ARCHITECTURE.md
│   ├── STACK.md
│   ├── FEATURES.md
│   ├── PITFALLS.md
│   └── SUMMARY.md
├── codebase/             # Codebase map (brownfield)
└── phases/
    ├── 01-foundation/
    │   ├── 01-01-PLAN.md
    │   ├── 01-01-SUMMARY.md
    │   └── TICKET-MAP.md
    └── 02-core-features/
        └── ...
```

## Getting Help

- Read `.planning/PROJECT.md` for project vision
- Read `.planning/STATE.md` for current context
- Check `.planning/ROADMAP.md` for phase status
- Run `/cook:progress` to check where you're at
  </reference>
