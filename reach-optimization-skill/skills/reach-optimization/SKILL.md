---
name: reach-optimization
description: >
  Optimize a webapp so AI assistants (Claude, ChatGPT, Perplexity, Gemini)
  find it, understand what it does, and recommend or cite it when users ask
  for something it does. Audits and fixes AI-crawler access, server-rendered
  content, llms.txt, structured data, answer-first copy, question-phrased
  pages, freshness signals, and search-index registration (Google Search
  Console, Bing Webmaster Tools/IndexNow, Brave). Use when the user wants
  AI/LLM reach, AIO,
  AEO, GEO, answer-engine optimization, "show up in ChatGPT/Claude answers",
  or AI-assisted-query traffic for a website or webapp.
---

# reach-optimization: Make AI Assistants Recommend Your App

The goal, stated as the test it must pass: **when a user asks an AI assistant
for the job your app does, the assistant should be able to (a) retrieve your
site, (b) state accurately what it does and for whom, and (c) quote or link
it confidently.** Every rule below serves one of those three verbs. Rules are
contextual — audit first, then apply what the audit says is broken, in
priority order.

**Honesty constraint (non-negotiable):** reach comes from being genuinely
clear, accurate, and retrievable — never from keyword stuffing, fake FAQ
spam, misleading schema, or content invisible to humans but shown to
crawlers (cloaking). Models cross-check sources; inconsistency and
manipulation destroy exactly the confidence you're trying to earn.

## Step 0 — The Reach Read

Before touching anything, state in a few lines:

