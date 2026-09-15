#!/usr/bin/env bash
# GNU-shaped date: -uj fails; -d parses. Proves ID/stamp times are used
# instead of file mtime when the id/stamp is valid.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
letterbox="${LETTERBOX_BIN:-$root/bin/letterbox}"
work="$(mktemp -d "${TMPDIR:-/tmp}/lb-date.XXXXXX")"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

box="$work/box"
LETTERBOX_DIR="$box" "$letterbox" init alpha beta >/dev/null

install_bin() {
  mkdir -p "$1"
  printf '%s\n' "$2" > "$1/$3"
  chmod +x "$1/$3"
}

real_date="$(command -v date)"
install_bin "$work/bin" "$(cat <<EOF
#!/usr/bin/env bash
echo "date \$*" >> "\${DATELOG:-/dev/null}"
if [[ "\${1:-}" == "-uj" ]]; then
  echo "date: invalid option -- j" >&2
  exit 1
fi
if [[ "\${1:-}" == "-u" && "\${2:-}" == "-d" ]]; then
  python3 -c 'import datetime,sys
s=sys.argv[1].replace(" UTC","")
print(int(datetime.datetime.strptime(s,"%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc).timestamp()))' "\$3"
  exit \$?
fi
exec $real_date "\$@"
EOF
)" date

# If date parsing is skipped, mtime would look fresh (live).
install_bin "$work/bin" "$(cat <<'EOF'
#!/usr/bin/env bash
echo "stat $*" >> "${STATLOG:-/dev/null}"
if [[ "${1:-}" == "-f" && "${2:-}" == "%m" ]]; then
  echo 1000000000
  exit 0
fi
if [[ "${1:-}" == "-c" && "${2:-}" == "%Y" ]]; then
  echo 1000000000
  exit 0
fi
exit 1
EOF
)" stat

run_check() {
  DATELOG="$work/date.log" STATLOG="$work/stat.log" PATH="$work/bin:$PATH" \
    LETTERBOX_DIR="$box" LETTERBOX_AGENT=beta "$letterbox" check >"$work/out" 2>"$work/err" || {
    cat "$work/err" >&2
    fail "check died"
  }
  if grep -q 'unbound variable' "$work/err" "$work/out"; then
    fail "unbound variable"
  fi
}

rm -f "$box/beta/inbox"/*.md "$work/date.log" "$work/stat.log"
cat > "$box/beta/inbox/old.md" <<'EOF'
---
id: 2020-01-01T000000-alpha-info-old-aaaaaaaa
from: alpha
to: beta
type: info
re:
priority: next
requires_ack: false
deadline:
---
body
EOF
run_check
grep -q -- '-uj' "$work/date.log" || fail "GNU-shaped date never saw -uj"
grep -q -- '-d' "$work/date.log" || fail "GNU-shaped date never reached -d"
grep -q "open: 0 live · 1 stale" "$work/out" || fail "old id should be stale (ID time, not mtime): $(cat "$work/out")"
pass "old id + fresh-looking mtime: GNU-shaped date uses ID time (stale)"

rm -f "$box/beta/inbox"/*.md "$work/date.log" "$work/stat.log"
cat > "$box/beta/inbox/nots.md" <<'EOF'
---
id: body-keys-ok
from: alpha
to: beta
type: info
re:
priority: next
requires_ack: false
deadline:
---
body
EOF
# mtime probe returns 1000000000 (stale). Fresh ack stamp must win if parsed.
printf 'ack_id: x\nacked_at: %s\nby: alpha\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$box/beta/inbox/nots.md.ack"
run_check
grep -q -- '-d' "$work/date.log" || fail "stamp_epoch never used GNU -d"
grep -q "open: 1 live · 0 stale" "$work/out" || fail "fresh ack should beat old mtime: $(cat "$work/out")"
pass "ACK recency: GNU-shaped date parses acked_at (live over old mtime)"

echo "letter-epoch-date: PASS"
