# PM Configuration Reference

The `pm` section in `.planning/config.json` controls Product Manager behavior.

## Fields

```json
{
  "pm": {
    "mode": "autonomous",
    "poll_interval_seconds": 60,
    "project_id": null,
    "repos": [],
    "default_executor": "CLAUDE_CODE",
    "auto_replan_on_failure": true,
    "auto_dispatch_next_wave": true,
    "max_replan_attempts": 3
  }
}
```

### mode
- `"autonomous"` — PM loop runs via pm-loop.sh, auto-reacts to ticket changes
- `"manual"` — User triggers /pm:check manually

### poll_interval_seconds
How often pm-loop.sh invokes /pm:check. Default: 60.

### project_id
Vibe Kanban project UUID. Auto-detected on first /pm:start via list_projects().

### repos
Array of `{repo_id, base_branch}` for dispatch. Auto-detected on first /pm:start via list_repos().

Example:
```json
"repos": [
  {"repo_id": "abc-123", "base_branch": "main"}
]
```

### default_executor
Which external agent to dispatch. Options:
`CLAUDE_CODE`, `AMP`, `GEMINI`, `CODEX`, `OPENCODE`, `CURSOR_AGENT`, `QWEN_CODE`, `COPILOT`, `DROID`

### auto_replan_on_failure
- `true` — PM auto-spawns planner on ticket failure, creates fix tickets, dispatches
- `false` — PM logs failure and waits for user `/pm:replan`

### auto_dispatch_next_wave
- `true` — When all wave N tickets are done, auto-dispatch wave N+1
- `false` — Log wave completion and wait for user

### max_replan_attempts
Max consecutive replans before escalating to human. Prevents infinite replan loops.
