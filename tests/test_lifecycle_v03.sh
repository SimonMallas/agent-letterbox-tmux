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
EXPECTED_PASS=20
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

# --- 1. doorbell grammar, executed through the REAL adapter ------------------
# Invokes adapters/tmux.sh with tmux mocked on PATH, exactly as
# tmux-doorbell-safety.sh does. Deleting or breaking the adapter fails these.
ADPT="$root/adapters/tmux.sh"
mockbin="$BOX/mockbin"; mkdir -p "$mockbin"
cat > "$mockbin/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
case "$1" in
  list-panes)  printf '%s\n' "$MOCK_PANE" ;;
  has-session) exit 0 ;;
esac
exit 0
MOCK
chmod +x "$mockbin/tmux"
printf 'alpha\t%%1\n' > "$BOX/patterns.tsv"

emit_real() { # $1 = token ("" for v0.2 shape); prints the line the adapter sent
  local log="$BOX/mock.log"; : > "$log"
  MOCK_LOG="$log" MOCK_PANE='%1' \
  PATH="$mockbin:$PATH" \
  LETTERBOX_DIR=/box LETTERBOX_TMUX_PATTERNS="$BOX/patterns.tsv" LETTERBOX_TMUX_SUBMIT=1 \
  LETTERBOX_DOORBELL_TOKEN="$1" \
    "$ADPT" alpha info someslug >/dev/null 2>&1 || true
  sed -n 's/^send-keys -t %1 -l //p' "$log" | head -1
}

real_v02="$(emit_real '')"
real_v03="$(emit_real a1b2c3d4)"

if [[ -n "$real_v02" ]]; then
  pass "real adapter emits a doorbell line (fixture is wired to adapters/tmux.sh)"
else
  fail "adapter produced no line — fixture would be vacuous"
fi
# Mutation hooks: prove exit 0 and set -e abort after assertion 1 cannot green-wash.
if [[ "${LETTERBOX_MUTATE_EARLY_EXIT0:-0}" == 1 ]]; then
  echo "MUTATION: early exit 0 after first assertion" >&2
  exit 0
fi
if [[ "${LETTERBOX_MUTATE_EARLY_ABORT:-0}" == 1 ]]; then
  echo "MUTATION: set-e abort after first assertion" >&2
  false
fi
if [[ -n "$real_v02" && "$real_v03" == "$real_v02"* && "$real_v03" != "$real_v02" ]]; then
  pass "real v0.2 line is a byte-prefix of the real v0.3 line"
else
  fail "adapter additive property broken: v02='$real_v02' v03='$real_v03'"
fi
if [[ "$real_v03" != *"$CANARY"* && "$real_v03" =~ \ ·\ [0-9a-f]{8}$ ]]; then
  pass "real v0.3 line ends in an 8-hex token and carries no slug"
else
  fail "real v0.3 token shape wrong or slug present: $real_v03"
fi

# --- 2. canary: a slug must never reach the doorbell -----------------------------
put "2026-08-16T100000-beta-delegate-${CANARY}-dead0001" delegate true
knock="$(LETTERBOX_DOORBELL="$root/adapters/noop.sh" lb nudge dead0001 2>&1 || true)"
if [[ "$knock" != *"$CANARY"* ]]; then
  pass "nudge doorbell carries no slug (canary negative assertion)"
else
  fail "SLUG LEAKED INTO DOORBELL: $knock"
fi

# --- 3. read resolves by bare token and by display id -------------------------
r1="$(lb read dead0001 2>/dev/null || true)"
if [[ "$r1" == *CONFIDENTIAL-BODY-TEXT* ]]; then
  pass "read resolves a bare 8-hex token"
else
  fail "read failed on bare token"
fi
r2="$(lb read '2026-08-16T100000 · dead0001' 2>/dev/null || true)"
if [[ "$r2" == *CONFIDENTIAL-BODY-TEXT* ]]; then
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

# --- 8. progress, check ordering, --recent, thread ---------------------------
put 2026-08-16T100300-beta-delegate-prog-feed0004 delegate true
printf 'x\n' | lb reply feed0004 ack s >/dev/null 2>&1
if lb progress feed0004 'halfway there' >/dev/null 2>&1 \
   && grep -q 'halfway there' "$BOX/alpha/inbox/2026-08-16T100300-beta-delegate-prog-feed0004.md.ack"; then
  pass "progress writes a note into the existing ACK sidecar"
