# Intelligent Loop

A methodology for executing a multi-step implementation plan with two model
tiers: a strong orchestrator model (Fable/Opus) that plans, dispatches,
reviews, and commits, and a cheaper implementer model (Sonnet) that does the
hands-on coding in isolated, fresh-context sessions. Abstracted from a real
run: six sequential prompts migrating a Go service to durable SQLite state,
all landed first-try with independent verification at every step.

## The core loop

```
                ┌─────────────────────────────────────────────┐
                │              ORCHESTRATOR (Fable)           │
                │  owns: branch, prompt queue, review, commits │
                └─────────────────────────────────────────────┘
                     │ dispatch prompt N          ▲
                     │ (full spec + context       │ final report
                     │  from prior prompts)       │
                     ▼                            │
                ┌─────────────────────────────────────────────┐
                │           IMPLEMENTER (Sonnet agent)         │
                │  fresh context, one prompt, does NOT commit  │
                └─────────────────────────────────────────────┘

  For each prompt in the plan:
    1. DISPATCH   — send the full prompt text to a fresh Sonnet agent
    2. IMPLEMENT  — agent codes, tests, reports; leaves work uncommitted
    3. REVIEW     — orchestrator reads the actual diff, not just the report
    4. VERIFY     — orchestrator independently re-runs tests/builds/checks
    5. DECIDE     — approve → commit with a clean message, move to next
                    reject → loop fixes back to the SAME agent (SendMessage)
                    with specific findings, then re-review
```

## Why the division of labor works

- **Fresh context per task.** Each implementer starts clean with exactly one
  well-scoped prompt. No context pollution from earlier tasks, no drift, no
  token exhaustion mid-implementation. The orchestrator carries the
  cross-task memory instead.
- **The orchestrator never trusts the report.** Agents report honestly in
  the aggregate but the incentive structure ("make tests pass") can produce
  weakened tests or missed edge cases. The review step reads the diff line
  by line and re-runs verification in the orchestrator's own shell. In the
  reference run this caught nothing fatal — but it *did* independently
  confirm subtle claims (e.g. "handlers map the new error type to 404")
  that a report alone couldn't prove.
- **Cost shape.** The expensive model spends tokens only on judgment
  (prompt design, diff review, decisions). The bulk token spend — reading
  files, writing code, running tests iteratively — happens on the cheaper
  tier. In the reference run the six implementer sessions consumed
  ~580k tokens; the orchestrator a fraction of that.
- **One commit per prompt.** The git history becomes the audit trail of the
  loop itself: each commit is a reviewed, independently verified, self
  contained unit. A failed prompt never contaminates the branch.

## What makes the prompts work (prerequisites)

The loop is only as good as the prompt series it executes. The prompt file
that worked had these properties, worth preserving in any adaptation:

1. **Self-contained prompts.** Each prompt names its goal, affected
   packages, concrete details, tests to write, invariants that must not
   change, and mandatory guardrail commands (`go test ./... -race -count=1`
   etc.). The implementer never has to guess scope.
2. **Explicit sequencing and dependencies.** "1 → 2 → 3 strictly; 4 and 5
   independent after 2; 6 last." The orchestrator schedules accordingly.
3. **Stop-and-report escape hatch.** "If a referenced helper does not
   exist, stop and report rather than improvise." This prevents an
   implementer from silently reinventing a prerequisite and forking the
   architecture.
4. **Invariants as review checklist.** Each prompt's invariants ("API
   responses byte-identical", "no secret material in SQLite", "no
   production code changes") become the orchestrator's review criteria —
   review is checking claims against a list, not vibes.
5. **Blast-radius flags.** The plan marked one prompt as highest-risk;
   the orchestrator gave that diff the deepest review (traced error-type
   changes through every caller).

## Orchestrator responsibilities, in order

1. **Branch setup** — create one feature branch to encapsulate the series.
2. **Dispatch** — paste the *full* prompt text into the agent prompt, plus:
   - project location and "read CLAUDE.md first"
   - context bridge: what previous prompts landed (names of packages/
     helpers now available), since the agent's context is fresh
   - the standing rule: **do not commit; the orchestrator reviews and
     commits**
   - what to include in the final report (files changed, exact commands
     run and results, deviations from spec)
3. **Review** (on completion) — in rough priority order:
   - `git status`/`git diff --stat` — does the footprint match the
     declared "affected packages"? Anything touched that shouldn't be?
   - Read the substantive diffs in full. Test files too — test honesty
     ("does this test actually exercise the claim?") is a first-class
     review dimension.
   - Chase cross-boundary risks the agent may not see: changed error
     types through their callers, changed signatures through their call
     sites, serialization compatibility.
   - Check each invariant from the prompt explicitly.
4. **Independent verification** — re-run the guardrail commands yourself.
   Never commit on the agent's word that tests pass.
5. **Decide** —
   - Pass: commit *only the files belonging to this prompt* (leave
     unrelated untracked files out), with a message describing the change
     — not the process.
   - Fail: message the same agent (its context is intact) with specific,
     located findings ("`Get` in manager.go now returns X but handler.go:322
     expects Y"). Re-review after the fix. Only spawn a fresh agent if the
     original's context is exhausted or poisoned.
6. **Report to the user between prompts** — one short paragraph: what
   landed, what the review confirmed, what's running next.

## Failure-handling rules

- **Agent reports a blocker** (missing prerequisite): stop the loop and
  surface it — a prior prompt didn't land as believed. Don't improvise.
- **Review finds defects**: loop back to the same agent, max 2–3 rounds;
  after that, escalate to the user or take over directly.
- **Tests fail on orchestrator re-run but agent claimed green**: treat as a
  serious signal — re-review the whole diff with suspicion, not just the
  failing part.
- **Scope creep found in diff**: either strip it before committing or have
  the agent revert it. Never let "bonus" changes ride along unreviewed.

---

## The skill

The invocable skill is `SKILL.md` in this directory
(`/intelligent-loop <prompts-file>`) — it is the single source of truth for
the procedure; this README carries the methodology and rationale only.

It pairs with its authoring counterpart in this collection:
**`fable-prompts` writes the prompt series; `intelligent-loop` executes it.**
The properties listed under "What makes the prompts work" above are exactly
what `fable-prompts` (via its principles and review rubric) guarantees —
authoring stays a separate, judgment-heavy activity with a human checkpoint
before execution, which is why this skill deliberately refuses to author
plans itself.

## When to use this loop (and when not)

Use it when:
- the work decomposes into 3+ self-contained, sequenceable tasks
- each task has objective acceptance criteria (tests, builds, invariants)
- the codebase has a fast, trustworthy verification command

Skip it when:
- the task is a single change (just do it directly)
- acceptance criteria are subjective/exploratory (design, research) —
  the dispatch/review structure adds latency without adding safety
- the plan itself is uncertain — plan first, loop second
