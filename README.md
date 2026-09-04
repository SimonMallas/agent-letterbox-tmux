# Agent Letterbox for tmux

## Ring the bell. Create the team. Build the memories.

![Eight coding agents handing work to each other over Agent Letterbox — panes ring as letters land](assets/hero/letterbox-team.gif)

*Shown: the cmux edition mid-storm — same letters, same protocol. This edition rings tmux panes.*

**Letterbox gives an agent team a durable place to build memory together.**

**Agent Letterbox for tmux turns separate coding-agent terminals into a live team — and every message between them into a durable record.**

## What it is

Agent Letterbox is not a model, a new terminal, or a second agent harness. It is the coordination layer that lets the agents you already run hand work to one another without making you the human message relay.

A task lands as a durable letter in a teammate's inbox. The doorbell rings, alerting the agent to check it:

```text
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check · <8-lowercase-hex>
```

The agent wakes, picks up the real task from disk, replies, and keeps the work flowing. The terminal gets a ring; the inbox keeps the message.

> **Agent mail that waits safely—and a bell brings it alive.**

## The Agent Letterbox family

One shared letter store and protocol — four native doorbell adapters, one edition per terminal. The memory record belongs to the team's shared store, not to each terminal. Pick the adapter matching the terminal you already run:

- **[cmux](https://github.com/SimonMallas/agent-letterbox-cmux)** — primary entry point
- [tmux](https://github.com/SimonMallas/agent-letterbox-tmux)
- [Herdr](https://github.com/SimonMallas/agent-letterbox-herdr)
- [Zellij](https://github.com/SimonMallas/agent-letterbox-zellij) — terminal ring requires `LETTERBOX_ZELLIJ_SUBMIT=1`

You are reading the **tmux** edition.

## Why it exists

Without coordination, a multi-agent workflow means juggling panes, copying task text, remembering who owns what, and hoping a disconnected agent eventually sees a message.

Directly injecting the full task into another terminal is fast, but the terminal becomes the only message record. Agent Letterbox keeps the fast part—the live doorbell—while putting the actual work in a durable, inspectable letter.

```text
full task    → durable inbox letter
live wake-up → short generic doorbell
reply        → sender inbox
archive      → recipient processed history
```

Read the full comparison in [Why Letterbox?](docs/why-letterbox.md).

## More memory than message

Letterbox is a thin shared memory layer for an agent team: durable
correspondence, handoffs, decisions, ACKs and RESULTs, and recoverable
history sitting on disk between separate context windows. It is the place the team writes what happened — not a model that
remembers for them.

When one agent types into another's terminal, the message is spent the
moment it lands: the pane scrolls, the session compacts, and nothing
remains. Between agents there is no phone keeping a copy — an injected
handoff is the ONLY copy, and it dies with the scrollback.

A letter is different. It carries sender, recipient, type, thread linkage
and time in its envelope, in plain Markdown, on disk — so the handoff that
happened at 9am is still readable at 3am, by the agent that crashed in
between, by the teammate who joined later, by whatever memory system you
point at the directory.

What that buys, mechanically:

- **A crashed or compacted agent recovers its context from its own
  inbox** — restore is reading, not reconstruction.
- **"What was actually said" has an answer** — the thread on disk, not
  competing recollections from two context windows.
- **Context windows stay clean** — the doorbell is one contentless line;
  the body enters an agent's context only when it chooses to read.
- **Any memory system can eat it** — letters are files with envelopes:
  searchable, addressable, born indexable.

Letterbox is not a memory intelligence system. It does not summarize,
embed, rank, promote, or interpret. A separate memory layer may use
these records as ground truth. We keep the letter; the librarian can be
anyone's.

## How a task moves

Public v0.3 keeps the v0.2 **correctness** lifecycle and adds operational reading verbs plus additive doorbell tokens.

```text
send task (requires_ack=true)
  → recipient: reply ack     # accepted WIP; letter stays in inbox (.md.ack)
  → recipient: does the work
  → recipient: reply result  # terminal; letter moves to processed/
```

Non-task letters (`info` / `status` / received replies) are filed with no invented response:

```bash
letterbox file <id>
```

See [SPEC.md](SPEC.md) and [docs/lifecycle.md](docs/lifecycle.md).

## What this opens up

- **Near-instant coordination** — a live tmux agent can receive a doorbell and begin its next turn without human copy/paste.
- **Real handoffs** — implementation, review, research, QA, and fixes can move between agents as explicit owned work.
- **Detached continuity** — tmux sessions can survive disconnects while Letterbox keeps the durable record.
- **Durable recovery** — if an agent is offline, restarting, busy, or misses the bell, the task remains in its inbox.
- **Clear responsibility** — task letters require ACK/NACK/RESULT; ACK means in progress, not done.
- **Evidence over claims** — inbox, reply, sidecar, and processed files show what happened even when an agent conversation is gone.
- **Less human relay work** — you direct the team instead of pasting the same request between terminals.

This repository is purpose-built for live tmux agent teams.

---

# Quick start: set up your tmux team

You need Bash, Git, and tmux. No server, database, cloud account, or custom tmux layout is required.

## Step 1 — Open a terminal and copy/paste this

Open any terminal window. You can either copy/paste the whole block below yourself, **or ask an existing coding agent**:

> Set up Agent Letterbox for tmux using the README Quick Start. Do not change my tmux layout.

### Or: add the skill straight to your agent

```bash
npx skills add SimonMallas/agent-letterbox-tmux
```

### Option A — Recommended: copy/paste installer

```bash
curl -fsSL https://raw.githubusercontent.com/SimonMallas/agent-letterbox-tmux/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
letterbox tmux setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source "$HOME/.agent-letterbox/env.sh"
```

This downloads a local copy and sets up the team. If you are new to GitHub, you do not need to understand Git first—copying the block is enough.

To update later, run the same installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/SimonMallas/agent-letterbox-tmux/main/install.sh | sh
```

### Option B — Manual Git install

Use this if you want to inspect the source, modify it, or contribute:

```bash
git clone https://github.com/SimonMallas/agent-letterbox-tmux.git \
  ~/src/agent-letterbox-tmux
cd ~/src/agent-letterbox-tmux
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"
letterbox tmux setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source "$HOME/.agent-letterbox/env.sh"
```

Setup automatically creates one shared Letterbox, agent inboxes, the global `letterbox` launcher, the shared Agent Letterbox skill, and the live-pane registration registry.

> `--automatic-doorbells` lets Letterbox type the generic doorbell line into a live agent pane (`LETTERBOX_TMUX_SUBMIT=1`). Use it only for dedicated agent panes: like any terminal-input tool, it can submit text already typed in a target terminal.

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
letterbox tmux run planner -- <your-agent-cli>
letterbox tmux run reviewer -- <your-agent-cli>
letterbox tmux run builder -- <your-agent-cli>
letterbox tmux run researcher -- <your-agent-cli>
```

Copy and paste the appropriate command into each agent's chosen pane. The launcher gives the agent its identity, registers its current tmux pane, and starts the command. That is what lets Letterbox find and ring agents.

## Step 4 — Send the first handoff (ack, then result)

From the planner pane:

```bash
printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  LETTERBOX_AGENT=planner letterbox send reviewer delegate auth-review --ack --now
```

Prefer `printf … | letterbox …` for bodies. Avoid unquoted heredocs when the text may contain `$` or backticks — the shell expands those before Letterbox sees them. The CLI owns frontmatter; only the body goes on stdin.

The reviewer receives a durable letter and a live tmux doorbell. Accept the work (non-terminal):

```bash
printf '%s\n' 'ACK: reviewing auth.ts now.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id-or-inbox-path> ack auth-review --now
```

The letter stays in the reviewer's inbox with an `.md.ack` sidecar (`letterbox check` shows `[ACCEPTED]`). When finished, close it:

```bash
printf '%s\n' 'RESULT: no critical issues; two nits in findings.md.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id-or-inbox-path> result auth-review --now
```

Only `nack` or final `result` moves the original letter to `processed/`. The reply is published to the sender's inbox before local archive.

## New or duplicate agents

Give each new or duplicate session a unique identity:

```bash
letterbox tmux run planner-research -- <your-agent-cli>
letterbox tmux run builder-a -- <your-agent-cli>
letterbox tmux run agent-zero -- <your-agent-cli>
```

Each live session self-registers its current tmux pane, avoiding title or session-name collisions.

## Using a pre-release checkout

If you installed an earlier checkout from `main`, reinstall from the current branch and use the lifecycle commands above. v0.3 adds operational verbs (`check --recent|--thread`, `read`, `progress`, `nudge`, `token`), additive doorbell tokens, one-shot `result|nack` on `requires_ack: false` letters, and `file <path> --read` for path-form terminal replies. v0.2 letters remain valid. v0.2 introduced an optional additive `thread` field; existing letters remain valid and older readers ignore it. Early scripts that send `ack`, `nack`, or `result` directly must use `letterbox reply` instead, and delegates must include `--ack`. All agents in one team should run the same helper version.

## Test the installation

```bash
letterbox --version
make test
```

## Tested with

The letter protocol is identical across the Agent Letterbox family; only the doorbell adapter differs per terminal. Six agent CLIs — **Claude Code, Gemini CLI, OpenAI Codex, OpenCode, Cursor Agent, and GitHub Copilot CLI** — have completed the full live cycle (durable letter, doorbell ring, `ACK`, then `RESULT`) against the [cmux edition](https://github.com/SimonMallas/agent-letterbox-cmux#tested-with), which carries the version matrix and field notes. Teaching your agent works the same way here: a short teach file in the working directory and a pane it can be rung in.

## Learn more

**If you are an agent, start here:** [skills/agent-letterbox/SKILL.md](skills/agent-letterbox/SKILL.md) — the operating manual. It carries the doorbell acceptance rule you need to recognise a doorbell, the reply lifecycle, and the safety boundaries. The list below is background.

- [docs/lifecycle.md](docs/lifecycle.md) — task vs non-task, ACK/NACK/RESULT, `file`
- [docs/why-letterbox.md](docs/why-letterbox.md) — why durable letters plus generic doorbells beat direct task injection
- [docs/team-setup.md](docs/team-setup.md) — detailed tmux team setup
- [docs/tmux.md](docs/tmux.md) — adapter safety, registry vs static patterns, recovery
- [SPEC.md](SPEC.md) — normative protocol (v0.3)
- [SECURITY.md](SECURITY.md) — threat model and reporting
- [ROADMAP.md](ROADMAP.md) — scope and deferred items
- [CHANGELOG.md](CHANGELOG.md) — user-visible changes

## License

[MIT](LICENSE)
