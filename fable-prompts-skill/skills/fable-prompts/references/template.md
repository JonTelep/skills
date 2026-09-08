# Series and task template

Use stable `Prompt N` headings for compatibility with intelligent-loop and Forge.
Separate tasks with `---`; horizontal rules inside code examples are not task
boundaries. Omit optional fields that do not apply rather than filling them with
boilerplate. Every dispatched task must include its own relevant contracts and checks.

```markdown
# <SERIES-NAME> — <outcome>

Plan revision: <revision/date>
Recon snapshot: <HEAD; relevant uncommitted changes; conventions snapshot if used>

**Outcome:** <observable result and completion criteria>
**Scope and constraints:** <included work, exclusions, compatibility requirements>
**Assumptions:** <unresolved assumptions, validation owner, consequence if false>
**Design decisions:** <consequential alternatives, selection, rationale, change triggers>
**Investigation results:** <question, evidence, result; omit if unnecessary>
**Sequencing:** <task dependency graph; research decisions before dependent design>
**User decisions/checkpoints:** <only unresolved choices or authorized review gates>

## Acceptance evidence

| Claim | Evidence and pass criterion | Owning task |
| --- | --- | --- |
| <user-visible or structural requirement> | <test, measurement, inspection, evaluation> | <Prompt N or final integration> |

**Final integration:** <real end-to-end scenario and exact required commands>
**Baseline:** <commands actually run, results, existing failures, unavailable checks>
**Execution:** Dispatch one complete task plus relevant series constraints and prior
accepted contracts. Investigate discrepancies, record amendments, and refresh affected
tasks before continuing. An implementation request authorizes the local review/fix/
verification loop and task commits unless the user says otherwise; it does not imply
push, publication, or deployment. Honor existing user authorization and checkpoints.

---

## Prompt 1: <coherent outcome>

**Goal:** <behavior this task delivers>
**Depends on:** <task IDs, or none>
**Prerequisite contracts:** <required artifact, producer, semantics, how to confirm>
**Evidence:** <observed paths and symbols with snapshot line anchors; mark future
artifacts as planned, not observed>
**Expected edit areas:** <likely packages/files, including callers and generated output>
**Protected boundaries:** <what must not change>

**Fixed:** <required behavior, error semantics, significant design choices and rationale>
**Flexible:** <local choices delegated to the implementer>
**Escalate when:** <specific contract/scope/evidence changes requiring orchestration>

**Implementation guidance:**
- <ordered guidance, existing helpers or platform features to reuse>
- <relevant edge cases and compatibility requirements>
- <deliberate limitation, ceiling, and upgrade trigger if applicable>

**Testing and acceptance:** <claims, boundary cases, regression evidence; identify
what each check proves and any part requiring inspection or user evaluation>
**Invariants:** <properties that must hold throughout this change>
**Guardrails:**
- <exact required commands, working directory, setup, and pass criteria>
- <spec/codegen ritual if triggered, otherwise omit>
- <manual inspection procedure and pass criterion if needed>

**Report:** files changed, acceptance evidence, exact commands/results, deviations,
remaining uncertainty, and information the next task needs. Distinguish passed,
failed, and not exercised. Do not commit; the orchestrator reviews and commits.
```

## Example of matching proof to a claim

For a source adapter change, these are separate claims:

| Claim | Appropriate evidence |
| --- | --- |
| Equivalent input produces equivalent results | Compare real fixture-backed sources through the engine, including nulls and errors |
| A source can be added without editing the engine | Implement a test-only adapter through the public extension seam and inspect the diff/import boundary |
| Existing consumers remain compatible | Exercise existing callers and justify every changed golden or expected value |

Name the actual repo commands and inspected symbols in the completed plan. Do not
copy hypothetical symbols from an example as verified facts.
