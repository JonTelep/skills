---
name: fantasy-keepers
description: >
  Decide which players to keep in a fantasy football keeper league on Sleeper or
  ESPN. Pulls the league, last season's draft (which sets keeper cost), last
  season's actual stats, and the current season's ADP and projections, then ranks
  candidates by surplus value — what a player is worth minus what he costs.
  Handles snake and auction drafts, PPR/half/standard scoring, and escalating
  keeper prices. Use when the user asks who to keep, which keepers to pick,
  whether a keeper is worth the round or the money, or wants a keeper analysis
  for a Sleeper or ESPN fantasy football league.
---

# Fantasy Keeper Analyzer

Pick keepers by **surplus value**, not by who is the best player.

The most common keeper mistake is keeping your two best players. If you drafted a
stud in the 1st round and he still goes in the 1st, keeping him buys you nothing —
you pay exactly what he is worth. The win comes from players whose price is stale.

But cheap is not the same as valuable. A quarterback costing a 16th-round pick
looks like a steal until you notice that in a 1-QB league the QB12 on waivers
scores nearly the same. So the ranking metric is **net value**:

```
VORP = projected points − last startable player at that position
NET  = VORP − the VORP the forfeited pick would have bought        (snake)
NET  = derived auction value − keeper price                        (auction)
```

A keeper only wins if he beats what that same pick or that same money buys.

## Running it

```bash
# Sleeper
python3 scripts/keepers.py --platform sleeper --username <name>

# ESPN (public league)
python3 scripts/keepers.py --platform espn --league-id <id> --season <year> --team <name|id>

# ESPN (private league — cookies from a logged-in espn.com session)
python3 scripts/keepers.py --platform espn --league-id <id> --season <year> \
    --team <name> --espn-s2 "$ESPN_S2" --swid "$SWID"
```

Ask the user for their **platform** first, then the identifier it needs: a Sleeper
username, or an ESPN league id (the number in their league URL) plus season. If a
Sleeper user is in several leagues, or an ESPN team is not specified, the script
prints the choices — show them and ask.

| Flag | Purpose |
|---|---|
| `--league-id` | Required for ESPN; disambiguates Sleeper |
| `--season` | Season being drafted. Required for ESPN |
| `--team` | ESPN team id, name, abbrev, or owner |
| `--keepers N` | Override the league's keeper count |
| `--escalate N` | Cost rises each year held: N rounds earlier, or +$N |
| `--escalate-pct N` | Auction: keeper price rises N% |
| `--undrafted-cost N` | Cost for a player who was never drafted |
| `--no-inherit` | Sleeper: skip tracing who each pickup replaced |
| `--scoring` | Force ppr / half_ppr / std |
| `--json` | Machine-readable, including replacement levels |

No auth for Sleeper or public ESPN leagues. Responses cache to
`~/.cache/fantasy-keepers/`; the Sleeper player list is 14 MB and Sleeper asks it
be fetched at most once a day, which the cache enforces.

**Read the error before retrying.** They name the fix — the list of leagues to pick
from, the teams in the league, or the missing flag.

## Reading the output

`*` marks the top N by net value, where N is the league's keeper count.

- **NET** — the ranking metric. Positive means keeping beats drafting at that slot.
- **VORP** — points above the last startable player at that position, using the
  league's real lineup slots. This is what corrects for positional depth.
- **COST / WORTH / SURPLUS** — the draft-capital view, in rounds or dollars. Useful
  context, but a big surplus on a replacement-level player is a mirage.
- **~ not drafted — inherits R8: replaced X** — a pickup priced from the player he
  replaced (Sleeper only; see below).
- **! not drafted — cost is an assumption** — verify before recommending him.

## Turning the table into a recommendation

The script ranks by price. You supply the judgment.

**1. Start from the top of NET.** Where NET and SURPLUS disagree, trust NET.
Surplus alone will hand you a cheap replacement-level player and call it a bargain.

