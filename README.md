# Agent Letterbox for tmux

## Ring the bell. Create the team.

**Agent Letterbox for tmux turns separate coding-agent terminals into a live team.**

A message is saved safely on disk. When the recipient is live, tmux sends one short instruction into its pane:

```text
📬 letterbox doorbell: check your inbox
```

The agent checks the durable message, replies, and hands work onward.

> **Agent mail that waits safely—and a bell brings it alive.**

## What this opens up

- Near-instant coordination between live tmux agents
- Agent-to-agent handoffs without a human copying task text between terminals
- Durable messages that survive detached tmux sessions, restarts, and missed doorbells
- Clear ownership through ACK/NACK and reply-first handling
- A team that can run locally, over SSH, or on headless systems

The automatic doorbell in this repository is **tmux only**. Ordinary terminals and desktop apps still receive durable mail, but need a manual/session-start check.

---

# Quick start: set up your tmux team

You need Bash, Git, and tmux. No server, database, cloud account, or custom tmux layout is required.

## Step 1 — Open a terminal and copy/paste this

Open any terminal window. You can either copy/paste the whole block below yourself, **or ask an existing coding agent**:

> Set up Agent Letterbox for tmux using the README Quick Start. Do not change my tmux layout.

```bash
git clone https://github.com/SimonMallas/agent-letterbox-tmux.git \
  ~/Developer/agent-letterbox-tmux
cd ~/Developer/agent-letterbox-tmux
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"
letterbox tmux setup --agents pi,claude,grok,hermes --automatic-doorbells
```

This downloads a local copy and sets up the team. If you are new to GitHub, you do not need to understand Git first—copying the block is enough.

If it is already downloaded:

```bash
cd ~/Developer/agent-letterbox-tmux
git pull
export PATH="$PWD/bin:$PATH"
letterbox tmux setup --agents pi,claude,grok,hermes --automatic-doorbells
```

Setup automatically creates one shared Letterbox, agent inboxes, the global `letterbox` launcher, the shared Agent Letterbox skill, and the live-pane registration registry.

> `--automatic-doorbells` lets Letterbox type the generic doorbell line into a live agent pane. Use it only for dedicated agent panes: like any terminal-input tool, it can submit text already typed in a target terminal.

Stay in this same terminal for the next step; you do not need to open another one yet.

## Step 2 — Open tmux your way

Open tmux and arrange agents however the task requires:

```text
one tmux session per agent
multiple panes in one session
separate windows
any mix that suits the task
```

Agent Letterbox does not create, move, or resize your tmux layout.

## Step 3 — Launch agents through Letterbox

In each agent's chosen tmux pane, use the launcher:

```bash
letterbox tmux run pi -- pi
letterbox tmux run claude -- claude
letterbox tmux run grok -- grok
letterbox tmux run hermes -- hermes
```

Copy and paste the appropriate command into each agent's chosen pane. The launcher gives the agent its identity, registers its current tmux pane, and starts the command. That is what lets Letterbox find and ring agents.

## Step 4 — Send the first handoff

From the Pi terminal:

```bash
printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  LETTERBOX_AGENT=pi letterbox send claude delegate auth-review --ack --now
```

Claude receives a durable letter and a live tmux doorbell. To reply:

```bash
printf '%s\n' 'ACK: I will review it now.' |
  letterbox reply <message-id-or-inbox-path> ack auth-review-ack --now
```

The reply reaches Pi before Claude's original letter is archived.

---

## New or duplicate agents

Give each new or duplicate session a unique identity:

```bash
letterbox tmux run pi-research -- pi
letterbox tmux run pi-builder -- pi
letterbox tmux run agent-zero -- agent-zero
```

Each live session self-registers its current tmux pane, avoiding title or session-name collisions.

## Test the installation

```bash
letterbox --version
make test
```

## Learn more

- [docs/team-setup.md](docs/team-setup.md) — detailed tmux team setup
- [docs/tmux.md](docs/tmux.md) — tmux adapter safety and behavior
- [SPEC.md](SPEC.md) — message format and reply-first semantics
- [SECURITY.md](SECURITY.md) — threat model and reporting

## License

[MIT](LICENSE)
