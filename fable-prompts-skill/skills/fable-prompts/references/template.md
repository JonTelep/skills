# Template — series and prompt anatomy

Two levels: the series header (once) and the prompt anatomy (per prompt). Section order is fixed — implementing agents benefit from predictable structure across prompts and across series.

---

## Series header

```markdown
# <SERIES-NAME>.md — <phase/theme title>

A series of standalone implementation prompts for `<repo>`, designed to be
handed one at a time to a <model> agent for implementation, with each result
reviewed before the next prompt runs. <One sentence of phase context, linking
the roadmap doc if one exists.>

**The non-negotiable outcome of this phase:** <the thesis — falsifiable,
with the enforcing test named and the prompt that writes it identified.>

**Scope guard:** <what this series deliberately does NOT do, and where the
deferred work belongs.>

**How to use:** paste one prompt (the full section between `---` separators)
into a fresh session. Prompts assume the ones before them have landed — run
them in order. Each prompt is self-contained: it references only artifacts
that exist in the codebase by the time it runs. If a referenced helper does
not exist, that signals a prerequisite session did not land — stop and report
rather than improvise.

**Review loop:** after each prompt lands, review the diff for correctness,
test honesty (do the tests actually exercise the claim?), and scope creep.
Loop fixes back to the same agent until the prompt's acceptance criteria
pass, then move on.

**Sequencing:** <the DAG in one line, e.g. "1 → 2 → 3 strictly; 4, 5, 6 all
require 3; 5 and 6 are independent of each other.">

**Human checkpoint recommended:** <which prompt(s), why (blast radius), and
the mitigation — "run in plan mode and review the plan before letting it
code.">
```

## Prompt anatomy

Each prompt, separated by `---`:

```markdown
## Prompt N: <imperative title naming the artifact or move>

**Goal:** <one paragraph: the outcome, not the activity. If the prompt has a
hard boundary ("no existing code is rewired yet — this prompt only builds and
proves the foundation"), it goes here.>

**Prerequisite check:** <only when the dependency is subtle: name the
artifact that must exist and instruct "if it doesn't, stop and report."
Omit when the Details' anchors already serve as tripwires.>

**Affected packages:** <exhaustive list, `(new)` markers for new ones. This
is a blast-radius declaration — everything unlisted is implicitly frozen.>

**STEP 0:** <only when the right design depends on what the code can
express, or a baseline must exist before edits: a mandatory read-and-report
or measure-first step, with the fallback scope decided by the author ("if X
isn't expressible, implement ONLY Y and defer — do not build a speculative
layer"). Omit otherwise.>

**Details:**
- <The design decisions, made by the author, with reasoning inline and
  recon-verified anchors. Bullets ordered by implementation sequence.
  This is the longest section — it should read like a senior engineer's
  design note, not a feature wishlist.>
- <Named scope-creep prohibitions where the tempting expansion is
  predictable.>

**OpenAPI / <cross-cutting ritual>:** <what spec/generated-artifact changes
this prompt requires, and the sync command. "None" is a valid and useful
entry — it tells the agent NOT to touch the spec.>

**Testing:** <the specific claims tests must prove, including the
no-regression proof (golden/byte-identical comparisons), boundary cases
called out by name, and repo gotchas inline.>

**Invariants:** <the negative space: untouched packages, byte-identical
outputs, preserved properties, hard compatibility lines.>

**Guardrails (mandatory):**
- Run <exact full-suite command with flags> and make it pass before finishing.
- <Repo rituals this prompt can trigger — restated even though the header
  mentions them.>
- <Unfakeable-verification clauses where the known dodge exists: "editing X
  without running it does not count as done", "no baseline, no perf claim".>
- If the codebase contradicts anything stated above, stop and report the
  discrepancy instead of improvising a workaround.
- Do not commit or push unless explicitly asked.
```

---

## Annotated example (abridged from a real series)

Below, `◀` comments mark what each element is doing and why.

```markdown
## Prompt 3: Engine and function registry on typed records

**Goal:** The transform engine consumes `record.Source` and evaluates rules
over `[]record.Value`; the function registry signature becomes typed. CSV
becomes one adapter on the way in and one serializer on the way out. This is
the phase's load-bearing cutover.            ◀ outcome + stakes, no activity list

**Affected packages:** `internal/engine`, `internal/functions`,
`internal/rules` (only if evaluator types leak there), `internal/jobs`,
`internal/api` (wiring).                     ◀ blast radius; the parenthetical
                                               pre-authorizes a boundary case
                                               so the agent doesn't stall on it

**Details:**
- **Registry cutover, one stroke, no dual path:**  ◀ author's decision, stated
  `type Func func(args []record.Value) (record.Value, error)`  as law — "no dual
  in `internal/functions/registry.go`. Provide one shim helper,  path" kills the
  `functions.StringFunc(...)`, that coerces every arg via         easy-but-wrong
  `Value.Format()`. Migrate all 39 existing transforms            design up front
  mechanically through the shim — their observable behavior
  must not change in this prompt. (Prompt 4 writes the first
  natively typed functions; opportunistically un-shimming
  existing ones is scope creep — don't.)     ◀ counted anchor ("39") = recon
                                               proof + tripwire; named
                                               scope-creep prohibition with the
                                               deferred home identified
- **Cross-source equivalence test — the phase's flagship test:**
  one ruleset run twice: once through a CSV fixture, once through
  a `record.SliceSource` built from the same logical data. Assert
  byte-identical output rows, identical report counts, identical
  skip decisions. Name it visibly (`TestTransform_SourceAgnostic`)
  and comment that Phase 3 sources must be added to it.
                                             ◀ the thesis-enforcing test:
                                               named, permanent, assigned here

**Testing:** all existing engine tests pass with at most mechanical
updates (same fixtures, same expected outputs — expectation changes
are a red flag, justify each one); pass-through fidelity test
(`"007"` int-hinted column, no rule touches it, output
byte-identical).                             ◀ claims, not "add tests";
                                               anti-dodge clause on
                                               expectation changes

**Invariants:** HTTP API responses byte-identical for existing
endpoints. `internal/profile`, `internal/checks` untouched.
Transform of an unhinted CSV is byte-identical to pre-refactor
output.                                      ◀ negative space: what must
                                               NOT move

**Guardrails (mandatory):**
- Run `go test ./... -race -count=1` and make it pass before finishing.
- Run `make soak` once and confirm it passes (the transform hot
  path changed).                             ◀ ritual + the reason it
                                               applies to THIS prompt
- If `internal/record` helpers from the earlier session are missing
  something, stop and report — do not reimplement inline.
                                             ◀ tripwire: broken-prerequisite
                                               detector
```
