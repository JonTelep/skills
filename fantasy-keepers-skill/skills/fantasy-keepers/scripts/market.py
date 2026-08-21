"""Player market data and valuation.

League structure comes from whichever platform the user plays on (Sleeper,
ESPN). Player *value* always comes from Sleeper's public endpoints, which are
free, unauthenticated, and carry both current ADP and current-season
projections. ESPN players are joined to that data by normalized name, because
Sleeper's `espn_id` field is null for most recent players.
"""

import json
import math
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.sleeper.app"
CACHE = os.path.expanduser("~/.cache/fantasy-keepers")
UA = "fantasy-keepers-skill/2.0"
POSITIONS = ("QB", "RB", "WR", "TE", "K", "DEF")


def http_json(url, cache_key=None, ttl=86400, headers=None):
    path = os.path.join(CACHE, cache_key) if cache_key else None
    if path and os.path.exists(path) and time.time() - os.path.getmtime(path) < ttl:
        with open(path) as fh:
            return json.load(fh)

    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            raise Auth(f"{exc.code} on {url}")
        if exc.code == 404:
            return None
        raise Fail(f"HTTP {exc.code} on {url}")
    except urllib.error.URLError as exc:
        raise Fail(f"could not reach {urllib.parse.urlparse(url).netloc} ({exc.reason})")

    if path:
        os.makedirs(CACHE, exist_ok=True)
        with open(path, "w") as fh:
            json.dump(data, fh)
    return data


class Fail(Exception):
    """Unrecoverable, with a message meant for the user."""


class Auth(Fail):
    """Credentials needed or rejected."""


# ---------------------------------------------------------------- name matching

SUFFIXES = {"jr", "sr", "ii", "iii", "iv", "v"}


def normalize(name):
    """ESPN says 'Kyle Pitts Sr.', Sleeper says 'Kyle Pitts'. Strip to a
    comparable core: lowercase, letters only, no generational suffix."""
    words = re.sub(r"[^a-z ]", "", (name or "").lower()).split()
    while words and words[-1] in SUFFIXES:
        words.pop()
    return "".join(words)


class PlayerBook:
    """Sleeper's player universe, indexed for fuzzy cross-platform lookup."""

    def __init__(self):
        self.players = http_json(f"{API}/v1/players/nfl", cache_key="players.json")
        self.by_name = {}
        self.by_last = {}
        for pid, meta in self.players.items():
            pos = meta.get("position")
            if pos not in POSITIONS:
                continue
            full = normalize(meta.get("full_name"))
            if full:
                self.by_name.setdefault((full, pos), pid)
            last = normalize(meta.get("last_name"))
            first = normalize(meta.get("first_name"))
            if last and first:
                self.by_last.setdefault((last, first[0], pos), pid)

    def find(self, name, pos, team=None):
        """Exact normalized name first, then last name + first initial, which
        rescues nicknames ('Kenneth' vs 'Ken')."""
        n = normalize(name)
        hit = self.by_name.get((n, pos))
        if hit:
            return hit
        parts = re.sub(r"[^a-z ]", "", (name or "").lower()).split()
        while parts and parts[-1] in SUFFIXES:
            parts.pop()
        if len(parts) >= 2:
            hit = self.by_last.get((normalize(parts[-1]), parts[0][0], pos))
            if hit:
                return hit
        return None

    def meta(self, pid):
        return self.players.get(pid) or {}


# ---------------------------------------------------------------- market

