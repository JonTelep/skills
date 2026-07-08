---
name: repo-conventions
description: Extract a repository's conventions into a single evidence-anchored facts document — build/test/verify commands, hard invariants, architectural boundaries, testing idioms and gotchas, existing seams. Use before writing implementation prompts, onboarding docs, or CLAUDE.md files, or whenever another skill needs ground truth about "how this repo works". Every fact must carry a file anchor.
---

# repo-conventions: Ground-Truth Extraction

Produce ONE document (`CONVENTIONS.md`, or the path the caller specifies) that states how this repository actually works — with a file anchor for every claim. This document is consumed by other agents who will NOT re-verify it, so a wrong fact here becomes a wrong decision downstream.

**The one rule that governs everything: no fact without evidence.** Every statement must cite `path/to/file:line` (or a command you actually ran and its output). If you believe something is true but cannot anchor it, either verify it now or leave it out. Never write from memory of "how Go projects usually work" — write from what you read.

## What to extract

Work through these six sections in order. For each, the extraction method is stated — follow it rather than free-form browsing.

### 1. Commands — how work is verified here

Read the `Makefile`, `package.json` scripts, CI workflows (`.github/workflows/`), and any `scripts/` directory. Record:

- The full-suite test command exactly as CI runs it (flags matter: `-race -count=1` is a different claim than `go test ./...`).
- Build, lint, format, audit, benchmark, fuzz, and soak/load targets — and which are NOT part of the default suite (build tags, separate make targets). Downstream prompt-writers need to know which guardrail commands exist to mandate.
- Any generate/sync rituals (code generation, spec syncing, schema regeneration) and what breaks silently when skipped.

### 2. Hard invariants — rules that must never be violated

Sources: `CLAUDE.md`, `CONTRIBUTING.md`, README, CI checks that enforce something, and load-bearing comments near public interfaces. Record each invariant with:

- The rule, stated as a testable sentence.
- Where it's enforced (a CI diff check? a test? only convention?).
- What violating it breaks.

Examples of the species: "the OpenAPI spec in `openapi/` is the source of truth; `internal/api/openapi.json` is an embedded copy synced via `make sync-openapi`", "the profiler is single-pass streaming and must never buffer the dataset", "optional API fields are pointers with omitempty".

### 3. Architectural boundaries — who may import whom

Map the dependency direction between the major packages/modules. Use real evidence: import statements, `go list -deps`, existing boundary tests. Record allowed and forbidden edges ("`datasets` may import `record`; `record` must never import `datasets`"). If the repo has a layering doc, verify it against reality and note discrepancies — the code wins.

### 4. Testing idioms and gotchas

- What a good test looks like here: table tests? golden files? fixtures directory? fuzz targets? Cite exemplary test files.
- Repo-specific traps that waste implementer time (e.g. "Go's csv.Reader skips blank lines — empty-value tests need multi-column CSVs"). Harvest these from CLAUDE.md, test comments, and oddly-shaped fixtures.
- How equivalence/no-regression is proven in this repo (byte-identical goldens? benchstat baselines?).

### 5. Existing seams and extension points

Interfaces, registries, plugin points, middleware chains — the places designed for extension. For each: name, location, one sentence on how you extend it, and one existing implementation to imitate. ("New view functions register via `RegisterView()` in `views.go`.")

### 6. Vocabulary

The repo's own names for things (job vs task, dataset vs source, transform vs rule) so downstream documents speak the local dialect instead of inventing synonyms.

## Method

1. Read the meta-files first: `CLAUDE.md`, README, `Makefile`, CI workflows. These are dense with declared conventions — but treat them as claims to verify, not facts.
2. Fan out over the code to verify and extend. For a large repo, spawn read-only subagents per subsystem, each returning anchored facts for the six sections. Merge, and discard any returned fact that lacks an anchor.
3. Where a declared convention contradicts the code, record BOTH with anchors and flag the discrepancy prominently — this is high-value output, not noise.
4. Write the document. Facts, not prose: short declarative sentences, each with its anchor. No hedging ("probably", "seems to") — verify or omit.

## Output shape

```markdown
# <repo> — Conventions (extracted <date>, HEAD <short-sha>)

## Commands
- Full suite: `go test ./... -race -count=1` (CI: .github/workflows/ci.yml:23)
...

## Hard invariants
- <rule>. Enforced by: <mechanism + anchor>. Violation breaks: <consequence>.
...

## Boundaries
## Testing idioms & gotchas
## Seams
## Vocabulary
## Discrepancies found
```

Stamp the git SHA at the top — the document is a snapshot, and consumers need to know when it has gone stale.
