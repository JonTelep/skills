#!/usr/bin/env python3
"""
Fantasy football keeper analyzer for Sleeper and ESPN.

Ranks keeper candidates by what they are worth minus what they cost, using free
public APIs. Read-only: it never writes to your league.

    python3 keepers.py --platform sleeper --username <name>
    python3 keepers.py --platform espn --league-id <id> --season 2026 --team "My Team"
"""

import argparse
import json
import math
import os
import sys

# Runnable from any working directory, however the skill is invoked.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from market import Fail, Market, PlayerBook, read_flags
from providers import espn_league, sleeper_league


def parse_args(argv):
    p = argparse.ArgumentParser(
        prog="keepers.py",
        description="Rank fantasy football keepers by surplus value (Sleeper + ESPN).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  Sleeper:  keepers.py --platform sleeper --username fillup00
  ESPN:     keepers.py --platform espn --league-id 1241838 --season 2026 --team 3
  Private:  ... --espn-s2 "$ESPN_S2" --swid "$SWID"
""")
    p.add_argument("--platform", choices=("sleeper", "espn"), default="sleeper")
    p.add_argument("--username", help="Sleeper username")
    p.add_argument("--league-id", help="League id (required for ESPN)")
    p.add_argument("--season", help="Season you are drafting (default: current)")
    p.add_argument("--team", help="ESPN team id, name, abbrev, or owner")
    p.add_argument("--espn-s2", help="espn_s2 cookie (private ESPN leagues)")
    p.add_argument("--swid", help="SWID cookie (private ESPN leagues)")
    p.add_argument("--keepers", type=int, help="How many you may keep (default: league setting)")
    p.add_argument("--escalate", type=float, default=0,
                   help="Cost escalation per year held: rounds earlier (snake) "
                        "or dollars added (auction)")
    p.add_argument("--escalate-pct", type=float, default=0,
                   help="Auction only: percent added to the keeper price")
    p.add_argument("--undrafted-cost", type=float,
                   help="Cost for a player who was never drafted "
                        "(default: last round + 1, or $1)")
    p.add_argument("--no-inherit", action="store_true",
                   help="Sleeper: do not trace who each pickup replaced")
    p.add_argument("--scoring", choices=("ppr", "half_ppr", "std"),
                   help="Override the detected scoring format")
    p.add_argument("--json", action="store_true", help="Machine-readable output")
    return p.parse_args(argv)


def effective_cost(raw, league, args):
    """Apply the league's escalation rule to the raw draft cost."""
    if league.auction:
        c = raw * (1 + args.escalate_pct / 100.0) + args.escalate
        return round(max(1.0, c), 1)
    return int(max(1, round(raw - args.escalate)))


def analyze(league, args):
    market = Market(league.season, args.scoring or league.scoring)
    market.set_baselines(league.slots, league.teams)
    book = PlayerBook()

    values = (market.auction_values(league.teams, league.budget or 200, league.roster_size)
              if league.auction else {})

    rows, unmatched = [], []
    for entry in league.roster:
        pid = entry.get("sleeper_id") or book.find(entry["name"], entry["pos"], entry.get("team"))
        if not pid:
            unmatched.append(f"{entry['name']} ({entry['pos']})")
            continue

        meta = book.meta(pid)
        stat = market.actuals.get(pid) or {}
        flags, share, td = read_flags(stat, meta, market.scoring)

        cost = effective_cost(entry["cost"], league, args)
        proj = market.points(pid)
        vorp = market.vorp(pid)
        adp = market.adp(pid)

        if league.auction:
            worth = values.get(pid, 1.0)
            surplus = round(worth - cost, 1)
            net = surplus
        else:
            worth = math.ceil(adp / league.teams) if adp else None
            surplus = (cost - worth) if worth else None
            net = (round(vorp - market.best_available_at(cost, league.teams), 1)
                   if vorp is not None else None)

        rows.append({
            "name": meta.get("full_name") or entry["name"] or pid,
            "pos": entry["pos"], "team": meta.get("team"),
            "cost": cost, "raw_cost": entry["cost"],
            "cost_basis": entry["cost_basis"], "cost_note": entry["cost_note"],
            "worth": worth, "surplus": surplus, "net": net,
            "adp": adp, "proj": proj, "vorp": round(vorp, 1) if vorp is not None else None,
            "last_points": stat.get(f"pts_{market.scoring}"),
            "games": stat.get("gp"), "snap_share": round(share, 3) if share else None,
            "flags": flags,
        })

    rows.sort(key=lambda r: (r["net"] is None, -(r["net"] if r["net"] is not None else 0)))
    return rows, unmatched, market


def render(league, rows, unmatched, market, args):
    keep = args.keepers or league.keeper_slots or 2
    money = league.auction

    print(f"\n{league.name}  —  {league.season} keepers")
    print(f"{league.platform.upper()} · {league.teams}-team · {market.scoring} · "
          f"{'auction ($%s)' % league.budget if money else '%s-round snake' % league.rounds}"
          f" · keep {keep}")
    if args.escalate or args.escalate_pct:
        print(f"Escalation applied: "
              f"{('+$%g' % args.escalate) if money else ('%g rounds earlier' % args.escalate)}"
              f"{' and +%g%%' % args.escalate_pct if args.escalate_pct else ''}")
    print()

    unit = "$" if money else "R"
    hdr = (f"{'PLAYER':<22}{'POS':<5}{'COST':>6}{'WORTH':>7}{'SURPLUS':>9}"
           f"{'PROJ':>7}{'VORP':>7}" + ("" if money else f"{'NET':>7}"))
    print(hdr)
    print("-" * len(hdr))

    def cell(v, prefix=""):
        if v is None:
            return "-"
        return f"{prefix}{v:g}" if not isinstance(v, float) else f"{prefix}{v:.0f}"

    for i, r in enumerate(rows):
        r["name"] = r["name"] or "?"
        star = "*" if i < keep and (r["net"] or 0) > 0 else " "
        print(f"{star}{r['name'][:20]:<21}{r['pos']:<5}"
              f"{unit + format(r['cost'], 'g'):>6}"
              f"{(unit + format(r['worth'], 'g')) if r['worth'] is not None else '-':>7}"
              f"{('%+g' % r['surplus']) if r['surplus'] is not None else '-':>9}"
              f"{cell(r['proj']):>7}{('%+g' % r['vorp']) if r['vorp'] is not None else '-':>7}"
              + ("" if money else f"{('%+g' % r['net']) if r['net'] is not None else '-':>7}"))
        if r["cost_basis"] == "inherited":
            print(f"    ~ not drafted — inherits {unit}{r['raw_cost']:g}: {r['cost_note']}")
        elif r["cost_basis"] == "trade":
            print(f"    ~ acquired by trade — {r['cost_note']}; note that leagues "
                  "differ on whether traded players are keepable")
        elif r["cost_basis"] == "assumed":
            print(f"    ! not drafted — cost {unit}{r['raw_cost']:g} is an assumption"
                  f"{'; ' + r['cost_note'] if r['cost_note'] else ''}")
        for f in r["flags"]:
            print(f"    · {f}")

    print(f"\n* = top {keep} by net value. "
          + ("Auction surplus is derived value minus keeper price."
             if money else "NET = points over replacement, minus what the forfeited pick buys."))
    if unmatched:
        print(f"\nNot matched to player data ({len(unmatched)}): {', '.join(unmatched)}")
    for n in league.notes:
        print(f"\nNote: {n}")


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    try:
        if args.platform == "espn":
            if not args.league_id:
                raise Fail("ESPN needs --league-id (the number in your league URL).")
            league = espn_league(args.league_id, args.season, args.team,
                                 args.espn_s2, args.swid, args.undrafted_cost)
        else:
            if not args.username and not args.league_id:
                raise Fail("Sleeper needs --username or --league-id.")
            league = sleeper_league(args.username, args.league_id, args.season,
                                    args.undrafted_cost, not args.no_inherit)

        rows, unmatched, market = analyze(league, args)
        if not rows:
            raise Fail("No roster players could be valued. "
                       "Check the season and team are right.")
        if args.json:
            print(json.dumps({
                "league": {"platform": league.platform, "name": league.name,
                           "season": league.season, "teams": league.teams,
                           "scoring": market.scoring, "draft_type": league.draft_type,
                           "rounds": league.rounds, "budget": league.budget,
                           "keeper_slots": args.keepers or league.keeper_slots,
                           "slots": league.slots,
                           "replacement_level": {k: round(v, 1)
                                                 for k, v in market.baseline.items()}},
                "candidates": rows, "unmatched": unmatched, "notes": league.notes},
                indent=2))
        else:
            render(league, rows, unmatched, market, args)
    except Fail as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
