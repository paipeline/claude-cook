---
name: cook:pm-replan
description: Replan based on feedback or failures — modify plans, sync ticket changes, dispatch fixes
argument-hint: "<phase> [feedback text]"
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
@~/.claude/cook/references/vibe-kanban.md
@~/.claude/cook/workflows/pm-replan.md
@~/.claude/cook/workflows/pm-sync.md
@~/.claude/cook/workflows/pm-dispatch.md
@~/.claude/agents/cook-pm.md
</execution_context>

<objective>
Manually trigger a replan for a phase based on user feedback. Modifies plans, syncs changes to Vibe Kanban (cancel old tickets, create new ones), and optionally dispatches.

**Use cases:**
- User realized the approach is wrong
- User wants to change technology/library
- User has new requirements mid-phase
- A ticket failed and auto-replan didn't resolve it
</objective>

<context>
Phase number: first argument from $ARGUMENTS
Feedback: remaining text after phase number

Example: `/cook:pm-replan 3 switch to Redis for caching instead of in-memory`
</context>

<process>

## 1. Parse Arguments

Extract:
- Phase number (required)
- Feedback text (optional — if empty, ask user interactively)

If no feedback provided, ask:
"What should change about the current plan for phase {X}? Describe the issue or new direction."

## 2. Load Context

Read:
- Current PLAN.md files for the phase
- TICKET-MAP.md — current ticket state
- STATE.md — overall position
- config.json — PM settings
- ROADMAP.md — phase goal

## 3. Classify Replan Scope

Follow pm-replan workflow classification:

**TARGETED:** Feedback mentions a specific plan or ticket
**REVISION:** Feedback modifies approach but keeps structure
**FULL_REPLAN:** Feedback fundamentally changes direction

Present classification to user:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► REPLAN ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Scope: {targeted|revision|full}
Affected plans: {list}
Tickets to cancel: {count}

Proceeding with replan...
```

## 4. Execute Replan

Follow the pm-replan workflow for the classified scope:
- Spawn cook-planner with feedback context
- Verify with cook-plan-checker
- Sync to Vibe Kanban (cancel old, create new, update changed)
- Update TICKET-MAP.md

## 5. Dispatch (if appropriate)

If new tickets were created and they're in a ready wave:
- Ask user: "Dispatch {N} new workers now?"
- If yes: follow pm-dispatch workflow

## 6. Present Summary

Follow the pm-replan workflow presentation format.

</process>
