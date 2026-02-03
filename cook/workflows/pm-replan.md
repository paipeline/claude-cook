# PM Replan Workflow — Dynamic Plan Modification

<purpose>
Modify plans and sync changes to Vibe Kanban when things go wrong or requirements change.
Handles three scopes: targeted fix, revision, and full replan.

Triggered by:
- `/cook:pm-check` detecting ticket failure (auto-replan)
- `/cook:pm-replan` manual command with user feedback
- `/cook:pm-check` detecting cascading issues
</purpose>

<process>

<step name="gather_context" priority="first">

## 1. Gather Replan Context

Read current state:
```bash
cat .planning/config.json
cat .planning/STATE.md
cat .planning/phases/{phase_dir}/TICKET-MAP.md
```

Read all current plans:
```bash
ls .planning/phases/{phase_dir}/*-PLAN.md
```

Read any relevant summaries or verification reports:
```bash
ls .planning/phases/{phase_dir}/*-SUMMARY.md 2>/dev/null
ls .planning/phases/{phase_dir}/*-VERIFICATION.md 2>/dev/null
```

Gather trigger-specific context:
- **Failure trigger:** failed ticket details from `get_task(task_id)`
- **Feedback trigger:** user feedback text from command arguments
- **Cascade trigger:** completed ticket output that changes assumptions

</step>

<step name="classify">

## 2. Classify Replan Scope

### TARGETED (single ticket failed)
Conditions:
- One specific ticket failed/cancelled
- Other tickets in the wave are unaffected
- The failure is isolated (not a systemic issue)

Action: Create a fix plan for just the failed task.

### REVISION (feedback changes approach)
Conditions:
- User provided feedback that modifies existing plans
- Plans exist but need updates
- Core approach is still valid

Action: Revise existing plans with new constraints.

### FULL_REPLAN (fundamental change)
Conditions:
- User wants to change the overall approach
- Multiple cascading failures suggest wrong direction
- New information invalidates the current plan set

Action: Cancel all undone tickets, re-plan from phase goal.

</step>

<step name="targeted_replan">

## 3a. Targeted Fix

1. Read the failed ticket's original PLAN.md content
2. Read the failure details from ticket description/notes
3. Spawn cook-planner via Task tool:
   - Mode: gap-closure (`--gaps`)
   - Context: failed plan + error details + phase goal
   - Output: one fix PLAN.md

4. Spawn cook-plan-checker to verify the fix plan
5. If checker rejects: revise (max 3 iterations)

6. Sync to Vibe Kanban:
   - `update_task(failed_ticket_id, status="cancelled")`
   - Build Agile ticket from fix plan (Task, Why, Acceptance Criteria, Dependencies, Scope — no code specifics)
   - `create_task(project_id, fix_title, agile_ticket_description)` → new ticket
   - Record in TICKET-MAP.md

7. Dispatch fix ticket if autonomous mode

</step>

<step name="revision_replan">

## 3b. Revision

1. Identify which plans are affected by the feedback
2. Spawn cook-planner via Task tool:
   - Mode: revision
   - Context: existing plans + user feedback
   - Output: updated PLAN.md files

3. Spawn cook-plan-checker to verify revised plans
4. If checker rejects: revise (max 3 iterations)

5. Sync to Vibe Kanban (via pm-sync workflow):
   - Updated plans → update ticket descriptions
   - New plans → create new tickets
   - Removed plans → cancel tickets
   - Update TICKET-MAP.md

6. Dispatch new/updated tickets if appropriate

</step>

<step name="full_replan">

## 3c. Full Replan

1. Cancel all undone tickets:
   ```
   For each ticket with status in [todo, inprogress]:
     update_task(ticket_id, status="cancelled")
   ```
   Note: tickets already `done` are kept — that work is preserved.

2. Spawn cook-planner via Task tool:
   - Mode: standard (fresh planning)
   - Context: phase goal + new requirements/feedback + what's already done
   - Output: new set of PLAN.md files

3. Spawn cook-plan-checker to verify
4. If checker rejects: revise (max 3 iterations)

5. Sync all new plans to Vibe Kanban (via pm-sync workflow)
6. Dispatch wave 1 of new plan set

</step>

<step name="record">

## 4. Record Replan

### In TICKET-MAP.md Replan History:
```markdown
### Replan #{N} — {TIMESTAMP}

- Trigger: {failure|feedback|cascade}
- Scope: {targeted|revision|full}
- Cancelled tickets: {list}
- New tickets: {list}
- Reason: {description}
```

### In PM-LOG.md:
```markdown
## [{TIMESTAMP}] REPLAN

- Scope: {targeted|revision|full}
- Trigger: {description}
- Plans affected: {list}
- Old tickets cancelled: {count}
- New tickets created: {count}
- Dispatched: {yes/no}
```

### In STATE.md:
Update the Vibe Kanban Status section with new ticket counts.

</step>

<step name="present">

## 5. Present Replan Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► REPLANNED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Scope: {targeted|revision|full}
Reason: {description}

Changes:
- Cancelled: {N} tickets
- Created: {N} new tickets
- Updated: {N} ticket descriptions
- Dispatched: {N} workers

## Current Ticket State
{Updated table from TICKET-MAP}

## Next
{Suggested action based on current state}
```

</step>

</process>
