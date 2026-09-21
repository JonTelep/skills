---
name: launch-checklist
description: >
  Audit the current website/webapp repo against a 37-point pre-launch
  checklist. Site polish (1-20): privacy policy, terms, secrets, HTTPS, cookie
  consent, meta titles/descriptions, social preview image, favicon,
  sitemap/robots.txt, image alt text, image compression, page speed, color
  contrast, mobile responsiveness, custom 404, broken links, form validation,
  spam protection, analytics, single clear CTA. App security (21-37):
  authentication, server-side permission checks, frontend-supplied user IDs,
  user data isolation, admin routes, database lockdown,
  Firebase/Supabase/storage rules, debug mode, error detail, server-side input validation,
  content sanitization, file uploads, SQL/NoSQL injection, login/signup rate
  limits, secrets in git history, security headers and CORS, and an
  untrusted-user test. Works out which items apply to this stack and collapses
  the rest to N/A. Reports PASS/FAIL/N-A with evidence, then fixes what the
  user approves. Use when the user asks "is this site/app ready to
  launch/release/ship", wants a launch checklist, pre-release audit, security
  check before launch, or go-live check of a website.
---

# launch-checklist: Is This Site Ready to Ship?

Thirty-seven things that separate a finished website from a deployed one:
twenty of site polish (1-20), seventeen of app security (21-37).
**Audit first (read-only), report, then fix only what the user approves.**
If invoked with `fix` as the argument, fix every FAIL that needs no user
decision and list the rest.

## Step 0 — Stack read

Before checking anything, establish in a few lines:

- **Framework and rendering**: Next/Astro/SvelteKit/Vite SPA/plain HTML/…
  This decides *where* each item lives (`app/layout.tsx` metadata vs
  `index.html` `<head>` vs a layout component).
- **Static root**: `public/`, `static/`, or repo root.
- **Host/deploy config**: `vercel.json`, `netlify.toml`, `_headers`,
  `_redirects`, `nginx.conf`, `Caddyfile`, `wrangler.toml`, Dockerfile.
- **Live URL**, if one exists (README, deploy config, `package.json`
  `homepage`, or ask once). Items marked 🌐 are checked against it; with no
  live URL, check them against a local build/dev server, or mark `UNVERIFIED`
  — never guess a PASS.
- **Does the site have**: forms? cookies/trackers? Items that can't apply are
  `N/A` with the reason, not FAIL.

### Applicability profile

Answer each gate yes/no **with evidence** (the dependency, directory, or grep
that decided it). The gates decide which of items 21-37 apply; print the
profile at the top of the report so the user can correct a wrong answer.

| Gate | "Yes" looks like | Gates items |
|------|------------------|-------------|
| **backend** | API routes, server actions, serverless/edge functions, a server dir, **or a BaaS SDK called from the client** | 22, 23, 29, 30, 33, 37 |
| **accounts** | an auth library/provider, login/signup routes, session or JWT handling | 21, 24, 34 |
| **datastore** | a database driver/ORM, Supabase, Firebase, Appwrite, PocketBase, S3/R2/GCS buckets | 26, 27 |
| **user content** | anything one user types that another user (or an admin) later sees rendered | 31 |
| **uploads** | a file input wired to storage, presigned URLs, multipart handlers | 32 |
| **admin** | `/admin`, dashboards, role checks, an `is_admin`/`role` column | 25 |
| *(always)* | every repo | 28, 35, 36 |

A frontend with no server code that talks straight to Supabase/Firebase is
**not** "no backend" — the security rules *are* the backend, and items 24,
26, and 27 are where those apps leak. Only a site with no server code and no
BaaS/database is backend-free.

A gate answered "no" collapses its items into one `N/A` row carrying the
gate's evidence (see Step 2) — don't pad the report with a dozen identical
rows, and don't skip the gate's evidence either.

## Step 1 — Audit

