#!/usr/bin/env bash
# Release 2 W2 — tmux edition end-to-end: bin/letterbox send --now with a fake
# tmux and the real adapter. Everything faked inside this temp dir; no real
# tmux server, no real letterbox state, no credentials.
set -euo pipefail

EDITION="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ROOT="$(mktemp -d /tmp/r2tmux-test.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT

mkdir -p "$ROOT/bin" "$ROOT/bin-notmux" "$ROOT/box/agent/inbox" \
         "$ROOT/box/agent/processed" "$ROOT/box/tester/inbox" \
         "$ROOT/box/tester/processed"

# Registry variants: pinned pane, dead pane, session-name form.
printf 'agent\t%%1\tsess-main\t2026-09-16T00:00:00Z\n' > "$ROOT/registry-pane.tsv"
printf 'agent\t%%9\tsess-main\t2026-09-16T00:00:00Z\n' > "$ROOT/registry-dead.tsv"
printf 'agent\tsess-main\tsess-main\t2026-09-16T00:00:00Z\n' > "$ROOT/registry-session.tsv"
printf 'agent\tsess-main\n' > "$ROOT/patterns.tsv"

export BOX="$ROOT/box" LETTERBOX_DIR="$ROOT/box" LETTERBOX_AGENT=tester
export LETTERBOX_DOORBELL_TIMEOUT=3

# Fake tmux (behavior by env) --------------------------------------------------
cat > "$ROOT/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -uo pipefail
log="${TMUX_FAKE_LOG:?}"
printf '%s\n' "$*" >> "$log"
case "${1:-}" in
  list-panes)
    case "${TMUX_FAKE_LIST:-ok}" in
      ok)      printf '%%1\n';;
      sleep)   sleep "${TMUX_FAKE_SLEEP:-5}";;
      exit124) exit 124;;
    esac
    exit 0;;
  has-session)
    case "${TMUX_FAKE_HASSESSION:-ok}" in
      ok) exit 0;; fail) exit 1;; sleep) sleep "${TMUX_FAKE_SLEEP:-5}";;
    esac
    exit 0;;
  display-message)
    if [[ "${2:-}" == "-p" ]]; then
      case "${TMUX_FAKE_RESOLVE:-ok}" in
        ok)     printf '%%1\n';;
        badval) printf 'sess-main\n';;
        fail)   exit 1;;
        sleep)  sleep "${TMUX_FAKE_SLEEP:-5}";;
      esac
    else
      case "${TMUX_FAKE_DISPLAY:-ok}" in
        ok) :;; sleep) sleep "${TMUX_FAKE_SLEEP:-5}";;
      esac
    fi
    exit 0;;
  send-keys)
    if [[ "$*" == *" -l "* ]]; then
      case "${TMUX_FAKE_SEND:-ok}" in
        ok) exit 0;; fail) exit 1;; sleep) sleep "${TMUX_FAKE_SLEEP:-5}";; exit124) exit 124;;
      esac
    else
      case "${TMUX_FAKE_ENTER:-ok}" in
        ok) exit 0;; fail) exit 1;; sleep) sleep "${TMUX_FAKE_SLEEP:-5}";;
      esac
    fi
    exit 0;;
esac
exit 0
TMUX
chmod +x "$ROOT/bin/tmux"
export PATH="$ROOT/bin:$PATH"
export TMUX_FAKE_LOG="$ROOT/tmux.log"
export LETTERBOX_DOORBELL="$EDITION/adapters/tmux.sh"
export LETTERBOX_TMUX_SUBMIT=1

# Misbehaving doorbells for wrapper classifier edge cases.
cat > "$ROOT/garbage.sh" <<'SH'
#!/usr/bin/env bash
echo 'not a contract line'
SH
cat > "$ROOT/double.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
SH
cat > "$ROOT/valid-exit1.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
exit 1
SH
cat > "$ROOT/line-hang.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
sleep 30
SH
cat > "$ROOT/spawn-hang.sh" <<'SH'
#!/usr/bin/env bash
sleep 60 & echo $! > "$GC_PID_FILE"
sleep 60
SH
chmod +x "$ROOT/garbage.sh" "$ROOT/double.sh" "$ROOT/valid-exit1.sh" "$ROOT/line-hang.sh" "$ROOT/spawn-hang.sh"

# Minimal PATH farm without tmux (adapter-level adapter_unavailable case).
for t in bash python3 grep awk sed shasum od tr date mktemp ln rm cat \
         dirname basename env; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$src" ]] && ln -sf "$src" "$ROOT/bin-notmux/$t"
done

# PATH farm WITH the fake tmux but WITHOUT python3: a missing runner must be
# adapter_unavailable (non-retryable), never helper_timeout.
mkdir -p "$ROOT/bin-nopython"
for t in bash grep awk sed shasum od tr date mktemp ln rm cat \
         dirname basename env sleep; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$src" ]] && ln -sf "$src" "$ROOT/bin-nopython/$t"
done
ln -sf "$ROOT/bin/tmux" "$ROOT/bin-nopython/tmux"