else
  fail "progress did not update the sidecar"
fi
if [[ -z "$(find "$BOX/beta/inbox" -name '*progress*' -print -quit)" ]]; then
  pass "progress creates no new letter"
else
  fail "progress created a letter"
fi
chk="$(lb check 2>&1)"
if [[ "$chk" == *progress* ]]; then
  pass "default check displays the progress note (the ratified condition)"
else
  fail "check does not display progress — the sidecar would rot unread"
fi
put 2026-06-01T090000-beta-info-ancient-0ldd0006 info false
chk2="$(lb check 2>&1)"
if [[ "$chk2" =~ STALE\ [0-9]+d ]]; then
  pass "check marks stale work loudly with an age"
else
  fail "no STALE marker"
fi
rec="$(lb check --recent 2>&1)"
if [[ "$rec" == *hidden* ]]; then
  pass "--recent prints a hidden-count footer"
else
  fail "--recent hid work without saying so"
fi
if lb check --thread 2026-08-16T100300-beta-delegate-prog-feed0004 >/dev/null 2>&1; then
  pass "check --thread runs read-only"
else
  fail "check --thread failed"
fi

# --- 9. named behavioural mutations -----------------------------------------
# Sub-run output is [mut]-prefixed so an expected failure is never mistaken for
# a real one by anything grepping this log.
MUT="$BOX/mut"; mkdir -p "$MUT"
mutate() { # $1=name $2=old $3=new ; prints the mutated helper path
  local d="$MUT/$1"; mkdir -p "$d"; cp "$letterbox" "$d/letterbox"; chmod +x "$d/letterbox"
  python3 - "$d/letterbox" "$2" "$3" <<'EOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
if sys.argv[2] not in t:
    sys.exit(3)
p.write_text(t.replace(sys.argv[2], sys.argv[3], 1))
EOF
  [[ $? -eq 0 ]] || return 1
  printf '%s' "$d/letterbox"
}
mlb() { local h="$1"; shift; LETTERBOX_DIR="$BOX" LETTERBOX_AGENT=alpha "$h" "$@" 2>&1; }

# collision: disable the real hits>1 refusal in resolve_action_ref.
if h="$(mutate collision 'if (( ${#hits[@]} > 1 )); then' 'if false; then')"; then
  if grep -q 'if false; then' "$h"; then
    if mlb "$h" read beef0003 >/dev/null 2>&1; then
      echo "[mut] ambiguity refusal disabled -> read resolved a colliding token"
      pass "[mut] collision: the hits>1 refusal is load-bearing"
    else
      fail "[mut] collision: refusal disabled but read still refused"
    fi
  else
    fail "[mut] collision: mutation did not apply — assertion would be vacuous"
  fi
else fail "[mut] collision anchor missing"; fi

# confirmation privacy: revert filed: to a raw basename and prove the canary leaks.
if h="$(mutate confirm 'printf '"'"'filed: %s → %s/processed/\n'"'"' "$(confirm_label "$msg")"' 'printf '"'"'filed: %s → %s/processed/\n'"'"' "$(basename "$msg")"')"; then
  if grep -q 'filed: %s → %s/processed/.n. "$(basename "$msg")"' "$h"; then
    put 2026-08-16T100600-beta-info-CANARYMUT-77770001 info false
    if mlb "$h" file 2026-08-16T100600-beta-info-CANARYMUT-77770001 2>&1 | grep -q CANARYMUT; then
      echo "[mut] confirm_label removed -> filed: leaked the slug-bearing basename"
      pass "[mut] confirm privacy: confirm_label is load-bearing"
    else
      fail "[mut] confirm privacy: basename restored but no leak observed"
    fi
  else
    fail "[mut] confirm privacy: mutation did not apply — assertion would be vacuous"
  fi
else fail "[mut] confirm anchor missing"; fi

put 2026-08-16T100500-beta-info-CANARYCONFIRM-9999abcd info false
cf="$(lb file 2026-08-16T100500-beta-info-CANARYCONFIRM-9999abcd 2>&1 || true)"
if [[ "$cf" == *CANARYCONFIRM* ]]; then
  fail "confirmation leaked a slug-bearing basename"
else
  pass "confirmation output carries no slug (canary)"
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
