# Review rubric — the adversarial critic pass

Stance: you are NOT checking whether the prompt is well-written. You are simulating its failure. For each prompt, ask: **how would a lazy, over-eager, or confused implementing agent fail this prompt while still claiming success?** Every gap you find is a place that will actually happen.

Read the prompt cold, the way the implementer will — without the author's context. If you needed the author's intent to understand an instruction, that instruction fails.

## Per-prompt checks

### A. Anchors and self-containment
- [ ] Every file path, function name, line range, and count in the prompt was verified against the codebase during recon. Spot-check the ones the Details lean on hardest.
- [ ] The prompt references **no other prompt by number** — only artifacts that exist in the codebase by the time it runs.
- [ ] Artifacts created by *earlier prompts in this series* are referenced with a tripwire framing (missing ⇒ "stop and report"), not assumed silently.
- [ ] Nothing referenced is created by a *later* prompt (sequencing bug — fatal).

### B. Decision completeness
- [ ] No design decision is delegated to the implementer. Hunt for "appropriately", "as needed", "consider", "either... or" without a decider — each is a fork the agent will take wrongly.
- [ ] Where a decision legitimately depends on what the code can express, a STEP 0 read-and-report exists WITH an author-chosen fallback scope — not "use your judgment".
- [ ] Error/edge semantics are stated where they'll be hit (null handling, failure policy, boundary values), not left to emerge.

### C. Blast radius and invariants
- [ ] Affected-packages list is exhaustive: trace the Details and confirm no edit implied by them touches an unlisted package.
- [ ] Invariants state the negative space: untouched packages, byte-identical outputs, preserved properties (streaming, bounded memory, API compatibility).
- [ ] Predictable scope-creep temptations are prohibited **by name**, with the deferred work's home identified.

### D. Verifiability — the anti-fake checks
- [ ] Every guardrail is a command with a pass/fail outcome, exact flags included. "Make sure it works" is not a guardrail.
- [ ] Perf claims require a baseline captured BEFORE edits ("no baseline, no perf claim").
- [ ] Anything that can be edited without being executed (containers, CI YAML, scripts) carries an "editing it does not count as done" clause, or an honest "state explicitly that this was not exercised" fallback when the environment may not allow execution.
- [ ] Repo rituals (spec sync, codegen) are restated in this prompt if this prompt can trigger them — the header doesn't count; fresh sessions read only their own section.
- [ ] The stop-and-report clause is present: codebase contradicts the prompt ⇒ report, don't improvise.

### E. Test honesty
- [ ] The Testing section states claims to prove, not activities. For each claim, ask: could a test pass without the claim being true? (Equivalence tests comparing a thing to itself; null tests that never construct a null.)
- [ ] A no-regression proof exists when existing behavior must survive (golden files, byte-identical comparisons on existing fixtures).
- [ ] "Existing tests pass with at most mechanical updates" is paired with "expectation changes are a red flag — justify each one" wherever fixtures could be quietly edited to make failures disappear.
- [ ] Repo testing gotchas that this prompt will hit are stated inline.

### F. Sizing
- [ ] One coherent architectural move plus its proof. If the prompt contains two independent moves, split it. If it's a trivial diff wrapped in ceremony, merge it into a neighbor.
- [ ] The context budget is plausible: an agent can hold the affected code, make the change, and write honest tests in one session. Cutover prompts that can't be split are flagged as human checkpoints instead.

## Series-level checks (once)

- [ ] The thesis is falsifiable and ONE prompt is assigned to write the test that enforces it permanently, named visibly.
- [ ] The sequencing line matches reality: walk each prompt's references and confirm the declared DAG admits no ordering that breaks an anchor.
- [ ] The scope guard exists and the deferred work is named with its future home.
- [ ] Human checkpoints sit on the largest-blast-radius prompts, with the mitigation stated (plan mode + review).
- [ ] How-to-use and review-loop boilerplate is present and consistent with the repo's actual commands.
- [ ] Vocabulary matches the repo's own (per the conventions doc) — no invented synonyms.

## Reporting

For each finding: prompt number, rubric item, the failure it enables (one sentence of the concrete bad outcome), and the fix. Fix all findings, then re-run the rubric on the changed prompts only. A prompt ships when a cold read produces zero findings.
