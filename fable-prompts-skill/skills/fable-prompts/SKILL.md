---
name: fable-prompts
description: Turn a general improvement goal for a codebase into a FABLE-PROMPTS-style series — self-contained, evidence-anchored implementation prompts designed to be handed one at a time to an unsupervised implementing agent, with each result reviewed before the next runs. Use when the user has a direction ("typed records", "harden the API", "add observability") and wants it decomposed into sequenced, guardrailed prompt sessions. Produces a docs/prompts/<NAME>.md file.
---

# fable-prompts: Prompt-Series Author

You are writing a document whose reader is an **unsupervised implementing agent in a fresh session** — no memory of this conversation, no access to your reasoning, and every incentive to improvise around gaps. The entire format exists to compensate for that reader's failure modes: improvising when a reference doesn't resolve, creeping scope, claiming success without verification, and writing tests that don't exercise the claim.

Read `references/principles.md` before writing anything. Render prompts against `references/template.md`. Review with `references/review-rubric.md`. Do not write prompts from this file alone — the taste is in the references.

## The pipeline

Four phases, strictly in order. Do not start writing prompts until Recon is complete.

### Phase 1 — Sharpen

Turn the user's goal into:

1. **A thesis: one falsifiable outcome sentence.** Not an aspiration ("make sources pluggable") but a test ("adding a new source must touch zero code in `internal/engine`, `internal/profile`, or `internal/functions` — enforced by a cross-source equivalence test that stays green forever"). If you cannot state the goal as something mechanically checkable, the series is not ready — sharpen further.
2. **A scope guard: what this series deliberately does NOT do**, stated up front ("no new sources in this phase; Parquet/S3 are Phase 3"). Unsupervised agents expand into any silence; the scope guard fills it.

If the goal is genuinely ambiguous, ask **one** clarifying question — never a multi-question dump. If you can confidently infer, declare your reading and proceed.

### Phase 2 — Recon

**Hard rule: no anchor may appear in a prompt that was not verified in this phase.** A `file.go:197` you didn't read is a trap you set for the implementer.

1. If no fresh conventions document exists for the repo, run the `repo-conventions` skill first. Its output supplies the guardrail commands, invariants, boundaries, and gotchas that every prompt must restate.
2. Identify the subsystems the thesis touches. Fan out read-only subagents (Explore-type) over each, tasked with returning **anchored facts**: exact file:line locations of the code each prompt will modify, the names and signatures of existing helpers, counts of things that must be migrated ("39 existing transforms in defaults.go"), and existing tests that lock current behavior.
3. Build a facts sheet. Discard any fact without an anchor. Where the goal assumes something the code contradicts, resolve it now — recon is where you find out the helper you planned to extend doesn't exist.

### Phase 3 — Decompose & Write

**Decompose** the thesis into a DAG of sessions:

- Each node is sized for one fresh context window of implementation work: one coherent architectural move, its tests, and its verification. Too big → the agent runs out of quality before it runs out of task. Too small → the overhead of session setup dominates.
- Order by dependency, and state the DAG explicitly in the header ("1→2→3 strictly; 5 and 6 are independent; 4 any time after 3").
- Mark **human checkpoints** on the nodes with the largest blast radius ("run Prompt 3 in plan mode and review the plan before letting it code").
- Design the **flagship test**: the one test that mechanically enforces the thesis, assigned to a specific prompt, named visibly, and documented as permanent ("Phase 3 sources must be added to it").

**Write** each prompt against `references/template.md`, using only recon facts. The author makes the architectural decisions — struct vs interface, naming, error semantics, what's deferred — and the prompt records them. Never delegate a design decision to the implementer; that is where unsupervised sessions go sideways.

**Write the series header**: title with phase context, the thesis paragraph, the scope guard, how-to-use instructions (paste one section per fresh session; prompts assume prior ones landed; a missing referenced artifact means a prerequisite didn't land — stop and report), the sequencing DAG, human checkpoints, and the review loop (after each prompt lands, review the diff for correctness, test honesty, and scope creep; loop fixes back to the same agent until acceptance criteria pass).

### Phase 4 — Adversarial Review

For each prompt, run a critic pass against `references/review-rubric.md` — as a subagent per prompt when the series is large, so each critic reads one prompt cold, the way the implementer will. The critic's stance is hostile: *how would a lazy, over-eager, or confused agent fail this prompt while claiming success?*

Fix every finding and re-check the fixed prompt. Do not ship a prompt with an unresolved rubric failure. This phase is the one that separates "a decent task list" from prompts that survive contact with an unsupervised implementer — do not skip or soften it.

## Output

Write the series to `docs/prompts/<SERIES-NAME>.md` in the target repo (match the repo's existing naming if a series already exists there — e.g. `FABLE-PROMPTS-5.md` follows `FABLE-PROMPTS-4.md`). Report to the user: the thesis, the DAG with checkpoint flags, and any rubric findings you fixed.
