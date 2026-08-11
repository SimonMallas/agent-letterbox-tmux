# Agent Letterbox for tmux roadmap

## v0.2 scope

Agent Letterbox for tmux is a filesystem-first coordination system for live tmux terminal-agent teams.

Public v0.2 is a **correctness** release: task vs non-task lifecycle, non-terminal ACK with `.md.ack` sidecars, terminal NACK/RESULT, `file` for non-task disposal, publish-before-close ordering, and doorbell-after-local-state.

**Supported:**

- Durable Markdown letters in per-agent inboxes.
- Task vs non-task handling (`requires_ack`).
- Non-terminal `ack` (accepted WIP + sidecar); terminal `nack` / `result`.
- `letterbox file` for non-task letters.
- Reply-first publication and recipient-owned archival.
- Atomic message publication, advisory locks, lifecycle locks, and filesystem completion proof.
- `letterbox tmux setup` / `run` / `register` bootstrap with live pane registry.
- Automatic opt-in tmux `send-keys` doorbells (registry first, static session-name patterns fallback).
- Local and SSH/headless tmux workflows where users arrange tmux sessions themselves.
- User-controlled tmux layouts: sessions, windows, and panes.

**Not supported (deferred / non-goals):**

Carried forward:

- cmux integration (maintained separately in `agent-letterbox-cmux`).
- Autonomous desktop-agent turns.
- Webhook-triggered unattended processing.
- Persistent watchers, relay/proxy services, or required background daemons.
- Multi-machine file transport; SSH access alone does not synchronize Letterbox files.
- Multi-machine or networked doorbells.

New explicit deferrals for v0.2:

- Automatic backlog drain tools that bulk-file inboxes.
- `check --deep` reconciliation of letters that older helpers wrongly archived after ACK.
- A frontmatter protocol-version field (v0.2 keeps the on-disk format unchanged).
- Built-in chat bridges (external intake remains operator-owned if used at all).
- Session `resume-log` as a public CLI surface.
- A permanent postmaster role or central dispatcher.

## Next milestones

1. Dogfood with real multi-agent tmux sessions, including SSH/headless use cases.
2. Soak the published artifact (curl + git install paths, one real ack→result cycle).
3. Keep lifecycle semantics aligned with the cmux sibling without coupling releases.
