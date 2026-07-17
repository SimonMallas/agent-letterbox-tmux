# Contributing to Agent Letterbox for tmux

## Scope (v0.1)

**Supported**

- Durable Markdown letters, reply-first handling, atomic publication, advisory locks
- Automatic opt-in tmux doorbells to live registered panes (or static session patterns)
- Local and SSH/headless tmux workflows where users arrange sessions themselves

**Not in scope**

- cmux, desktop agents, webhooks, persistent watchers, relay services, or required daemons
- Autonomous unattended processing without a human-in-the-loop terminal agent

## Development

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
make test
```

Expect each script to print an explicit **PASS** (or SKIP when tmux is unavailable).

## Pull requests

- Prefer small, reviewable commits
- Keep the CLI dependency-free (Bash + standard Unix tools + tmux)
- Do not reintroduce cmux or desktop adapters into this product tree