For every item record `PASS` / `FAIL` / `N/A` / `UNVERIFIED` with evidence
(`file:line`, a command's output, or a URL + status). A PASS without evidence
is not a PASS.

### Legal & trust

1. **Privacy policy** — a real route/page exists (`/privacy`,
   `/privacy-policy`), is linked from the footer of every page, and its
   content is not lorem/template placeholders (`[Company Name]`,
   `example.com`). It should name what is actually collected — cross-check
   against items 5 and 19 (analytics in the code but not in the policy = FAIL).
2. **Terms & conditions** — same test: exists, footer-linked, no
   placeholders. `N/A` only for a purely informational site with no accounts,
   payments, or user content — say so rather than silently skipping.
3. **Secrets** — nothing secret ships to the browser, and nothing secret is
   hardcoded anywhere: server code reads keys from the environment or a
   secret manager, never from a string literal or a committed config file.
   Check:
   - Grep source *and the build output* (`dist/`, `.next/static/`, `build/`)
     for: `sk_live_`, `sk-`, `AKIA`, `AIza`, `ghp_`, `xox[bp]-`,
     `-----BEGIN`, `service_role`, `secret`, `password`, `api[_-]?key`.
   - Client-exposed env prefixes (`NEXT_PUBLIC_`, `VITE_`, `PUBLIC_`,
     `REACT_APP_`) holding anything that isn't meant to be public.
     Publishable keys (Stripe `pk_`, Supabase anon key, analytics IDs) are
     fine; a Supabase `service_role` key or any provider secret key is not.
   - `.env*` files tracked in git: `git ls-files | grep -E '\.env'` (only
     `.env.example` should appear, holding placeholders rather than real
     values), `.env*` is in `.gitignore` and in `.dockerignore`, and the
     static root / deploy output doesn't serve one (🌐
     `curl -s -o /dev/null -w '%{http_code}' <url>/.env` must not be 200).
     Past commits are item 35.
   - Source maps published in production exposing server code.
   A leaked key is **not fixed by deleting it** — report it as "rotate this
   key"; it is in git history and possibly in deployed bundles.
4. **Enforce HTTPS** 🌐 — `curl -sI http://<domain>` returns a 301/308 to
   `https://`; `curl -sI https://<domain>` carries
   `Strict-Transport-Security`. In the repo: no hard-coded `http://` asset,
   API, or form-action URLs (mixed content) — grep `http://` excluding
   `localhost`, `127.0.0.1`, xmlns/schema URIs, and comments. Most hosts
   (Vercel, Netlify, Cloudflare Pages) redirect by default; self-hosted
   nginx/Caddy configs need it spelled out.
5. **Cookie consent banner** — first inventory what sets cookies or tracks:
   analytics, ad pixels, embedded YouTube/maps, chat widgets, session
   cookies. Then:
   - Only strictly-necessary cookies (auth session, CSRF) → `N/A`, no banner
     needed. Say so; a banner nobody needs is clutter.
   - Non-essential trackers present → a banner must exist, **and trackers
     must not load before consent** (the script tag is gated on the consent
     state, not just hidden behind a dismissible notice). "Reject" must be as
     easy as "Accept".
   - Cookieless analytics (Plausible, Fathom, Umami, Vercel Analytics) → no
     banner needed; note it.

### SEO & sharing

6. **Meta titles/descriptions** — every indexable page has a **unique**
   `<title>` (≈ 50–60 chars) and `<meta name="description">` (≈ 120–160
   chars). FAIL on: framework defaults ("Vite + React", "Create Next App",
   "Astro"), the same title on every route, or missing descriptions. Also
   check `<html lang>` and `<link rel="canonical">`.
7. **Social preview image** — `og:title`, `og:description`, `og:image`,
   `og:url`, and `twitter:card=summary_large_image` present. The image file
   exists, is ~1200×630, under ~1 MB, and `og:image` is an **absolute**
   `https://` URL (relative URLs silently fail on most platforms).
8. **Favicon** — `favicon.ico` (or `.svg`/`.png`) in the static root, linked
   in `<head>`, plus `apple-touch-icon` (180×180). FAIL if it is still the
   framework's default logo (Vite, Next, Astro, React) — compare the file
   against the starter template's.
