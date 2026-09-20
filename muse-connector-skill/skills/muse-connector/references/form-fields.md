# Muse Connector Platform — submission form, field by field

Captured from https://muse.ai/platform → "Submit a connector" on 2026-09-20 by
stepping through the live form in a browser (nothing was submitted). Re-verify
against the live form before a real submission; Meta can change it any time.

The form is a single page, three steps. `name=` is the HTML input name. Max
lengths are the `maxlength` attributes the form ships with. Nothing is marked
`required` in HTML, but the form blocks "Next" with an inline error when a
field is missing (observed: "Add a 512×512 PNG or SVG connector icon.").
Treat every non-"(optional)" field as required.

## Step 1 — Overview

| Label (verbatim) | name | Type | Limits / placeholder |
|---|---|---|---|
| Connector name | `productName` | text | max 80 · "Your connector" |
| Company or developer | `companyName` | text | max 120 · "Your company or name" |
| Product website | `website` | url | "https://yourcompany.com" |
| Example prompts | `useCases` | textarea | max 10000 · "What might someone ask Muse to do? e.g. “Add a morning run to my training plan,” “Dim the lights in the dining room”" |
| Connector icon | `brandFilesInput` | file | accepts `image/png,image/svg+xml,.png,.svg` · UI text: "Drop a 512×512 PNG or SVG or click to browse" · **blocks Next if missing** |
| Payments | `payments` | select | options: "My connector accepts payments" / "My connector does not accept payments" |
| Your name | `contactName` | text | "Full name" |
| Work email | `contactEmail` | email | "you@company.com" · help text: "Use your company email address." |
| Support email or URL | `support` | text | "https://help.yourcompany.com or help@yourcompany.com" |
| Your privacy policy | `privacyUrl` | url | "https://yourcompany.com/privacy" |
| Your terms of service | `productTerms` | url | "https://yourcompany.com/terms" |
| Anything else? (optional) | `extraNotes` | textarea | "Add any other details you want to share." |

## Step 2 — Technical specs

**Connection type** — two toggle buttons: **Raw API** or **Existing MCP**. The
fields below change with the toggle.

Raw API:

| Label (verbatim) | name | Type | Placeholder |
|---|---|---|---|
| API URL | `endpoint` | url | "https://api.yourproduct.com" |
| OpenAPI specification (optional) | `openapi` | url | "https://api.yourproduct.com/openapi.json" |
| API or MCP documentation | `documentationUrl` | url | "https://docs.yourproduct.com" |
| Access requirements | `limits` | textarea | "List any account, plan, regional, rate or usage requirements" · help: "Include anything that affects who can use the connector or what it can do." |
| Authentication methods (optional) | `authMethods` | checkboxes | "API keys" · "OAuth with PKCE" · "Other" |

Existing MCP (the `openapi` field disappears, `endpoint` is relabelled):

| Label (verbatim) | name | Type | Placeholder |
|---|---|---|---|
| Hosted MCP endpoint | `endpoint` | url | "https://api.yourproduct.com" |
| API or MCP documentation | `documentationUrl` | url | "https://docs.yourproduct.com" |
| Access requirements | `limits` | textarea | as above |
| Authentication methods (optional) | `authMethods` | checkboxes | "API keys" · "OAuth with PKCE" · "Other" |

## Step 3 — Review

Read-only summary of steps 1–2 (each with an "Edit" button), then three
checkboxes and the **Submit for review** button:

| Checkbox text (verbatim) | name |
|---|---|
| I confirm I’m authorized to submit this connector and its brand assets. | `authorized` |
| I understand that submission doesn’t guarantee approval and promotion is based on usage and editorial discretion. | `distributionUnderstood` |
| I agree to the Muse Connector Terms. | `termsAccepted` |

"Muse Connector Terms" links to https://muse.ai/platform/terms (returned
"Sorry, this content isn't available right now" on 2026-09-20 — read it
yourself before submitting).

## What Meta says happens after submit (from the platform page)

1. **Describe your product** — "Tell us what your connector does and how users will use it."
2. **Submit for review** — "We'll review your connector for functional, security, and legal requirements, and complete end to end testing."
3. **Appear in the directory** — "Once approved, users will be able to find your connector in Muse. Editors will review connectors for featured placement."

Also stated: Meta has partnered with Stripe so connectors can accept payments
with Link. Not stated anywhere public as of 2026-09-20: fees, revenue share,
review SLA, an SDK, or a connector spec beyond "Raw API or Existing MCP".

## How Muse consumes a connector (public, third-party reporting — verify)

From Meta's Help Center ("How Muse works with Connectors") and reporting on
custom integrations:

- Muse runs an agent on its own VM. For **MCP** it builds an MCP client with the
  official SDK and connects over **streamable HTTP**. For **REST** it wants the
  OpenAPI document or docs page. It can also install a **CLI from npm/PyPI**.
- Credentials go into Muse's "Secure Credentials Store"; a component called
  Sentinel swaps a surrogate token for the real one at egress, so the agent
  never sees raw secrets. **Bearer tokens and API-key headers fit this flow
  directly; OAuth-only services need more back and forth.** This is why the
  form lists "API keys" and "OAuth with PKCE" (no client secret) as the named
  auth options.
- Muse "is designed to exchange with Connectors only the data that's needed"
  and "will not take many important actions, like sending an email, without
  your approval". Connectors can be read-only. Design tools with clear
  read vs. write separation and per-action purpose strings.
- Meta says custom (unreviewed) connectors are used at the user's risk; the
  directory submission is the reviewed path.

Sources: https://muse.ai/platform · https://www.meta.com/help/artificial-intelligence/1687253048996149/ · https://parallel.ai/articles/meta-muse-custom-integrations
