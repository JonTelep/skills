# forge

Continuous, gate-checked progression of a project toward production-ready —
across sessions, usage windows, and models. Planning stays with
[fable-prompts](../fable-prompts-skill); forge consumes its plans.

```
/fable-prompts "goal"            → docs/prompts/<PLAN>.md   (unchanged)
/forge init docs/prompts/<PLAN>  → .forge/ ledger (tasks, milestones, gates)
/forge iterate                   → one idempotent step: dispatch → review →
                                   verify → commit → update ledger → EXIT status
/local-deploy                    → app running on the tailnet, verified URLs
```

The **ledger** (`.forge/STATE.json` + `LEDGER.md`) is the only memory: any
model, session, or machine picks up by reading it. Iterations are
re-entrant — each one re-verifies the last claim before advancing. Opus
orchestrates; Sonnet subagents implement.

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

`PROGRESS` loop again · `MILESTONE` PR opened, loop · `BARRIER` gate open,
park for human · `BLOCKED` needs human · `DONE` prod-ready checklist green.

## Install

```
./install.sh
```

Symlinks both skills into `~/.claude/skills/`, creates `~/.forge/` (shared
port registry; later: telegram config, per-project inboxes).

## Human control surface

- approve / redirect: write `.forge/DIRECTION.md` in the target repo
  (`approve G1`, or free-text direction → becomes ledger tasks)
- watch: tmux session per project (slice 2), `git log`, PRs per milestone
- test on phone: gate messages include tailnet URLs from /local-deploy
