#!/usr/bin/env bash
# Live disposable tmux proof for the opt-in automatic doorbell (static patterns).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
adapter="$root/adapters/tmux.sh"
session="letterbox-doorbell-test-$$"
tmp="$(mktemp -d)"
trap 'tmux kill-session -t "$session" 2>/dev/null || true; rm -rf "$tmp"' EXIT

command -v tmux >/dev/null 2>&1 || {
  echo 'tmux doorbell test: SKIP (tmux unavailable)'
  [[ "${LETTERBOX_REQUIRE_TMUX:-}" == 1 ]] && exit 1
  exit 0
}
printf 'receiver\t%s\n' "$session" > "$tmp/patterns.tsv"
# cat echoes received input into the pane, allowing capture-pane verification.
tmux new-session -d -s "$session" 'cat'

LETTERBOX_DIR="$tmp/box" \
LETTERBOX_TMUX_PATTERNS="$tmp/patterns.tsv" \
LETTERBOX_TMUX_SUBMIT=1 \
"$adapter" receiver delegate smoke-test

sleep 1
# -J joins soft wraps and keeps the wrap-edge space. Do not strip newlines:
# that would glue a hard line break into a false one-line match.
received="$(tmux capture-pane -p -J -t "$session")"
expected="📬 letterbox doorbell: unacked delegate in $tmp/box/receiver/inbox/ — please check"
printf '%s\n' "$received" | grep -F "$expected" >/dev/null
printf '%s\n' 'tmux automatic doorbell test: PASS'
