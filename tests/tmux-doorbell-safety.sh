#!/usr/bin/env bash
# Mock-backed proof that adapters/tmux.sh never injects keystrokes into a live
# target unless the caller explicitly opts in via LETTERBOX_TMUX_SUBMIT=1.
#
# Runs anywhere: a real tmux server is never started. The adapter calls `tmux`
# directly, so the mock is placed on PATH.
#
# The adapter resolves a target two different ways, and this exercises BOTH:
#   %pane-id     -> tmux list-panes -a -F '#{pane_id}' | grep -Fx
#   session-name -> tmux has-session -t
# The mock answers each accordingly, so target resolution genuinely happens.
# A mock that merely exited 0 would make the adapter defer at lookup, and the
# refusal assertions would then pass for a reason unrelated to the submit gate.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
adapter="$root/adapters/tmux.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

PANE='%1'
SESSION='letterbox-mock-session'

mockbin="$work/bin"; mkdir -p "$mockbin"
cat > "$mockbin/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
case "$1" in
  list-panes)   printf '%s\n' "$MOCK_PANE" ;;   # satisfies grep -Fx "$t"
  has-session)  exit 0 ;;                        # named session is "live"
esac
exit 0
MOCK
chmod +x "$mockbin/tmux"

box="$work/box"; mkdir -p "$box/reviewer/inbox"
registry="$box/tmux-agents.tsv"
patterns="$work/tmux-patterns.tsv"

MOCK_LOG="$work/tmux-calls.log"
export MOCK_LOG MOCK_PANE="$PANE"

fails=0
fail() { printf 'FAIL: %s\n' "$*" >&2; cat "$MOCK_LOG" >&2; fails=$((fails+1)); }
injected() { grep -qE '^send-keys ' "$MOCK_LOG"; }

# $1 = "registry" | "patterns"
run_adapter() {
  : > "$MOCK_LOG"; : > "$work/stderr"
  if [[ "$1" == registry ]]; then
    printf 'reviewer\t%s\t%s\t0\n' "$PANE" "$SESSION" > "$registry"
    env PATH="$mockbin:$PATH" LETTERBOX_DIR="$box" MOCK_LOG="$MOCK_LOG" MOCK_PANE="$PANE" \
      ${LETTERBOX_TMUX_SUBMIT+LETTERBOX_TMUX_SUBMIT="$LETTERBOX_TMUX_SUBMIT"} \
      "$adapter" reviewer delegate smoke-test >/dev/null 2>"$work/stderr"
  else
    rm -f "$registry"
    printf 'reviewer\t%s\n' "$SESSION" > "$patterns"
    env PATH="$mockbin:$PATH" LETTERBOX_DIR="$box" LETTERBOX_TMUX_PATTERNS="$patterns" \
      MOCK_LOG="$MOCK_LOG" MOCK_PANE="$PANE" \
      ${LETTERBOX_TMUX_SUBMIT+LETTERBOX_TMUX_SUBMIT="$LETTERBOX_TMUX_SUBMIT"} \
      "$adapter" reviewer delegate smoke-test >/dev/null 2>"$work/stderr"
  fi
}

assert_resolved() { # proves lookup happened rather than deferring
  local how="$1"
  grep -q 'deferred' "$work/stderr" && fail "adapter deferred on the $how path — the mock target was NOT found, so the refusal checks prove nothing"
  case "$how" in
    registry) grep -q '^list-panes ' "$MOCK_LOG" || fail 'registry path never called list-panes — pane resolution not exercised';;
    patterns) grep -q '^has-session ' "$MOCK_LOG" || fail 'patterns path never called has-session — session resolution not exercised';;
  esac
}

for how in registry patterns; do
  # --- unset: must never inject, but must still notify ---
  unset LETTERBOX_TMUX_SUBMIT || true
  before=$fails
  run_adapter "$how"
  assert_resolved "$how"
  injected && fail "[$how] tmux send-keys called without LETTERBOX_TMUX_SUBMIT=1"
  grep -q '^display-message ' "$MOCK_LOG" || fail "[$how] expected the safe display-message to still fire"
  (( fails == before )) && printf 'PASS: [%s] no keystroke injection without opt-in\n' "$how"

  # --- explicit 0: same ---
  before=$fails
  LETTERBOX_TMUX_SUBMIT=0 run_adapter "$how"
  injected && fail "[$how] tmux injected with LETTERBOX_TMUX_SUBMIT=0"
  (( fails == before )) && printf 'PASS: [%s] explicit 0 also refuses\n' "$how"

  # --- opt-in: MUST inject to the resolved target, and MUST send Enter ---
  before=$fails
  LETTERBOX_TMUX_SUBMIT=1 run_adapter "$how"
  assert_resolved "$how"
  target=$([[ "$how" == registry ]] && printf '%s' "$PANE" || printf '%s' "$SESSION")
  grep -qE "^send-keys -t ${target//%/\\%} -l " "$MOCK_LOG" \
    || fail "[$how] opt-in did not send the doorbell text to the resolved target ($target)"
  grep -qE "^send-keys -t ${target//%/\\%} Enter$" "$MOCK_LOG" \
    || fail "[$how] opt-in sent text but never sent Enter"
  (( fails == before )) && printf 'PASS: [%s] explicit opt-in injects into the resolved target (%s)\n' "$how" "$target"
  unset LETTERBOX_TMUX_SUBMIT || true
done

if (( fails > 0 )); then
  printf 'tmux-doorbell-safety test: FAIL (%d)\n' "$fails" >&2
  exit 1
fi
printf 'tmux-doorbell-safety test: PASS\n'
