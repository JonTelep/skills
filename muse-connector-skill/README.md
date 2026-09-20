# muse-connector-skill

Skill: `/muse-connector` — build a complete, evidence-anchored submission
packet for Meta's [Muse Connector Platform](https://muse.ai/platform) from
whatever repository the skill is invoked in.

The live "Submit a connector" form is three steps (Overview, Technical specs,
Review). Its exact fields, input names, limits, and checkbox wording are
recorded in `skills/muse-connector/references/form-fields.md` (captured
2026-09-20). The skill:

1. runs `scripts/scan.sh` to mine the repo for every field's answer
   (identity, MCP tools or HTTP routes, OpenAPI, hosted URLs, auth style,
   env vars, rate limits/tiers, payments, legal URLs, 512×512 icon, docs);
2. decides Raw API vs Existing MCP;
3. writes `docs/muse-connector/SUBMISSION.md` in the target repo with
   paste-ready values, `path:line` evidence, a capability inventory,
   readiness checks, and a gap list.

It never touches the live form. Link it with `make link` from the repo root.
