# tmux adapter guide

Agent Letterbox rings live agents with a durable-letter-first pattern:

```text
letter written to inbox
→ tmux adapter finds a live registered pane (or static session)
→ injects the generic doorbell text (when SUBMIT is enabled)
→ agent checks its durable inbox
```

The terminal gets the knock; the inbox keeps the message. Doorbell delivery is best-effort. The letter on disk is the record.

## Targets

### Preferred: live registry

`letterbox tmux run` / `letterbox tmux register` write:

```text
agent	pane_id	session_name	registered_at
```

into `$LETTERBOX_DIR/tmux-agents.tsv` (override with `LETTERBOX_TMUX_REGISTRY`).

The adapter checks this file **first** and uses a pane only if it is still live. Registration refuses to silently assign the same live pane to two agent identities.

### Fallback: static patterns

```text
# agent<TAB>tmux-session-name
planner	planner-session
reviewer	reviewer-session
```

```bash
export LETTERBOX_TMUX_PATTERNS="$LETTERBOX_DIR/tmux-patterns.tsv"
```

Static session-name matching is a convenience fallback for agents that do not self-register. It is never proof of identity when several panes share a session or titles collide. Prefer live registration for multi-agent teams.

## Enable automatic agent input

By default the adapter only posts a tmux status-line notification. To inject the standardized doorbell and Enter into the live pane:

```bash
export LETTERBOX_TMUX_SUBMIT=1
```

This uses:

```bash
tmux send-keys -t <pane-or-session> -l '<doorbell>'
tmux send-keys -t <pane-or-session> Enter
```

Setup flag `--automatic-doorbells` (alias `--submit`) turns this on in the generated environment.

## Safety

`LETTERBOX_TMUX_SUBMIT=1` can submit text already waiting in the target terminal buffer. Use it only for dedicated agent panes where that risk is acceptable.

The doorbell contains no task content — only a short generic nudge such as:

```text
📬 letterbox doorbell: check your inbox
```

Doorbell delivery means a wake-up was submitted to a verified live target, not that the agent read or accepted the letter. If a safe live target cannot be verified, Letterbox prefers silent durable delivery over risky pane injection.

## Maintenance and recovery

Do not rebuild tmux layouts while important agents are mid-turn unless you plan to re-register.

### After detach/reattach, host restart, or layout rebuild

1. Confirm tmux is healthy and list panes/sessions:

   ```bash
   tmux list-sessions
   tmux list-panes -a
   ```

2. **Re-register every live agent from inside its own pane.** Do not reuse remembered pane ids.

   ```bash
   letterbox tmux register <agent-id>
   letterbox tmux status
   ```

3. Each agent should scan its inbox (including any `[ACCEPTED]` WIP marked by `.md.ack` sidecars):

   ```bash
   letterbox check
   ```

4. Run a harmless smoke check:

   - Send a `priority: now` `info` letter to a live agent in another pane.
   - Confirm the letter appears in that agent's inbox.
   - Confirm the standardized doorbell reaches the intended pane only (when submit is on).
   - Have the recipient `letterbox file` the info letter.
   - Optionally run one disposable `delegate --ack` → `reply ack` → `reply result` cycle.

### Accepted WIP after interruption

An `[ACCEPTED]` task letter is still open work. After recovery:

- finish with `letterbox reply <id> result …`, or
- decline with `letterbox reply <id> nack …`.

Do not `file` it, and do not hand-delete the `.md.ack` sidecar.

### SSH / headless notes

- You can ring panes over SSH if you attach to the same tmux server that holds the registered panes.
- Letterbox files still need a shared filesystem path (`LETTERBOX_DIR`). SSH alone does not replicate mailboxes between machines.
- On headless hosts, prefer status-line notifications unless agent panes are dedicated and `LETTERBOX_TMUX_SUBMIT=1` is an accepted risk.

## Validate

```bash
./tests/test_tmux_doorbell.sh
./tests/test_tmux_bootstrap.sh
```

`make test` runs the full suite.