send_now() { # $1.. = env overrides (must trail base assignments to win)
  env BOX="$BOX" LETTERBOX_AGENT=tester LETTERBOX_DIR="$BOX" \
    LETTERBOX_DOORBELL="$LETTERBOX_DOORBELL" LETTERBOX_TMUX_SUBMIT="$LETTERBOX_TMUX_SUBMIT" \
    LETTERBOX_DOORBELL_TIMEOUT="$LETTERBOX_DOORBELL_TIMEOUT" \
    LETTERBOX_TMUX_REGISTRY="$ROOT/registry-pane.tsv" LETTERBOX_TMUX_PATTERNS= \
    PATH="$PATH" TMUX_FAKE_LOG="$TMUX_FAKE_LOG" "$@" \
    bash -c 'printf "test body\n" | "$0" send agent info testslug --now' "$EDITION/bin/letterbox" 2>/dev/null
}

one_line() {
  local out="$1" n
  n="$(printf '%s\n' "$out" | grep -c '^doorbell-outcome ' || true)"
  [[ "$n" == "1" ]] || { echo "SOLE-EMISSION FAIL ($n lines): $out"; exit 1; }
}

craft_letter() { # $1=from $2=id — hand-write a durable letter into agent's inbox
  cat > "$BOX/agent/inbox/$2.md" <<EOF
---
id: $2
from: $1
to: agent
type: info
re:
priority: later
requires_ack: false
deadline:
---
crafted body
EOF
}

nudge() { # $1=id — re-ring an existing letter through the full wrapper path
  env BOX="$BOX" LETTERBOX_AGENT=tester LETTERBOX_DIR="$BOX" \
    LETTERBOX_DOORBELL="$LETTERBOX_DOORBELL" LETTERBOX_TMUX_SUBMIT=1 \
    LETTERBOX_DOORBELL_TIMEOUT="$LETTERBOX_DOORBELL_TIMEOUT" \
    LETTERBOX_TMUX_REGISTRY="$ROOT/registry-pane.tsv" LETTERBOX_TMUX_PATTERNS= \
    PATH="$PATH" TMUX_FAKE_LOG="$TMUX_FAKE_LOG" \
    "$EDITION/bin/letterbox" nudge "$1" 2>/dev/null
}

pass=0
check() { # $1=name $2=env-string $3=expected
  local name="$1" envs="$2" expected="$3" out
  out="$(send_now $envs)"
  one_line "$out"
  out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
  if [[ "$out" == "$expected" ]]; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name"; echo "  expected: $expected"; echo "  got:      $out"; exit 1
  fi
}

check "submitted via registry pane"      "" \
  'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
# The injected line carries the v0.3 opaque token derived from the letter id,
# and names the durable letter's sender (from tester).
if grep -Eq "send-keys -t %1 -l 📬 letterbox ""doorbell: unacked info from tester in .*/agent/inbox/ — please check · [0-9a-f]{8}" "$TMUX_FAKE_LOG"; then
  echo "PASS: injected line carries sender + v0.3 token"; pass=$((pass+1))
else
  echo "FAIL: injected line carries sender + v0.3 token"; cat "$TMUX_FAKE_LOG"; exit 1
fi
check "list-panes timeout → helper_timeout" "TMUX_FAKE_LIST=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=helper_timeout target=-'
check "registry pane dead → surface_not_found" "LETTERBOX_TMUX_REGISTRY=$ROOT/registry-dead.tsv" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "registry session form → resolved pinned pane" "LETTERBOX_TMUX_REGISTRY=$ROOT/registry-session.tsv" \
  'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
check "session resolve fail → surface_not_found" "LETTERBOX_TMUX_REGISTRY=$ROOT/registry-session.tsv TMUX_FAKE_RESOLVE=fail" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "session resolve bad value → surface_not_found" "LETTERBOX_TMUX_REGISTRY=$ROOT/registry-session.tsv TMUX_FAKE_RESOLVE=badval" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "session resolve timeout → helper_timeout" "LETTERBOX_TMUX_REGISTRY=$ROOT/registry-session.tsv TMUX_FAKE_RESOLVE=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=helper_timeout target=-'
check "patterns fallback session → submitted" "LETTERBOX_TMUX_REGISTRY=$ROOT/missing.tsv LETTERBOX_TMUX_PATTERNS=$ROOT/patterns.tsv" \
  'doorbell-outcome v=1 outcome=submitted reason=- target=%1'
check "has-session timeout → helper_timeout" "LETTERBOX_TMUX_REGISTRY=$ROOT/missing.tsv LETTERBOX_TMUX_PATTERNS=$ROOT/patterns.tsv TMUX_FAKE_HASSESSION=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=helper_timeout target=-'
check "send reported fail → send_failed" "TMUX_FAKE_SEND=fail" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=send_failed target=-'
check "send timeout → unconfirmed"       "TMUX_FAKE_SEND=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "enter reported fail → pasted"     "TMUX_FAKE_ENTER=fail" \
  'doorbell-outcome v=1 outcome=pasted_not_submitted reason=enter_failed target=%1'
