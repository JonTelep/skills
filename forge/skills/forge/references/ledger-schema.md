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
      "verify": ["go test ./internal/registry/...", "go vet ./..."],
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
      "verify": ["..."],
      "depends_on": ["T1"]
    }
  ],
  "milestones": [
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
    { "check": "app deploys locally end-to-end", "cmd": "/local-deploy", "status": "pending" },
    { "check": "no secrets in repo", "cmd": "gitleaks detect --no-banner", "status": "pending" }
  ]
}
```

Field rules:

- `status` for tasks: `pending | in_progress | done | blocked`. A task is
  `done` ONLY when its `verify` commands were re-run by the orchestrator in
  its own shell and passed, and the work is committed. `verified` and
  `commit` MUST be set together with `done`.
- `tier`: which model implements it (`sonnet` default; `opus` for tasks the
  plan flags high-risk or that require design judgment). The orchestrator is
  always Opus regardless.
- `in_progress` at iteration start means the previous iteration died
  mid-task: treat the working tree as suspect — inspect `git status`, either
  salvage (review + verify as normal) or `git checkout .` and restart the task.
- `blocked` requires `notes` explaining what is missing. Blocked tasks stop
  the loop (exit `BLOCKED`) unless another `pending` task has all its
  `depends_on` satisfied.
- Gates: `closed → open → approved`. The loop may not pass an `open` gate.
  `direction` holds the human's reply text when it wasn't a plain approval.
- Timestamps: ISO-8601 UTC, from `date -u +%Y-%m-%dT%H:%M:%SZ`.

Edit STATE.json with `jq` or careful Write — it must always parse. Corrupt
STATE.json is the one unrecoverable failure; git history is the backup
(`git log -- .forge/STATE.json`).

## `.forge/LEDGER.md` — human-readable journal (append-only)

One dated entry per iteration, newest last:

```markdown
## 2026-08-25 15:02 — iteration 4
- T1 done: registry foundation. Sonnet, 1 fix round (error type mismatch
  in handler.go:322). Verified: go test ./internal/registry/... PASS.
  Commit abc1234.
- Next: T2.
- Exit: PROGRESS
```

This is what a human attaching to tmux (or a fresh model doing handoff
triage) reads first. Keep entries under ~8 lines; the diff and STATE.json
carry the detail.

## `.forge/EXIT` — iteration exit status

The final act of every iteration is writing exactly one word to
`.forge/EXIT` and echoing it as the last line of output:

| status      | meaning                                        | outer-loop reaction (slice 2)     |
|-------------|------------------------------------------------|-----------------------------------|
| `PROGRESS`  | ≥1 task advanced, more work remains            | loop again immediately            |
| `MILESTONE` | milestone completed, PR opened/updated         | notify (FYI), loop again          |
| `BARRIER`   | gate reached, app deployed, awaiting human     | notify + park until approval      |
| `BLOCKED`   | cannot proceed without human/prereq            | notify + park                     |
| `DONE`      | all tasks done, prod_ready checklist green     | notify, stop                      |

## `.forge/DIRECTION.md` — inbound human direction

Written by the human (or by the slice-3 telegram dispatcher). If present at
iteration start, it is the FIRST thing processed: convert its content into
ledger changes (new tasks, edited tasks, an approved gate), append a LEDGER.md
entry crediting it, then move it to `.forge/direction-archive/<timestamp>.md`.
Never delete it unprocessed, never process it twice.
