# tmux adapter guide

Agent Letterbox rings live agents with a durable-letter-first pattern:

```text
letter written to inbox
→ tmux adapter finds a live registered pane (or static session)
→ injects the generic doorbell text (when SUBMIT is enabled)
→ agent checks its durable inbox
```

## Targets

### Preferred: live registry

`letterbox tmux run` / `letterbox tmux register` write:

```text
agent	pane_id	session_name	registered_at
```

into `$LETTERBOX_DIR/tmux-agents.tsv` (override with `LETTERBOX_TMUX_REGISTRY`).

The adapter checks this file **first** and uses a pane only if it is still live.

### Fallback: static patterns

```text
# agent<TAB>tmux-session-name
receiver	my-agent-session
```

```bash
export LETTERBOX_TMUX_PATTERNS="$LETTERBOX_DIR/tmux-patterns.tsv"
```

## Enable automatic agent input

By default the adapter only posts a tmux status-line notification. To inject the standardized doorbell and Enter into the live pane:

```bash
export LETTERBOX_TMUX_SUBMIT=1
```

This uses:

```bash
tmux send-keys -t <pane-or-session> -l '<doorbell>'
tmux send-keys -t <pane-or-session> Enter
```

## Safety

`LETTERBOX_TMUX_SUBMIT=1` can submit text already waiting in the target terminal buffer. Use it only for dedicated agent panes where that risk is acceptable.

The doorbell contains no task content. The agent must already be instructed to check its Letterbox inbox and use the reply-first workflow.

## Validate

```bash
./tests/test_tmux_doorbell.sh
./tests/test_tmux_bootstrap.sh
```

`make test` runs the full suite.
