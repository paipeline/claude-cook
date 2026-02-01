# PM Dispatch Workflow — Wave-Aware Worker Launch

<purpose>
Launch external coding agents on Vibe Kanban tickets, respecting wave ordering.
Only dispatches tickets whose wave dependencies are satisfied.

Called by:
- `/gsd:pm-start` after sync (dispatch wave 1)
- `/gsd:pm-check` when WAVE_COMPLETE detected (dispatch next wave)
- `/gsd:pm-dispatch` manual command
</purpose>

<process>

<step name="load_context" priority="first">

## 1. Load Dispatch Context

Read config for executor and repo settings:
```bash
cat .planning/config.json   # pm.default_executor, pm.repos
```

Read TICKET-MAP.md for the target phase:
```bash
cat .planning/phases/{phase_dir}/TICKET-MAP.md
```

Determine target wave:
- If wave specified (e.g., `--wave=2`): use that wave
- If not specified: find the lowest wave number with `todo` tickets where all prior waves are complete

</step>

<step name="validate_wave">

## 2. Validate Wave Dependencies

For the target wave N:

1. Check all wave N-1 tickets are `done` (if wave > 1)
2. If any wave N-1 tickets are NOT done:
   - If `inprogress`: "Wave {N-1} still running. Wait for completion."
   - If `todo`: "Wave {N-1} has undispatched tickets. Dispatch those first."
   - If `cancelled`/`failed`: "Wave {N-1} has failed tickets. Replan needed."
   - **Do NOT dispatch wave N.** Exit with status.

3. Collect all wave N tickets with status `todo`
4. If none: "All wave {N} tickets already dispatched." Exit.

</step>

<step name="dispatch">

## 3. Dispatch Workers

For each `todo` ticket in the target wave:

1. Read executor from config (or per-ticket override if specified in TICKET-MAP notes)
2. Read repos from config
3. Call:
   ```
   mcp__vibe_kanban__start_workspace_session(
     task_id: ticket_uuid,
     executor: default_executor,
     repos: [{repo_id, base_branch}]
   )
   ```
4. Update TICKET-MAP.md for this ticket:
   - status: inprogress
   - executor: {executor_name}
   - dispatched: {timestamp}
5. Log dispatch to PM-LOG.md

**Error handling:**
- If `start_workspace_session` fails: log error, skip ticket, continue with others
- Report failed dispatches at the end

</step>

<step name="report">

## 4. Report Dispatch Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PM ► DISPATCHING WAVE {N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dispatched {X} workers for phase {P}, wave {N}:

| Ticket | Plan | Executor | Status |
| ------ | ---- | -------- | ------ |
| {id}   | 01   | CLAUDE_CODE | launched |
| {id}   | 02   | CLAUDE_CODE | launched |

Next: Workers are running. Check progress with /gsd:pm-check
```

Update STATE.md Vibe Kanban Status section.

</step>

</process>
