# Vibe Kanban MCP Reference

Reference for PM agent interactions with the Vibe Kanban task management system.

## Tool Catalog

### Reading State

**`mcp__vibe_kanban__list_projects`**
Returns all available projects. Use to discover `project_id` on first run.

**`mcp__vibe_kanban__list_tasks(project_id, [status])`**
List all tickets in a project. Optional status filter: `todo`, `inprogress`, `inreview`, `done`, `cancelled`.

**`mcp__vibe_kanban__get_task(task_id)`**
Get full ticket details including description and status. Use to read worker output/notes.

**`mcp__vibe_kanban__list_repos(project_id)`**
List all repositories for a project. Returns `repo_id` needed for dispatch.

**`mcp__vibe_kanban__get_repo(repo_id)`**
Get repo details including scripts (setup, cleanup, dev server).

### Writing State

**`mcp__vibe_kanban__create_task(project_id, title, [description])`**
Create a new ticket. The description should contain the full PLAN.md content as the worker's prompt.

**`mcp__vibe_kanban__update_task(task_id, [title], [description], [status])`**
Update ticket fields. Use for:
- Marking tickets `done` after verification
- Marking tickets `cancelled` during replan
- Updating description when plans change

**`mcp__vibe_kanban__delete_task(task_id)`**
Permanently delete a ticket. Prefer `update_task(status: cancelled)` for audit trail.

### Dispatching Workers

**`mcp__vibe_kanban__start_workspace_session(task_id, executor, repos, [variant])`**
Launch an external coding agent to work on a ticket.

Parameters:
- `task_id`: The ticket UUID to assign
- `executor`: Agent type — one of:
  - `CLAUDE_CODE` — Claude Code CLI
  - `AMP` — Amp agent
  - `GEMINI` — Gemini CLI
  - `CODEX` — OpenAI Codex
  - `OPENCODE` — OpenCode
  - `CURSOR_AGENT` — Cursor agent
  - `QWEN_CODE` — Qwen Code
  - `COPILOT` — GitHub Copilot
  - `DROID` — Droid agent
- `repos`: Array of `{repo_id, base_branch}` objects
- `variant`: Optional executor variant

### Repository Scripts

**`mcp__vibe_kanban__update_setup_script(repo_id, script)`**
Set the script that runs when a workspace initializes (e.g., `npm install`).

**`mcp__vibe_kanban__update_cleanup_script(repo_id, script)`**
Set the script that runs when a workspace tears down.

**`mcp__vibe_kanban__update_dev_server_script(repo_id, script)`**
Set the dev server script (e.g., `npm run dev`).

## Ticket Status Lifecycle

```
todo ──→ inprogress ──→ inreview ──→ done
  │          │              │
  │          └──→ cancelled ←──┘
  └──→ cancelled
```

- `todo`: Created, not yet dispatched
- `inprogress`: Worker session launched
- `inreview`: Worker completed, awaiting PM review
- `done`: PM confirmed completion
- `cancelled`: Abandoned (replanned or removed)

## PM Usage Patterns

### Initial Setup (first /pm:start)

```
1. list_projects() → find project_id
2. list_repos(project_id) → find repo_id + base_branch
3. Save to .planning/config.json pm section
```

### Plan-to-Ticket Sync

```
For each PLAN.md:
  title = "Phase {X} Plan {Y}: {objective_summary}"
  description = full PLAN.md content
  create_task(project_id, title, description)
  → record ticket_id in TICKET-MAP.md
```

### Dispatch Workers

```
For each ticket in current wave with status=todo:
  start_workspace_session(
    task_id=ticket_id,
    executor=config.pm.default_executor,
    repos=[{repo_id, base_branch}]
  )
  update_task(ticket_id, status="inprogress")
```

### Monitor Cycle

```
tickets = list_tasks(project_id)
For each ticket:
  current = ticket.status
  previous = TICKET-MAP[ticket_id].status
  if current != previous:
    handle_transition(previous, current, ticket)
    update TICKET-MAP
```

### Replan Sync

```
# Cancel old tickets
For each obsolete ticket:
  update_task(ticket_id, status="cancelled")

# Create new tickets
For each new plan:
  create_task(project_id, title, description)

# Update modified tickets
For each changed plan:
  update_task(ticket_id, description=new_plan_content)
```
