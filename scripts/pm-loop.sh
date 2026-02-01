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
# RUNS IN FOREGROUND by default — you see live progress.
# Use --background to detach (output goes to .planning/pm-loop.log).
#
# Usage:
#   ./scripts/pm-loop.sh [--phase=N] [--interval=60] [--max-iterations=50]
#   PM_PHASE=1 PM_POLL_INTERVAL=30 ./scripts/pm-loop.sh
#
# Stop:
#   touch .planning/.pm-stop
#   OR run /gsd:pm-stop
#   OR Ctrl+C (foreground mode)

set -euo pipefail

# ─── Parse arguments ──────────────────────────────────────────────

PHASE="${PM_PHASE:-}"
INTERVAL="${PM_POLL_INTERVAL:-60}"
MAX_ITERS="${PM_MAX_ITERATIONS:-0}"  # 0 = unlimited
BACKGROUND=false
NOTIFY=true

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
    --background)
      BACKGROUND=true
      ;;
    --no-notify)
      NOTIFY=false
      ;;
    --help|-h)
      echo "Usage: pm-loop.sh [--phase=N] [--interval=60] [--max-iterations=0]"
      echo ""
      echo "Fully autonomous PM loop. Each cycle invokes /gsd:pm-cycle which"
      echo "reads state and decides what to do: plan, sync, dispatch, monitor,"
      echo "replan, advance phases, or complete milestone."
      echo ""
      echo "Runs in FOREGROUND by default — you see live progress."
      echo ""
      echo "Options:"
      echo "  --phase=N           Starting phase number (auto-detected if omitted)"
      echo "  --interval=N        Seconds between cycles (default: 60)"
      echo "  --max-iterations=N  Safety cap on cycles (default: 0 = unlimited)"
      echo "  --background        Detach and run in background (logs to pm-loop.log)"
      echo "  --no-notify         Disable desktop notifications"
      echo ""
      echo "Environment variables:"
      echo "  PM_PHASE             Phase number"
      echo "  PM_POLL_INTERVAL     Seconds between cycles (default: 60)"
      echo "  PM_MAX_ITERATIONS    Max cycles (default: 0 = unlimited)"
      echo ""
      echo "Stop: touch .planning/.pm-stop  OR  /gsd:pm-stop  OR  Ctrl+C"
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

# ─── Background mode: re-exec detached ───────────────────────────

if [ "$BACKGROUND" = true ]; then
  # Strip --background from args, re-exec with nohup
  ARGS=()
  for arg in "$@"; do
    [ "$arg" != "--background" ] && ARGS+=("$arg")
  done
  nohup "$0" "${ARGS[@]}" > .planning/pm-loop.log 2>&1 &
  BG_PID=$!
  echo "$BG_PID" > .planning/.pm-loop-pid
  echo "PM loop launched in background (PID: $BG_PID)"
  echo "Log: tail -f .planning/pm-loop.log"
  echo "Stop: touch .planning/.pm-stop"
  exit 0
fi

# ─── Desktop notification helper ─────────────────────────────────

notify() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"  # normal, critical

  if [ "$NOTIFY" = false ]; then
    return
  fi

  # macOS
  if command -v osascript &> /dev/null; then
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    # Sound for critical events
    if [ "$urgency" = "critical" ]; then
      afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    fi
    return
  fi

  # Linux
  if command -v notify-send &> /dev/null; then
    local urgency_flag="normal"
    [ "$urgency" = "critical" ] && urgency_flag="critical"
    notify-send -u "$urgency_flag" "$title" "$message" 2>/dev/null || true
    return
  fi
}

# ─── Progress summary helper ─────────────────────────────────────

