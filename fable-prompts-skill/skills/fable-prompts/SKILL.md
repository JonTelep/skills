---
name: fable-prompts
description: Turn a codebase improvement goal into an evidence-backed, sequenced implementation plan with acceptance checks and explicit decision boundaries. Use when the user wants a plan of standalone tasks to review before execution with intelligent-loop. Produces a named Markdown plan under docs/prompts/; does not implement the series.
---

# Fable Prompts

Write for an implementing agent starting without this conversation. Give it the
outcome, evidence, constraints, and decision authority needed to work independently.
Read `references/principles.md` for planning decisions, use
`references/template.md` for the output, and review with
`references/review-rubric.md`. Read `references/ponytail.md` once for the shared
simplicity rules.

## 1. Sharpen the outcome

State the observable outcome, scope, compatibility constraints, and what counts as
completion. Separate user requirements from inferred preferences. Ask only questions
whose answers materially change the plan; investigate what the repo can answer and
continue independent work while waiting. State reasonable assumptions explicitly.

Apply the reuse ladder to the proposal itself: identify what already exists and
what can be omitted. A single small change does not need a multi-task series.

## 2. Gather evidence and resolve uncertainty

Read applicable repository instructions, including AGENTS.md and relevant
agent-specific files. Use an existing conventions snapshot if its relevant claims
still hold. When available, `repo-conventions` can produce or refresh it; otherwise
collect the commands, invariants, extension points, and testing gotchas directly.

Inspect the subsystems the outcome touches. Delegate bounded, read-only research
when available and useful; use the host's tools and configured model preferences.
Collect paths, symbols, supporting line numbers, and a reuse inventory. Verify
consequential findings against the source, including delegated findings.

Separate **observed facts**, **assumptions**, and **planned artifacts**. Stamp recon
with HEAD and relevant working-tree changes. Line numbers locate evidence at that
snapshot; they are not permanent identities. Never invent a line anchor for an
artifact a later task will create.

Before prescribing a design, identify uncertainties that could invalidate it.
Resolve them with targeted inspection or a bounded experiment: question, method,
stopping condition, result, and consequence for the design. Keep experiment outputs
separate from production work. If uncertainty cannot be resolved now, schedule a
research task with explicit deliverables and a decision point before dependent
implementation tasks; do not invent a detailed downstream design.

For consequential decisions, compare plausible approaches against the constraints,
record why the selected one fits, and state what evidence would change it. Skip
ceremonial alternatives for routine choices.

## 3. Decompose and write

Create a dependency graph of coherent tasks, each with implementation and proof.
Prefer useful behavior through the real system over speculative foundation layers;
use a foundation task when an actual dependency requires it. Declare independence
only after checking shared files, contracts, generated outputs, and test resources.

For every task specify:
- **Fixed:** required behavior, invariants, and consequential architectural choices
  with rationale.
- **Flexible:** local implementation choices the implementer may make.
- **Escalate when:** evidence requires changing a fixed contract, dependency, scope,
  or verification claim. The orchestrator investigates first; only decisions outside
  existing user authorization require user input.

The planner settles consequential tradeoffs, not every helper name or file split.
Allow maintainable local choices within the stated boundaries. Record prerequisites
as artifact contracts with producing task IDs, not as facts already observed.

Build an **acceptance evidence map** from each material outcome to its proof and
owning task. Ask what could remain false while the proposed check passes. Combine
behavioral tests, structural inspection, benchmarks, and user evaluation when needed.
Automate durable regression checks where useful; do not manufacture a test for every
low-impact edit. Name a final integrated scenario and required final checks.

Use the template. Include exact verification commands, known baseline failures,
plan revision, recon snapshot, dependencies, and genuine human decision points.
An inspection-only check must say what to inspect and the pass criterion. A command
not yet exercised is marked unverified, not assumed working.

## 4. Review and deliver

Review the plan cold against the rubric: simulate plausible failures without relying
on the author's unstated intent. An independent critic is useful for consequential
or large plans when delegation is available; a local critic pass is sufficient for
small plans. Findings need a concrete failure scenario or violated requirement.
Fix blocking findings and recheck changed tasks and their dependents. Record remaining
uncertainty and nonblocking tradeoffs rather than chasing stylistic perfection.

Write `docs/prompts/<SERIES-NAME>.md`, matching existing repository naming. Report
the outcome, sequencing, decisions needing user judgment, and how to execute it.
Planning alone does not authorize implementation. If the user already authorized
planning and execution, continue to execution once the plan is ready unless a required
decision remains; do not insert an extra approval solely because this skill was used.