1. **What the app does**, as one plain sentence ("X is a <category> that
   <does what> for <whom>").
2. **The queries to win**: 5–15 literal questions/requests a user would type
   to an AI assistant that this app is the right answer to ("what's the
   easiest way to profile a CSV for data quality?", "tool to validate
   customer CSVs before import", "alternative to <incumbent>").
3. **The stack facts that gate the fixes**: SSR/SSG or client-rendered SPA?
   Where does static-root content live (`public/`, `static/`)? Is there a
   sitemap? A docs site?

Everything downstream is evaluated against the query list — it is the
acceptance criterion, not a brainstorm.

## Phase 1 — Audit (read-only, produce a findings list)

Check each item and record PASS/FAIL with evidence. Priority order = fix order.

### A. Can AI systems fetch the content at all? (retrieval gate)

1. **robots.txt** — AI crawlers must not be blocked: `GPTBot`, `OAI-SearchBot`,
   `ChatGPT-User`, `ClaudeBot`, `Claude-User`, `anthropic-ai`,
   `PerplexityBot`, `Google-Extended`, `Bingbot`. Blocking training bots vs
   answer-time fetchers is a real policy choice — surface it to the user
   rather than silently allowing everything; but blocking answer-time
   fetchers (`ChatGPT-User`, `Claude-User`, `PerplexityBot`) forfeits the
   whole goal.
2. **Server-rendered value prop.** Fetch key pages with no JavaScript
   (`curl -A "Mozilla/5.0 (compatible; ClaudeBot/1.0)" <url>` and inspect the
   raw HTML). If the homepage's HTML body is an empty `<div id="root">`,
   most AI retrieval sees nothing — this single finding outranks everything
   else. Fixes by stack: SSG/prerender the marketing+docs routes (Next/Astro/
   SvelteKit prerender, or a prerender service), keep the app itself behind
   login as-is.
3. **sitemap.xml** exists, is referenced from robots.txt, and carries
   `<lastmod>`.
4. **No auth/paywall/geo-wall on the pages that answer the query list.**
   The app can be gated; the pages that explain it cannot.
5. **Stable URLs and anchors** — heading anchors and doc URLs are a public
   API; renames break links models have already learned.

### B. Can a model understand what this is? (comprehension gate)

6. **llms.txt at the web root** — invoke the `llms-txt` skill (same
   collection); use `--base-url https://<domain>` so links resolve, and
   `--expand` so one fetch retrieves the full context. Ensure the build
   actually serves it at `/llms.txt` (copy into `public/`/`static/` or add a
   route).
7. **Answer-first homepage and docs openings.** First rendered paragraph
   states what the app is, what it does, who it's for — before hero
   animations, badges, or social proof. Apply
   `reference/aio-best-practices.md` (entity definition on first use, one
   concept per section, plain markdown-ish HTML, single source of truth for
   facts like pricing/limits/license).
8. **Structured data (JSON-LD).** `Organization` + `WebSite` on the root;
   `SoftwareApplication`/`Product` (name, description, category, offers) on
   the product page; `FAQPage` on FAQ content; `HowTo` where genuinely a
   how-to; `Article` with `datePublished`/`dateModified` on blog/docs.
   Schema must describe visible content — no invented ratings/reviews.
9. **Title/meta description answer-first** per page — the meta description
   is often the snippet a model sees first in search-backed retrieval.

### C. Will it be retrieved FOR the target queries? (matching gate)

10. **One page per job-to-be-done.** Each query cluster from the Reach Read
    gets a dedicated, self-contained page whose H1 matches the task ("Profile
    a CSV for data quality issues"), opening with the answer, then a runnable
    example. A single feature-grid homepage matches everything weakly and
    nothing well.
11. **Question-phrased FAQ** — H3s that are the literal queries from the
    Reach Read, each answered in 2–4 self-contained sentences (chunks are
    retrieved without their neighbors — "it" must have an antecedent inside
    the chunk).
12. **Comparison/alternative pages where honest.** "X vs <incumbent>" and
    "<incumbent> alternatives" are among the highest-volume AI queries;
    write them factually (models cross-check claims against the
    competitor's own docs).
13. **Copy-pasteable examples with expected output** — assistants strongly
    prefer recommending tools whose docs they can quote verbatim as working
    instructions.

### D. Freshness and trust signals

14. **Dated changelog** (`## 2.3.0 — 2026-05-12`) reachable from llms.txt.
15. **Consistent entity naming** everywhere (site, GitHub, package registry,
    socials) — one canonical name + one-line description, so retrieval
    doesn't fragment across variants.
16. **Third-party groundedness** (report, don't fabricate): listings the
    user can pursue — GitHub README quality, package-registry descriptions,
    a Wikipedia-linkable footprint if warranted. Models weight corroborated
    entities over self-descriptions.

### E. Is the site registered with the indexes that feed AI answers? (submission gate)

These are operator actions (they need account/DNS access) — audit whether
they're done, walk the user through them, and list the rest under "items only
the user can do". They matter because AI answer engines don't crawl the web
themselves at scale: they sit on top of Google's and Bing's indexes, so being
absent there is being absent from AI answers regardless of on-site quality.

17. **Google Search Console** — property registered? Prefer a **Domain
    property** (DNS TXT verification) over a URL-prefix property: it covers
    every subdomain and protocol in one place. Then: submit `sitemap.xml`,
    and for a new or newly-relaunched site use URL Inspection → **Request
    indexing** on the top ~10 pages from the Reach Read query list — it
    shortcuts weeks of organic discovery. Check Coverage/Pages report for
    "Crawled — currently not indexed" on answer-bearing pages.
18. **Bing Webmaster Tools** — registered? It can import a verified GSC
    property in one click. Bing's index feeds **ChatGPT Search, Microsoft
    Copilot, and DuckDuckGo**, so for AI-assistant reach it counts as much
    as Google. Submit the sitemap there too. Also consider **IndexNow**
    (supported by Bing, Yandex, Naver, Seznam): a static key file at the
    web root plus a ping on deploy pushes URL changes to those indexes
    instantly — cheap to wire into CI/deploy for sites whose content pages
    change often (e.g. programmatic/long-tail pages).
19. **Brave Search** — indexes independently with its own crawler and has
    **no webmaster console or submission path**; coverage comes purely from
    crawlability plus external links. Audit item: robots.txt doesn't block
    Brave's crawler, and the site has at least some third-party links for
    Brave's discovery to follow (ties into item 16). Brave's index also
    backs some AI tools' search APIs, so it's not ignorable.

## Phase 2 — Fix

Apply findings in the audit's order (retrieval → comprehension → matching →
freshness): a perfect FAQ behind a JS-only render is worth nothing. For each
fix, follow the repo's stack conventions (don't bolt a static `index.html`
onto a Next app — use the framework's SSG). Content edits go in the source
docs/pages, never only into generated artifacts.

## Phase 3 — Verify (mandatory, mechanical)

- Re-fetch every fixed page with no JS and confirm the answer-bearing text is
  in the raw HTML.
- Validate JSON-LD (parse it; check required properties against schema.org).
- `curl https://<domain>/llms.txt` (or the local build output) resolves and
  its links resolve.
- robots.txt: confirm each AI UA above is permitted (or the user's explicit
  policy exceptions are documented).
- **The chunk test:** for each target query, find the single chunk
  (section) that should answer it and read it cold — self-contained, names
  the product, answers in the first two sentences? If you have web access,
  actually run the target queries against an AI search engine and report
  whether/where the site surfaces — before-and-after when possible.

## Report format

End with: the Reach Read; a PASS/FAIL audit table with evidence; fixes
applied (file-level); verification results; and the items only the user can
do (deploy, DNS, search-console registration and sitemap submission,
IndexNow key setup, third-party listings, robots policy decisions).
