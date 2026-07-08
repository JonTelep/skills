# Principles — why each rule exists

Every rule here compensates for a specific, observed failure mode of unsupervised implementing agents. The WHY is stated because you (the prompt author) will face situations the rules don't cover — reason from the failure mode, not the letter.

---

## 1. The thesis must be falsifiable, and a test must enforce it

**Failure mode:** a series built on an aspiration ("make the code cleaner", "support more sources") produces prompts that all individually succeed while the goal quietly fails. Nobody can point to the moment it was lost.

**Rule:** state the series' outcome as a literal test, and assign one prompt to write the test that enforces it permanently.

- ❌ "Every component should operate on the internal typed record stream."
- ✅ "Adding a new source in Phase 3 must touch **zero** code in `internal/engine`, `internal/profile`, or `internal/functions`. Prompt 3 enforces this with a cross-source equivalence test (`TestTransform_SourceAgnostic`) that must stay green forever."

## 2. Every code reference is a verified anchor — and a tripwire

**Failure mode:** a prompt says "extend the ValidateID helper" but the helper doesn't exist (the author guessed, or a prerequisite session didn't land). The agent improvises one, diverging from the intended design, and reports success.

**Rule:** every file, function, line range, and count in a prompt was verified during recon (`internal/profile/engine.go:197-221`, "all 39 existing transforms"). Then weaponize the anchors: instruct that a missing referenced artifact means a prerequisite session did not land — **stop and report rather than improvise**. Anchors serve double duty: they save the agent discovery time, and they detect broken prerequisites.

Corollary: prompts never reference each other by number ("as done in Prompt 2") — a fresh session can't see Prompt 2. Reference only artifacts that will exist **in the codebase** by the time the prompt runs.

## 3. The author decides; the implementer executes

**Failure mode:** left to choose, an implementing agent picks the design that is easiest to generate, not the one that fits — an interface where a tagged struct was needed, a speculative metadata layer, a second parallel code path "for safety".

**Rule:** make the architectural calls in the prompt, with the reasoning inline so the agent can't rationalize around them.

- ❌ "Create a Value type to represent typed cells."
- ✅ "`record.Value` is a small **tagged struct, not an interface** — no boxing in the hot path: `{Kind Kind; Raw string; I int64; F float64; B bool; T time.Time}`."

When a decision genuinely depends on what the code can express, don't guess — mandate a STEP 0 read-and-report ("read the AST types first; if implied-rule insertion isn't cleanly expressible, implement ONLY conflict detection and explicitly defer — do not build a speculative metadata layer").

## 4. Invariants are the negative space — state what must NOT change

**Failure mode:** blast radius creep. The agent "improves" adjacent code, breaks an untested consumer, or introduces buffering into a streaming path because nothing said not to.

**Rule:** every prompt declares affected packages (which implicitly excludes everything else) AND an explicit Invariants section: untouched packages, byte-identical outputs, preserved properties ("single-pass streaming preserved — the source abstraction must not introduce buffering"), and compatibility lines ("rulesets without `on_failure` behave byte-identically — this is a hard compatibility line").

## 5. Name scope creep before it happens

**Failure mode:** the agent sees an "obvious" adjacent improvement and takes it, entangling the diff and making review impossible.

**Rule:** when you can predict the tempting expansion, forbid it by name and say where it belongs instead.

- ✅ "Migrate all 39 existing functions mechanically through the shim — opportunistically un-shimming existing ones is scope creep. Don't. (Prompt 4 writes the first natively typed functions.)"

## 6. Guardrails must be mechanical and unfakeable

**Failure mode:** the agent reports success on work it didn't verify — edits the Containerfile without booting it, claims a perf win without a baseline, ships a flaky test as passing.

**Rule:** exit criteria are commands with pass/fail outcomes, plus explicit anti-rationalization clauses for the known dodges:

- "Run `go test ./... -race -count=1` and make it pass before finishing." (Exact flags — they're a different claim than `go test ./...`.)
- "STEP 0: save a benchmark baseline before editing anything. No baseline, no perf claim."
- "You MUST actually boot the resulting container and confirm `/healthz` responds. Editing the Containerfile without booting it does not count as done."
- "If you cannot make BOTH gates pass, ship with the feature opt-in and report exactly why. Do not rationalize a flaky pass."
- "If the live path could not be exercised, your summary must state so explicitly — do not report success."

Repo rituals (spec syncing, generated code) are restated in **every** prompt that can trigger them — a fresh session has no memory, and cross-cutting invariants must travel with each prompt.

## 7. Testing sections state the claims to prove, not "add tests"

**Failure mode:** tests that exercise the code but not the claim — a null-handling test that never constructs a null, an equivalence test comparing a thing to itself.

**Rule:** enumerate the specific propositions tests must establish, including the no-regression proof:

- ✅ "Profile of a CSV dataset with int/float hints is numerically identical to the pre-refactor output (golden comparison on an existing fixture — this is the no-regression proof)."
- ✅ "`NullValue() != StringValue(\"\")` under `Equal`."
- ✅ "All existing engine tests pass with at most mechanical updates — expectation changes are a red flag; justify each one."

Include the repo's known testing gotchas inline (from the conventions doc) so the agent doesn't waste a session rediscovering them.

## 8. Size sessions to one architectural move

**Failure mode (too big):** quality degrades through the session; the last third is rushed, tests are thin, the summary glosses. **Failure mode (too small):** every session pays full recon cost for a trivial diff.

**Rule:** one coherent move plus its proof per prompt — "create the record package and prove it, wiring nothing" then "rewire the profiler onto it" — not both, not half of one. When a cutover can't be split, mark it as the human checkpoint and mandate plan mode.

## 9. Sequencing is explicit; parallelism is explicit

**Rule:** the header states the DAG in one line ("1→2→3 strictly; 5 and 6 independent of each other; 4 any time after 3") so the human running the series can schedule without re-deriving dependencies. Human checkpoints are flagged where blast radius is largest, with the mitigation named (plan mode + plan review).

## 10. The review loop is part of the format

**Rule:** the header tells the human what to review after each prompt lands — correctness, **test honesty** (do the tests actually exercise the claim?), and scope creep — and to loop fixes back to the same agent until acceptance criteria pass before moving on. The series assumes review between sessions; prompts can therefore afford to trust that prerequisites landed *if their tripwires don't fire*.

## 11. Voice

Write in dense, declarative, second-person-imperative prose. Bold the load-bearing decisions. Parentheticals carry the reasoning ("no boxing in the hot path"). No hedging, no "consider", no "you may want to" — the implementer executes; optionality is the author's to resolve. Use the repo's own vocabulary (from the conventions doc), never synonyms.
