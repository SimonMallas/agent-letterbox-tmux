#!/usr/bin/env bash
# tmux doorbell adapter — doorbell-outcome v=1 emitter.
# The letter is already durable; this rings a live pane and reports ONE
# machine-readable outcome line on stdout (the wrapper owns forwarding).
#
# Lookup order for a live target:
#   1) LETTERBOX_TMUX_REGISTRY (default: $LETTERBOX_DIR/tmux-agents.tsv)
#      agent<TAB>pane_id_or_session<TAB>session_name<TAB>registered_at
#   2) LETTERBOX_TMUX_PATTERNS (static fallback)
#      agent<TAB>tmux-session-name
#
# Submit is opt-in: LETTERBOX_TMUX_SUBMIT=1 injects the doorbell + Enter.
set -uo pipefail

to="${1:?recipient}"
type="${2:?type}"
slug="${3:?slug}"

# doorbell-outcome v=1: exactly one line, validated before printing.
# outcome ∈ {submitted, pasted_not_submitted, no_live_surface}; reason/target
# cross-checked per the contract (no_live_surface always target=-; submitted
# and pasted always target=<pinned pane>, reason=- or enter_failed|-).
emit_outcome() { # $1=outcome $2=reason $3=target
    local outcome="$1" reason="$2" target="$3"
    case "$outcome" in
        submitted)
            [[ "$reason" == "-" && "$target" != "-" ]] || return 1
            [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
            ;;
        pasted_not_submitted)
            case "$reason" in enter_failed|-) ;; *) return 1;; esac
            [[ "$target" != "-" ]] || return 1
            [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
            ;;
        no_live_surface)
            [[ "$reason" != "-" && "$reason" =~ ^[A-Za-z0-9._:+-]+$ ]] || return 1
            [[ "$target" == "-" ]] || return 1
            ;;
        *) return 1;;
    esac
    printf 'doorbell-outcome v=1 outcome=%s reason=%s target=%s\n' \
        "$outcome" "$reason" "$target"
}

# Bounded call: 124 = timeout (incl. missing python3), 127 = missing binary,
# else the child's exit code. Same semantics as the bus helper's bounded_cmd.
bounded_cmd() { # $1=seconds, rest=argv
    local secs="$1"; shift
    command -v python3 >/dev/null 2>&1 || return 124
    python3 -c '
import os, signal, subprocess, sys
try:
    p = subprocess.Popen(sys.argv[2:], start_new_session=True)
except FileNotFoundError:
    sys.exit(127)
try:
    sys.exit(p.wait(timeout=float(sys.argv[1])))
except subprocess.TimeoutExpired:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except Exception:
        p.kill()
    p.wait()
    sys.exit(124)
' "$secs" "$@"
}

command -v tmux >/dev/null 2>&1 || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }

# v0.3: additive opaque token. The v0.2 line remains a byte-prefix, so v0.2
# permitted-line rules still match. Never a slug, body, path or secret.
# Ruling 5 middle insert: name the durable letter's sender, but only when the
# wrapper supplied a value that passes the safe-identifier regex (re-checked
# here — env is never trusted). Otherwise the line stays the old shape.
tok="${LETTERBOX_DOORBELL_TOKEN:-}"
line_from="${LETTERBOX_DOORBELL_FROM:-}"
if [[ "$line_from" =~ ^[A-Za-z][A-Za-z0-9._-]{0,31}$ ]]; then
  line="📬 letterbox doorbell: unacked $type from $line_from in ${LETTERBOX_DIR:?set LETTERBOX_DIR}/$to/inbox/ — please check"
else
  line="📬 letterbox doorbell: unacked $type in ${LETTERBOX_DIR:?set LETTERBOX_DIR}/$to/inbox/ — please check"
fi
[[ "$tok" =~ ^[0-9a-f]{8}$ ]] && line="$line · $tok"

bound_s="${LETTERBOX_DOORBELL_TIMEOUT:-5}"

