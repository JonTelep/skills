---
name: intelligent-loop
description: Execute a reviewed multi-task plan through implementation, diff review, verification, fixes, and local task commits, with durable progress and evidence-based plan amendments. Use when the user asks to run or resume a prompt series. Supports available subagents or sequential execution when delegation is unavailable.
---

# Intelligent Loop

Own the plan, dispatch, review, verification, recovery, and task commits. Delegate
implementation when supported and useful. If delegation is unavailable, implement
sequentially and report self-review honestly; a second test run is not an independent
reviewer. Use `../fable-prompts/references/ponytail.md` for simplicity decisions. If
that companion file is unavailable, use the minimum maintainable solution consistent
with requirements; do not block solely on optional review guidance.

## Input and preflight

Read the plan path supplied by the user (or host-provided arguments). Parse task
headings, dependencies, contracts, acceptance evidence, required checks, and existing
user checkpoints; do not split mechanically on every Markdown horizontal rule.

Read applicable repository instructions, including AGENTS.md and agent-specific
files. Inspect HEAD, branch, staged/unstaged changes, and untracked files. Reuse an
appropriate feature branch or create one from the intended baseline. Preserve user
work; isolate conflicting work in a worktree when practical. Never reset or clean
the tree to obtain a convenient baseline.

Check required tools and relevant baseline verification before editing. Record
existing failures and unavailable checks. Investigate missing acceptance criteria
or commands and repair the plan within the agreed goal where possible; ask only
when a material decision cannot be inferred or resolved from repository evidence.
A baseline failure is not permission to waive a required gate.

An execution request authorizes the local implementation/review/fix loop and task
commits unless the user says otherwise. It does not imply authorization to push,
merge, publish, or deploy. Honor authorization and review checkpoints already agreed
with the user; do not ask again merely because this skill is running. If asked only
to plan, use fable-prompts and stop at the plan.

## Durable progress

For an ordinary run, keep a compact `## Execution record` at the end of the plan:
plan revision, starting commit and branch, initial user changes, baseline results,
and a task table with ID, status, accepted commit, verification evidence, deviations,
and next action. Record amendments with rationale and affected task IDs. Statuses:
`pending`, `in_progress`, `done`, `blocked`; done means reviewed, required checks
passed, and committed (or explicitly accepted without a commit at the user's request).
Record non-automated acceptance evidence and unresolved claims too.

If the project already uses Forge, read its ledger schema and use `.forge/STATE.json`
and `.forge/LEDGER.md` instead of a second execution record. Preserve its schema,
gates, and harness ownership. Put additional plan revision/baseline/evidence details
in task notes and journal entries. When invoked by Forge, execute only the assigned
iteration and return control; do not run the remaining series or operate the harness.

Before dispatch, persist `in_progress`. After accepting code, record the accepted
commit and checks. A separate small record commit may follow the task commit; never
invent a self-referential commit SHA. On resume, reconcile records with Git and actual
artifacts, inspect unfinished changes, and check relevant prerequisites. Recover a
commit made before its record update through review and verification. Re-run checks
when changes, stale evidence, or uncertainty justify it; do not restart completed work.

## Task loop

1. **Select and refresh.** Choose a task with satisfied dependencies. Confirm its
   prerequisite contracts against the current checkout, update stale references,
   and include accepted amendments. Do not dispatch dependent work on unresolved
   assumptions.
2. **Dispatch.** Use the host's available delegation tools and configured model
   preferences. Choose capability appropriate to uncertainty and consequence; do not
   hardcode a vendor model or assume cheaper is always adequate. Provide:
   - repo/worktree path, branch, and applicable instruction files;
   - full current task text, relevant series constraints, prerequisite contracts,
     and the context bridge from prior accepted work;
   - fixed requirements, flexible choices, escalation conditions, and relevant
     simplicity guidance (the compact block when the companion file is available);
   - no commit/push; preserve unrelated work; return files changed, exact commands
     and outcomes, evidence for claims, deviations, and unresolved questions.
3. **Review actual artifacts.** Inspect staged and unstaged diffs plus new/untracked
   files belonging to the task. Read substantive code and tests, trace changed
   contracts through callers, check protected boundaries, and assess test honesty.
   Explain changed expectations. Classify findings by concrete correctness risks,
   violated requirements, or material maintenance cost; preferences are nonblocking.
4. **Verify.** Run required task checks yourself on the reviewed work. For delegated
   work this independently verifies the implementer's report. Use targeted checks
   during repair and broader checks when required by repository rules or impact.
   Distinguish pass, fail, and not exercised. A command failure requires diagnosis,
   not an assumption of dishonesty; compare environment, revision, and exact command.
5. **Repair or amend.** Send located findings and acceptance conditions to the same
   agent using the host's continuation facility. If it cannot resume, give a fresh
   agent the current diff and findings. After three unsuccessful correction rounds,
   diagnose whether the cause is the contract, implementation, environment, or task
   size. Change strategy: split, investigate, revise within scope, select a suitable
   agent, or take over. If taking over, obtain a separate review when available and
   warranted, otherwise disclose self-review. Do not repeat an unchanged failing
   strategy indefinitely. Block only dependent work that cannot proceed; continue
   independent authorized work when useful.
6. **Accept and record.** Commit only the reviewed task changes after required gates
   pass. Stage paths or hunks explicitly and inspect the staged diff; a shared file
   may include user changes. Reverify if staged content differs materially from the
   tested state. Leave unrelated work intact. Update durable progress and report
   briefly what landed, what evidence supports it, and what is next.

## Discrepancy recovery

An unexpected reference is a finding to investigate, not proof of a failed prior task.
- **Stale reference:** locate the renamed/moved symbol and confirm equivalent semantics;
  update the reference and continue.
- **Missing prerequisite:** inspect producer commits and checkout state. Restore or
  complete the prerequisite only through scoped review and verification; do not
  recreate a guessed substitute inside the consumer.
- **Invalid assumption/design:** gather evidence, propose the smallest amendment that
  preserves the agreed outcome, and revise affected tasks and acceptance evidence.

Implementers surface fixed-contract changes to the orchestrator before acting on them.
The orchestrator resolves routine amendments within existing authorization and records
why. Ask the user when the resolution changes agreed outcomes or constraints, needs
new permission, or leaves a consequential choice unresolved. While waiting, work only
on independent tasks. Every amendment is reviewed before affected tasks are dispatched.

## Parallel work

Sequential by default. Parallel writers require separate Git worktrees and genuinely
independent contracts and resources. If isolation is unavailable, stay sequential.
Serialize review and integration. Recheck the combined result after integration:
passing checks in isolated worktrees does not prove the merged behavior works.

## Completion

Run the plan's final integrated scenario and required final checks, including relevant
dependency joins. Reconcile every acceptance claim with its evidence. Do not report
the series complete while required checks or user evaluations remain unfulfilled.
Report task-to-commit mapping, integrated results, deviations, and anything not
exercised. Summarize deliberate limitations added or changed by this series, including
`ponytail:` ceilings and upgrade triggers; do not dump unrelated historical debt.
Record the final state so another session can resume without this conversation.
