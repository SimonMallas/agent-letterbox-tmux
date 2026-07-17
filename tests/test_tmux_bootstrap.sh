#!/usr/bin/env bash
# Dependency-free proofs for tmux setup, live register via tmux run, and registry-first doorbell.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
letterbox="$root/bin/letterbox"
adapter="$root/adapters/tmux.sh"
tmp="$(mktemp -d)"
session="lb-boot-$$"
trap 'tmux kill-session -t "$session" 2>/dev/null || true; rm -rf "$tmp"' EXIT

command -v tmux >/dev/null 2>&1 || { echo 'tmux bootstrap test: SKIP (tmux unavailable)'; exit 0; }

box="$tmp/box"

# --- setup ---
HOME="$tmp/home" \
LETTERBOX_BIN_DIR="$tmp/bin" \
LETTERBOX_SKILLS_DIR="$tmp/skills" \
"$letterbox" tmux setup --agents alpha,beta --dir "$box" --automatic-doorbells >/dev/null

test -f "$box/env.sh"
test -f "$box/tmux-agents.tsv"
test -f "$box/tmux-patterns.tsv"
test -d "$box/alpha/inbox"
grep -q 'adapters/tmux.sh' "$box/env.sh"
grep -q 'LETTERBOX_TMUX_SUBMIT=1' "$box/env.sh"
grep -q 'LETTERBOX_TMUX_REGISTRY=' "$box/env.sh"
test -L "$tmp/bin/letterbox"
if grep -qi cmux "$box/env.sh"; then
  echo 'setup env still mentions cmux' >&2
  exit 1
fi
printf '%s\n' 'tmux setup: PASS'

# --- real live-pane proof: letterbox tmux run must register (no hand-written registry) ---
: > "$box/tmux-patterns.tsv"
# cat keeps the pane alive and echoes injected doorbell text for capture-pane
tmux new-session -d -s "$session" \
  "export LETTERBOX_DIR='$box' LETTERBOX_TMUX_REGISTRY='$box/tmux-agents.tsv' PATH='$root/bin:'\"\$PATH\"; letterbox tmux run alpha -- cat"

registered=0
for _ in $(seq 1 50); do
  if grep -q $'^alpha\t' "$box/tmux-agents.tsv" 2>/dev/null; then
    registered=1
    break
  fi
  sleep 0.1
done
if [[ "$registered" != 1 ]]; then
  echo 'letterbox tmux run did not register alpha in tmux-agents.tsv' >&2
  echo '--- registry ---' >&2
  cat "$box/tmux-agents.tsv" >&2 || true
  echo '--- pane ---' >&2
  tmux capture-pane -p -t "$session" 2>/dev/null >&2 || true
  exit 1
fi
printf '%s\n' 'tmux run live register: PASS'

out="$(LETTERBOX_DIR="$box" LETTERBOX_TMUX_REGISTRY="$box/tmux-agents.tsv" "$letterbox" tmux status)"
printf '%s\n' "$out" | grep -q 'alpha' || { echo "status missing alpha: $out" >&2; exit 1; }
printf '%s\n' 'tmux status: PASS'

pane="$(awk -F '\t' '$1 == "alpha" { print $2; exit }' "$box/tmux-agents.tsv")"
test -n "$pane"
tmux list-panes -a -F '#{pane_id}' | grep -Fx "$pane" >/dev/null || {
  echo "registered pane not live: $pane" >&2
  exit 1
}

# --- registry-first doorbell ---
LETTERBOX_DIR="$box" \
LETTERBOX_TMUX_REGISTRY="$box/tmux-agents.tsv" \
LETTERBOX_TMUX_PATTERNS="$box/tmux-patterns.tsv" \
LETTERBOX_TMUX_SUBMIT=1 \
"$adapter" alpha delegate boot-test

sleep 0.8
received="$(tmux capture-pane -p -t "$pane" | tr -d '\n')"
expected="📬 letterbox doorbell: unacked delegate in $box/alpha/inbox/ — please check"
printf '%s\n' "$received" | grep -F "$expected" >/dev/null || {
  echo "doorbell not found in pane. got: $received" >&2
  exit 1
}
printf '%s\n' 'registry-first live doorbell: PASS'

LETTERBOX_DIR="$box" LETTERBOX_TMUX_REGISTRY="$box/tmux-agents.tsv" \
  "$letterbox" tmux unregister alpha >/dev/null
if grep -q $'^alpha\t' "$box/tmux-agents.tsv" 2>/dev/null; then
  echo 'unregister failed' >&2
  exit 1
fi
printf '%s\n' 'tmux unregister: PASS'

if "$letterbox" cmux status 2>/dev/null; then
  echo 'cmux subcommand still present' >&2
  exit 1
fi
if "$letterbox" 2>&1 | grep -qi cmux; then
  echo 'usage still mentions cmux' >&2
  exit 1
fi
printf '%s\n' 'cmux CLI removed: PASS'

printf '%s\n' 'tmux bootstrap suite: PASS'
