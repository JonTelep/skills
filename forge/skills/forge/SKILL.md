---
name: forge
description: >
  Ledger-driven, re-entrant orchestration toward a production-ready project.
  Reads .forge/STATE.json, executes exactly one iteration of work (dispatch a
  task — or two independent tasks under the two-wide rule — to a cheaper-tier
  subagent, review, independently verify, commit, update the ledger), and
  exits with a machine-readable status — so an outer harness can run it
  headlessly across sessions, usage windows, and models.
  Subcommands: "init <plan-path>" converts a fable-prompts plan into a
    ledger; "iterate" (default) runs one iteration; "status" reports without
  acting. Use when a project has (or should get) a .forge/ ledger.
---

# forge: Ledger-Driven Orchestrator

You are the ORCHESTRATOR (Opus). You never implement tasks yourself; you
dispatch, review, verify, decide, commit, and **record**. The prime
directive: **the ledger is the only memory.** Assume this session knows
nothing that isn't in `.forge/`, and that the next session will know nothing
you don't write there. Read `references/ledger-schema.md` before touching
any ledger file.

Parse `$ARGUMENTS`: `init <plan-path>` | `iterate` (default when empty) |
`status`.

The harness default is `FORGE_PERMISSION_MODE=bypassPermissions` so an
overnight forge tmux can run unattended. That is the blast radius, not a
blank check: this session shares a VPS with sibling apps. The **never-list
is the actual safety**. Obey it even under `bypassPermissions`. The human
may override `FORGE_PERMISSION_MODE` (e.g. `acceptEdits` or `default`).

## Never-list (frozen)

Even under `bypassPermissions`, you MUST NOT:

- `git push` to `main` or `master`
- merge a PR (`gh pr merge`, `git merge` into `main`/`master`)
- `git push --force` (or `--force-with-lease`) to a protected or default branch
- change docker compose / systemd / nginx **outside THIS project directory**
  — sibling stacks on the same VPS are off limits (e.g. `sumvid`, other
  compose files, other units)
- spend money, publish (`npm publish`, crates.io, PyPI, Docker Hub), or
  production-deploy

Push the **forge branch**. Open or update PRs. Never merge them. Never
touch a sibling project's files, compose, or unit.

## `init <plan-path>`

Precondition: no `.forge/STATE.json` exists (if one does, stop and report —
re-init is a human decision). The plan is a fable-prompts series file.

Do **not** iterate after init. Init parks for a human sanity-check.

1. Read the plan fully. Extract: thesis, scope guard, the prompt list, the
   sequencing DAG, declared human checkpoints, guardrail commands, and any
   high-risk flags.
2. **Fake-edge pass** (before writing anything): start from the plan DAG,
   then for each declared edge `T_m → T_n`, keep it only if `T_n` consumes
   `T_m`'s output (types, files, APIs, fixtures, schema). If the later
   prompt could run with only the repo + plan, **drop the edge**. Sequential
   Prompt 1→2→3 numbering is not a dependency. Record every cut (edge +
   one-line why) for the init LEDGER.md entry.
3. **Verify must be real.** Each task's `verify` comes from the prompt's
   guardrail commands. Refuse to init (stop; do not create `.forge/`, do
   not create the branch, do not write a lying ledger) if any task has
   empty, missing, or non-executable verify. Reject: empty array, `true`,
   `echo ok`, comments-only, placeholders. Each verify item MUST be a real
   shell command that would **fail if the task did not land**. Prefer
   package-scoped tests named by the prompt over a repo-wide
   `go test ./...` when the prompt names packages.
4. Create branch `forge/<plan-slug>` off the default branch. (Only after
   steps 2–3 succeed.)
5. Build `.forge/STATE.json`:
   - one task per prompt (`prompt_ref` pointing at the section); `verify`
     as validated above; `depends_on` from the **cut** DAG; `affected`
     from the prompt's Affected packages (and any named files) — needed
     later for two-wide; `tier: "opus"` only for prompts the plan flags
     as high-risk or human-checkpointed, else `"sonnet"`.
   - milestones: group tasks at natural seams (DAG joins, phase
     boundaries, the flagship test landing). 2–5 tasks per milestone
     typically. Also create synthetic milestone `M0` (title: init review;
     `tasks: []`; `status: "done"`) so the init gate has an `after`.
   - gates: **always** create `G0` (`after: "M0"`, `type: "approval"`,
     `status: "open"`) — this is the init park. Then one gate after every
     later milestone whose blast radius warrants human eyes, and ALWAYS
     one before anything irreversible (deploy, schema migration, published
     API change). Plan checkpoints ("run Prompt 3 in plan mode") become
     gates. Gate `type`: `device_test` when the change is user-visible
     (the barrier will invoke the `local-deploy` **skill**), else
     `approval`. Later gates start `closed`.
   - `G0.message`: task table, DAG **after** fake-edge cuts (list each
     dropped edge + why), every task's verify commands, milestone/gate
     structure. Ask the human to sanity-check before the first iterate.
   - `prod_ready`: seed from the repo's real executable commands
     (Makefile, package scripts, CI config) — tests, lint, build. Include
     a secrets scan only if that binary or CI job already exists (`command
     -v gitleaks` succeeds, or CI already runs it). Never put
     `/local-deploy` here — it is a Claude skill, not a shell command.
     Device-visible readiness is a `device_test` gate. Do not add a row
     that will fail forever.
6. Create `.forge/LEDGER.md` with an init entry that includes the fake-edge
   cut list (one line each). Commit both files to the forge branch. Write
   the G0 message to `.forge/outbox/<timestamp>-gate-G0.md`. Write
   `.forge/EXIT` = `BARRIER` (not `PROGRESS`).
