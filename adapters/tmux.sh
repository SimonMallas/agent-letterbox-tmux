#!/usr/bin/env bash
# tmux doorbell adapter (automatic live-agent ring).
#
# Lookup order for a live target:
#   1) LETTERBOX_TMUX_REGISTRY (default: $LETTERBOX_DIR/tmux-agents.tsv)
#      agent<TAB>pane_id_or_session<TAB>session_name<TAB>registered_at
#   2) LETTERBOX_TMUX_PATTERNS (static fallback)
#      agent<TAB>tmux-session-name
#
# Submit is opt-in: LETTERBOX_TMUX_SUBMIT=1 injects the doorbell + Enter.
set -euo pipefail

to="${1:?recipient}"
type="${2:?type}"
slug="${3:?slug}"

command -v tmux >/dev/null 2>&1 || { echo 'tmux doorbell deferred: tmux is unavailable' >&2; exit 0; }

line="📬 letterbox doorbell: unacked $type in ${LETTERBOX_DIR:?set LETTERBOX_DIR}/$to/inbox/ — please check"
target=''

target_live() {
  local t="$1"
  [[ -n "$t" ]] || return 1
  if [[ "$t" == %* ]]; then
    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -Fx "$t" >/dev/null
  else
    tmux has-session -t "$t" 2>/dev/null
  fi
}

# 1) Live self-registration registry (preferred)
registry_file="${LETTERBOX_TMUX_REGISTRY:-}"
if [[ -z "$registry_file" && -n "${LETTERBOX_DIR:-}" ]]; then
  registry_file="$LETTERBOX_DIR/tmux-agents.tsv"
fi
if [[ -n "$registry_file" && -r "$registry_file" ]]; then
  while IFS=$'\t' read -r agent pane _session _ts || [[ -n "${agent:-}" ]]; do
    [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
    if target_live "$pane"; then
      target="$pane"
      break
    fi
  done < "$registry_file"
fi

# 2) Static patterns fallback
if [[ -z "$target" ]]; then
  patterns_file="${LETTERBOX_TMUX_PATTERNS:-}"
  if [[ -n "$patterns_file" && -r "$patterns_file" ]]; then
    while IFS=$'\t' read -r agent session || [[ -n "${agent:-}" ]]; do
      [[ "$agent" == \#* || -z "${agent:-}" ]] && continue
      [[ "$agent" == "$to" && -n "${session:-}" ]] || continue
      if target_live "$session"; then
        target="$session"
        break
      fi
    done < "$patterns_file"
  fi
fi

if [[ -z "$target" ]]; then
  if [[ -z "${registry_file:-}" && -z "${LETTERBOX_TMUX_PATTERNS:-}" ]]; then
    echo 'tmux doorbell deferred: no LETTERBOX_TMUX_REGISTRY or LETTERBOX_TMUX_PATTERNS' >&2
  else
    echo "tmux doorbell deferred: no live tmux target for $to" >&2
  fi
  exit 0
fi

# Input injection is explicit opt-in: Enter can submit unrelated buffer text.
if [[ "${LETTERBOX_TMUX_SUBMIT:-0}" == 1 ]]; then
  tmux send-keys -t "$target" -l "$line"
  tmux send-keys -t "$target" Enter
  printf 'tmux doorbell submitted to %s on %s\n' "$to" "$target"
else
  tmux display-message -t "$target" "$line" 2>/dev/null || true
  printf 'tmux notification sent to %s; set LETTERBOX_TMUX_SUBMIT=1 to inject the doorbell\n' "$to"
fi
