# Ledger schema

The ledger is the **only** state that survives between iterations, sessions,
models, and machines. Anything not written here does not exist. Two files,
both living in `.forge/` at the target repo root (committed to git, on the
forge branch):

## `.forge/STATE.json` — machine state (authoritative)

```json
{
  "version": 1,
  "project": "myapp",
  "plan": "docs/prompts/FABLE-PROMPTS-3.md",
  "branch": "forge/fable-prompts-3",
  "created": "2026-08-25T14:00:00Z",
  "thesis": "one falsifiable outcome sentence, copied from the plan",
  "tasks": [
    {
      "id": "T1",
      "title": "Build the source registry foundation",
      "prompt_ref": "Prompt 1",
      "tier": "sonnet",
      "status": "done",
      "affected": ["internal/registry"],
      "verify": ["go test ./internal/registry/...", "go vet ./internal/registry/..."],
      "verified": "2026-08-25T15:02:11Z",
      "commit": "abc1234",
      "notes": "deviation: helper named NewRegistry not MakeRegistry (pre-existing convention)"
    },
    {
      "id": "T2",
      "title": "...",
      "prompt_ref": "Prompt 2",
      "tier": "sonnet",
      "status": "pending",
      "affected": ["internal/store"],
      "verify": ["go test ./internal/store/..."],
      "depends_on": []
    }
  ],
  "milestones": [
    {
      "id": "M0",
      "title": "Init review",
      "tasks": [],
      "status": "done",
      "pr": null
    },
    {
      "id": "M1",
      "title": "Registry foundation proven",
      "tasks": ["T1", "T2"],
      "status": "pending",
      "pr": null
    }
  ],
  "gates": [
    {
      "id": "G0",
      "after": "M0",
      "type": "approval",
      "status": "approved",
      "message": "init review: task table, DAG after fake-edge cuts, verify cmds, milestone/gate structure",
      "approved": "2026-08-25T14:05:00Z",
      "direction": null
    },
    {
      "id": "G1",
      "after": "M1",
      "type": "device_test",
      "status": "closed",
      "message": "what the human should test, in one paragraph",
      "approved": null,
      "direction": null
    }
  ],
  "prod_ready": [
    { "check": "all tests green", "cmd": "make test", "status": "pending" },
    { "check": "lint clean", "cmd": "make lint", "status": "pending" },
    { "check": "build succeeds", "cmd": "make build", "status": "pending" }
  ]
}
```

