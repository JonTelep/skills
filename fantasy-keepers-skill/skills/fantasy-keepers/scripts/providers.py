"""League adapters. Each returns the same League shape so the valuation code
never needs to know which platform the user plays on."""

from market import API, Auth, Fail, http_json

ESPN = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl"


class League:
    def __init__(self, **kw):
        self.platform = kw["platform"]
        self.name = kw["name"]
        self.season = str(kw["season"])
        self.teams = kw["teams"]
        self.scoring = kw["scoring"]            # ppr | half_ppr | std
        self.slots = kw["slots"]                # starting lineup, by position
        self.roster_size = kw["roster_size"]
        self.draft_type = kw["draft_type"]      # snake | auction
        self.rounds = kw.get("rounds")
        self.budget = kw.get("budget")
        self.keeper_slots = kw.get("keeper_slots")
        self.roster = kw["roster"]              # [{name,pos,team,cost,cost_basis,cost_note}]
        self.notes = kw.get("notes", [])

    @property
    def auction(self):
        return self.draft_type == "auction"


def _fmt(rec_points):
    if rec_points is None:
        return "half_ppr"
    if rec_points >= 0.75:
        return "ppr"
    if rec_points >= 0.25:
        return "half_ppr"
    return "std"


# ===================================================================== SLEEPER

SLEEPER_SKIP = {"BN", "IR", "TAXI"}


