# Agent Letterbox for tmux

## Ring the agent. Keep the message.

**Agent Letterbox for tmux turns separate coding-agent terminals into a live team.**

A message is saved safely on disk. When the recipient is live, tmux sends one short instruction into its terminal:

```text
📬 letterbox doorbell: check your inbox
```

The agent checks the durable message, replies, and hands work onward.

> **Agent mail that waits safely—and a bell brings it alive.**

## What this opens up

- Near-instant coordination between live tmux agents
- Durable agent-to-agent handoffs without human copy/paste
- Sessions that can run locally, over SSH, or on headless systems
- Durable letters that survive a disconnected or closed terminal

The automatic doorbell in this repository is **tmux only**. Ordinary terminals and desktop apps still receive durable mail, but need a manual/session-start check.

## Quick start

You need Bash, Git, and tmux.

```bash
git clone https://github.com/SimonMallas/agent-letterbox-tmux.git \
  ~/Developer/agent-letterbox-tmux
cd ~/Developer/agent-letterbox-tmux
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

export LETTERBOX_DIR="$HOME/.agent-letterbox"
letterbox init pi claude grok hermes
```

Create the tmux session mapping:

```bash
printf 'pi\tpi-session\nclaude\tclaude-session\n' \
  > "$LETTERBOX_DIR/tmux-patterns.tsv"

export LETTERBOX_DOORBELL="$PWD/adapters/tmux.sh"
export LETTERBOX_TMUX_PATTERNS="$LETTERBOX_DIR/tmux-patterns.tsv"
export LETTERBOX_TMUX_SUBMIT=1
```

Launch agents in tmux sessions named to match the mapping, then send a live handoff:

```bash
printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  LETTERBOX_AGENT=pi letterbox send claude delegate auth-review --ack --now
```

The letter is written first; tmux then uses `send-keys` to inject the generic doorbell into Claude's live session.

> `LETTERBOX_TMUX_SUBMIT=1` can submit text already waiting in a target terminal buffer. Use it only for dedicated agent sessions.

## Test

```bash
make test
```

## Learn more

- [docs/tmux.md](docs/tmux.md) — tmux doorbell setup
- [SPEC.md](SPEC.md) — message format and reply-first semantics
- [SECURITY.md](SECURITY.md) — threat model and reporting

## License

[MIT](LICENSE)