9. **Sitemap and robots.txt** — both exist in the static root or are
   generated at build. `robots.txt` has a `Sitemap:` line with the production
   URL and does **not** contain a leftover `Disallow: /`. The sitemap lists
   real production URLs (not `localhost` or a preview domain), covers the
   actual routes, and excludes 404/admin/auth pages. Also grep for a stray
   `<meta name="robots" content="noindex">` left over from staging.

### Accessibility & UX

10. **Image alt text** — every `<img>` / `<Image>` has an `alt` attribute.
    Meaningful images get a description; decorative ones get `alt=""` (that
    is a PASS, a missing attribute is not). FAIL on filename-as-alt
    (`alt="IMG_2041.jpg"`) and `alt="image"`. Icon-only buttons/links need an
    `aria-label`.
11. **Image compression** — list images in the static root and asset dirs by
    size: `find <dirs> -type f \( -name '*.png' -o -name '*.jp*g' -o -name '*.gif' -o -name '*.webp' \) -size +200k -exec ls -lhS {} +`.
    FAIL on anything > ~300 KB that isn't a deliberate hero, PNG/JPEG
    photographs that should be WebP/AVIF, images served far larger than their
    rendered size, and below-the-fold images without `loading="lazy"` /
    `width`+`height` (layout shift). Using the framework's image component
    (`next/image`, Astro `<Image>`) is a PASS for the ones routed through it.
12. **Page load speed** 🌐 — run Lighthouse if available:
    `npx lighthouse <url> --only-categories=performance --form-factor=mobile --output=json --quiet --chrome-flags="--headless"`
    and report LCP (< 2.5 s), CLS (< 0.1), TBT (< 200 ms), and the score
    (≥ 90 target, < 50 FAIL). Without a URL or Chrome, fall back to static
    evidence: production bundle sizes from the build output, render-blocking
    scripts in `<head>` without `defer`/`async`, unsubsetted web fonts
    without `font-display: swap`, no compression/caching headers — and mark
    the item `UNVERIFIED` rather than PASS.
13. **Color contrast** — extract the actual text/background pairs from the
    theme (CSS variables, Tailwind config, design tokens) and compute WCAG
    contrast ratios: ≥ 4.5:1 body text, ≥ 3:1 large text (≥ 24 px or 18.66 px
    bold) and UI component boundaries. The usual offenders: gray placeholder
    and muted/secondary text, text on brand-color buttons, disabled states,
    text over images. Check both themes if there is a dark mode. Lighthouse's
    accessibility category (`--only-categories=accessibility`) catches these
    on a live page.
14. **Mobile responsiveness** — `<meta name="viewport"
    content="width=device-width, initial-scale=1">` present; no fixed pixel
    widths wider than ~360 px on layout containers; nav collapses or wraps;
    tables/code blocks/wide media scroll inside their own container rather
    than the page; tap targets ≥ 44×44 px; inputs ≥ 16 px font-size (smaller
    triggers iOS zoom-on-focus). If browser tools are available, load the
    site at 375 px wide and confirm no horizontal page scroll — that beats
    reading CSS.
15. **Custom 404 page** — the framework's 404 convention is implemented
    (`app/not-found.tsx`, `pages/404.*`, `src/pages/404.astro`,
    `src/routes/+error.svelte`, `404.html` for static hosts) with site
    chrome and a link home. 🌐 `curl -s -o /dev/null -w '%{http_code}' <url>/definitely-not-a-page`
    must return **404** — an SPA catch-all that serves `index.html` with a
    200 (a "soft 404") is a FAIL even if the page looks right.
16. **Broken links** — internal: every `href`/`<Link to>`/router path
    resolves to an actual route or file, and every `#anchor` has a matching
    `id`. Placeholder links (`href="#"`, `href=""`, `javascript:void(0)`,
    `example.com`, "Coming soon" social icons pointing nowhere) are FAILs.
    External: `curl -sIL -o /dev/null -w '%{http_code}'` each unique external
    URL and report non-2xx/3xx (treat 403/429 from bot-blocking sites as
    `UNVERIFIED`, not broken). 🌐 With a live URL, `npx linkinator <url>
    --recurse` does all of this in one pass.

