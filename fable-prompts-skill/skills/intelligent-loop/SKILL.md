---
name: intelligent-loop
description: >
  Orchestrate a multi-prompt implementation plan: dispatch each prompt to a
  cheaper-tier subagent (Sonnet) with fresh context, review the diff as the
  orchestrator, independently verify, loop fixes back to the same agent, and
  commit each prompt's work separately on a dedicated branch. Use when the
  user has a prompt-series file (a plan of standalone implementation prompts)
  and asks to execute it with the dispatch/review loop.
---

# Intelligent Loop

You are the ORCHESTRATOR. You never implement prompts yourself; you
dispatch, review, verify, decide, and commit. See README.md in this
directory for the full methodology and rationale.

## Input

`$ARGUMENTS` is the path to a prompts file. Read it fully. Extract:

- the ordered list of prompts (sections between `---` separators)
- sequencing constraints and any prompts flagged high-risk
- per-prompt guardrail commands and invariants

If any prompt lacks objective acceptance criteria (tests, builds,
invariants) or a guardrail command, surface that to the user before
starting — the loop's safety depends on them.

## Procedure

1. **Branch setup.** Create one feature branch named after the plan (ask
   only if the working tree is dirty with conflicting changes).
2. **For each prompt, in the declared order:**
   a. **Dispatch** a `general-purpose` agent with `model: sonnet`. The
      agent prompt MUST contain:
      - the repo path and branch; "read CLAUDE.md first"
      - a context bridge naming what previous prompts landed (packages,
        helpers, types now available), since the agent's context is fresh
      - the FULL verbatim prompt text — never a summary
      - the standing rule: "do NOT commit — leave changes in the working
        tree; the orchestrator reviews and commits"
      - a required final-report format: files changed, exact commands run
        and their results, any deviations from spec
   b. **Review** on completion, in rough priority order:
      - `git status` / `git diff --stat` — does the footprint match the
        declared affected packages? Anything touched that shouldn't be?
      - Read the substantive diffs in full. Test files too — test honesty
        ("does this test actually exercise the claim?") is a first-class
        review dimension.
      - Trace cross-boundary changes (error types, signatures,
        serialization formats) through their callers — risks the agent
        may not see from inside its scope.
      - Check every invariant listed in the prompt explicitly. Review is
        checking claims against a list, not vibes.
   c. **Verify independently.** Re-run every guardrail command in your
      own shell. Never commit on the agent's word that tests pass.
   d. **On defects:** SendMessage the SAME agent (its context is intact)
      with located, specific findings ("`Get` in manager.go now returns X
      but handler.go:322 expects Y"); re-review after the fix. Max 3
      rounds, then surface to the user or take over directly. Only spawn
      a fresh agent if the original's context is exhausted or poisoned.
   e. **On pass:** commit ONLY this prompt's files (leave unrelated
      untracked files out) with a message describing the change — not the
      process. One commit per prompt.
   f. **Report to the user** in 1–3 sentences: what landed, what the
      review confirmed, what's running next.
3. **Blocker rule.** If an agent reports a missing prerequisite, STOP the
   loop and report — a prior prompt didn't land as believed. Never
   improvise the prerequisite.
4. **Finish** with a summary table (commit ↔ prompt), overall
   verification status, and offer to open a PR.

## Parallelism

Sequential by default. If the prompts file declares two prompts
independent, you may dispatch them concurrently — but:

- parallel agents must use `isolation: worktree` so they don't trip over
  each other's working tree
- review and commit must still be serialized

## Failure-handling rules

- **Tests fail on your re-run but the agent claimed green:** treat as a
  serious signal — re-review the whole diff with suspicion, not just the
  failing part.
- **Scope creep found in the diff:** strip it before committing or have
  the agent revert it. Never let "bonus" changes ride along unreviewed.
- **High-risk-flagged prompts** get the deepest diff review (trace every
  caller of anything whose type or behavior changed).

## Hard rules

- Orchestrator commits; implementers never do.
- Independent verification before every commit.
- Dispatch the full verbatim prompt text, never a paraphrase.
- Unrelated untracked files never ride along in commits.
- This skill does NOT author the prompts file. If the user has no plan
  yet, tell them to plan first — writing a good prompt series is a
  separate, judgment-heavy activity with a human checkpoint before
  execution.

## Composing with other skills

- The review step may invoke `/code-review` on the diff for an extra
  adversarial pass before commit.
- `/verify` can drive the affected flow end-to-end when a prompt changes
  runtime behavior.

## When to use (and when not)

Use when the work decomposes into 3+ self-contained, sequenceable tasks,
each with objective acceptance criteria, in a codebase with a fast,
trustworthy verification command.

Skip when the task is a single change (just do it directly), when
acceptance criteria are subjective or exploratory, or when the plan
itself is uncertain — plan first, loop second.
