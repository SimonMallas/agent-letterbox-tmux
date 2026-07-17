# Agent Letterbox for tmux roadmap

## v0.1 scope

Agent Letterbox for tmux is a filesystem-first coordination system for live tmux terminal-agent teams.

**Supported:**

- Durable Markdown letters, reply-first handling, atomic publication, and advisory locks.
- Automatic opt-in tmux `send-keys` doorbells to configured live sessions.
- Local and SSH/headless tmux workflows where users arrange tmux sessions themselves.

**Not supported:**

- cmux integration (maintained separately in `agent-letterbox-cmux`).
- Autonomous desktop-agent turns, webhooks, persistent watchers, relay services, or required daemons.
- Multi-machine file transport; SSH access alone does not synchronize Letterbox files.

## Next milestones

1. Add tmux setup/run bootstrap parity with the cmux repository.
2. Dogfood with real tmux agent sessions, including SSH/headless use cases.
3. Review/import approved visual identity assets.
4. Prepare a separate public v0.1 release.
