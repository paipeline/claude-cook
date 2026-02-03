# PM Sync Workflow — Plan-to-Ticket Synchronization

<purpose>
Synchronize PLAN.md files with Vibe Kanban tickets. Creates tickets for new plans, updates tickets for modified plans, cancels tickets for removed plans. Maintains TICKET-MAP.md as the authoritative mapping.

Called by:
- `/cook:pm-start` after planning completes
- `/cook:pm-replan` after plans are revised
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

**Ticket philosophy:** Tickets are Agile-style task assignments — atomic, isolated, and code-agnostic. They describe **what** to deliver and **why**, not **how** to implement it. The worker agent reads the codebase to figure out implementation. This makes tickets robust to codebase changes and readable by any stakeholder.

For each new plan:

1. Read the PLAN.md content
2. Extract from frontmatter: `wave`, `depends_on`, `phase`, `plan`
3. Extract from `<objective>` section: what this plan accomplishes and why
4. Extract from `must_haves` frontmatter: truths (observable behaviors), artifacts (deliverables)
5. Build an **Agile ticket** (NOT a code dump):

   - **title:** `"Phase {phase} Plan {plan}: {objective_summary}"`
   - **description:** Structured Agile ticket (see format below)

6. Call `mcp__vibe_kanban__create_task(project_id, title, description)`
7. Record in TICKET-MAP.md:
   ```
   | {plan} | {task_summary} | {ticket_uuid} | todo | — | {wave} | — | — | new |
   ```

### Agile Ticket Format

```markdown
## Task

{One-paragraph summary of what to deliver. Written as a user story or task statement.
Focus on the deliverable, not implementation details. No file paths, no function names, no code snippets.}

## Why

{Why this task matters for the project. What value it adds. What it unblocks.}

## Acceptance Criteria

- [ ] {Observable behavior 1 — from must_haves.truths}
- [ ] {Observable behavior 2}
- [ ] {Deliverable exists — from must_haves.artifacts, described generically}

## Dependencies

- {List ticket IDs this depends on, from depends_on field, or "None"}

## Scope

- Wave: {N}
- Phase: {phase_name}
- Plan ref: {plan_id} (see .planning/ for implementation details)
```

**What NOT to include in tickets:**
- File paths or directory structures
- Function/class/method names
- Code snippets or pseudocode
- Specific library API calls
- Internal architecture decisions

**Why:** Workers are coding agents with full codebase access. They figure out implementation from context. Tickets that prescribe code become stale, create merge conflicts, and prevent the agent from making better decisions based on actual codebase state.

</step>

<step name="sync_modified">

## 4. Update Tickets for Modified Plans

For each modified plan:

1. Find ticket_id from TICKET-MAP.md
2. Check current ticket status:
   - If `todo`: safe to update → rebuild Agile ticket from updated PLAN.md, then `update_task(task_id, description=new_agile_ticket)`
   - If `inprogress`: **WARNING** — worker is running. Log warning, do NOT update.
   - If `done`/`cancelled`: skip (no point updating)
3. Update TICKET-MAP.md with notes

**Important:** Always regenerate the Agile ticket format from the updated PLAN.md. Never dump raw PLAN.md content into the ticket description.

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