### Forms & conversion

17. **Form validation** — for every form: native constraints on the inputs
    (`required`, `type="email"`, `minlength`, `pattern`), correct
    `autocomplete` and `<label>`s, errors shown next to the field and
    announced (`aria-invalid`, `aria-describedby`), a visible
    success/failure state after submit, and the submit button disabled
    while in flight (no double-submits). **Client validation is UX, not
    security** — the receiving endpoint/server action must validate the same
    fields again. Client-only validation is a FAIL. `N/A` if no forms.
18. **Spam protection** — every public, unauthenticated form has at least
    one of: a honeypot field, Cloudflare Turnstile / hCaptcha / reCAPTCHA, or
    the form provider's built-in filter (Netlify Forms, Formspree); and its
    endpoint is rate-limited. Bare `mailto:` links with a plain-text address
    count too — they get scraped. A contact form that emails the owner with
    none of these is a FAIL. `N/A` if no public forms.
19. **Analytics setup** — a provider is installed, loads in production only
    (not counting dev traffic), uses the real production site ID (not a
    placeholder or an ID copied from another project), and — on an SPA —
    tracks client-side route changes, not just the first page load. It must
    agree with item 5 (consent-gated if it uses cookies) and item 1 (named
    in the privacy policy). No analytics at all is a FAIL unless the user
    says that's deliberate.
20. **Single clear CTA** — read the landing page as a first-time visitor.
    Above the fold there is **one** visually dominant action with a specific
    verb ("Start free trial", "Book a demo" — not "Learn more" / "Submit" /
    "Click here"). Count the competing primary-styled buttons in the hero: more
    than one = FAIL. The same CTA repeats at the bottom of the page, and its
    `href` goes somewhere that works (cross-check item 16). This is a
    judgment call — quote the button copy and explain the verdict.

### Access control

21. **Authentication** — every route, API endpoint, and server action that
    reads or changes non-public data requires a signed-in user. List the
    endpoints and mark each public/protected; the FAIL is a protected *page*
    whose underlying *API route* is open — hiding the button is not auth.
    Check: auth is enforced in middleware or per-handler on the server, not
    by a client-side redirect; sessions use `HttpOnly`, `Secure`,
    `SameSite` cookies (a JWT in `localStorage` is readable by any XSS);
    passwords are hashed by the auth library (bcrypt/argon2/scrypt), never
    stored or compared in plain text; hand-rolled auth is a FAIL when a
    maintained library is already in the stack.
22. **Server-side permission checks** — each mutating or sensitive handler
    checks, on the server, that *this* user may do *this* action on *this*
    record. A role/plan check that exists only in the UI (`{isAdmin &&
    <Button/>}`, a disabled button, a client route guard) is a FAIL: the
    request can be replayed with curl. Paid-feature and quota checks count.
23. **Frontend-supplied user IDs** — the acting user comes from the verified
    session/token on the server, never from the request. Grep handlers for
    `userId`, `user_id`, `ownerId`, `uid`, `email`, `role` read out of
    `req.body`, query params, headers, or form fields and then used in a query
    or an authorization decision. `where: { id: body.userId }` is a FAIL;
    `where: { id: session.user.id }` is a PASS. Same for price, plan, and
    `isAdmin` fields accepted from the client.
24. **User data isolation** — every query for user-owned data is scoped to
    the owner (`WHERE user_id = <session user>`, or an RLS policy doing the
    same; tenant/org ID on multi-tenant apps). Look for IDOR: a handler that
    loads `/api/invoices/:id` by `id` alone returns anyone's invoice to anyone
    who guesses the ID. Sequential integer IDs make it trivial, UUIDs do not
    make it safe. Also check list endpoints, exports, search, and cache keys
    (a shared cache keyed without the user ID serves one user's page to
    another).
