# Intelligent Loop

`SKILL.md` is the procedure. The loop executes a reviewed plan with a fresh implementer
per coherent task when delegation is available. The orchestrator retains context,
reviews the actual artifacts, runs required checks, handles amendments, and commits
accepted work. Without delegation, the same process runs sequentially with explicit
self-review disclosure.

The division is about responsibility, not vendor model names. Choose available models
according to the user's preferences, task uncertainty, and observed results. A cheaper
implementer can be useful for well-specified tasks; difficult implementation may need
as much capability as planning.

## Workflow

```text
plan + evidence → confirm prerequisites → implement → review → verify → commit
                         ↑                   ↓
                         └── investigate / repair / amend

all tasks accepted → integrated acceptance → final report
```

Plans constrain outcomes, compatibility, and consequential design choices while leaving
local implementation judgment available. Discrepancies are investigated and classified
before escalating. Review findings need a concrete failure scenario or material cost;
line count and stylistic preference alone do not block acceptance.

Progress survives sessions in the plan's execution record. Existing Forge projects
use their ledger instead. Local commits provide reviewable units; publication and
external operations follow the user's actual authorization.

Use this for work that benefits from multiple coherent tasks and review between them.
Do a single small change directly. When the approach is uncertain, use `fable-prompts`
to investigate and plan before implementation. See the collection's
[usage guide](../../README.md#use) for copyable requests, including resume.
