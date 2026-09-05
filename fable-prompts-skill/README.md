# fable-prompts-skill

Skills for turning a general improvement goal into a **FABLE-PROMPTS-style series**: self-contained, evidence-anchored implementation prompts designed to be handed one at a time to an unsupervised implementing agent (e.g. Sonnet), with each result reviewed before the next prompt runs.

The format originated in the `easy-data-quality` repo's `docs/prompts/FABLE-PROMPTS*.md` series. Its core idea: the prompt author (a strong model, with full codebase context) makes every architectural decision and encodes distrust of the implementer — tripwires for broken prerequisites, named scope-creep prohibitions, mechanical unfakeable guardrails, and tests that prove claims rather than exercise code.

## Skills

| Skill | Purpose |
|---|---|
| `skills/repo-conventions` | Extract a repo's ground truth (commands, invariants, boundaries, testing gotchas, seams, vocabulary) into one evidence-anchored facts document. Standalone — also useful for onboarding docs and CLAUDE.md authoring. |
| `skills/fable-prompts` | The author: Sharpen (goal → falsifiable thesis + scope guard) → Recon (invokes `repo-conventions`, fans out anchor-gathering subagents) → Decompose & Write (session DAG, prompts rendered against the template) → Adversarial Review (critic pass per prompt against the rubric). |
| `skills/intelligent-loop` | The executor: takes a prompt-series file and runs the dispatch/review loop — each prompt implemented by a fresh cheaper-tier subagent, the orchestrator reviews the diff, independently re-runs guardrails, loops fixes back to the same agent, and commits one reviewed commit per prompt. |

Together they close the loop: `repo-conventions` grounds it, `fable-prompts` writes the plan (with a human checkpoint), `intelligent-loop` executes it.

## Simplicity: the ponytail rule

Both skills carry the philosophy of [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) — *he says nothing, he writes one line, it works.* Before any code, stop at the first rung that holds:

```
1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it, don't rewrite
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum that works
```

Lazy, not negligent: validation at trust boundaries, data-loss handling, security, accessibility, and anything the prompt explicitly requires are never on the chopping block.

The ruleset is vendored once, in `skills/fable-prompts/references/ponytail.md` (MIT, attribution inside), and used at every stage: `fable-prompts` climbs the ladder while making each design decision and forbids the predictable over-build by name; its review rubric has a ponytail pass; `intelligent-loop` pastes the compact block into every implementer dispatch, runs the `delete`/`stdlib`/`native`/`yagni`/`shrink` review on every diff before commit, and harvests the `ponytail:` debt ledger at the end.

`skills/fable-prompts/references/` holds the deep knowledge, kept out of the entrypoint so it stays lean:

- `principles.md` — the design rules, each stated with the implementer failure mode it compensates for, plus good/bad contrasting examples.
- `template.md` — series-header and per-prompt anatomy, with an annotated real example.
- `review-rubric.md` — the adversarial checklist (anchor verification, decision completeness, blast radius, unfakeable guardrails, test honesty, sizing, over-engineering).
- `ponytail.md` — the simplicity ruleset: the ladder, the not-lazy list, the review tags, the `ponytail:` marker convention, and the compact block that `intelligent-loop` pastes into implementer prompts.

## Install

Symlink the skill directories into your Claude Code skills path:

```sh
ln -s "$(pwd)/skills/repo-conventions" ~/.claude/skills/repo-conventions
ln -s "$(pwd)/skills/fable-prompts"    ~/.claude/skills/fable-prompts
ln -s "$(pwd)/skills/intelligent-loop" ~/.claude/skills/intelligent-loop
```

(Or per-project under `<repo>/.claude/skills/`.)

## Use

```
/fable-prompts Phase 3: new sources — S3/Parquet, Excel, deeper Postgres
```

The skill will sharpen the goal (asking at most one clarifying question if genuinely ambiguous), run recon, and write `docs/prompts/<SERIES-NAME>.md` in the target repo, following the repo's existing series naming.