def sleeper_league(username=None, league_id=None, season=None, undrafted_cost=None,
                   inherit=True):
    state = http_json(f"{API}/v1/state/nfl")
    season = str(season or state["league_season"])

    if league_id:
        lg = http_json(f"{API}/v1/league/{league_id}")
        if not lg:
            raise Fail(f"No Sleeper league with id {league_id}.")
    else:
        user = http_json(f"{API}/v1/user/{username}")
        if not user:
            raise Fail(f"No Sleeper user named '{username}'.")
        leagues = http_json(f"{API}/v1/user/{user['user_id']}/leagues/nfl/{season}") or []
        if not leagues:
            raise Fail(f"'{username}' has no NFL leagues in {season}. "
                       "Try --season with the year that was actually drafted.")
        if len(leagues) > 1:
            listing = "\n".join(f"  {x['league_id']}  {x['name']}"
                                f"  (keepers: {(x.get('settings') or {}).get('max_keepers', '?')})"
                                for x in leagues)
            raise Fail(f"'{username}' is in {len(leagues)} leagues. Pick one with "
                       f"--league-id:\n{listing}")
        lg = leagues[0]

    lid = lg["league_id"]
    teams = lg.get("total_rosters") or 12
    users = http_json(f"{API}/v1/league/{lid}/users") or []
    rosters = http_json(f"{API}/v1/league/{lid}/rosters") or []

    owner_id = None
    if username:
        for u in users:
            if (u.get("display_name") or "").lower() == username.lower():
                owner_id = u["user_id"]
    if owner_id is None and len(rosters) == 1:
        owner_id = rosters[0].get("owner_id")
    mine = next((r for r in rosters if r.get("owner_id") == owner_id), None)
    if mine is None:
        names = "\n".join(f"  {u.get('display_name')}" for u in users)
        raise Fail(f"Could not find your team in '{lg['name']}'. Pass --username "
                   f"matching one of:\n{names}")

    # Pre-draft leagues often have empty rosters. The keeper pool is last
    # season's final roster anyway, so fall back to it.
    roster_ids = mine.get("players") or []
    roster_source = "current"
    if not roster_ids and lg.get("previous_league_id"):
        prev_rosters = http_json(f"{API}/v1/league/{lg['previous_league_id']}/rosters") or []
        prev_mine = next((r for r in prev_rosters if r.get("owner_id") == owner_id), None)
        if prev_mine:
            roster_ids = prev_mine.get("players") or []
            roster_source = "prior season (this year's roster is still empty)"
    if not roster_ids:
        raise Fail(f"Your roster in '{lg['name']}' is empty and no prior-season roster "
                   "was found — nothing to evaluate yet.")

    picks, draft = _sleeper_draft(lg)
    if not picks:
        raise Fail(f"No completed draft found for '{lg['name']}' or its prior season. "
                   "Keeper cost needs the draft that was actually held.")
    dsettings = (draft or {}).get("settings") or {}
    rounds = dsettings.get("rounds") or 15
    auction = (draft or {}).get("type") == "auction" or bool(dsettings.get("budget"))
    default_cost = undrafted_cost or (rounds + 1)

    cost, bid = {}, {}
    for p in picks:
        pid = p.get("player_id")
        if pid and pid not in cost:
            cost[pid] = p.get("round")
            amount = (p.get("metadata") or {}).get("amount")
            if amount:
                bid[pid] = float(amount)

    inherited = {}
    notes = []
    prev = lg.get("previous_league_id")
    if inherit and prev and owner_id and not auction:
        prev_rosters = http_json(f"{API}/v1/league/{prev}/rosters") or []
        prev_mine = next((r for r in prev_rosters if r.get("owner_id") == owner_id), None)
        if prev_mine:
            inherited = _sleeper_inherit(prev, prev_mine["roster_id"], cost, default_cost)

    players = http_json(f"{API}/v1/players/nfl", cache_key="players.json")
    roster = []
    if roster_source != "current":
        notes.append(f"Roster taken from {roster_source}.")
    for pid in roster_ids:
        meta = players.get(pid) or {}
        pos = meta.get("position")
        if pos not in ("QB", "RB", "WR", "TE", "K", "DEF"):
            continue
        basis, note = "drafted", None
        c = bid.get(pid) if auction else cost.get(pid)
        if c is None:
            if pid in inherited:
                c, basis, note = inherited[pid]
                note = _name_ids(note, players)
            else:
                c, basis = (1.0 if auction else default_cost), "assumed"
        roster.append({"sleeper_id": pid, "name": _display(meta, pid), "pos": pos,
                       "team": meta.get("team"), "cost": c, "cost_basis": basis,
                       "cost_note": note})

    slots = {}
    for s in lg.get("roster_positions") or []:
        if s not in SLEEPER_SKIP:
            slots[s] = slots.get(s, 0) + 1

    return League(platform="sleeper", name=lg.get("name"), season=season, teams=teams,
                  scoring=_fmt((lg.get("scoring_settings") or {}).get("rec")),
                  slots=slots, roster_size=len(lg.get("roster_positions") or []) or 15,
                  draft_type="auction" if auction else "snake", rounds=rounds,
                  budget=dsettings.get("budget"),
                  keeper_slots=(lg.get("settings") or {}).get("max_keepers"),
                  roster=roster, notes=notes)


def _display(meta, fallback):
    """Team defenses carry no full_name, only a player_id like 'WAS'."""
    name = meta.get("full_name") or " ".join(
        x for x in (meta.get("first_name"), meta.get("last_name")) if x).strip()
    return name or fallback


def _sleeper_draft(league):
    for lid in [league.get("previous_league_id"), league["league_id"]]:
        if not lid:
            continue
        for d in http_json(f"{API}/v1/league/{lid}/drafts") or []:
            if d.get("status") == "complete":
                picks = http_json(f"{API}/v1/draft/{d['draft_id']}/picks") or []
                if picks:
                    return picks, d
    return [], None


