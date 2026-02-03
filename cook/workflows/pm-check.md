# PM Check Workflow — Single Poll+React Cycle

<purpose>
Execute one stateless monitoring cycle: poll Vibe Kanban tickets, diff against TICKET-MAP.md, react to state changes, log decisions, update persistent state.

This workflow is the atomic unit of the PM loop. Called by:
- `pm-loop.sh` (autonomous mode — once per interval)
- `/cook:pm-check` (manual mode — user-triggered)

Each invocation is a fresh Claude context. All state comes from files.
</purpose>

<process>

<step name="load_state" priority="first">

## 1. Load Persistent State

Read the following files to reconstruct PM context:

```bash
cat .planning/config.json           # pm section
cat .planning/STATE.md              # current position
```

From config.json, extract:
- `pm.project_id` — VK project UUID
- `pm.repos` — repo configs for dispatch
- `pm.default_executor` — which agent to use
- `pm.auto_replan_on_failure` — whether to auto-fix
- `pm.auto_dispatch_next_wave` — whether to auto-advance
- `pm.max_replan_attempts` — replan limit

Find the active phase:
```bash
# Get current phase from STATE.md
grep "Phase:" .planning/STATE.md | head -1
```

Read the active TICKET-MAP:
```bash
cat .planning/phases/{phase_dir}/TICKET-MAP.md
```

**If no TICKET-MAP exists:** This phase has no tickets yet. Exit with message suggesting `/cook:pm-start`.

**If phase_status is `complete`:** Exit with message that phase is done.

</step>

<step name="poll_vk">

## 2. Poll Vibe Kanban

Call `mcp__vibe_kanban__list_tasks(project_id)` to get all tickets.

For each ticket returned, build a map:
```
current_state = {
  ticket_id: { status, title, description_snippet }
}
```

</step>

<step name="diff">

## 3. Diff Against TICKET-MAP

For each ticket tracked in TICKET-MAP.md:

```
previous_status = TICKET-MAP[ticket_id].status
current_status  = current_state[ticket_id].status

if previous_status != current_status:
  events.push({
    ticket_id, title,
    from: previous_status,
    to: current_status
  })
```

Classify each event:

| Transition | Event Type |
| ---------- | ---------- |
| todo → inprogress | WORKER_STARTED |
| inprogress → inreview | WORKER_COMPLETED |
| inprogress → done | WORKER_AUTO_COMPLETED |
| any → cancelled | TICKET_CANCELLED |
| (no change, inprogress for too long) | POTENTIALLY_STUCK |

Aggregate events:

| Condition | Aggregate Event |
| --------- | --------------- |
| All wave N tickets are `done` | WAVE_COMPLETE |
| All tickets across all waves are `done` | PHASE_COMPLETE |
| Tickets in `inreview` awaiting review | NEEDS_REVIEW |
| No changes detected | NO_CHANGE |

</step>

<step name="react">

## 4. React to Events

Process events in priority order:

### PHASE_COMPLETE (highest priority)
1. Update TICKET-MAP.md: `phase_status: complete`
2. Update STATE.md: mark phase complete, advance current position
3. Log phase completion summary to PM-LOG.md
4. Present to user:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► PHASE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase {X}: {name} — all tickets done.

Run /cook:pm-start {X+1} to begin next phase.
```

### WAVE_COMPLETE
1. Identify next wave tickets in TICKET-MAP
2. Check `pm.auto_dispatch_next_wave` in config
3. If true: dispatch all next-wave tickets (call dispatch flow from cook-pm agent)
4. If false: log and present suggestion to user
5. Update STATE.md wave summary

### WORKER_COMPLETED (inprogress → inreview)
1. Call `get_task(task_id)` to read worker output/notes
2. Update TICKET-MAP.md: status=inreview, review_started=timestamp
3. Trigger automated code review:
   - Spawn `feature-dev:code-reviewer` agent via Task tool
   - Provide: ticket title, acceptance criteria from ticket description, recent commits (use `git log --oneline -10` to find relevant commits)
   - The reviewer examines the diff and returns a verdict: **PASS** or **FAIL** with issues
4. Based on review result:
   - **PASS:** Update ticket status to `done` via `mcp__vibe_kanban__update_task(task_id, status="done")`. Update TICKET-MAP.md: status=done, completed=timestamp, review=passed. Check if this completes the wave.
   - **FAIL:** Update ticket status back to `inprogress` via `mcp__vibe_kanban__update_task(task_id, status="inprogress")`. Update TICKET-MAP.md: status=inprogress, review=failed. Append review feedback as a task note via `mcp__vibe_kanban__update_task(task_id, description=original_description + "\n\n## Review Feedback\n\n" + reviewer_issues)`. Re-dispatch the ticket so the worker can address review feedback.
5. Log review result to PM-LOG.md

### WORKER_AUTO_COMPLETED (inprogress → done, bypass review)
1. Call `get_task(task_id)` to read worker output/notes
2. Update TICKET-MAP.md: status=done, completed=timestamp, review=skipped
3. Check if this completes the wave

> **Note:** `inprogress → done` skips review (worker or human marked it done directly). To enforce review, workers should transition to `inreview` instead of `done`.

### TICKET_CANCELLED (potential failure)
1. Call `get_task(task_id)` to read cancellation reason
2. Check `pm.auto_replan_on_failure` in config
3. Read current replan_count from TICKET-MAP Replan History
4. If auto_replan AND replan_count < max_replan_attempts:
   - Spawn cook-planner via Task tool in gap-closure mode
   - Pass: failed ticket details, phase goal, existing plans
   - After planner returns: sync new plan to VK ticket
   - Dispatch fix ticket
   - Increment replan_count
5. If not auto or max reached: log and present failure to user with options

### POTENTIALLY_STUCK
1. Log warning
2. If autonomous: consider re-dispatching
3. Present to user if manual mode

### NO_CHANGE
1. Brief log entry only

</step>

<step name="log">

## 5. Log to PM-LOG.md

Append a timestamped entry:

```markdown
## [YYYY-MM-DD HH:MM:SS] POLL

- Checked {N} tickets for phase {X}
- Events: {list of transitions, or "No changes"}
- Actions: {list of actions taken, or "None"}
- Next: {what to expect}
```

For significant events (dispatch, replan, phase complete), use the specific event type instead of POLL:

```markdown
## [YYYY-MM-DD HH:MM:SS] DISPATCH

- Dispatched wave {N}: {ticket list}
- Executor: {name}

## [YYYY-MM-DD HH:MM:SS] REPLAN

- Failed ticket: {title} ({ticket_id})
- Reason: {error details}
- Fix plan created: {plan_name}
- Fix ticket: {new_ticket_id}
```

</step>

<step name="update_state">

## 6. Update Persistent State

### TICKET-MAP.md
- Update status column for all changed tickets
- Update last_polled timestamp
- Add replan entries if applicable

### STATE.md — Vibe Kanban Status section
- Update ticket summary table
- Update last_polled
- Update PM loop status
- Update next action description
- Update Recent Ticket Events (keep last 5)

</step>

</process>
