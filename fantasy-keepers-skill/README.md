# fantasy-keepers

A Claude Code skill that tells you **which players to keep** in a fantasy football
keeper league — on **Sleeper** or **ESPN**, snake or auction.

It reads your league, finds last year's draft to work out what each keeper *costs*,
pulls this year's ADP and projections to work out what each player is *worth*, and
ranks the difference.

Free public APIs. No keys. Read-only — it never touches your league.

## The idea

Keeping your two best players is usually wrong. If you drafted a stud in round 1
and he still goes in round 1, keeping him buys you nothing.

But "cheap" isn't the same as "valuable" either. A QB costing a 16th-round pick
looks like a steal until you notice the QB12 on waivers scores nearly the same. So
the ranking metric is net value:

```
VORP = projected points − last startable player at that position
NET  = VORP − the VORP the forfeited pick would have bought      (snake)
NET  = derived auction value − keeper price                      (auction)
```

A keeper only wins if he beats what that same pick, or that same money, buys.

## Example

```
PeachTree Fillups  —  2026 keepers
SLEEPER · 12-team · ppr · 15-round snake · keep 2

PLAYER                POS    COST  WORTH  SURPLUS   PROJ   VORP    NET
----------------------------------------------------------------------
*Quinshon Judkins     RB       R8     R5       +3    196  +35.8  +16.8
    · injury status: Questionable
*Kyle Pitts           TE      R13     R6       +7    172   +9.1   +4.1
    · bell-cow role (87% of snaps)
 Caleb Williams       QB       R8     R6       +2    299   +3.6  -15.4
    ~ not drafted — inherits R8: replaced Kyler Murray
    · bell-cow role (99% of snaps)
 Jalen Hurts          QB       R3     R6       -3    311  +14.8  -51.8
```

Hurts is the highest-projected player on that roster and a terrible keeper — you'd
burn a 3rd-round pick to gain ~15 points over a waiver QB. Caleb Williams looks
like a bargain until you see he cost an 8th-round pick, not a 16th.

## Install

```bash
git clone https://github.com/JonTelep/skills
ln -s "$PWD/skills/fantasy-keepers-skill/skills/fantasy-keepers" \
      ~/.claude/skills/fantasy-keepers
```

Then just ask Claude Code: *"who should I keep this year?"*

## Usage

```bash
# Sleeper — all you need is your username
python3 scripts/keepers.py --platform sleeper --username <name>

# ESPN public league — id is the number in your league URL
python3 scripts/keepers.py --platform espn --league-id <id> --season 2026 --team "My Team"

# ESPN private league — cookies from a logged-in espn.com session
python3 scripts/keepers.py --platform espn --league-id <id> --season 2026 \
    --team "My Team" --espn-s2 "$ESPN_S2" --swid "$SWID"
```

If you're in multiple leagues, or haven't named your ESPN team, it prints the
options.

| Flag | Purpose |
|---|---|
| `--keepers N` | Override the league's keeper count |
| `--escalate N` | Cost rises each year held: N rounds earlier, or +$N |
| `--escalate-pct N` | Auction: keeper price rises N% |
| `--undrafted-cost N` | Cost for a player who was never drafted |
| `--scoring` | Force ppr / half_ppr / std |
| `--json` | Machine-readable, including replacement levels |

## What it handles

- **Sleeper and ESPN**, snake and auction, PPR / half / standard
- **Scoring and lineup slots read from your league** — VORP baselines come from your
  actual starting positions, so a QB is valued differently in 1-QB and superflex
- **Escalating keeper costs**, in rounds or dollars
- **Real cost for waiver pickups** (Sleeper): traces the transaction log to find who
  each pickup replaced and inherits that draft round, following chains
- **Regression flags** from last season's actuals — TD rate vs. positional baseline,
  snap share, red-zone role, games missed, RB age cliff

## Where the data comes from

League structure comes from your platform. Player *value* always comes from
Sleeper's public endpoints, which are free, unauthenticated, and carry both current
ADP and current-season projections — ESPN has no equivalent open ADP feed.

| Source | Supplies |
|---|---|
| `api.sleeper.app/v1/league/*` | League, rosters, scoring, lineup slots |
| `api.sleeper.app/v1/draft/{id}/picks` | Keeper cost — the round each player went |
| `api.sleeper.app/v1/league/{id}/transactions/{week}` | Real cost for undrafted pickups |
| `api.sleeper.app/v1/stats/nfl/regular/{year}` | Last season: snaps, targets, RZ looks, TD rate |
| `api.sleeper.app/projections/nfl/{year}` | Current ADP + projections |
| `lm-api-reads.fantasy.espn.com/apis/v3/games/ffl` | ESPN league, roster, draft, settings |

ESPN players are joined to Sleeper's data **by normalized name**, not by id —
Sleeper's `espn_id` is null for most recent players, including nearly every rookie.
Suffixes are stripped so ESPN's "Kyle Pitts Sr." matches "Kyle Pitts", with a
last-name + first-initial fallback for nicknames. Measured 99.4% across a full
10-team league; anything unmatched is listed rather than silently dropped.

## Caveats, honestly

- **ESPN's fantasy API is undocumented and unofficial.** It works, it needs no key,
  and it can change without notice. Sleeper's is documented and stable.
- **ESPN can't price waiver pickups properly.** It doesn't expose which player each
  pickup replaced, so they fall back to a default cost and are flagged. Use
  `--undrafted-cost` if your league charges something specific.
- **Auction values are derived, not published.** Every roster spot costs $1 and the
  rest of the money is split proportional to points above replacement. A consistent
  yardstick, not a market quote.
- **Projections are projections.** This tells you which keeper is better *priced*,
  not who will score the most.
- Two-round-minimum and no-consecutive-year rules aren't modeled.

## License

MIT.