def _sleeper_inherit(league_id, roster_id, drafted_cost, default_cost):
    """A pickup inherits the draft round of whoever he replaced. Chains follow;
    trades do not (a traded-for player keeps his own round)."""
    moves = []
    for week in range(0, 19):
        for tx in http_json(f"{API}/v1/league/{league_id}/transactions/{week}") or []:
            if tx.get("status") != "complete" or roster_id not in (tx.get("roster_ids") or []):
                continue
            adds = [p for p, r in (tx.get("adds") or {}).items() if r == roster_id]
            drops = [p for p, r in (tx.get("drops") or {}).items() if r == roster_id]
            if adds:
                moves.append({"w": week, "c": tx.get("created") or 0,
                              "type": tx.get("type"), "adds": adds, "drops": drops})
    moves.sort(key=lambda m: (m["w"], m["c"]))

    out = {}
    for m in moves:
        for i, pid in enumerate(m["adds"]):
            if m["type"] == "trade":
                if pid not in drafted_cost:
                    out[pid] = (default_cost, "trade", "he was never drafted, so his cost is a default")
                continue
            if not m["drops"]:
                out[pid] = (default_cost, "assumed", "added without dropping anyone")
                continue
            src = m["drops"][i] if i < len(m["drops"]) else m["drops"][0]
            if src in drafted_cost:
                out[pid] = (drafted_cost[src], "inherited", ("replaced {}", src))
            elif src in out:
                out[pid] = (out[src][0], "inherited",
                            ("replaced {} (who was himself a pickup)", src))
            else:
                out[pid] = (default_cost, "assumed",
                            ("replaced {}, whose own cost is unknown", src))
    return out


def _name_ids(note, players):
    """Notes carry (template, player_id) so exactly one id is resolved. Scanning
    the text for any known id would corrupt names, since short ids appear inside
    longer ones."""
    if not note:
        return None
    if isinstance(note, str):
        return note
    template, pid = note
    return template.format(_display(players.get(pid) or {}, pid))


# ======================================================================== ESPN

ESPN_POS = {1: "QB", 2: "RB", 3: "WR", 4: "TE", 5: "K", 16: "DEF"}
# Lineup slots. 20=bench, 21=IR, 24=ER are not starting spots.
ESPN_SLOT = {0: "QB", 2: "RB", 3: "RB_WR", 4: "WR", 5: "WR_TE", 6: "TE",
             7: "SUPER_FLEX", 16: "DEF", 17: "K", 23: "FLEX"}
ESPN_BENCH = {20, 21, 24}
STAT_RECEPTION = 53