**2. Discount for regression.** The flags do this work:

- *TD-lucky* — touchdown rate far above the positional baseline. TD rate is the
  least sticky stat in football. 14 scores on 85 targets is a sell; the same points
  on 150 targets is real. Prefer the next player down if NET is close.
- *TD-unlucky* — the reverse, and a genuine buy signal.
- *bell-cow role* — the strongest positive signal here. Volume is what survives.
- *low snap share* — production not backed by playing time. Fragile.
- *missed time* — compare per-game rates, not totals. An RB1 pace in 11 games may
  be the best keeper on the roster.
- *age N RB* — production falls off sharply around 28.

**3. Consider what the keepers do to the draft.** Two keepers cost two picks. Two
mid-round keepers often build a better roster than one spectacular keeper who
costs a 1st.

**4. Sanity-check scarcity.** VORP handles most of this (`replacement_level` in the
JSON shows the baselines), but know what it is doing: in a 1-QB league replacement
QB is high, so even a QB10 nets almost nothing; in superflex the baseline collapses
and QB becomes the most valuable keep. TE has the lowest baseline, which makes
elite TE VORP look enormous — that is real, but you can only start one.

## Present it like this

Lead with the recommendation — the names and a one-line reason each. Then the table
so they can see alternatives. Then the closest call: who just missed, and what
would have to be true for them to be right instead. Do not bury the answer under
methodology.

## Keeper cost for players you never drafted

This is where most marginal mistakes come from, and the default — last round plus
one — is usually too generous.

**Sleeper** exposes a transaction log, so the script reconstructs the real cost: a
pickup inherits the draft round of the player he replaced, tracing weeks 0–18 of
the drafted season, oldest move first, following chains when the replaced player
was himself a pickup. On a real roster this turned a quarterback who looked like
the best keeper available at an assumed 16th-round cost into a negative-value keep,
once the log showed he had replaced an 8th-round pick.

**ESPN** does not expose the same drop-for-add detail, so undrafted players fall
back to the default and are flagged `!`. Ask the user what their league charges and
pass `--undrafted-cost`.

Two ambiguities to raise rather than silently resolve:

- If the replaced player was himself acquired free, does cost chain back to *his*
  original round (what the script does, since the round follows the player) or
  reset to the last round (if the league prices the roster slot)?
- Leagues differ on whether a traded-for player carries his original round, and on
  whether he is keepable at all.

## How player values are sourced

League structure comes from the user's platform. Player *value* always comes from
Sleeper's public endpoints — free, unauthenticated, and carrying both current ADP
and current-season projections — because ESPN has no equivalent open ADP feed.

ESPN players are joined to that data **by normalized name**, not by id: Sleeper's
`espn_id` field is null for most recent players, including nearly every rookie.
Normalization lowercases, strips punctuation, and drops generational suffixes, so
ESPN's "Kyle Pitts Sr." matches Sleeper's "Kyle Pitts", with a last-name +
first-initial fallback for nicknames. Measured 99.4% on a full 10-team league.
Anything unmatched is listed explicitly rather than dropped silently.

Auction values are **derived**, not published: every roster spot costs at least $1
and the rest of the league's money is split in proportion to points above
replacement. Treat them as a consistent yardstick, not a market quote.

## Edge cases

- **Escalating cost** — use `--escalate` / `--escalate-pct`. Say that you applied it.
- **Auction leagues** — detected automatically; costs and values are dollars, and
  NET is dollar surplus.
- **Pre-draft empty rosters** — Sleeper falls back to last season's final roster,
  which is the correct keeper pool anyway, and says so.
- **Players who changed teams** show current team but last season's stats came with
  the old one. Role may not carry over — flag it.
- **Free agents** (no NFL team) are flagged. Do not recommend keeping one.
- **Two-round-minimum / no-consecutive-year rules** are not modeled. If the user
  mentions one, adjust by hand and say so.
