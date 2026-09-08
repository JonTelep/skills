# Ponytail — simplicity and maintenance

Adapted from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail).
The MIT notice is preserved below. This adaptation prioritizes the minimum
maintainable solution over line count.

## Reuse ladder

Understand the real flow and requirements before choosing an implementation:

1. Does the capability need to exist for the agreed outcome?
2. Does the codebase already provide a suitable helper or pattern?
3. Does the standard library cover the required semantics?
4. Does the platform provide the capability?
5. Does an installed dependency provide a suitable solution?
6. Otherwise, write the minimum maintainable implementation.

Choose the first suitable option, not the first superficially similar API. Check
edge cases, compatibility, and required performance. A concise expression is useful
when readable; a one-liner is not a goal in itself.

## Decision rules

Prefer fewer unnecessary concepts, less coupling, and less duplication. A new file,
abstraction, or dependency needs a concrete benefit; its mere existence is not a
defect. Do not add scaffolding for hypothetical requirements. Respect the plan's
fixed decisions; report contrary evidence through its amendment procedure. Use
judgment for choices explicitly left flexible.

For bug fixes, trace relevant callers and fix the root cause. Do not silently expand
a task beyond its contract to clean up every adjacent issue. Report discoveries and
agree an amendment when required.

Never simplify away validation at trust boundaries, protection against data loss,
security, accessibility, or required performance. Tests should prove material claims;
reuse existing coverage when sufficient. Do not add tests that merely mirror the
implementation or force new tests for trivial changes.

## Review tags

Locate each finding and explain its concrete cost and proposed improvement:

- `delete`: unused or speculative behavior.
- `reuse`: suitable existing behavior duplicated by the change.
- `stdlib` / `native`: custom machinery replaceable without losing required semantics.
- `yagni`: complexity whose benefit depends on a hypothetical requirement.
- `simplify`: fewer concepts or clearer flow with the same required behavior.

Block on violated requirements or material maintenance costs. Label preferences
nonblocking. Do not require a negative line-count target or repeat reviews just to
find something else to shorten. Correctness and acceptance checks remain necessary
when the simplicity pass has no findings.

## Deliberate limitations

Mark a real deferred limitation with a `ponytail:` comment naming the ceiling and
an observable upgrade trigger. Example:

```text
// ponytail: serial account updates; use per-account locks if measured lock wait
// exceeds the service latency budget under expected concurrent load.
```

At completion, summarize markers added or materially changed by the series, using
tracked changed files and excluding generated/vendor content. Report ceiling and
upgrade trigger; flag missing triggers. Do not turn this into an inventory of all
historical debt. Ordinary design decisions do not need markers.

## Compact block for implementer dispatch

```text
SIMPLICITY AND MAINTENANCE
Understand the affected flow first. Check whether the capability is needed, then
look for suitable repo helpers, stdlib, platform features, and installed dependencies
before writing new code. Prefer the minimum maintainable solution: fewer unnecessary
concepts, less coupling, and less duplication. Line count alone is not a quality gate.
New files, abstractions, and dependencies need concrete benefits consistent with the
plan's constraints. Preserve required behavior, validation, data-loss protection,
security, accessibility, and performance. Prove material claims with appropriate
checks; do not add tests solely to mirror implementation. Honor fixed decisions and
use judgment within flexible choices. If evidence invalidates a fixed decision,
report it with a proposed amendment before changing the contract. Mark real deferred
limitations with a ponytail: ceiling and observable upgrade trigger.
```

---

MIT License. Copyright (c) 2026 DietrichGebert. Permission is hereby granted, free of
charge, to any person obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions: The above copyright notice
and this permission notice shall be included in all copies or substantial portions of
the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
