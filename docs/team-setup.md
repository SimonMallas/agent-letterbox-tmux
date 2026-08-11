# tmux team setup

This is the standard Agent Letterbox setup for a live **tmux** agent team.

**You control tmux.** Create whatever sessions, windows, and panes fit the task. Letterbox never creates or rearranges your layout; it only registers the pane you launch each agent in, then rings that pane when mail arrives.

## One-time setup

From the Agent Letterbox for tmux checkout:

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

letterbox tmux setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source ~/.agent-letterbox/env.sh
```

This creates `~/.agent-letterbox/` by default, including:

```text
inboxes and processed folders for every named agent
tmux-agents.tsv          # live pane self-registrations
tmux-patterns.tsv        # optional static session-name fallback
env.sh                   # shared Letterbox/tmux environment
AGENT-LETTERBOX.md       # startup/resume instruction snippet
```

It also links:

- `~/.local/bin/letterbox` → this checkout’s CLI
- `~/.agents/skills/agent-letterbox` → the bundled skill

`--automatic-doorbells` enables `LETTERBOX_TMUX_SUBMIT=1` (inject the doorbell line + Enter into the live agent pane). Leave it out if you only want a tmux status-line notification.

Use another shared location when needed:

```bash
letterbox tmux setup --agents planner,reviewer --dir /shared/letterbox --automatic-doorbells
source /shared/letterbox/env.sh
```

## Launch agents in any tmux layout

Open tmux and create your own layout. In **each agent’s pane**, launch through the wrapper:

```bash
source ~/.agent-letterbox/env.sh

letterbox tmux run planner -- <your-agent-cli>
# other panes:
letterbox tmux run reviewer -- <your-agent-cli>
letterbox tmux run builder -- <your-agent-cli>
letterbox tmux run researcher -- <your-agent-cli>
```

`tmux run` will:

1. register the **current pane** for that agent id
2. start the agent command in the foreground

Surface / pane ids change after detach/reattach or layout rebuilds — run `letterbox tmux run` (or `letterbox tmux register <id>`) again after relaunch.

### Manual registration

If the agent is already running in this pane:

```bash
letterbox tmux register reviewer-secondary
letterbox tmux status
letterbox tmux unregister reviewer-secondary
```

### Static fallback patterns

If you prefer fixed session names without self-registration, edit `tmux-patterns.tsv`:

```text
planner	planner-session
reviewer	reviewer-session
```

The adapter prefers the live registry, then falls back to this file.

## Send a live handoff

```bash
source ~/.agent-letterbox/env.sh
export LETTERBOX_AGENT=planner

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send reviewer delegate auth-review --ack --now
```

The letter is written to the reviewer’s inbox first. If the reviewer’s pane is registered and live, the tmux adapter injects the generic doorbell:

```text
📬 letterbox doorbell: unacked delegate in <letterbox>/reviewer/inbox/ — please check
```

## Validate

```bash
make test
```

Then send a harmless `--now` delegate between two live agents in separate panes. Verify the inbox letter, the target pane doorbell, the ACK/result, and the archived original.
