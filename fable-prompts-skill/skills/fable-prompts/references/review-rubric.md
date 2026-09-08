# Plan review rubric

Read each task without the author's unstated context. Simulate a plausible incorrect
implementation and ask whether the instructions and evidence would detect it.

## Outcome and evidence
- Each material user requirement appears in the acceptance evidence map.
- Every check proves the associated claim: what could still be false if it passes?
- Behavioral equivalence is not substituted for structural extensibility, static
  inspection for runtime success, or a build for user acceptance.
- Relevant baselines, regression evidence, and unavailable checks are explicit.
- Final integration exercises the complete outcome, not just isolated task checks.

## Grounding and uncertainty
- Observed references were inspected at the recorded snapshot; consequential anchors
  are spot-checked against source. Paths and symbols permit navigation after line drift.
- Assumptions are labeled and assigned validation. Planned artifacts identify their
  producers and contracts without fabricated line anchors.
- Consequential uncertainty was investigated or assigned a bounded research task
  before dependent design. Experiments have stopping conditions and recorded results.
- Significant design decisions have rationale; alternatives are compared where useful.

## Delegation and dependencies
- Fixed requirements, flexible choices, and escalation conditions are distinguishable.
- The task includes its prerequisite contracts and relevant series constraints; it
  does not require another agent's conversation or an unseen prior prompt.
- Dependency order matches artifact production. Parallel tasks do not silently share
  edits, changing contracts, generated files, or exclusive test resources.
- Task scope fits a coherent implementation and review; trivial work is not padded
  into a series. User checkpoints reflect actual decisions and existing authorization.

## Scope and simplicity
- Expected edits cover callers, tests, and generated outputs; protected boundaries
  are explicit without freezing every unlisted file.
- Reuse candidates were checked for suitability, not selected by name alone.
- Dependencies and abstractions have concrete benefits. Findings identify unnecessary
  concepts, coupling, duplication, or maintenance cost rather than merely more lines.
- Validation, data-loss handling, security, accessibility, and required performance
  survive simplification. Real deferred limitations have ceilings and upgrade triggers.

## Recovery and completion
- Discrepancies go through investigation and classification before blocking the user.
- Plan amendments preserve agreed outcomes and constraints and refresh dependents.
- Exact checks and pass criteria are supplied; unverified commands are labeled.
- Changed expectations require explanation; failures cannot be waived as unrelated
  without evidence. Completion cannot silently omit a required gate.
- Instructions use host capabilities rather than unavailable tool/model names.

## Finding format and stopping rule

Record task ID, severity (blocking/nonblocking), violated requirement or concrete
failure scenario, evidence, and proposed correction. Preferences are nonblocking.
Fix blocking findings, then review changed tasks and affected dependents. Deliver
with remaining uncertainty and accepted tradeoffs visible; do not require an endless
zero-preference-findings loop.
