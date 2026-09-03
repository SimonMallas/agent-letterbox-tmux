#!/usr/bin/env bash
# Mutation harness for the private-vocabulary gate, adopting the standard set by the
# Herdr candidate (kimi): the gate must catch residue wherever it lands — a visible
# file, a dotfile, and a .github workflow — and must fail with file:line.
#
# Why this exists rather than a reviewer planting residue by hand: the gate is only
# proven when someone thinks to test it. An earlier version of ours scanned a directory
# allowlist and never looked at .github/, and that hole survived until a reviewer
# happened to plant something there.
#
# All sub-run output is prefixed [mut] so a clean outer run can never be mistaken for a
# failure by anything grepping FAIL. Herdr's harness omits this and I misread its output
# as a real failure earlier today, which is the same ambiguity raised on wave2.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
gate='tests/test_private_vocabulary.sh'
fails=0

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vocabmut.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Self-contained copy including .git, so the gate's git ls-files enumeration runs for real.
cp -R "$root" "$tmp/repo"

plant_and_run() { # $1 = relative residue path; returns the gate's rc
  local rel="$1" out rc
  mkdir -p "$tmp/repo/$(dirname "$rel")"
  # split so this harness is not itself a vocabulary hit
  printf 'residue shared''-brain here\n' > "$tmp/repo/$rel"
  git -C "$tmp/repo" add -A >/dev/null 2>&1 || true
  out="$(cd "$tmp/repo" && bash "$gate" 2>&1)" && rc=0 || rc=$?
  printf '%s\n' "$out" | sed 's/^/[mut] /'
  echo "[mut] residue at $rel -> gate rc=$rc"
  rm -f "$tmp/repo/$rel"
  git -C "$tmp/repo" add -A >/dev/null 2>&1 || true
  LAST_OUT="$out"
  return "$rc"
}

for rel in "docs/visible-residue.md" ".github/workflows/residue-ci.yml" ".hidden-residuerc"; do
  if plant_and_run "$rel"; then
    echo "FAIL: gate PASSED with residue planted at $rel" >&2
    fails=$((fails + 1))
  else
    # the gate must name the offending file AND a line number, not just a count
    if printf '%s' "$LAST_OUT" | grep -qE "${rel}:[0-9]+:"; then
      echo "PASS: gate caught residue at $rel with file:line"
    else
      echo "FAIL: gate caught $rel but did not report file:line" >&2
      fails=$((fails + 1))
    fi
  fi
done

# Wrapped forbidden phrase (word1 + newline + word2) must fail with file:line.
mkdir -p "$tmp/repo/docs"
printf 'residue shared''\n''brain here\n' > "$tmp/repo/docs/wrap-residue.md"
git -C "$tmp/repo" add -f docs/wrap-residue.md >/dev/null 2>&1 || true
wrap_out="$(cd "$tmp/repo" && bash "$gate" 2>&1)" && wrap_rc=0 || wrap_rc=$?
printf '%s\n' "$wrap_out" | sed 's/^/[mut] /'
echo "[mut] wrap residue -> gate rc=$wrap_rc"
if [[ "$wrap_rc" -eq 0 ]]; then
  echo "FAIL: gate PASSED with wrapped private phrase" >&2
  fails=$((fails + 1))
elif ! printf '%s' "$wrap_out" | grep -qE "docs/wrap-residue.md:[0-9]+:"; then
  echo "FAIL: wrap hit missing file:line" >&2
  fails=$((fails + 1))
else
  echo "PASS: gate caught wrapped phrase with file:line"
fi
rm -f "$tmp/repo/docs/wrap-residue.md"
git -C "$tmp/repo" add -A >/dev/null 2>&1 || true

# Clean tree must pass, or every assertion above is meaningless.
if (cd "$tmp/repo" && bash "$gate" >/dev/null 2>&1); then
  echo "PASS: gate passes on a clean tree"
else
  echo "FAIL: gate fails on a clean tree — the assertions above prove nothing" >&2
  fails=$((fails + 1))
fi

if (( fails > 0 )); then
  echo "private-vocabulary mutation: FAIL ($fails)" >&2
  exit 1
fi
echo "private-vocabulary mutation: PASS"