print_progress() {
  # Read TICKET-MAP.md for quick progress snapshot
  local ticket_map=""
  ticket_map=$(find .planning/phases/ -name "TICKET-MAP.md" -print -quit 2>/dev/null || true)

  if [ -n "$ticket_map" ] && [ -f "$ticket_map" ]; then
    local done_count=$(grep -c "| done " "$ticket_map" 2>/dev/null || echo "0")
    local inprogress_count=$(grep -c "| inprogress " "$ticket_map" 2>/dev/null || echo "0")
    local todo_count=$(grep -c "| todo " "$ticket_map" 2>/dev/null || echo "0")
    local total=$((done_count + inprogress_count + todo_count))

    if [ "$total" -gt 0 ]; then
      # Build progress bar
      local pct=0
      if [ "$total" -gt 0 ]; then
        pct=$((done_count * 100 / total))
      fi
      local bar_len=20
      local filled=$((pct * bar_len / 100))
      local empty=$((bar_len - filled))
      local bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done

      echo "  ┌─────────────────────────────────────────┐"
      echo "  │  Progress: [$bar] ${pct}%"
      echo "  │  Done: $done_count  Running: $inprogress_count  Todo: $todo_count  Total: $total"
      echo "  └─────────────────────────────────────────┘"
    fi
  fi
}

# ─── Graceful Ctrl+C handling ────────────────────────────────────

cleanup() {
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo ""
  echo "[$TIMESTAMP] PM loop interrupted (Ctrl+C). Cleaning up..."
  echo "" >> "$LOG_FILE"
  echo "## [$TIMESTAMP] INTERRUPTED" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "- PM loop interrupted by user" >> "$LOG_FILE"
  echo "- Completed $CYCLE cycles" >> "$LOG_FILE"
  rm -f "$PID_FILE"
  notify "GSD PM" "PM loop stopped by user after $CYCLE cycles"
  exit 0
}
trap cleanup SIGINT SIGTERM

# ─── Configuration ────────────────────────────────────────────────

STOP_FILE=".planning/.pm-stop"
PID_FILE=".planning/.pm-loop-pid"
LOG_FILE=".planning/PM-LOG.md"
CYCLE=0
ERROR_STREAK=0
MAX_ERROR_STREAK=5

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

# ─── Startup banner ──────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PM ► AUTONOMOUS MODE ACTIVE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Phase: ${PHASE:-auto-detect}"
echo "  Interval: ${INTERVAL}s"
echo "  PID: $$"
if [ "$MAX_ITERS" -gt 0 ] 2>/dev/null; then
  echo "  Max iterations: $MAX_ITERS"
fi
echo ""
echo "  Stop: Ctrl+C  |  touch .planning/.pm-stop  |  /gsd:pm-stop"
echo ""
echo "  The PM will autonomously:"
echo "    plan → sync → dispatch → monitor → replan → advance phases"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

notify "GSD PM" "Autonomous PM started for Phase ${PHASE:-auto}" "normal"

# ─── Main loop ────────────────────────────────────────────────────