# One bounded pane snapshot serves all %-pane liveness checks. A lookup hang
# here is the contract's only retryable class (proven pre-inject timeout).
panes_ec=0
panes="$(bounded_cmd "$bound_s" tmux list-panes -a -F '#{pane_id}' 2>/dev/null)" || panes_ec=$?
if [[ "$panes_ec" -eq 124 ]]; then
  emit_outcome no_live_surface helper_timeout -
  exit 0
fi

# 0 = live, 1 = dead, 124 = lookup timeout (retryable, pre-inject).
target_live() {
  local t="$1"
  [[ -n "$t" ]] || return 1
  if [[ "$t" == %* ]]; then
    printf '%s\n' "$panes" | grep -Fx "$t" >/dev/null
  else
    bounded_cmd "$bound_s" tmux has-session -t "$t" 2>/dev/null
  fi
}

target=''

# 1) Live self-registration registry (preferred)
registry_file="${LETTERBOX_TMUX_REGISTRY:-}"
if [[ -z "$registry_file" && -n "${LETTERBOX_DIR:-}" ]]; then
  registry_file="$LETTERBOX_DIR/tmux-agents.tsv"
fi
if [[ -n "$registry_file" && -r "$registry_file" ]]; then
  while IFS=$'\t' read -r agent pane _session _ts || [[ -n "${agent:-}" ]]; do
    [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
    live_ec=0
    target_live "$pane" || live_ec=$?
    if [[ "$live_ec" -eq 124 ]]; then
      emit_outcome no_live_surface helper_timeout -
      exit 0
    fi
    if [[ "$live_ec" -eq 0 ]]; then
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
      live_ec=0
      target_live "$session" || live_ec=$?
      if [[ "$live_ec" -eq 124 ]]; then
        emit_outcome no_live_surface helper_timeout -
        exit 0
      fi
      if [[ "$live_ec" -eq 0 ]]; then
        target="$session"
        break
      fi
    done < "$patterns_file"
  fi
fi

[[ -n "$target" ]] || { emit_outcome no_live_surface surface_not_found -; exit 0; }

# The contract target is always a pinned %pane id, never a session name:
# resolve a session target to its active pane before injecting.
if [[ "$target" != %* ]]; then
  pane_ec=0
  pane="$(bounded_cmd "$bound_s" tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" || pane_ec=$?
  if [[ "$pane_ec" -eq 124 ]]; then
    emit_outcome no_live_surface helper_timeout -
    exit 0
  fi
  if [[ "$pane_ec" -ne 0 || ! "$pane" =~ ^%[0-9]+$ ]]; then
    emit_outcome no_live_surface surface_not_found -
    exit 0
  fi
  target="$pane"
fi

# Input injection is explicit opt-in: Enter can submit unrelated buffer text.
if [[ "${LETTERBOX_TMUX_SUBMIT:-0}" == 1 ]]; then
  send_ec=0
  bounded_cmd "$bound_s" tmux send-keys -t "$target" -l "$line" || send_ec=$?
  if [[ "$send_ec" -ne 0 ]]; then
    if [[ "$send_ec" -eq 124 ]]; then
      # Text step started; bytes may or may not have been injected.
      emit_outcome no_live_surface unconfirmed -
    else
      emit_outcome no_live_surface send_failed -
    fi
    exit 0
  fi
  enter_ec=0
  bounded_cmd "$bound_s" tmux send-keys -t "$target" Enter || enter_ec=$?
  if [[ "$enter_ec" -ne 0 ]]; then
    if [[ "$enter_ec" -eq 124 ]]; then
      # Enter may have landed after text was confirmed sent.
      emit_outcome no_live_surface unconfirmed -
    else
      emit_outcome pasted_not_submitted enter_failed "$target"
    fi
    exit 0
  fi
  emit_outcome submitted - "$target"
else
  tmux display-message -t "$target" "$line" 2>/dev/null || true
  emit_outcome no_live_surface notify_only -
fi
