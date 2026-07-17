# Agent Letterbox for tmux

## Ring the agent. Keep the message. Work as a team.

**Agent Letterbox for tmux turns separate coding-agent terminals into a live team.**

A message is saved safely on disk. When the recipient is live, tmux sends one short instruction into its pane:

```text
📬 letterbox doorbell: unacked delegate in <letterbox>/<agent>/inbox/ — please check
```

The agent checks the durable message, replies, and hands work onward.

> **The doorbell makes you a team.**

## What you need

- Bash, Git, and **tmux**
- Agents you already run in terminals (Claude Code, Pi, Grok, Hermes, …)

No servers. No desktop app. No cmux. No webhooks.

## Install (copy / paste)

```bash
git clone https://github.com/SimonMallas/agent-letterbox-tmux.git \
  ~/Developer/agent-letterbox-tmux
cd ~/Developer/agent-letterbox-tmux

chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

# One-time team bootstrap (creates ~/.agent-letterbox and links the CLI)
letterbox tmux setup --agents pi,claude,grok,hermes --automatic-doorbells
source ~/.agent-letterbox/env.sh
```

Check:

```bash
letterbox --version
echo "$LETTERBOX_DIR"
```

## Launch agents (you choose the panes)

Create any tmux layout you like. In **each agent pane**:

```bash
source ~/.agent-letterbox/env.sh

letterbox tmux run pi -- pi
# other panes:
letterbox tmux run claude -- claude
letterbox tmux run grok -- grok
letterbox tmux run hermes -- hermes chat
```

`tmux run` registers that pane for live doorbells, then starts the command.

If a pane was rebuilt after detach, register again:

```bash
letterbox tmux register pi
letterbox tmux status
```

## Send a live handoff

```bash
source ~/.agent-letterbox/env.sh
export LETTERBOX_AGENT=pi

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send claude delegate auth-review --ack --now
```

1. Letter lands in Claude’s inbox
2. Doorbell is injected into Claude’s registered pane
3. Claude ACKs / works / replies with `letterbox reply`
4. Original letter is archived

> `LETTERBOX_TMUX_SUBMIT=1` (set by `--automatic-doorbells`) can submit text already in a buffer. Use dedicated agent panes only.

## Static session fallback (optional)

If you prefer fixed session names without self-registration, edit:

```bash
$EDITOR "$LETTERBOX_DIR/tmux-patterns.tsv"
```

```text
pi	pi-session
claude	claude-session
```

The adapter prefers the live registry, then this file.

## Test

```bash
make test
```

## Learn more

- [docs/team-setup.md](docs/team-setup.md) — full team bootstrap
- [docs/tmux.md](docs/tmux.md) — adapter details and safety
- [SPEC.md](SPEC.md) — message format and reply-first semantics
- [SECURITY.md](SECURITY.md) — threat model

## License

[MIT](LICENSE)