while true; do
  # ── Check stop signal ──
  if [ -f "$STOP_FILE" ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " PM ► STOPPED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  [$TIMESTAMP] Stop signal received after $CYCLE cycles."
    echo ""
    echo "" >> "$LOG_FILE"
    echo "## [$TIMESTAMP] STOP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "- PM loop stopped by stop file" >> "$LOG_FILE"
    echo "- Completed $CYCLE cycles" >> "$LOG_FILE"
    rm -f "$STOP_FILE" "$PID_FILE"
    notify "GSD PM" "PM loop stopped after $CYCLE cycles"
    exit 0
  fi

  # ── Max iterations guard ──
  CYCLE=$((CYCLE + 1))
  if [ "$MAX_ITERS" -gt 0 ] 2>/dev/null && [ "$CYCLE" -gt "$MAX_ITERS" ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " PM ► MAX ITERATIONS REACHED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Completed $((CYCLE - 1)) cycles. Safety cap: $MAX_ITERS."
    echo ""
    echo "" >> "$LOG_FILE"
    echo "## [$TIMESTAMP] MAX_ITERATIONS" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "- Reached max iterations: $MAX_ITERS" >> "$LOG_FILE"
    rm -f "$PID_FILE"
    notify "GSD PM" "PM loop reached max iterations ($MAX_ITERS)" "normal"
    exit 0
  fi

  # ── Cycle header ──
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "┌─────────────────────────────────────────────────────"
  echo "│ Cycle #$CYCLE — $TIMESTAMP"
  echo "└─────────────────────────────────────────────────────"
  echo ""

  # Build the prompt
  # Only pass phase hint on cycle 1 — after that, pm-cycle auto-detects
  # from STATE.md so it can advance through phases autonomously.
  if [ "$CYCLE" -eq 1 ] && [ -n "$PHASE" ]; then
    PROMPT="/gsd:pm-cycle $PHASE"
  else
    PROMPT="/gsd:pm-cycle"
  fi

  # Fresh Claude invocation — full brain, fresh 200k context
  # Output streams directly to terminal (foreground mode)
  CYCLE_START=$(date +%s)
  claude -p --dangerously-skip-permissions "$PROMPT" 2>&1
  EXIT_CODE=$?
  CYCLE_END=$(date +%s)
  CYCLE_DURATION=$((CYCLE_END - CYCLE_START))

  echo ""

  # ── Handle exit codes ──
  case $EXIT_CODE in
    0)
      # Normal — more work to do
      ERROR_STREAK=0
      print_progress
      echo ""
      echo "  Cycle #$CYCLE completed in ${CYCLE_DURATION}s. Next in ${INTERVAL}s..."
      echo ""
      ;;
    42)
      # Milestone complete — all done!
      TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " PM ► MILESTONE COMPLETE"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "  All phases complete after $CYCLE cycles."
      echo "  Run /gsd:complete-milestone to archive."
      echo ""
      print_progress
      echo ""
      echo "" >> "$LOG_FILE"
      echo "## [$TIMESTAMP] LOOP_EXIT" >> "$LOG_FILE"
      echo "" >> "$LOG_FILE"
      echo "- Milestone complete after $CYCLE cycles" >> "$LOG_FILE"
      rm -f "$PID_FILE"
      notify "GSD PM" "Milestone complete! All phases done after $CYCLE cycles." "critical"
      exit 0
      ;;
    *)
      # Error — log and continue (don't crash the loop)
      ERROR_STREAK=$((ERROR_STREAK + 1))
      TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
      echo "  ⚠ Cycle #$CYCLE failed (exit code $EXIT_CODE, streak: $ERROR_STREAK/$MAX_ERROR_STREAK)"
      echo "" >> "$LOG_FILE"
      echo "## [$TIMESTAMP] ERROR" >> "$LOG_FILE"
      echo "" >> "$LOG_FILE"
      echo "- Claude exited with code $EXIT_CODE on cycle #$CYCLE" >> "$LOG_FILE"
      echo "- Error streak: $ERROR_STREAK/$MAX_ERROR_STREAK" >> "$LOG_FILE"

      # Notify on errors
      notify "GSD PM" "Cycle #$CYCLE failed (code $EXIT_CODE)" "critical"

      # Stop if too many consecutive errors
      if [ "$ERROR_STREAK" -ge "$MAX_ERROR_STREAK" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " PM ► ERROR — TOO MANY FAILURES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  $ERROR_STREAK consecutive errors. Stopping to prevent waste."
        echo "  Check .planning/PM-LOG.md for details."
        echo "  Fix the issue, then restart with /gsd:pm-start"
        echo ""
        echo "" >> "$LOG_FILE"
        echo "## [$TIMESTAMP] ERROR_STREAK_HALT" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "- Halted after $ERROR_STREAK consecutive errors" >> "$LOG_FILE"
        rm -f "$PID_FILE"
        notify "GSD PM" "PM halted: $ERROR_STREAK consecutive errors" "critical"
        exit 1
      fi
      ;;
  esac

  # ── Countdown to next cycle ──
  for ((remaining=INTERVAL; remaining>0; remaining--)); do
    # Check stop signal during sleep too
    if [ -f "$STOP_FILE" ]; then
      break
    fi
    # Show countdown every 15 seconds
    if [ $((remaining % 15)) -eq 0 ] && [ "$remaining" -ne "$INTERVAL" ]; then
      echo "  ... next cycle in ${remaining}s"
    fi
    sleep 1
  done
done
