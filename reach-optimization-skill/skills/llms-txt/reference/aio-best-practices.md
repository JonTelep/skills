# AIO / AEO best practices for repository documentation

> How to structure READMEs and docs so LLMs and answer engines (Claude, GPT,
> Perplexity, Gemini) retrieve, recommend, and cite your project accurately.

## Why structure matters

Answer engines don't read your repo the way humans do. They chunk documents,
embed the chunks, retrieve the few that match a user's question, and quote
or paraphrase them. A doc wins when each chunk is **self-contained,
answer-first, and unambiguous about what entity it describes**.

## The checklist

### 1. Answer-first openings

The first paragraph of every doc — especially the README — should state
what the thing is, what it does, and who it's for, in plain language,
before any badges, logos, or tables of contents.

Bad: a logo, six badges, a ToC, then "Motivation".
Good: `Foo is a zero-dependency Python CLI that converts X to Y in one
command. It's built for data engineers who need Z.`

### 2. Define entities on first use

Models must disambiguate your project from similarly named ones. On first
mention in any doc, attach a defining clause: "Portmap (this repo's
container-port visualizer), not the SunRPC portmapper." Repeat the project
name in section openings rather than using "it" — chunks get retrieved
without their neighbors.

### 3. Question-phrased FAQ headings

Add an `## FAQ` whose H3 headings are literal questions users would type:
`### How do I install Foo without root?` Answer engines match query strings
against headings; a question-phrased heading plus a 2–4 sentence answer is
the single highest-yield AEO pattern.

### 4. One concept per H2 section

Retrieval chunking roughly follows heading boundaries. A section that mixes
installation, configuration, and troubleshooting produces chunks that match
everything weakly and nothing well. Split them.

### 5. Copy-pasteable, complete examples

Code blocks should run as-is (include imports, show expected output).
Models strongly prefer recommending tools whose docs contain runnable
snippets, because they can pass them through to users verbatim.

### 6. Single source of truth for facts

Version requirements, license, supported platforms: state them once
(README or a dedicated doc) and link elsewhere. Contradictory copies cause
models to hedge or miscite.

### 7. Plain markdown over HTML

Markdown survives text-extraction pipelines cleanly; nested HTML, `<details>`
collapsibles, and image-only content often get stripped or mangled. Keep
tables small (wide tables linearize badly).

### 8. Maintain llms.txt and serve it from the web root

`/llms.txt` is the model-facing sitemap: a curated, prioritized index with
one-line descriptions. `llms-full.txt` lets a single fetch ingest the whole
doc set. Regenerate them whenever docs change (use the pre-commit hook or
CI `--check`).

### 9. Stable headings and anchors

Renamed headings break the deep links other sites and models have learned.
Treat heading text like a public API.

### 10. Dates and versions in changelog entries

`## 2.3.0 — 2026-05-12` style entries let models reason about recency and
avoid recommending deprecated APIs.
