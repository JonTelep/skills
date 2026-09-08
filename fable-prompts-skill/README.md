# Planning and implementation skills

`repo-conventions` gathers repository evidence. `fable-prompts` turns a goal into a
reviewable plan. `intelligent-loop` executes that plan through implementation, review,
verification, fixes, and local commits. They work with the host's available tools and
model preferences rather than requiring a particular vendor or agent API.

## What the plan contains

- Observable outcomes and an acceptance evidence map.
- Inspected code references, explicit assumptions, and future artifact contracts.
- Bounded investigation of consequential unknowns and rationale for design choices.
- Task dependencies, fixed requirements, flexible implementation choices, and escalation
  conditions.
- Relevant baseline checks, per-task verification, and final integrated acceptance.

The loop investigates discrepancies and amends the plan within the agreed scope.
It asks for user judgment when an unresolved decision changes agreed outcomes or
constraints, or needs new authorization. Progress is recorded in the plan, or in an
existing Forge ledger, so the work can resume in another session.

## Install

From the parent SKILLS repository root:

```bash
make link-codex
make link-cursor
make link          # Claude Code
```

The symlinks load the source files directly; edits here need no copy/sync step.
Start a fresh agent session if an existing session retains older skill instructions.

## Use

Open the **project you want to change**, not this skills repository. These examples
are messages to the agent, not shell commands. Naming a skill in plain language also
works when the host does not expose the same skill picker or command syntax.

### 1. Write a plan

```text
Use fable-prompts to plan: [describe the outcome I want].
Constraints: [compatibility, scope, performance, or other requirements].
Inspect this repository and resolve consequential unknowns before prescribing the
implementation. Compare approaches where the tradeoff matters. Write the plan to
docs/prompts/MY-PLAN.md with acceptance evidence, dependencies, fixed versus flexible
decisions, and final integration checks. Do not implement yet. Surface decisions
that need my judgment.
```

Review the goal, consequential choices, excluded work, and acceptance evidence.
Reply with corrections; ask the agent to update affected tasks and dependencies.
You do not need to decide every helper name or local file split.

### 2. Execute the reviewed plan

```text
Use intelligent-loop to execute docs/prompts/MY-PLAN.md.
Use available subagents when useful. Continue through implementation, review, fixes,
verification, and local task commits. Resolve routine choices autonomously and record
plan amendments that preserve the agreed outcome and constraints. Keep durable
progress. Ask me only for unresolved consequential decisions or required permissions.
Do not push or deploy. Finish by checking the integrated outcome and reporting
anything not exercised.
```

This starts the loop in the current agent session. It is not a background scheduler;
if the session stops, use the resume request below. For existing Forge-managed work,
the loop respects the ledger and returns control to Forge for each assigned iteration.

### 3. Resume or inspect

```text
Use intelligent-loop to resume docs/prompts/MY-PLAN.md. Reconcile the execution record
with Git and unfinished changes, then continue from the first ready unfinished task.
Preserve unrelated work and do not repeat completed work without a verification reason.
```

For a read-only update:

```text
Read docs/prompts/MY-PLAN.md and its execution record (or the Forge ledger). Report
accepted work, remaining tasks, blockers, and missing evidence. Do not modify anything.
```

You can authorize planning and execution together when the outcome is clear. Say so
explicitly; the skills do not force another approval between phases. For uncertain
work, the separate plan review gives you a useful decision point.

## Simplicity and references

The shared simplicity rules are adapted from
[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), with the MIT notice
preserved in `skills/fable-prompts/references/ponytail.md`. Prefer existing capabilities
and the minimum maintainable solution. Evaluate coupling, duplication, and operational
burden rather than rewarding fewer lines at any cost.

Planning details live in `principles.md`, `template.md`, and `review-rubric.md` under
that references directory. Each skill's `SKILL.md` is its procedural source of truth.
