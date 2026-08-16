#!/usr/bin/env bash
# v0.3 core lifecycle fixtures for the public tmux product.
#
# EXIT-trap gate pattern adopted from the Zellij candidate (hermes 2026-08-16):
# an early set -e/-u abort must NOT green-wash. The gate is registered BEFORE the
# first assertion, so every exit path — clean exit, failing command, signal — runs it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
letterbox="$root/bin/letterbox"
PASS=0
FAIL=0
EXPECTED_PASS=10
SUITE_DONE=0
FOOTER_MARK='lifecycle v0.3: PASS'
BOX=""

cleanup_box() { [[ -n "$BOX" && -d "$BOX" ]] && rm -rf "$BOX"; return 0; }

lifecycle_exit_gate() {
  cleanup_box
  [[ "$SUITE_DONE" == 1 ]] && return 0
  echo "lifecycle v0.3: FAIL (early abort or incomplete: pass=${PASS:-0} expected=${EXPECTED_PASS} fail=${FAIL:-0}; missing '${FOOTER_MARK}')" >&2
  exit 1
}
trap lifecycle_exit_gate EXIT

fail() { echo "FAIL: $*" >&2; FAIL=$((FAIL+1)); return 0; }
pass() { echo "PASS: $*"; PASS=$((PASS+1)); }

BOX="$(mktemp -d "${TMPDIR:-/tmp}/lbv03.XXXXXX")"
mkdir -p "$BOX/alpha/inbox" "$BOX/alpha/processed" "$BOX/beta/inbox" "$BOX/beta/processed"
lb() { LETTERBOX_DIR="$BOX" LETTERBOX_AGENT=alpha "$letterbox" "$@"; }

CANARY='canaryslug-leaky-task'
put() { # $1=id $2=type $3=requires_ack
  cat > "$BOX/alpha/inbox/$1.md" <<EOF
---
id: $1
from: beta
to: alpha
type: $2
re:
priority: now
requires_ack: $3
deadline:
---
CONFIDENTIAL-BODY-TEXT
EOF
}

# --- 1. doorbell grammar: additive, token-only, no slug -----------------------
v02='📬 letterbox doorbell: unacked info in /box/alpha/inbox/ — please check'
v03="$v02 · a1b2c3d4"
if [[ "$v03" == "$v02"* ]] && [[ "$v03" != *"$CANARY"* ]]; then
  pass "doorbell v0.2 line is a byte-prefix of the v0.3 line"
else
  fail "doorbell additive property broken"
fi

# A v0.2 permitted-line rule (prefix match) must accept BOTH shapes.
if [[ "$v02" == "$v02"* && "$v03" == "$v02"* ]]; then
  pass "v0.2 prefix rule accepts tokenless and token-bearing lines"
else
  fail "bidirectional doorbell compatibility broken"
fi

# --- 2. canary: a slug must never reach the knock -----------------------------
put "2026-08-16T100000-beta-delegate-${CANARY}-dead0001" delegate true
knock="$(LETTERBOX_DOORBELL="$root/adapters/noop.sh" lb nudge dead0001 2>&1 || true)"
if [[ "$knock" != *"$CANARY"* ]]; then
  pass "nudge knock carries no slug (canary negative assertion)"
else
  fail "SLUG LEAKED INTO KNOCK: $knock"
fi

# --- 3. read resolves by bare token and by display id -------------------------
if lb read dead0001 2>/dev/null | grep -q CONFIDENTIAL-BODY-TEXT; then
  pass "read resolves a bare 8-hex token"
else
  fail "read failed on bare token"
fi
if lb read '2026-08-16T100000 · dead0001' 2>/dev/null | grep -q CONFIDENTIAL-BODY-TEXT; then
  pass "read resolves a display id"
else
  fail "read failed on display id"
fi

# --- 4. check is operational and leaks nothing --------------------------------
out="$(lb check 2>&1)"
if [[ "$out" == *"live"* && "$out" == *"stale"* ]] \
   && [[ "$out" != *"$CANARY"* ]] && [[ "$out" != *CONFIDENTIAL-BODY-TEXT* ]]; then
  pass "check reports live/stale and leaks neither slug nor body"
else
  fail "check output wrong or leaking: $out"
fi

# --- 5. structural C: path needs --read, explicit id does not -----------------
put 2026-08-16T100100-beta-result-peer-cafe0002 result false
if ! lb file "$BOX/alpha/inbox/2026-08-16T100100-beta-result-peer-cafe0002.md" >/dev/null 2>&1; then
  pass "filing an inbound RESULT from a PATH is refused without --read"
else
  fail "path-form RESULT filed without --read"
fi
if lb file 2026-08-16T100100-beta-result-peer-cafe0002 >/dev/null 2>&1; then
  pass "filing an inbound RESULT by explicit id succeeds"
else
  fail "id-form RESULT was refused"
fi

# --- 6. reply fails fast on empty stdin and holds no lock ---------------------
if ! lb reply dead0001 ack slug </dev/null >/dev/null 2>&1; then
  if [[ -z "$(find "$BOX" -name '*.lifecycle.lock' -print -quit)" ]]; then
    pass "empty stdin fails fast and leaves no lifecycle lock"
  else
    fail "lifecycle lock left behind after failed reply"
  fi
else
  fail "empty stdin did not fail"
fi

# --- 7. ambiguous reference refuses rather than guessing ----------------------
put 2026-08-16T100200-beta-info-one-beef0003 info false
put 2026-08-16T100200-beta-info-two-beef0003 info false
if ! lb read beef0003 >/dev/null 2>&1; then
  pass "ambiguous reference refuses with non-zero exit"
else
  fail "ambiguous reference resolved to a guess"
fi

SUITE_DONE=1
echo "lifecycle v0.3: $PASS passed, $FAIL failed (expected $EXPECTED_PASS passes)"
if [[ "$FAIL" != 0 || "$PASS" != "$EXPECTED_PASS" ]]; then
  echo "lifecycle v0.3: FAIL (pass=$PASS expected=$EXPECTED_PASS fail=$FAIL)" >&2
  cleanup_box
  exit 1
fi
echo "$FOOTER_MARK"
cleanup_box
