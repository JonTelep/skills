# Planning principles

## Outcomes and evidence

State the behavior that matters to the user before prescribing code. Every material
claim needs evidence capable of disproving it. A passing test establishes only what
it exercises; passing all task checks does not automatically establish the series goal.

For example, cross-source equivalence shows that tested sources behave alike. It does
not establish that adding a source requires zero engine edits. That second claim needs
an extension exercise or structural check as well. Record both in the acceptance map.
Use a benchmark baseline for performance claims and a real runtime check for runtime
claims. Report unavailable checks explicitly. User evaluation is appropriate for
subjective outcomes; do not disguise it as an automated guarantee.

## Facts, assumptions, and future contracts

Observed references carry a path, symbol, and supporting location at the recon
snapshot. Counts and signatures must have been inspected. Assumptions carry a
validation method. Future artifacts carry a producing task and expected contract,
never fabricated source anchors. Dependency IDs are useful metadata; every dispatched
task must also contain the prerequisite contracts it needs to understand its work.

Recheck relevant snapshot facts before implementation. A stale line number is a
navigation problem; an absent contract is a dependency problem. Neither justifies
silently recreating the planned helper. Investigate before deciding how to recover.

## Resolve consequential uncertainty early

Use the smallest investigation that can distinguish the plausible designs. Give an
experiment a question and stop condition. Document its result and whether the design
changed. Do not let an exploratory prototype become an unreviewed implementation.
If a question remains open, make investigation a task and defer detailed dependent
specifications until its result is known.

## Decision authority

Fixed decisions cover public behavior, compatibility, data semantics, and significant
architectural boundaries. Include rationale and evidence so implementers can recognize
when assumptions fail. Flexible decisions cover local code organization, helper names,
and equivalent algorithms within required complexity and correctness bounds.

Implementers report proposed changes to fixed decisions with evidence. Orchestrators
may amend the plan within the user's agreed outcome, constraints, and authorization;
user input is needed for unresolved consequential choices outside those bounds.
Record amendments and refresh affected future tasks before dispatch. User instructions
and applicable repository instructions take precedence over this planning format.

## Scope without brittle file freezes

List expected edit areas and explicit protected boundaries. Required caller updates,
tests, and generated files should be anticipated. Unexpected local edits can be
justified within the contract; crossing a protected boundary needs review first.
Name predictable scope expansion when it matters. Do not prohibit all unlisted files
or treat every new abstraction as a defect regardless of its purpose.

## Simplicity and maintenance

Use `ponytail.md`: need, reuse, standard library, platform, installed dependency, then
the minimum maintainable implementation. Evaluate concepts, coupling, duplication,
and operational burden rather than line count. A shorter diff can preserve the wrong
abstraction or hide a root cause. Preserve correctness, accessibility, security, and
required performance. Record real deferred limitations with a ceiling and upgrade
trigger, not markers for ordinary design choices.

## Verification proportional to the claim

Each task states claims to prove, boundary cases, and relevant regression evidence.
For a bug fix, demonstrate that the regression check detects the old behavior when
practical. Inspect changed expectations and fixtures; do not weaken them merely to
obtain a passing run. Use targeted checks during fixes, required task gates before
acceptance, and integrated checks at dependency joins and completion. Full-suite runs
per task are appropriate when repository rules or impact require them, not universal.

Capture relevant baseline failures before editing. Distinguish existing failures,
regressions, and unavailable environments. A baseline failure is not an automatic
waiver of a required acceptance gate. Do not claim performance improvements without
a comparable baseline or runtime success from static inspection alone.

## Task size, review, and voice

One task is a coherent outcome and its proof. Split when uncertainty, dependencies,
or review scope become too large; merge trivial tasks that only add setup overhead.
Specify a dependency graph, then verify that it matches the artifact contracts.

Review for plausible incorrect outcomes, missing dependencies, and unnecessary
complexity. Blocking findings name a requirement or material risk; preferences are
nonblocking. Recheck amended tasks and affected dependents, not the whole series by
ritual. Write direct, concrete instructions with rationale where it changes decisions.
Avoid personality labels, threats, and claims that a test is unfakeable.
