# PM Sync Workflow — Plan-to-Ticket Synchronization

<purpose>
Synchronize PLAN.md files with Vibe Kanban tickets. Creates tickets for new plans, updates tickets for modified plans, cancels tickets for removed plans. Maintains TICKET-MAP.md as the authoritative mapping.

Called by:
- `/gsd:pm-start` after planning completes
- `/gsd:pm-replan` after plans are revised
</purpose>

<process>

<step name="load_vk_context" priority="first">

## 1. Load Vibe Kanban Context

Read `.planning/config.json` for pm section.

**If `pm.project_id` is null (first run):**
1. Call `mcp__vibe_kanban__list_projects()` to discover projects
2. If single project: use it. If multiple: present choice to user.
3. Call `mcp__vibe_kanban__list_repos(project_id)` for repo details
4. Save to config.json:
   ```json
   "pm": {
     "project_id": "{discovered_uuid}",
     "repos": [{"repo_id": "{uuid}", "base_branch": "main"}]
   }
   ```

**If already configured:** Use stored values.

</step>

<step name="discover_plans">

## 2. Discover Plans and Build Diff

List all PLAN.md files in the phase directory:
```bash
ls .planning/phases/{phase_dir}/*-PLAN.md 2>/dev/null
```

Read existing TICKET-MAP.md if it exists:
```bash
cat .planning/phases/{phase_dir}/TICKET-MAP.md 2>/dev/null
```

Build three lists:

**New plans:** PLAN.md exists but no corresponding ticket in TICKET-MAP
**Modified plans:** PLAN.md exists, ticket exists, but plan content has changed
**Removed plans:** Ticket exists in TICKET-MAP but PLAN.md no longer exists

</step>

<step name="sync_new">

## 3. Create Tickets for New Plans

For each new plan:

1. Read the full PLAN.md content
2. Extract from frontmatter: `wave`, `depends_on`, `phase`, `plan`
3. Extract objective from the `<objective>` section (first line)
4. Build ticket:
   - **title:** `"Phase {phase} Plan {plan}: {objective_first_line}"`
   - **description:** Full PLAN.md content as-is (this is the worker's prompt)
5. Call `mcp__vibe_kanban__create_task(project_id, title, description)`
6. Record in TICKET-MAP.md:
   ```
   | {plan} | {task_summary} | {ticket_uuid} | todo | — | {wave} | — | — | new |
   ```

</step>

<step name="sync_modified">

## 4. Update Tickets for Modified Plans

For each modified plan:

1. Find ticket_id from TICKET-MAP.md
2. Check current ticket status:
   - If `todo`: safe to update → `update_task(task_id, description=new_content)`
   - If `inprogress`: **WARNING** — worker is running. Log warning, do NOT update.
   - If `done`/`cancelled`: skip (no point updating)
3. Update TICKET-MAP.md with notes

</step>

<step name="sync_removed">

## 5. Cancel Tickets for Removed Plans

For each plan that no longer exists:

1. Find ticket_id from TICKET-MAP.md
2. Check current ticket status:
   - If `todo`: cancel → `update_task(task_id, status="cancelled")`
   - If `inprogress`: **WARNING** — worker running. Log but don't cancel yet.
   - If already `done`/`cancelled`: skip
3. Mark as cancelled in TICKET-MAP.md

</step>

<step name="finalize">

## 6. Write TICKET-MAP.md

If TICKET-MAP.md doesn't exist yet, create it from template with all ticket entries.

If it exists, update the existing entries and add new ones.

Update the Wave Summary table:

```markdown
## Wave Summary

| Wave | Total | Done | In Progress | Todo | Failed |
| ---- | ----- | ---- | ----------- | ---- | ------ |
| 1    | 3     | 0    | 0           | 3    | 0      |
| 2    | 2     | 0    | 0           | 2    | 0      |
```

Update `last_polled` timestamp.

</step>

</process>
