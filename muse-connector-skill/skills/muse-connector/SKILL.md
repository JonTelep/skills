---
name: muse-connector
description: >
  Prepare a complete "Submit a connector" packet for Meta's Muse Connector
  Platform (https://muse.ai/platform) from the repository this skill is
  invoked in. Scans the repo for every field the three-step form asks for
  (identity, example prompts, 512×512 icon, payments, legal URLs, Raw API vs
  Existing MCP, endpoint, OpenAPI, docs, access requirements, auth methods),
  writes docs/muse-connector/SUBMISSION.md with paste-ready values, evidence
  anchors, and a gap list. Use when the user says Muse, Meta Muse, Muse
  connector, muse.ai, "submit a connector", or wants their API/MCP server
  listed in the Muse directory. Never submits the form.
allowed-tools:
  - Bash(bash *scan.sh *)
  - Bash(git *)
  - Bash(curl *)
  - Bash(python3 *)
---

# muse-connector — build the Muse submission packet from this repo

The Muse form (captured 2026-09-20, see `references/form-fields.md`) is three
steps: **Overview → Technical specs → Review**. This skill turns the repo
you're standing in into a filled-out packet for that form. It never submits
anything; the user pastes values into the live form themselves.

**Rule: no value without evidence.** Every field in the packet is either
anchored to `path:line` / a command you ran, or explicitly marked as a human
decision (name, work email, payments stance, terms acceptance). Do not invent
URLs, rate limits, or company names. A ❌ is more useful to the user than a
plausible guess.

## Workflow

1. **Scan.** From the repo root (the script lives next to this SKILL.md):
   ```bash
   bash <skill-dir>/scripts/scan.sh .     # e.g. bash ~/.claude/skills/muse-connector/scripts/scan.sh .
   ```
   Read the whole output. It is grouped by form field. It is a lead sheet,
   not the answer — open the files it points at and confirm.

2. **Decide the connection type.** This is the fork that changes step 2.
   - MCP SDK dependency / `server.tool(` / `@mcp.tool` present → **Existing MCP**.
     Confirm the transport is **streamable HTTP** (Muse's client connects
     over HTTP, not stdio). If it's stdio-only, that's a ❌ gap: the
     connector needs a hosted HTTP endpoint before submission.
   - HTTP routes but no MCP → **Raw API**. Find or generate the OpenAPI doc
     (FastAPI serves `/openapi.json`; NestJS/Swagger etc. per scan output).
   - Both present → prefer Existing MCP; note the REST API URL in
     "Anything else?".
   - Neither (library, CLI, frontend) → say so plainly. The packet can
     still be written, but "Endpoint" is ❌ and the gap list leads with it.

3. **Fill every field** using `references/packet-template.md` as the
   skeleton. Field-specific rules:
   - **Connector name / Company** — from package manifest or README H1;
     respect max 80 / 120 chars.
   - **Product website** — manifest `homepage`, README links, deployed URL
     from CI/config. Must be the product, not the GitHub repo, unless the
     repo *is* the product.
   - **Example prompts** — write 5–8, each mapped to a real tool/route in the
     capability table. Imperative, concrete, user voice, like the form's own
     examples ("Add a morning run to my training plan"). Cover reads and
     writes. Do not list prompts the connector cannot fulfil.
   - **Connector icon** — must be exactly 512×512 PNG or SVG. The scan
     prints dimensions for candidates. If none, ❌ and name the source image
     to export from. Don't generate an icon unless asked.
   - **Payments** — ⚠️ human decision. Report Stripe/billing evidence only.
   - **Your name / Work email** — human. Suggest from git config / manifest
     author but mark ⚠️. The form says "Use your company email address."
   - **Support / Privacy / Terms URLs** — must be real URLs that resolve.
     If the scan finds candidates, `curl -sI` them and record the status.
     Missing legal pages are a hard ❌; Meta reviews for legal compliance.
   - **Endpoint** — the *hosted* URL, not localhost. Curl it; record status.
   - **API or MCP documentation** — a URL, not a repo path. README on
     GitHub is acceptable only if it actually documents the tools/routes.
   - **Access requirements** — pull concrete numbers (per-day/per-minute
     limits, tiers, regions, account prerequisites) with anchors. Muse's
     reviewers run end-to-end tests, so state what a tester needs.
   - **Authentication methods** — map evidence to the three checkboxes.
     Muse's credential store handles API keys / bearer headers directly;
     OAuth must be PKCE (public client, no secret). Session-cookie or
     client-secret-only auth → "Other" plus a gap entry explaining the
     mismatch.

4. **Build the capability inventory** (template table). One row per MCP tool
   or route Muse could call: read/write, whether it should require user
   approval (Muse asks before "important actions"), one-line purpose. This
   is what reviewers exercise; it also feeds the example prompts.

5. **Run the readiness checks** in the template. Actually run what you can:
   tests, `curl` of endpoint/legal/support URLs, a secrets grep (the scan
   does a quick one). Record commands and results.

6. **Write `docs/muse-connector/SUBMISSION.md`** (create the directory).
   Lead with a 3-line summary: connection type, readiness (n/m checks), and
   the top blocker. End with a numbered gap list ordered by what blocks
   submission first (icon, legal URLs, hosted endpoint, auth mismatch are
   the usual four).

7. **Report** to the user: where the packet is, the blockers, and remind
   them the three step-3 checkboxes and the Connector Terms are theirs to
   read and accept. Do not open or fill the live form.

## What you must not do

- Submit, or fill, the live form at muse.ai — not even with placeholders.
- Fabricate privacy/terms/support URLs, rate limits, or company identity.
- Commit the icon, packet, or any change without the user asking.
- Treat third-party reporting about Muse internals as fact; the only
  authoritative surfaces are the form itself and Meta's help center. See
  the "How Muse consumes a connector" section of `references/form-fields.md`
  for what's verified vs reported.

## Files

- `scripts/scan.sh` — read-only repo scan, Markdown out, grouped by form field.
- `references/form-fields.md` — the live form, verbatim labels, input names, limits, all three steps.
- `references/packet-template.md` — skeleton for `docs/muse-connector/SUBMISSION.md`.
