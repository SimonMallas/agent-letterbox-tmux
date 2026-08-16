#!/usr/bin/env bash
# Required public-port gate: no private-bus vocabulary may appear in a public product.
# Distinct from test_no_private_data.sh, which guards personal data. This guards our
# own internal naming, which review cannot reliably catch — it reads as ordinary text.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root"
PATTERNS='shared-brain|bus doorbell|BUS_AGENT|BUS_DIR|bus\.sh|kimik357|telegram_bridge|launchd|utc_now'
TARGETS='bin adapters tests docs skills Makefile SPEC.md README.md CHANGELOG.md'
hits=0
for target in $TARGETS; do
  [[ -e "$target" ]] || continue
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in "tests/test_private_vocabulary.sh:"*) continue;; esac
    echo "FAIL: private vocabulary in public product -> $line" >&2
    hits=$((hits+1))
  done < <(grep -rInE "$PATTERNS" "$target" 2>/dev/null || true)
done
if (( hits > 0 )); then
  echo "private-vocabulary: FAIL ($hits occurrence(s))" >&2
  exit 1
fi
echo "PASS: no private-bus vocabulary in public product"
echo "private-vocabulary: PASS"