def espn_league(league_id, season=None, team=None, espn_s2=None, swid=None,
                undrafted_cost=None):
    """ESPN keeps one league id across seasons and selects the year in the URL,
    so last season's draft and final roster come from season - 1."""
    if not season:
        raise Fail("ESPN needs --season (the year you are drafting).")
    season = int(season)
    prior = season - 1

    headers = {}
    if espn_s2 and swid:
        swid = swid if swid.startswith("{") else "{%s}" % swid
        headers["Cookie"] = f"espn_s2={espn_s2}; SWID={swid}"

    def fetch(view, year):
        url = f"{ESPN}/seasons/{year}/segments/0/leagues/{league_id}?view={view}"
        try:
            return http_json(url, headers=headers)
        except Auth:
            raise Auth("ESPN rejected the request. Private leagues need --espn-s2 "
                       "and --swid cookies from a logged-in espn.com session.")

    settings_doc = fetch("mSettings", prior)
    if settings_doc is None:
        raise Fail(
            f"ESPN returned nothing for league {league_id} in {prior}. Either the id "
            "is wrong, or the league is private — pass --espn-s2 and --swid.")
    s = settings_doc.get("settings") or {}
    draft_cfg = s.get("draftSettings") or {}
    roster_cfg = s.get("rosterSettings") or {}
    teams_n = s.get("size") or 10

    rec = next((i.get("points") for i in (s.get("scoringSettings") or {}).get("scoringItems", [])
                if i.get("statId") == STAT_RECEPTION), None)

    slots, roster_size = {}, 0
    for sid, count in (roster_cfg.get("lineupSlotCounts") or {}).items():
        if not count:
            continue
        roster_size += count
        if int(sid) in ESPN_BENCH:
            continue
        key = ESPN_SLOT.get(int(sid))
        if key:
            slots[key] = slots.get(key, 0) + count

    auction = str(draft_cfg.get("type", "")).upper() == "AUCTION"
    budget = draft_cfg.get("auctionBudget")
    rounds = roster_size

    # -- identify the user's team
    team_doc = fetch("mTeam", prior) or {}
    members = {m.get("id"): m.get("displayName") for m in team_doc.get("members") or []}
    teams = team_doc.get("teams") or []
    picked = _espn_pick_team(teams, members, team)

    # -- draft cost
    draft_doc = fetch("mDraftDetail", prior) or {}
    picks = (draft_doc.get("draftDetail") or {}).get("picks") or []
    if not picks:
        raise Fail(f"ESPN has no draft on record for league {league_id} in {prior}.")
    cost = {}
    for p in picks:
        pid = p.get("playerId")
        if pid is None or pid in cost:
            continue
        cost[pid] = float(p.get("bidAmount") or 0) if auction else p.get("roundId")

    # -- roster
    roster_doc = fetch("mRoster", prior) or {}
    entry_team = next((t for t in roster_doc.get("teams") or []
                       if t.get("id") == picked["id"]), None)
    if not entry_team:
        raise Fail(f"No roster returned for team id {picked['id']}.")

    default_cost = undrafted_cost or (1.0 if auction else rounds + 1)
    roster, notes = [], []
    for e in (entry_team.get("roster") or {}).get("entries") or []:
        p = (e.get("playerPoolEntry") or {}).get("player") or {}
        pos = ESPN_POS.get(p.get("defaultPositionId"))
        if not pos:
            continue
        pid = e.get("playerId")
        c, basis, note = cost.get(pid), "drafted", None
        if c is None:
            c, basis = default_cost, "assumed"
            note = f"acquired by {(e.get('acquisitionType') or 'unknown').lower()}"
        roster.append({"espn_id": pid, "name": p.get("fullName"), "pos": pos,
                       "team": None, "cost": c, "cost_basis": basis, "cost_note": note})

    if any(r["cost_basis"] == "assumed" for r in roster):
        notes.append("ESPN does not expose which player each pickup replaced, so "
                     "undrafted players fall back to the default cost. Override with "
                     "--undrafted-cost if your league prices them differently.")

    return League(platform="espn", name=s.get("name") or f"ESPN league {league_id}",
                  season=str(season), teams=teams_n, scoring=_fmt(rec), slots=slots,
                  roster_size=roster_size or 16,
                  draft_type="auction" if auction else "snake",
                  rounds=rounds, budget=budget,
                  keeper_slots=draft_cfg.get("keeperCount"),
                  roster=roster, notes=notes)


def _espn_pick_team(teams, members, wanted):
    if not teams:
        raise Fail("ESPN returned no teams for this league.")
    if wanted:
        w = str(wanted).strip().lower()
        for t in teams:
            owners = [str(members.get(o, "")).lower() for o in (t.get("owners") or [])]
            if w in {str(t.get("id")), str(t.get("abbrev", "")).lower(),
                     str(t.get("name", "")).strip().lower(), *owners}:
                return t
        listing = "\n".join(
            f"  id={t['id']:<3} {t.get('name') or t.get('abbrev')}"
            f"  (owner: {', '.join(members.get(o, '?') for o in t.get('owners') or []) or '?'})"
            for t in teams)
        raise Fail(f"No ESPN team matched '{wanted}'. Teams in this league:\n{listing}")
    if len(teams) == 1:
        return teams[0]
    listing = "\n".join(
        f"  id={t['id']:<3} {t.get('name') or t.get('abbrev')}"
        f"  (owner: {', '.join(members.get(o, '?') for o in t.get('owners') or []) or '?'})"
        for t in teams)
    raise Fail(f"Which team is yours? Pass --team with an id, name, or owner:\n{listing}")
