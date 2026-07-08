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

`skills/fable-prompts/references/` holds the deep knowledge, kept out of the entrypoint so it stays lean:

- `principles.md` — the design rules, each stated with the implementer failure mode it compensates for, plus good/bad contrasting examples.
- `template.md` — series-header and per-prompt anatomy, with an annotated real example.
- `review-rubric.md` — the adversarial checklist (anchor verification, decision completeness, blast radius, unfakeable guardrails, test honesty, sizing).

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