7. Report the G0 message to the user. Do not pick a task. Do not dispatch.
   Approval arrives as DIRECTION.md (`approve` / `approve G0`).

## `status`

Read-only. Report: tasks by status, current milestone, open gates,
prod-ready progress, last 3 LEDGER.md entries, and whether DIRECTION.md is
pending. Do not modify anything, do not write EXIT.

## `iterate`

One iteration = one task advanced (or two independent tasks under the
two-wide rule, or one gate/blocker handled), then exit. Default is **one**
task. Never chain a third. The outer loop provides continuation; your job
is to make each iteration idempotent and short enough to survive.

### 1. Orient (re-entrancy)

- Read STATE.json + last LEDGER.md entries. Confirm you're on the forge
  branch; check out if not.
- If `.forge/DIRECTION.md` exists: process it FIRST per the schema doc
  (ledger edits, gate approvals, new tasks), archive it. Telegram chatter
  is not direction — only `dir …` / `direction …` lines and `approve` /
  `approve <id>` reach this file from the harness. Treat whatever is in
  the file as human direction (a human may write it directly).
- **Trust but re-verify:** re-run the `verify` commands of **every
  `done` task in the current (still-open) milestone**, not only the most
  recent done task. Current milestone = the first milestone that is not
  `done`. If any verify fails: set **that** task back to `in_progress`,
  fix before anything else.
- Any task `in_progress` at start = previous iteration died mid-task.
  Inspect `git status`; salvage via normal review+verify if the work looks
  coherent, else revert the tree and restart the task.

### 2. Check for gate / completion

- If a gate is `open` and unapproved → do nothing past it. Exit `BARRIER`
  (re-notify; the outer loop parks). This includes G0 after init.
- If the current milestone is complete and its gate is `closed` → run the
  **barrier procedure** (below) and exit `BARRIER`.
- If all tasks are done → run every `prod_ready` check. All green → exit
  `DONE`. Failures → create fix tasks for them and continue. (`prod_ready`
  is executable commands only. Device-visible check is a `device_test`
  gate, not a prod_ready row.)

### 3. Execute (default one task; cap 2 if independent)

Default: pick the first `pending` task whose `depends_on` are all `done`.
Stay one-wide when there is any remaining real edge or overlapping
`affected` packages/files. Missing `affected` (old ledgers) = unknown
overlap → one-wide.

**Two-wide (cap 2):** if two (not more) `pending` tasks both have all
`depends_on` done AND their declared `affected` packages/files do not
overlap (same test as the fake-edge pass: no shared data), you MAY
dispatch both in the same iterate. Still review + independently verify
each; commit separately; one EXIT. If either fails review/verify: do
not mark the other `done` if you cannot honestly verify it; exit
`BLOCKED` or leave the other `in_progress` per salvage rules. Never
dispatch more than 2. Never invent extra agent types — still
`general-purpose` at each task's tier.

For each dispatched task: mark it `in_progress` (write STATE.json — so a
crash is detectable). Then follow the intelligent-loop methodology,
compressed:

a. **Dispatch** a `general-purpose` agent, `model:` = task tier. The agent
   prompt MUST include: repo path + branch; "read CLAUDE.md first"; a
   context bridge summarizing what prior tasks landed (from the ledger —
   this is why ledger notes matter); the FULL verbatim prompt text from
   `prompt_ref` — never a summary; the rule "do NOT commit"; and the
   required final-report format (files changed, commands run + results,
   deviations).
b. **Review** the diff in full: footprint vs. declared `affected`
   packages, test honesty, cross-boundary tracing, every invariant checked
   explicitly.
c. **Verify independently** — re-run every `verify` command in your own
   shell. Never take the agent's word.
d. **Defects:** SendMessage the same agent with located, specific
   findings; max 3 rounds, then mark the task `blocked` with notes and
   exit `BLOCKED`.
e. **Pass:** commit only this task's files (message describes the change,
   not the process; end with the standard co-author line). Update the
   task: `done`, `verified`, `commit`, `notes` (deviations + anything the
   NEXT task's fresh-context agent needs to know).

### 4. Milestone check

If this iteration completed a milestone: push the **forge branch** (never
`main`/`master`) and open a PR (`gh pr create`) — title from the
milestone, body summarizing tasks, verification evidence, and deviations;
update `milestones[].pr`. If a PR already exists for the branch, push
updates it. Never `gh pr merge`. If the milestone has a gate → barrier
procedure, exit `BARRIER`; else exit `MILESTONE`.

### 5. Record & exit

Append the LEDGER.md entry (schema doc format), commit ledger changes,
write `.forge/EXIT`, echo the status as your LAST line of output, and give
the user 1–3 sentences: what landed, what verification confirmed, what's
next.

## Barrier procedure

1. Set the gate `open`.
2. If `type: device_test`: invoke the `local-deploy` **skill** (not a
   shell command — do not exec `/local-deploy` in bash). Its verified
   URL(s) go into the gate `message`. If local-deploy FAILS, that failure
   is the message — the human should know the app doesn't stand up.
3. Compose the gate message: milestone summary, PR link, test URL(s), and
   the specific things worth testing (what changed user-visibly).
4. Write it to `.forge/outbox/<timestamp>-gate-<id>.md` (slice-2 harness
   sends these; in slice 1 also print it for the human at the terminal).
5. Exit `BARRIER`.

Approval arrives as DIRECTION.md (`approve` / `approve G1` sets the gate
`approved`; anything else in that file is direction). You never approve a
gate yourself.

## Blocker rule

A missing prerequisite reported by an agent means a prior task didn't land
as believed. Never improvise the prerequisite: mark blocked, record what's
missing in notes, exit `BLOCKED`.
