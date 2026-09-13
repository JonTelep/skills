# Minimalist Entrepreneur — sales trio

Selected skills from Sahil Lavingia’s [The Minimalist Entrepreneur](https://www.minimalistentrepreneur.com/) playbook.

**Author:** Sahil Lavingia  
**Source:** [slavingia/skills](https://github.com/slavingia/skills) (`skills/<name>/SKILL.md`)  
**Vendored commit:** `eb9f57fba03ddb0382ed3bfe6654d3d7df128c70`

This package copies **three** of the ten upstream skills (the “sales trio”), not the full pack:

| Skill | When to use |
| --- | --- |
| `skills/first-customers` | Have a product, need the first 100 customers |
| `skills/pricing` | Setting prices or considering a price change |
| `skills/minimalist-review` | Gut-check a business decision through a minimalist lens |

`SKILL.md` content is preserved verbatim from upstream.

## Install

From the parent SKILLS repository root:

```bash
make link          # Claude Code (~/.claude/skills)
make link-codex    # Codex (~/.agents/skills)
make link-cursor   # Cursor (~/.cursor/skills)
```

`make link` discovers each `SKILL.md` automatically. Restart the agent or IDE after linking.

## License and attribution

[slavingia/skills](https://github.com/slavingia/skills) currently publishes **no LICENSE file** (GitHub `license` is null). These files are included with attribution to Sahil Lavingia / The Minimalist Entrepreneur. See `NOTICE`.
