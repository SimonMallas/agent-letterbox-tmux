# Agent Letterbox for tmux

## Ring the bell. Create the team. Build the memories.

![Eight coding agents handing work to each other over Agent Letterbox — panes ring as letters land](assets/hero/letterbox-team.gif)

*Shown: the cmux edition mid-storm — same letters, same protocol. This edition rings tmux panes.*

**Letterbox gives an agent team a durable place to build memory together.**

### The 60-second evaluation

Agent Letterbox is a cross-agent communication system for terminal CLI agents: it gives the coding agents you already run the ability to talk to each other. Agents send each other **durable, queryable, accountable letters** — each a hybrid Markdown file in an envelope with a typed address — that land in a teammate's inbox, and a doorbell rings to wake the recipient. The bell is one contentless line by design, but it is the heartbeat of the team; the letters it points to are the memory.

The letterbox is the team's **episodic memory**: a write-once record of what was asked, answered, and decided — episode by episode, with provenance on every entry. Every letter carries a typed envelope — sender, addressee, type, priority, whether it demands an answer — and every new v0.5.0 send and reply also carries publication UTC in `sent`; letters can carry thread linkage and a `supersedes` reference to an earlier record. Letters are never edited in place; a correction is a new letter that supersedes the old. It is not semantic memory: nothing is summarized, embedded, ranked, or consolidated. The context window is working memory; this is the long-term store it offloads to — and ground truth for whatever memory layer you point at it later.

Until now that record was **Envelope Memory**: everything kept, but to find anything you had to open the letters and read. This release upgrades it to **Queryable Envelope Memory (QEM)** — the reason those letters are more than mail, and the third retrieval lane: dense retrieval finds meaning, lexical retrieval finds strings, and **structured-metadata retrieval finds records**. Exact filters over typed envelope fields, in one read-only command:

```bash
letterbox query                                            # newest envelopes, scope stated
letterbox query from=planner to=reviewer type=request state=open
letterbox query thread=thread-id answered=no 'slug~=design'
letterbox query superseded=head since=2026-01-01T00:00:00Z
```

- **What did a teammate decide?** — filter by sender, type, topic, or time.
- **Is it still current?** — currency is bookkeeping, not inference: publish an update with
  `letterbox send ... --supersedes <prior-id>` and the supersession is declared by the author,
  never guessed by software. `superseded=head` filters to envelopes not superseded in the
  scanned scope. Dangling supersession references are reported. The envelope record, not a
  truth certificate.
- **What do I still owe?** — `letterbox query state=open answered=no type=request` (and again
  with `type=delegate`): open promises derived from the letter lifecycle at scan time.
- **Did that never happen?** — an empty answer is scoped to the folders searched, from a
  non-atomic scan — never evidence that something did not happen anywhere.
- **Where do two accounts disagree?** — inspect a thread's envelope provenance, then read
  the letters to compare their accounts. Query does not read bodies or identify disagreements.

No database, no embeddings, no service — the envelope is the memory, and query is retrieval over it, not recall: exact filters on typed fields, never similarity search. Strict-v1 envelopes by default; `--compat-v2` explicitly for older corpora, with diagnostics instead of silent assumptions — a lens over the record, not a rewrite of it. Existing letters are unchanged: older letters without `sent` keep their UTC timestamp-from-ID fallback in strict mode and report unknown time in compatibility mode. Read-only: query never sends, rings, files, or changes a letter — and nothing it returns is ever written back, so the record never eats its own output. No archive traversal. Runs on the Python 3.9+ standard library; macOS Command Line Tools provide Python 3 alongside Git, and many Linux distributions include it. **Durable over persistent**: persistent means merely kept around in a process or context; durable means letters survive agent restarts, compaction, and new sessions as files on disk. You can check every byte. See [query contracts and limitations](docs/query.md).

**Agent Letterbox for tmux turns separate coding-agent terminals into a live team — and every message between them into a durable record.** This edition rings tmux panes. The v0.4.0 live-cycle notes are historical transport qualification, not evidence for this query release.

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

Working an inbox day to day: [Handling mail](https://github.com/SimonMallas/agent-letterbox-cmux/blob/main/docs/handling-mail.md).
The guide is edition-neutral and notes where platforms differ.


## More memory than message

Letterbox is a thin shared memory layer for an agent team — in the field's terms, the team's **episodic memory**: durable correspondence, handoffs, decisions, ACKs and RESULTs, and recoverable history on disk between separate context windows. It is the place the team writes what happened — not a model that remembers for them.

When one agent types into another's terminal, the message is spent the moment it lands: the pane scrolls, the session compacts, and nothing remains. Between agents there is no phone keeping a copy — an injected handoff is the ONLY copy, and it dies with the scrollback.

A letter is different. It carries sender, recipient, type, thread linkage and time in its envelope, in plain Markdown, on disk — so the handoff that happened at 9am is still readable at 3am, by the agent that crashed in between, by the teammate who joined later, by whatever memory system you point at the directory. Every memory exists because someone wrote it, on purpose — authored, never inferred.

What that buys, mechanically:

- **A crashed or compacted agent recovers its context from its own inbox** — restore is
  reading, not reconstruction. The context window is working memory; the letterbox is the
  long-term store.
- **"What was actually said" has an answer** — the thread on disk, not competing
  recollections from two context windows. Memory is nice; a **truth layer** is the actual
  product: one place where what was said, by whom, and what is still current is
  answerable, with receipts.
- **Context windows stay clean** — the doorbell is one contentless line; the body enters
  an agent's context only when it chooses to read.
- **Any memory system can eat it** — letters are files with envelopes: searchable,
  addressable, born indexable.

Letterbox is not a memory intelligence system. It does not summarize, embed, rank, promote, or interpret — no consolidation, and nothing is remembered that was not written. A query is a window, not a pump: its results point at letters and are never ingested, ranked, or written back — no amplification loop, no store eating its own output. A separate memory layer may use these records as ground truth. We keep the letter; the librarian can be anyone's.

The honest cost: query finds what was filed, not what was known. The envelope answers only what the envelope says, and a session that understood more than it wrote down is still gone. That is a deliberate choice of failure mode. Memory with a system risks remembering something false, quietly and at volume; memory without one risks forgetting something true. Letterbox chooses the second, on purpose.

## One brain, not a silo per agent

Many memory systems are built per user: your assistant remembers *you*, in a silo, and a second agent on the same machine usually starts without it. Letterbox is built per **team**. Every agent reads and writes the same letter store, so what one agent learns, decides, or promises is on the record for all of them, with an author and a date attached. Not separate minds with separate memories glued together: specialists around one brain, not a silo per agent. The letters are simultaneously what the team remembers and how it talks: coordination and memory are the same files. And because the record is shared, any teammate, agent or human, can check what was said against it in seconds.

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

**A record you can review.** Each **enveloped letter** — a letter that carries
its own envelope: sender, addressee, id, and time — gives a request or reply a
durable, addressable record. Another agent can check a conclusion against the
recorded exchange rather than rely on a retelling. Linked letters let you
revisit what was asked, what was answered, and when it was recorded. That
gives review a concrete starting point, with the judgement left to the
reviewer. The thinking in full:
[*Memory without the system*](https://github.com/SimonMallas/agent-letterbox-cmux/blob/main/docs/memory-without-the-system.md).

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
