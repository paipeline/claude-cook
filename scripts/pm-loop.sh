#!/bin/bash
# pm-loop.sh — Fully autonomous PM loop (Ralph-style)
#
# Runs an infinite loop. Each iteration invokes claude CLI with /gsd:pm-cycle —
# the full-brain PM that reads state, decides what to do, acts, and exits.
# Each invocation is a fresh 200k context — no context rot.
# State persists via .planning/ files.
#
# The PM brain handles the ENTIRE lifecycle autonomously:
#   plan → sync tickets → dispatch workers → monitor → replan → advance phases → complete milestone
#
# Usage:
#   ./scripts/pm-loop.sh [--phase=N] [--interval=60] [--max-iterations=50]
#   PM_PHASE=1 PM_POLL_INTERVAL=30 ./scripts/pm-loop.sh
#
# Stop:
#   touch .planning/.pm-stop
#   OR run /gsd:pm-stop
#
# Background:
#   nohup ./scripts/pm-loop.sh --phase=1 > .planning/pm-loop.log 2>&1 &

set -euo pipefail

# ─── Parse arguments ──────────────────────────────────────────────

PHASE="${PM_PHASE:-}"
INTERVAL="${PM_POLL_INTERVAL:-60}"
MAX_ITERS="${PM_MAX_ITERATIONS:-0}"  # 0 = unlimited

for arg in "$@"; do
  case $arg in
    --phase=*)
      PHASE="${arg#*=}"
      ;;
    --interval=*)
      INTERVAL="${arg#*=}"
      ;;
    --max-iterations=*)
      MAX_ITERS="${arg#*=}"
      ;;
    --help|-h)
      echo "Usage: pm-loop.sh [--phase=N] [--interval=60] [--max-iterations=0]"
      echo ""
      echo "Fully autonomous PM loop. Each cycle invokes /gsd:pm-cycle which"
      echo "reads state and decides what to do: plan, sync, dispatch, monitor,"
      echo "replan, advance phases, or complete milestone."
      echo ""
      echo "Options:"
      echo "  --phase=N           Starting phase number (auto-detected if omitted)"
      echo "  --interval=N        Seconds between cycles (default: 60)"
      echo "  --max-iterations=N  Safety cap on cycles (default: 0 = unlimited)"
      echo ""
      echo "Environment variables:"
      echo "  PM_PHASE             Phase number"
      echo "  PM_POLL_INTERVAL     Seconds between cycles (default: 60)"
      echo "  PM_MAX_ITERATIONS    Max cycles (default: 0 = unlimited)"
      echo ""
      echo "Stop: touch .planning/.pm-stop  OR  /gsd:pm-stop"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

# ─── Validate ─────────────────────────────────────────────────────

if [ ! -d ".planning" ]; then
  echo "ERROR: No .planning/ directory found."
  echo "Run /gsd:new-project first, then /gsd:pm-start"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  echo "ERROR: claude CLI not found in PATH."
  echo "Install: https://docs.anthropic.com/en/docs/claude-code"
  exit 1
fi

# ─── Configuration ────────────────────────────────────────────────

STOP_FILE=".planning/.pm-stop"
PID_FILE=".planning/.pm-loop-pid"
LOG_FILE=".planning/PM-LOG.md"
CYCLE=0

# Clean any stale stop signal
rm -f "$STOP_FILE"

# Record PID for /gsd:pm-stop
echo $$ > "$PID_FILE"

# ─── Init log ─────────────────────────────────────────────────────

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" << EOF
# PM Decision Log

Started: $TIMESTAMP
Mode: autonomous
Poll interval: ${INTERVAL}s
Phase: ${PHASE:-auto}
Max iterations: ${MAX_ITERS:-unlimited}

---

EOF
fi

echo "" >> "$LOG_FILE"
echo "## [$TIMESTAMP] INIT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "- PM loop started (PID: $$)" >> "$LOG_FILE"
echo "- Phase: ${PHASE:-auto-detect}" >> "$LOG_FILE"
echo "- Interval: ${INTERVAL}s" >> "$LOG_FILE"
echo "- Max iterations: ${MAX_ITERS:-unlimited}" >> "$LOG_FILE"

# ─── Main loop ────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PM Loop — Phase: ${PHASE:-auto} | Interval: ${INTERVAL}s"
echo " PID: $$ | Stop: touch $STOP_FILE"
if [ "$MAX_ITERS" -gt 0 ] 2>/dev/null; then
  echo " Max iterations: $MAX_ITERS"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

while true; do
  # ── Check stop signal ──
  if [ -f "$STOP_FILE" ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Stop signal received. Exiting."
    echo "" >> "$LOG_FILE"
    echo "## [$TIMESTAMP] STOP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "- PM loop stopped by stop file" >> "$LOG_FILE"
    echo "- Completed $CYCLE cycles" >> "$LOG_FILE"
    rm -f "$STOP_FILE" "$PID_FILE"
    exit 0
  fi

  # ── Max iterations guard ──
  CYCLE=$((CYCLE + 1))
  if [ "$MAX_ITERS" -gt 0 ] 2>/dev/null && [ "$CYCLE" -gt "$MAX_ITERS" ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Max iterations ($MAX_ITERS) reached. Stopping."
    echo "" >> "$LOG_FILE"
    echo "## [$TIMESTAMP] MAX_ITERATIONS" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "- Reached max iterations: $MAX_ITERS" >> "$LOG_FILE"
    rm -f "$PID_FILE"
    exit 0
  fi

  # ── Run one brain cycle ──
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Cycle #$CYCLE — brain thinking..."

  # Build the prompt
  if [ -n "$PHASE" ]; then
    PROMPT="/gsd:pm-cycle $PHASE"
  else
    PROMPT="/gsd:pm-cycle"
  fi

  # Fresh Claude invocation — full brain, fresh 200k context
  claude -p --dangerously-skip-permissions "$PROMPT" 2>&1
  EXIT_CODE=$?

  # ── Handle exit codes ──
  case $EXIT_CODE in
    0)
      # Normal — more work to do, continue loop
      ;;
    42)
      # Milestone complete — all done
      TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
      echo ""
      echo "[$TIMESTAMP] Milestone complete! PM loop exiting."
      echo "" >> "$LOG_FILE"
      echo "## [$TIMESTAMP] LOOP_EXIT" >> "$LOG_FILE"
      echo "" >> "$LOG_FILE"
      echo "- Milestone complete after $CYCLE cycles" >> "$LOG_FILE"
      rm -f "$PID_FILE"
      exit 0
      ;;
    *)
      # Error — log and continue (don't crash the loop)
      TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
      echo "[$TIMESTAMP] WARNING: claude exited with code $EXIT_CODE (cycle #$CYCLE)"
      echo "" >> "$LOG_FILE"
      echo "## [$TIMESTAMP] ERROR" >> "$LOG_FILE"
      echo "" >> "$LOG_FILE"
      echo "- Claude exited with code $EXIT_CODE on cycle #$CYCLE" >> "$LOG_FILE"
      ;;
  esac

  echo ""

  # ── Sleep until next cycle ──
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Next cycle in ${INTERVAL}s..."
  sleep "$INTERVAL"
done
