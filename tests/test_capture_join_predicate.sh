#!/usr/bin/env bash
# Offline predicate for the capture-pane -p -J pipeline. Does not call tmux.
# Mocks the text that -J would return (soft wraps joined, spaces kept, hard
# newlines kept). Native tmux is not invoked.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

box="/tmp/tmp.XXXXXXXXXX/box"
expected="📬 letterbox doorbell: unacked delegate in $box/alpha/inbox/ — please check"

assert_match() {
  local label="$1" received="$2"
  if printf '%s\n' "$received" | grep -F "$expected" >/dev/null; then
    pass "mock accepted: $label"
  else
    fail "mock should accept $label"
  fi
}
assert_reject() {
  local label="$1" received="$2"
  if printf '%s\n' "$received" | grep -F "$expected" >/dev/null; then
    fail "mock should reject $label (got a match)"
  else
    pass "mock rejected: $label"
  fi
}

# Valid -J join: wrap-edge space before em dash retained; optional trailing newline.
assert_match "joined text with space before em dash" \
  "$expected"$'\n'

# Without -J, wrap at the space before — drops that space.
assert_reject "missing wrap-edge space (inbox/—)" \
  "📬 letterbox doorbell: unacked delegate in $box/alpha/inbox/— please check"

# Hard newline kept (we no longer tr -d '\\n'): must not reassemble.
assert_reject "hard-broken across a real newline" \
  "📬 letterbox doorbell: unacked delegate in $box/alpha/inbox/"$'\n'" — please check"

echo "capture-join predicate (mock, not native tmux): PASS"
