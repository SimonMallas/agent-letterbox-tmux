# Changelog

All notable changes to Agent Letterbox for tmux are documented here.

## [Unreleased]

### Added

- `letterbox tmux setup`, `run`, `register`, `unregister`, and `status` for beginner team bootstrap.
- Live pane self-registration registry (`tmux-agents.tsv`) preferred by `adapters/tmux.sh`.
- Static `tmux-patterns.tsv` fallback.
- Live tmux-run bootstrap and doorbell tests.
- Beginner-friendly, copy/paste tmux installation guide.

### Changed

- Extracted the tmux-specific product from the former combined implementation.
- Removed cmux, desktop, and webhook runtime code from this repository.
