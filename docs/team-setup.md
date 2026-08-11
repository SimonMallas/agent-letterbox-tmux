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

`--automatic-doorbells` (alias `--submit`) enables `LETTERBOX_TMUX_SUBMIT=1` — inject the doorbell line + Enter into the live agent pane. Leave it out if you only want a tmux status-line notification.

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

Pane ids change after detach/reattach or layout rebuilds — run `letterbox tmux run` (or `letterbox tmux register <id>`) again after relaunch. Do not reuse remembered pane ids.

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

The adapter prefers the live registry, then falls back to this file. Title/session matching is a fallback only — never proof of identity when panes can collide.

## Send a live handoff (two-step lifecycle)

```bash
source ~/.agent-letterbox/env.sh
export LETTERBOX_AGENT=planner

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send reviewer delegate auth-review --ack --now
```

Prefer `printf` (or a quoted heredoc `<<'EOF'`) for the body so the shell does not expand `$` or backticks. Letterbox owns frontmatter; only the body is on stdin.

The letter is written to the reviewer’s inbox first. If the reviewer’s pane is registered and live (or a static pattern matches), and submit is enabled, the tmux adapter injects the generic doorbell:

```text
📬 letterbox doorbell: check your inbox
```

Accept work (non-terminal — letter stays in inbox):

```bash
printf '%s\n' 'ACK: I am reviewing it now.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id> ack auth-review --now
```

Finish work (terminal — letter moves to `processed/`):

```bash
printf '%s\n' 'RESULT: findings in body.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id> result auth-review --now
```

Non-task letters (`info` / `status`) are disposed without a reply:

```bash
LETTERBOX_AGENT=reviewer letterbox file <message-id>
```

See [lifecycle.md](lifecycle.md) for the full state machine.

## Safety

Automatic terminal input is powerful and intentionally opt-in. `--automatic-doorbells` / `LETTERBOX_TMUX_SUBMIT=1` may submit text already waiting in a target terminal buffer. Use it only for dedicated agent panes.

The doorbell contains no task content. The durable letter remains the real message and fallback if an agent is offline.

## Validate

```bash
make test
```

Then send a harmless `--now` delegate between two live agents in separate panes. Verify the inbox letter, the target pane doorbell, the ACK (letter still present with sidecar), the RESULT, and the archived original.