class Market:
    """Current ADP + projections, and last season's actuals."""

    def __init__(self, season, scoring):
        self.season = str(season)
        self.prior = str(int(season) - 1)
        self.scoring = scoring

        positions = "".join(f"&position[]={p}" for p in POSITIONS)
        rows = http_json(
            f"{API}/projections/nfl/{self.season}?season_type=regular{positions}"
            f"&order_by=adp_{scoring}",
            cache_key=f"adp-{self.season}-{scoring}.json", ttl=21600) or []

        self.proj = {}
        self.pool = []
        for r in rows:
            pid = r.get("player_id")
            st = r.get("stats") or {}
            if not pid:
                continue
            self.proj[pid] = st
            pos = (r.get("player") or {}).get("position")
            adp = st.get(f"adp_{scoring}")
            pts = st.get(f"pts_{scoring}")
            if pos in POSITIONS and pts:
                self.pool.append({"pid": pid, "pos": pos, "pts": pts,
                                  "adp": adp if adp and adp < 999 else None})

        self.actuals = http_json(f"{API}/v1/stats/nfl/regular/{self.prior}",
                                 cache_key=f"stats-{self.prior}.json") or {}
        self.baseline = {}

    # -- replacement level -------------------------------------------------

    def set_baselines(self, slots, teams):
        """Points of the last startable player at each position. This is what
        makes a QB10 in a 1-QB league worth almost nothing while the same player
        in superflex is a cornerstone."""
        flex = sum(n for k, n in slots.items() if "FLEX" in k.upper() or k == "OP")
        superflex = slots.get("SUPER_FLEX", 0) + slots.get("OP", 0)
        need = {
            "QB": (slots.get("QB", 1) + superflex) * teams,
            "RB": slots.get("RB", 2) * teams + round(flex * teams * 0.5),
            "WR": slots.get("WR", 2) * teams + round(flex * teams * 0.5),
            "TE": slots.get("TE", 1) * teams,
            "K": slots.get("K", 1) * teams,
            "DEF": slots.get("DEF", 1) * teams,
        }
        for pos, n in need.items():
            pts = sorted((x["pts"] for x in self.pool if x["pos"] == pos), reverse=True)
            self.baseline[pos] = pts[min(max(n, 1), len(pts)) - 1] if pts else 0.0
        return self.baseline

    def vorp(self, pid):
        st = self.proj.get(pid) or {}
        pts = st.get(f"pts_{self.scoring}")
        pos = None
        for x in self.pool:
            if x["pid"] == pid:
                pos = x["pos"]
                break
        if pts is None or pos is None or pos not in self.baseline:
            return None
        return pts - self.baseline[pos]

    def points(self, pid):
        return (self.proj.get(pid) or {}).get(f"pts_{self.scoring}")

    def adp(self, pid):
        a = (self.proj.get(pid) or {}).get(f"adp_{self.scoring}")
        return a if a and a < 999 else None

    # -- snake: what a forfeited pick buys ---------------------------------

    def best_available_at(self, round_no, teams):
        """Highest VORP realistically on the board at the pick you give up.
        Keeping only wins if the player beats this."""
        pick = (round_no - 1) * teams + teams / 2
        best = 0.0
        for x in self.pool:
            if x["adp"] and pick - teams / 2 <= x["adp"] <= pick + teams * 1.5:
                best = max(best, x["pts"] - self.baseline.get(x["pos"], 0.0))
        return best

    # -- auction: convert projections to dollars ---------------------------

    def auction_values(self, teams, budget, roster_size):
        """Standard VORP-proportional allocation: every roster spot costs at
        least $1, and the remaining money is split in proportion to points above
        replacement. Sleeper publishes no auction values, so we derive them."""
        spots = teams * roster_size
        ranked = sorted(self.pool, key=lambda x: -x["pts"])[:spots]
        surplus = {x["pid"]: max(0.0, x["pts"] - self.baseline.get(x["pos"], 0.0))
                   for x in ranked}
        total = sum(surplus.values())
        free = teams * budget - spots
        if total <= 0 or free <= 0:
            return {pid: 1.0 for pid in surplus}
        return {pid: round(1.0 + s * free / total, 1) for pid, s in surplus.items()}


# ---------------------------------------------------------------- last-season signal

TD_BASELINE = {"WR": 0.055, "TE": 0.055, "RB": 0.043}


def read_flags(stat, meta, scoring):
    """Role and regression warnings from last season's actuals. Fantasy points
    say what happened; these say whether it will happen again."""
    flags = []
    pos = meta.get("position")

    off, tm = stat.get("off_snp"), stat.get("tm_off_snp")
    share = off / tm if off and tm else None

    if pos in ("WR", "TE"):
        opp, tds = stat.get("rec_tgt") or 0, stat.get("rec_td") or 0
    elif pos == "RB":
        opp = (stat.get("rush_att") or 0) + (stat.get("rec_tgt") or 0)
        tds = (stat.get("rush_td") or 0) + (stat.get("rec_td") or 0)
    else:
        opp = tds = 0
    rate = tds / opp if opp >= 40 else None
    base = TD_BASELINE.get(pos)

    if rate and base:
        if rate > base * 1.6:
            flags.append(f"TD-lucky ({rate*100:.1f}%/opp vs {base*100:.1f}% baseline) "
                         "— expect regression")
        elif rate < base * 0.5:
            flags.append(f"TD-unlucky ({rate*100:.1f}%/opp vs {base*100:.1f}% baseline) "
                         "— expect positive regression")
    if share is not None:
        if share >= 0.75:
            flags.append(f"bell-cow role ({share*100:.0f}% of snaps)")
        elif share < 0.45 and (stat.get(f"pts_{scoring}") or 0) > 100:
            flags.append(f"low snap share ({share*100:.0f}%) — production not backed by role")

    gp = stat.get("gp")
    if gp is not None and gp <= 12:
        flags.append(f"missed time ({int(gp)} games) — per-game rate matters more than total")
    age = meta.get("age")
    if age and pos == "RB" and age >= 28:
        flags.append(f"age {age} RB — cliff risk")
    if meta.get("injury_status"):
        flags.append(f"injury status: {meta['injury_status']}")
    if not meta.get("team"):
        flags.append("currently a free agent — no NFL team")
    return flags, share, rate