check "enter timeout → unconfirmed"      "TMUX_FAKE_ENTER=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "notify-only (SUBMIT=0)"           "LETTERBOX_TMUX_SUBMIT=0" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=notify_only target=-'
check "wrapper: doorbell env unset"      "LETTERBOX_DOORBELL=" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "wrapper: doorbell not executable" "LETTERBOX_DOORBELL=/etc/hosts" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "adapter: tmux missing from PATH"  "PATH=$ROOT/bin-notmux" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "missing python3 → adapter_unavailable (not helper_timeout)" "PATH=$ROOT/bin-nopython" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'

# Fail closed without a bounder: prompt adapter_unavailable, and the adapter
# is NEVER invoked (invocation marker must not appear).
cat > "$ROOT/hang-marker.sh" <<'SH'
#!/usr/bin/env bash
touch "${INVOKED_MARKER:?}"
sleep 30
SH
chmod +x "$ROOT/hang-marker.sh"
rm -f "$ROOT/invoked"
out="$(send_now PATH="$ROOT/bin-nopython" LETTERBOX_DOORBELL="$ROOT/hang-marker.sh" INVOKED_MARKER="$ROOT/invoked")"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-' ]] \
  && [[ ! -e "$ROOT/invoked" ]]; then
  echo "PASS: no python3 → adapter_unavailable, adapter never invoked"; pass=$((pass+1))
else
  echo "FAIL: fail-closed without bounder"; echo "$out"; ls -la "$ROOT/invoked" 2>/dev/null; exit 1
fi
check "wrapper: garbage child → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/garbage.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "wrapper: double line → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/double.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
# Exit-status precedence: a valid line after a NONZERO exit is never forwarded.
check "wrapper: valid line + nonzero exit → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/valid-exit1.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
# Runner-owned sentinel: a child exiting 124 on its own is NOT a timeout.
check "child exit 124 in lookup → surface_not_found (not helper_timeout)" "TMUX_FAKE_LIST=exit124" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "child exit 124 in send → send_failed (not unconfirmed)" "TMUX_FAKE_SEND=exit124" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=send_failed target=-'
# A success line followed by a hang: the wrapper backstop kills, line or not.
check "wrapper: valid line then hang → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/line-hang.sh LETTERBOX_DOORBELL_TIMEOUT=1" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
# Bounded notify: a hung display-message still yields the outcome line.
check "notify-only with hung display-message → notify_only" "LETTERBOX_TMUX_SUBMIT=0 TMUX_FAKE_DISPLAY=sleep TMUX_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=notify_only target=-'

# Ruling 5 provenance: the from clause names the durable letter's sender,
# never the calling process identity (ME=tester, letter from relaybot).
craft_letter relaybot 2026-09-16T000000-relaybot-info-crafted-a1b2c3d4
out="$(nudge 2026-09-16T000000-relaybot-info-crafted-a1b2c3d4)"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target=%1' ]] \
  && grep -q 'unacked info from relaybot in ' "$TMUX_FAKE_LOG"; then
  echo "PASS: from clause names the letter's sender, not ME"; pass=$((pass+1))
else
  echo "FAIL: from clause names the letter's sender, not ME"; echo "$out"; cat "$TMUX_FAKE_LOG"; exit 1
fi

# Ruling 5 safety: an invalid sender value omits the clause (never "from -").
craft_letter 'bad/../x' 2026-09-16T000001-badsend-info-crafted-b2c3d4e5
: > "$TMUX_FAKE_LOG"
out="$(nudge 2026-09-16T000001-badsend-info-crafted-b2c3d4e5)"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target=%1' ]] \
  && ! grep -q ' from ' "$TMUX_FAKE_LOG" \
  && grep -q 'unacked info in ' "$TMUX_FAKE_LOG"; then
  echo "PASS: invalid sender omits the from clause"; pass=$((pass+1))
else
  echo "FAIL: invalid sender omits the from clause"; echo "$out"; cat "$TMUX_FAKE_LOG"; exit 1
fi

# Owned-child cleanup: the runner kills the whole process group on timeout.
export GC_PID_FILE="$ROOT/gc.pid"
out="$(send_now LETTERBOX_DOORBELL="$ROOT/spawn-hang.sh" LETTERBOX_DOORBELL_TIMEOUT=1 GC_PID_FILE="$GC_PID_FILE")"
one_line "$out"
[[ "$out" == *"reason=unconfirmed"* ]] || { echo "FAIL: spawn-hang outcome: $out"; exit 1; }
sleep 0.3
if [[ -f "$GC_PID_FILE" ]] && kill -0 "$(cat "$GC_PID_FILE")" 2>/dev/null; then
  echo "FAIL: grandchild survived the backstop kill"; exit 1
else
  echo "PASS: owned-child cleanup (process-group kill)"; pass=$((pass+1))
fi

echo "──"
echo "tmux edition e2e: $pass/30 PASS"