The example is mid-run (G0 already approved). At init, G0 is `open` and
unapproved; T2's empty `depends_on` is what a fake-edge cut looks like
(plan said 1→2; T2 does not consume T1's output). Old ledgers without
`affected` or `M0`/`G0` remain valid: missing `affected` ⇒ one-wide;
missing G0 ⇒ no init park (only new inits create it).

Field rules:

- `status` for tasks: `pending | in_progress | done | blocked`. A task is
  `done` ONLY when its `verify` commands were re-run by the orchestrator in
  its own shell and passed, and the work is committed. `verified` and
  `commit` MUST be set together with `done`.
- `verify`: non-empty array of real shell commands that fail if the task
  did not land. Init refuses (no ledger) on empty/missing verify, `true`,
  `echo ok`, comments-only, or other non-commands. Prefer package-scoped
  tests named by the prompt over a repo-wide `go test ./...`.
- `depends_on`: edges that survived the fake-edge pass. Sequential prompt
  numbering is not a dependency. Cuts are recorded in the init LEDGER.md
  entry, one line each.
- `affected` (optional): packages/files the prompt declares. Used for
  two-wide overlap checks. Absent or empty ⇒ treat as unknown overlap ⇒
  one-wide. Old ledgers stay valid without it.
- `tier`: which model implements it (`sonnet` default; `opus` for tasks the
  plan flags high-risk or that require design judgment). The orchestrator is
  always Opus regardless.
- `in_progress` at iteration start means the previous iteration died
  mid-task: treat the working tree as suspect — inspect `git status`, either
  salvage (review + verify as normal) or `git checkout .` and restart the task.
- `blocked` requires `notes` explaining what is missing. Blocked tasks stop
  the loop (exit `BLOCKED`) unless another `pending` task has all its
  `depends_on` satisfied.
- Milestones: `pending | done`. `M0` is the synthetic init milestone
  (`tasks: []`, `done` at init) so `G0.after` has a target.
- Gates: `closed → open → approved`. The loop may not pass an `open` gate.
  Init creates `G0` (`type: approval`, `after: M0`) already `open` — first
  iterate parks until `approve` / `approve G0`. Later gates start `closed`
  and open via the barrier procedure. `direction` holds the human's reply
  text when it wasn't a plain approval. The orchestrator never self-approves.
- `prod_ready[].cmd` must be an executable shell command seeded from the
  repo (Makefile, package scripts, CI). Never `/local-deploy` — that is a
  Claude skill; device-visible readiness is a `device_test` gate that
  invokes the `local-deploy` skill in the barrier procedure. Include a
  secrets-scan row only when the binary or CI job already exists; do not
  add a row that will fail forever.
- Timestamps: ISO-8601 UTC, from `date -u +%Y-%m-%dT%H:%M:%SZ`.

Edit STATE.json with `jq` or careful Write — it must always parse. Corrupt
STATE.json is the one unrecoverable failure; git history is the backup
(`git log -- .forge/STATE.json`).

## `.forge/LEDGER.md` — human-readable journal (append-only)

One dated entry per iteration, newest last:

```markdown
## 2026-08-25 14:00 — init
- Plan: docs/prompts/FABLE-PROMPTS-3.md. 6 tasks, milestones M0+M1–M3, G0 open.
- Fake-edge cuts:
  - T1→T2 dropped: T2 only needs repo + plan (shared types already in tree).
  - T3→T4 dropped: T4 does not import T3's package.
- Verify: all package-scoped. G0 parks for human review.
- Exit: BARRIER

## 2026-08-25 15:02 — iteration 4
- T1 done: registry foundation. Sonnet, 1 fix round (error type mismatch
  in handler.go:322). Verified: go test ./internal/registry/... PASS.
- Next: T2.
- Exit: PROGRESS
```

This is what a human attaching to tmux (or a fresh model doing handoff
triage) reads first. Keep entries under ~8 lines; the diff and STATE.json
carry the detail. Init entry MUST list every fake-edge cut (or "none").

## `.forge/EXIT` — iteration exit status

The final act of every iteration (and of `init`) is writing exactly one
word to `.forge/EXIT` and echoing it as the last line of output:

| status      | meaning                                        | outer-loop reaction (slice 2)     |
|-------------|------------------------------------------------|-----------------------------------|
| `PROGRESS`  | ≥1 task advanced, more work remains            | loop again immediately            |
| `MILESTONE` | milestone completed, PR opened/updated         | notify (FYI), loop again          |
| `BARRIER`   | gate open, awaiting human (incl. init G0)      | notify + park until approval      |
| `BLOCKED`   | cannot proceed without human/prereq            | notify + park                     |
| `DONE`      | all tasks done, prod_ready checklist green     | notify, stop                      |

Harness counts successful `PROGRESS` and `MILESTONE` exits toward
`FORGE_MAX_ITERATIONS` (default 8) in this process, then idles. `BARRIER`,
`BLOCKED`, and `DONE` do not count. `run` starts another batch.

No other EXIT words. Harness parks on `BARRIER` / `BLOCKED`.

## `.forge/DIRECTION.md` — inbound human direction

Written by the human (or by the telegram listener). If present at iteration
start, it is the FIRST thing processed: convert its content into ledger
changes (new tasks, edited tasks, an approved gate), append a LEDGER.md
entry crediting it, then move it to `.forge/direction-archive/<timestamp>.md`.
Never delete it unprocessed, never process it twice.

The harness writes this file **only** for:

- lines prefixed `dir ` / `dir:` / `direction ` / `direction:` (prefix
  stripped; remainder appended)
- `approve` or `approve <id>` (gate approval; written as-is)

Any other telegram text is ignored and is **not** written here. A human
may still write the file directly in the repo. `approve` / `approve G0`
is how the init gate (and later gates) clear. The orchestrator never
self-approves.
