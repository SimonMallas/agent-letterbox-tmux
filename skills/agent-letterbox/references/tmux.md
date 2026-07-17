# tmux doorbell

Automatic live doorbells use the `adapters/tmux.sh` adapter.

Lookup order:

1. Live registry (`LETTERBOX_TMUX_REGISTRY`, default `$LETTERBOX_DIR/tmux-agents.tsv`) from `letterbox tmux run` / `register`
2. Static patterns (`LETTERBOX_TMUX_PATTERNS`)

Submit is opt-in via `LETTERBOX_TMUX_SUBMIT=1`. Input injection can submit text already present in the target terminal buffer — use dedicated agent panes only.