25. **Admin routes** — admin pages *and the API routes behind them* check an
    admin role server-side on every request (middleware or per-handler),
    backed by a role stored server-side — not a client flag, not a
    hard-to-guess URL, not a check that only runs on the page. Also look for
    leftover framework/admin surfaces reachable in production: `/admin`
    scaffolds, Django admin at the default path, Prisma Studio, phpMyAdmin,
    GraphQL playground/introspection, Swagger UI, `/debug`, `/metrics`,
    `/actuator`, seed/reset endpoints.

### Data stores

26. **Database lockdown** — the database is not reachable from the public
    internet (private network, or an IP allowlist — not `0.0.0.0/0`; no
    `5432`/`3306`/`27017`/`6379` published in `docker-compose.yml` or a
    security group); no default or empty passwords; TLS required
    (`sslmode=require`); the app connects as a least-privilege role, not
    `postgres`/`root`; connection strings live in env/secret storage
    (cross-check item 3); backups exist and are not in a public bucket.
    Redis/Mongo/Elasticsearch with no auth is a FAIL on sight.
27. **Firebase, Supabase, and storage rules** — the anon/public key is
    *meant* to be public, so the rules are the only thing between the internet
    and the data:
    - **Supabase**: RLS enabled on **every** table in an exposed schema, with
      policies scoped to `auth.uid()` — check migrations for
      `enable row level security` per table. RLS enabled with a `using (true)`
      policy is still a FAIL for private data. `service_role` only
      server-side (item 3). Storage buckets private unless deliberately
      public, with policies.
    - **Firebase**: `firestore.rules` / `database.rules.json` /
      `storage.rules` are in the repo and contain no
      `allow read, write: if true`, no expired-or-not test-mode date rule, and
      no bare `if request.auth != null` on per-user data (that lets any
      signed-in user read everyone's).
    - **S3/R2/GCS**: no public-read/list ACLs or wildcard-principal bucket
      policies on buckets holding user data; private files served through
      short-lived signed URLs.
    Rules that live only in a dashboard and not in the repo are `UNVERIFIED`
    — ask the user to export them; never assume they're fine.

### Exposure

28. **Production debug mode** — Django `DEBUG = False`, Flask/FastAPI
    `debug=False` and no `--reload`, Laravel `APP_DEBUG=false`, Rails
    production env, `NODE_ENV=production`, Spring devtools/actuator off. The
    production start command runs a production server, not the dev server
    (`next start` not `next dev`, gunicorn/uvicorn not `flask run`). No
    verbose `console.log` of tokens, request bodies, or user records; no
    debug toolbars, dev-only routes, or test credentials/bypass flags
    (`if (email === 'test@…')`, `SKIP_AUTH`) left in.
29. **Detailed errors** — error responses give the client a generic message
    and a status code; stack traces, SQL text, file paths, and library
    versions go to server logs only. Grep handlers for
    `res.json(err)` / `err.stack` / `str(e)` / `e.message` returned to the
    client. A global error handler exists. Login and password-reset responses
    don't reveal whether an account exists ("invalid email or password", not
    "no such user"). No `X-Powered-By` / server version banner. 🌐
    Provoke a 500 (malformed JSON to an API route) and read what comes back.

### Input handling

