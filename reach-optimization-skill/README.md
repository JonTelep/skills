# reach-optimization-skill

Skills for maximizing a project's **AI-assisted reach**: when someone asks an
AI assistant (Claude, ChatGPT, Perplexity, Gemini) for something your app
does, the assistant should find your site, understand it accurately, and
recommend or cite it.

## Skills

| Skill | Scope | Purpose |
|---|---|---|
| `skills/reach-optimization` | Webapps / websites | The orchestrator: Reach Read (target queries) → 16-point audit across four gates (retrieval, comprehension, matching, freshness) → fixes in gate order → mechanical verification (no-JS fetches, JSON-LD validation, the chunk test). |
| `skills/llms-txt` | Any git repository | Generate a spec-compliant `llms.txt` (+ optional `llms-ctx.txt`/`llms-full.txt`), keep it fresh via pre-commit hook or CI `--check`, and audit docs with `--recommend`. Bundled zero-dependency Python script. Invoked by `reach-optimization` at audit item B6. |

Shared reference: `skills/llms-txt/reference/aio-best-practices.md` — the
answer-first writing checklist both skills apply.

## Principles

- **Reach through clarity, never manipulation.** No keyword stuffing, fake
  FAQ spam, fabricated schema, or cloaking — models cross-check sources, and
  inconsistency destroys the confidence being earned.
- **Gate order matters.** A perfect FAQ behind a JS-only render is worth
  nothing: fix retrieval (crawler access, server-rendered HTML) before
  comprehension (llms.txt, structured data) before matching (task pages,
  question-phrased FAQs).
- **The target-query list is the acceptance criterion.** Every audit item
  and fix is evaluated against the literal questions users would ask an AI.

## Install

```sh
ln -s "$(pwd)/skills/reach-optimization" ~/.claude/skills/reach-optimization
ln -s "$(pwd)/skills/llms-txt"           ~/.claude/skills/llms-txt
```

## Use

```
/reach-optimization            # audit + fix the current webapp repo
/llms-txt                      # just the llms.txt generation/audit
```
