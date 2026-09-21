# forge

Continuous, gate-checked progression of a project toward production-ready —
across sessions, usage windows, and models. Planning stays with
[fable-prompts](../fable-prompts-skill); forge consumes its plans.

```
/fable-prompts "goal"            → docs/prompts/<PLAN>.md   (unchanged)
/forge init docs/prompts/<PLAN>  → .forge/ ledger + G0 open; EXIT=BARRIER
                                   (parks — no auto-iterate)
approve G0                       → first iterate may run
/forge iterate                   → one idempotent step: dispatch → review →
                                   verify → commit → update ledger → EXIT status
/local-deploy                    → Claude skill (not a shell cmd); invoked
                                   by device_test gates, never via prod_ready
```

The **ledger** (`.forge/STATE.json` + `LEDGER.md`) is the only memory: any
model, session, or machine picks up by reading it. Iterations are
re-entrant — each one re-verifies every `done` task in the current open
milestone before advancing. Opus orchestrates; Sonnet subagents implement.

`/forge init` does **not** start work. It writes the ledger, opens gate
`G0` (approval), writes `EXIT=BARRIER`, and waits. Sanity-check the task
table, the DAG after fake-edge cuts, verify commands, and milestone/gate
structure, then `approve` / `approve G0` (telegram or `.forge/DIRECTION.md`).

Default is **one task per iterate**. If two (not more) `pending` tasks both
have `depends_on` done and non-overlapping `affected` packages/files, the
orchestrator MAY dispatch both in that iterate (review + verify each,
commit separately, one EXIT). Cap 2. No extra agent types. Missing
`affected` (old ledgers) stays one-wide.

## Never-list (actual safety)

The harness default is `FORGE_PERMISSION_MODE=bypassPermissions` so overnight
runs on a dedicated forge tmux. That VPS also hosts other apps. Bypass is
the blast radius; the never-list is the safety. Override the mode if you
want (e.g. `FORGE_PERMISSION_MODE=acceptEdits`). The orchestrator must not,
even under bypass:

- `git push` to `main` or `master`
- merge a PR (`gh pr merge`, `git merge` into `main`/`master`)
- `git push --force` to a protected/default branch
- docker compose / systemd / nginx changes **outside this project
  directory** (sibling stacks are off limits: `sumvid`, other compose files)
- spend money, publish (npm / crates / PyPI / Docker Hub), or production-deploy

## Components

| piece                       | what                                             | slice |
|-----------------------------|--------------------------------------------------|-------|
| `skills/forge`              | ledger-driven orchestrator (init/iterate/status) | 1 ✅  |
| `skills/local-deploy`       | discover→provision→run→verify→tailnet URLs       | 1 ✅  |
| `bin/forge.sh`              | outer loop: run iterate, classify EXIT, sleep    |       |
|                             | through usage-limit windows, park at barriers    | 2     |
| telegram outbound           | gate notifications (`.forge/outbox/` → bot)      | 2     |
| `bin/forged`                | single-poller telegram dispatcher; routes        |       |
|                             | replies to per-project `DIRECTION.md`            | 3     |
| multi-project               | one bot token, `[project]` tags, port registry   | 3     |

## Exit statuses (contract between skill and harness)

`PROGRESS` loop again · `MILESTONE` PR opened, loop · `BARRIER` gate open
(including init G0), park for human · `BLOCKED` needs human · `DONE`
prod-ready checklist green.

Harness counts `PROGRESS` + `MILESTONE` toward `FORGE_MAX_ITERATIONS`
(default 8) per process, then idles. `BARRIER` / `BLOCKED` / `DONE` do not
count. `run` starts another batch and resets the counter.

## Install

```
./install.sh
```

Symlinks both skills into `~/.claude/skills/`, creates `~/.forge/` (shared
port registry; later: telegram config, per-project inboxes).

## Env (harness)

| variable                 | default              | effect |
|--------------------------|----------------------|--------|
| `FORGE_MODEL`            | `opus`               | model for `/forge iterate` |
| `FORGE_PERMISSION_MODE`  | `bypassPermissions`  | Claude permission mode. Override to shrink blast radius. Never-list still applies. |
| `FORGE_MAX_ITERATIONS`   | `8`                  | successful `PROGRESS`+`MILESTONE` exits this process, then idle |
| `FORGE_LIMIT_RETRY_MIN`  | `30`                 | fallback sleep (minutes) when a usage-limit reset time cannot be parsed |

## Human control surface

Telegram (a background listener in `forge.sh` answers any time, even mid-task):

| send                         | effect |
|------------------------------|--------|
| `status` / `s`               | harness state, tasks done/total, gates, recent commits, ledger |
| `help` / `?`                 | this command list |
| `run` / `go` / `resume` / `continue` / `start` | start iterating from idle, or retry now while parked/sleeping |
| `stop` / `pause` / `halt`    | finish the current task, then idle (harness stays alive) |
| `quit` / `exit` / `kill`     | exit the harness |
| `dir …` / `dir: …` / `direction …` / `direction: …` | strip prefix, append remainder to `.forge/DIRECTION.md`, touch run |
| `approve` / `approve G1`     | write to `.forge/DIRECTION.md` (gate approval), touch run |
| anything else                | **ignored** — not written to DIRECTION.md; reply says to use `dir …`, `approve G1`, or a command |

Chatter is not direction. Free text does not start a run.

The harness also sends one line per completed task, milestone PR links,
gate messages (with tailnet URLs from the `local-deploy` skill),
usage-limit sleeps, and a batch-cap notice when `FORGE_MAX_ITERATIONS` is
hit.

- same thing without telegram: write `.forge/DIRECTION.md` in the repo
  (`approve G0`, or any other direction)
- watch: `tmux attach -t forge-<project>`, `.forge/harness.log`, `git log`