30. **Server-side input validation** — every handler that accepts input
    validates it on the server against a schema (zod, valibot, joi, pydantic,
    the framework's validator): types, lengths, ranges, enums, and an
    allowlist of accepted fields. Passing `req.body` straight into an ORM
    create/update is mass assignment — a FAIL (the client can set `role`,
    `user_id`, `price`). Extends item 17 from forms to every endpoint,
    including webhooks (verify the provider's signature).
31. **Sanitize user content** — user-supplied content is escaped or sanitized
    wherever it is rendered. Grep for `dangerouslySetInnerHTML`, `v-html`,
    `{@html}`, `innerHTML`, `|safe`, `html_safe`, `raw(`, and for markdown
    rendered with raw HTML allowed; each must pass through a sanitizer
    (DOMPurify, sanitize-html, bleach) or be replaced with text rendering.
    Also: user-supplied URLs in `href`/`src` restricted to `http(s):`
    (blocks `javascript:`), user content in emails and PDFs, and redirects
    to a user-supplied `next`/`returnTo` URL restricted to same-origin paths.
32. **File uploads** — validated **on the server**: size cap, extension
    *and* sniffed content type against an allowlist (SVG and HTML are
    scripts — treat them that way), server-generated filenames (never the
    client's name in a path — path traversal), stored outside the web root or
    in object storage that will not execute or inline-render them
    (`Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`,
    ideally a separate domain), authentication required, per-user quota.
    Presigned upload URLs must pin content type and max size and expire
    quickly. Access to private uploads goes through item 24's ownership
    check.
33. **SQL and NoSQL injection** — all queries are parameterized or go
    through the ORM's query builder. Grep for string-built queries: template
    literals / f-strings / `+` / `.format()` inside `query(`, `execute(`,
    `raw(`, `$queryRawUnsafe`, `$executeRawUnsafe`, `sequelize.query`,
    `knex.raw`, `.extra(`, `whereRaw`. Dynamic `ORDER BY`/column/table names
    must come from an allowlist (they can't be parameterized). NoSQL: request
    values passed into Mongo filters unvalidated let `{"$ne": null}` through —
    cast to the expected type first (item 30); no `$where` with user input.
    Same family: user input reaching `exec`/`spawn`/`eval`/template engines
    or a server-side `fetch(url)` (SSRF).

### Abuse & hygiene

34. **Rate-limit login and signup** — login, signup, password reset,
    magic-link/OTP send, and OTP verify are rate-limited per IP **and** per
    account, server-side, in a store shared across instances (an in-memory
    counter on serverless resets on every cold start — FAIL). A managed auth
    provider's built-in limits count: name the setting. Signup additionally
    needs bot protection or email verification (cross-check item 18), and
    anything that sends email/SMS or calls a paid API needs a cap — that one
    is a billing incident, not just a security one.
35. **Secrets in git history** — scan every commit, not just the working
    tree. Prefer `gitleaks detect --no-banner` or
    `trufflehog git file://. --only-verified` if installed; otherwise
    `git log --all -p -G '<pattern>' --oneline` with item 3's patterns, and
    `git log --all --diff-filter=A --name-only --format= | grep -Ei
    '\.env|\.pem|\.key|id_rsa|credentials|serviceAccount|\.p12'` for
    files that were ever added. Any real secret found is a FAIL even if long
    deleted — it is in every clone and fork. Report the commit and the key's
    *type*, never echo the value.
36. **Security headers and CORS** 🌐 — `curl -sI https://<domain>` (or read
    the host/framework header config) for: `Content-Security-Policy` (no
    `unsafe-inline`/`*` in `script-src` if avoidable; at minimum
    `frame-ancestors`), `X-Content-Type-Options: nosniff`,
    `X-Frame-Options: DENY`/`SAMEORIGIN` or CSP `frame-ancestors`,
    `Referrer-Policy: strict-origin-when-cross-origin`,
    `Permissions-Policy`, and HSTS (item 4). CORS (needs the **backend**
    gate, else N/A for that half): `Access-Control-Allow-Origin` is an
    explicit allowlist of the production origins — FAIL on `*` for any
    credentialed or non-public API, on reflecting the request `Origin`
    back unchecked, and on `*`/reflection combined with
    `Allow-Credentials: true`. Cookie-authenticated mutations need CSRF
    protection (`SameSite` cookies plus a token or origin check).
37. **Untrusted-user test** 🌐 — stop reading code and attack it the way a
    stranger would, against a local or staging instance (ask before touching
    production; read-style probes only, never destructive ones):
    - **Logged out**: `curl` every API route and server action from item
      21's list with no credentials → expect 401/403, not data.
    - **Wrong user**: as user A, request user B's record IDs (read, update,
      delete) → expect 403/404. This is the live proof of items 23-24.
    - **Wrong role**: as a normal user, hit the admin pages *and* admin API
      routes → expect 403.
    - **BaaS direct**: query the Supabase REST endpoint / Firestore with only
      the public anon key, bypassing the app entirely
      (`curl "$SUPABASE_URL/rest/v1/<table>?select=*" -H "apikey: $ANON_KEY"`)
      → expect zero rows of private data. Proof of item 27.
    - **Tampered payload**: add `role`, `user_id`, `price` to a legitimate
      request body → the extra fields are ignored or rejected.
    Without a running instance this item is `UNVERIFIED` — code review of
    21-27 does not substitute for it.

## Step 2 — Report

Open with the applicability profile from Step 0, one line per gate with its
evidence:

```
backend: yes (app/api/*, 14 route handlers) · accounts: yes (next-auth)
datastore: yes (Supabase) · user content: no · uploads: no · admin: yes (/admin)
```

Then one table in checklist order. Items 1-20 always get their own row.
Items 21-37 get their own row when their gate is "yes"; each "no" gate
collapses to a single row listing the item numbers it covers:

| # | Item | Status | Evidence | Fix |
|---|------|--------|----------|-----|
| 31 | Sanitize user content | N/A | gate *user content*: no — no user-authored text is rendered to others | — |
| 21-27, 29-34, 37 | App security | N/A | no backend: no server code, no BaaS/DB dependency in `package.json` | — |

Then a one-line tally counting items, not rows
(`24 PASS · 6 FAIL · 5 N/A · 2 UNVERIFIED`), and the FAILs restated in
**fix order**:

1. Data exposed right now — 3, 35, 27, 26.
2. Access control — 21-25.
3. The rest of security — 4, 28-34, 36, then re-run 37.
4. Legal — 1, 2, 5.
5. Anything blocking indexing or sharing — 6-9, 15, 16.
6. The rest.

## Step 3 — Fix

Fix only after the report, and only what the user approves (or everything
mechanical, if invoked with `fix`). Follow the repo's existing conventions —
its component library, its metadata API, its image pipeline; add no
dependency where a few lines or a native feature will do.

**Never fabricate — ask or leave a clearly marked TODO:**

- **Legal text (1, 2).** Scaffolding the page, route, and footer link is
  fine. The policy content needs the user's real company name, contact,
  jurisdiction, and data practices; a drafted policy must be labelled as a
  draft needing legal review, never presented as compliant.
- **Leaked secrets (3, 35).** Move the call server-side and remove the key
  from the client, but tell the user to **rotate it** — removal does not
  un-leak it. Do not rewrite git history without being asked.
- **Auth and authorization (21-25).** Don't pick an auth provider or
  invent a role model; ask. Adding the missing ownership/role check to a
  handler, in the pattern the repo's other handlers already use, is fine.
- **Database rules (26, 27).** Write RLS policies / Firebase rules as a
  migration or rules file for the user to review and apply — a wrong policy
  either leaks data or locks every user out. Never apply them to a live
  project, and never change network/firewall settings, without being asked.
- **CORS and CSP (36).** The origin allowlist needs the real production
  domains; a CSP needs the real list of third-party scripts. Propose, and
  ship CSP as `Content-Security-Policy-Report-Only` first if unsure.
- **Analytics (19).** Don't pick a vendor or invent a site ID; ask.
- **CTA (20).** Propose copy; the user decides what the one action is.
- **Production domain.** Sitemap, canonical, `og:url` need the real one.

Everything else is mechanical: meta tags, OG tags, favicon links, `robots.txt`,
sitemap generation, `alt` attributes (describe what the image actually shows —
look at it), image conversion to WebP, `loading="lazy"`, contrast-passing
color values, viewport meta, a 404 page, dead-link repair, `required`/`type`
attributes, a honeypot field. On the security side: parameterizing a
string-built query, swapping a client-supplied user ID for the session's,
adding a schema to an unvalidated handler (reuse the repo's validation
library), wrapping `dangerouslySetInnerHTML` input in the sanitizer, a generic
error handler, debug flags read from the environment, the static security
headers, `.env*` in `.gitignore`/`.dockerignore`.

## Step 4 — Verify

Re-run the audit check for every item touched and show the before/after
status. Run the project's build and lint/typecheck — a launch fix that breaks
the build is worse than the gap it closed. Items that were `UNVERIFIED` stay
`UNVERIFIED` until checked against a running site; say so in the final tally.
