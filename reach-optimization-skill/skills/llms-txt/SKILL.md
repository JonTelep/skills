---
name: llms-txt
description: >
  Generate or update an llms.txt file (per the https://llmstxt.org/ spec) for
  the current Git repository, plus optional llms-ctx.txt / llms-full.txt
  context files, a git pre-commit hook to keep them fresh, and an AIO/AEO
  audit of the repo's docs. Use when the user asks to create or update
  llms.txt, optimize a repo for AI search / answer engines (AIO, AEO, GEO),
  improve LLM discoverability or citability, or audit docs for AI retrieval.
---

# llms-txt — AI-discoverability generator for any repository

This skill makes a repository easy for LLMs (Claude, GPT, Perplexity, etc.)
to ingest, summarize, recommend, and cite accurately. It does this by
generating a spec-compliant `llms.txt` index, optional expanded context
files, and an actionable audit of the repo's documentation structure.

## What the bundled script does

`scripts/generate_llms_txt.py` (Python 3.9+, zero dependencies):

1. **Detects project identity** — name and description from `package.json`,
   `pyproject.toml`, `Cargo.toml`, `composer.json`, `go.mod`, falling back to
   the README's H1 and first paragraph, then the directory name.
2. **Discovers high-value docs** — README, `docs/`, `examples/`,
   CONTRIBUTING, CHANGELOG, LICENSE, `.github/` docs — and buckets them into
   spec sections: `Documentation`, `Examples`, `Development`, `Optional`.
3. **Writes a description for every link** by extracting each file's first
   prose paragraph (badges, frontmatter, and code fences are skipped).
4. **Renders a spec-compliant `llms.txt`**: `# Name`, `> summary`
   blockquote, a short entity-grounding prose line (language, license,
   hosting URL), then H2 sections of `- [Title](url): description` bullets.
5. **Optionally expands** into `llms-ctx.txt` (linked docs inlined, minus the
   `Optional` section) and `llms-full.txt` (everything inlined), mirroring
   the official `llms_txt2ctx` output shape.
6. **Stays fresh** via a managed git pre-commit hook or a CI `--check` mode.

## How to run it

Always run from (or point `--root` at) the repository root:

```bash
# Preview without writing anything
python3 scripts/generate_llms_txt.py --root /path/to/repo --dry-run

# Generate llms.txt
python3 scripts/generate_llms_txt.py --root /path/to/repo

# Generate llms.txt + llms-ctx.txt + llms-full.txt
python3 scripts/generate_llms_txt.py --root /path/to/repo --expand

# Overwrite a hand-written llms.txt (the tool refuses by default)
python3 scripts/generate_llms_txt.py --root /path/to/repo --force

# Audit the repo's AI-discoverability and print fixes (writes nothing)
python3 scripts/generate_llms_txt.py --root /path/to/repo --recommend

# Keep llms.txt updated automatically on every commit that touches docs
python3 scripts/generate_llms_txt.py --root /path/to/repo --install-hook

# CI guard: exit 2 if llms.txt has drifted from the docs
python3 scripts/generate_llms_txt.py --root /path/to/repo --check
```

| Flag | Effect |
|---|---|
| `--dry-run` | Print generated llms.txt to stdout; write nothing |
| `--force` | Overwrite an existing llms.txt lacking the generated-by marker |
| `--expand` | Also write `llms-ctx.txt` and `llms-full.txt` |
| `--check` | Exit 2 if llms.txt is missing/stale (CI/pre-push use) |
| `--recommend` | Print an AIO/AEO audit with concrete fixes |
| `--install-hook` | Install/refresh a managed pre-commit hook block |
| `--base-url URL` | Prefix links with an absolute URL (use the site or raw-GitHub URL when the file will be served at `https://domain/llms.txt`) |
| `--max-links N` | Cap links per section (default 20; drops are logged, never silent) |

## Workflow for Claude when this skill is invoked

1. Run `--dry-run` first and show the user the proposed llms.txt.
2. If an `llms.txt` already exists without the generator marker, **ask before
   using `--force`** — it may be hand-curated.
3. After generating, run `--recommend` and relay the FIX items to the user.
4. If the generated descriptions are weak (empty or truncated awkwardly),
   improve them by hand-editing the source docs' first paragraphs — not the
   llms.txt — then regenerate. The source docs are the canonical content.
5. If the repo is published as a website, suggest `--base-url` so links
   resolve when `llms.txt` is served from the site root, and suggest
   `--expand` so answer engines can fetch one self-contained context file.
6. Offer `--install-hook` (local automation) or `--check` in CI (team-safe).

## AIO guidance for future docs

See `reference/aio-best-practices.md` for the full checklist this skill's
`--recommend` audit is based on: answer-first writing, question-phrased FAQ
headings, entity definitions on first use, one-concept-per-section
structure, and single-source-of-truth facts.

## FAQ

### Does the generated llms.txt follow the official spec?

Yes. It produces the exact structure defined at https://llmstxt.org/: a
required H1, an optional blockquote summary, optional prose, H2 link-list
sections, and an `Optional` section whose contents may be skipped when a
consumer needs a shorter context.

### Will it clobber a hand-written llms.txt?

No. Generated files carry an HTML-comment marker; if the marker is absent
the tool refuses to overwrite unless you pass `--force`.

### Where should llms.txt live in production?

At the web root of the project's domain (`https://example.com/llms.txt`),
alongside `robots.txt`. In a bare repo, the repo root is the convention.
