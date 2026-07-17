# Agent Letterbox for tmux roadmap

## v0.1 scope

Agent Letterbox for tmux is a filesystem-first coordination system for live tmux terminal-agent teams.

**Supported:**

- Durable Markdown letters, reply-first handling, atomic publication, and advisory locks
- `letterbox tmux setup` / `run` / `register` bootstrap with live pane registry
- Automatic opt-in tmux `send-keys` doorbells (registry first, static patterns fallback)
- Local and SSH/headless tmux workflows where users arrange tmux sessions themselves

**Not supported:**

- cmux integration (separate product tree)
- Autonomous desktop-agent turns, webhooks, persistent watchers, relay services, or required daemons
- Multi-machine file transport; SSH access alone does not synchronize Letterbox files

## Next milestones

1. Dogfood with real multi-agent tmux sessions, including SSH/headless use cases
2. Review/import approved visual identity assets
3. Prepare a separate public v0.1 release
