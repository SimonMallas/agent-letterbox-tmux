#!/usr/bin/env bash
# Required public-port gate: no private-bus vocabulary may appear in a public product.
#
# Distinct from test_no_private_data.sh, which guards Simon's personal data. This guards
# our own internal naming, which review cannot reliably catch because it reads as ordinary
# text — e.g. `die "letterbox check <agent> (or set BUS_AGENT)"` looks like usage help.
#
# Scope is EVERY TRACKED FILE, not an allowlist of directories. An allowlist misses
# anything new and anything hidden: an earlier version of this gate named
# `bin adapters tests docs skills Makefile SPEC.md README.md CHANGELOG.md` and therefore
# never looked at `.github/workflows/`, where a CI file referencing a private path would
# have shipped unnoticed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root"

PATTERNS='shared-brain|bus doorbell|BUS_AGENT|BUS_DIR|bus\.sh|kimik357|telegram_bridge|launchd|utc_now'
SELF='tests/test_private_vocabulary.sh'

# Prefer git: it is exactly the set of files that ship, and it includes dotfiles and
# dotted directories. Fall back to find for a non-git checkout.
list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z
  else
    find . -type f -not -path './.git/*' -print0
  fi
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required for whitespace-normalised scan" >&2
  exit 1
fi

hits=0
while IFS= read -r -d '' f; do
  [[ "$f" == "$SELF" || "$f" == "./$SELF" ]] && continue
  [[ "$f" == "tests/vocab_normalized.py" || "$f" == "./tests/vocab_normalized.py" ]] && continue
  [[ -f "$f" ]] || continue
  # -I skips binaries; -n gives line numbers. Filename comes from the loop, so it is
  # always printed even when grep is handed a single file.
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    echo "FAIL: private vocabulary in public product -> ${f#./}:${m}" >&2
    hits=$((hits + 1))
  done < <(grep -InE "$PATTERNS" "$f" 2>/dev/null || true)
  set +e
  norm="$(python3 tests/vocab_normalized.py "${f#./}" "shared"" brain" "bus ""doorbell" 2>&1)"
  nrc=$?
  set -e
  if [[ "$nrc" -ne 0 ]]; then
    echo "FAIL: whitespace-normaliser error on ${f#./} (rc=$nrc): $norm" >&2
    hits=$((hits + 1))
    continue
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    echo "FAIL: private vocabulary (whitespace-normalised) at $hit" >&2
    hits=$((hits + 1))
  done <<<"$norm"
done < <(list_files)

if (( hits > 0 )); then
  echo "private-vocabulary: FAIL ($hits occurrence(s))" >&2
  exit 1
fi
echo "PASS: no private-bus vocabulary in any tracked file"
echo "private-vocabulary: PASS"
