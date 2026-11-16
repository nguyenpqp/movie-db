"""Build res/films.js (the data index.html loads) from the TMDB data in res/data.

Usage (from the repo root):  python scripts/build_data.py

Inputs
  res/data/phim_<year>.json      TMDB records saved by scripts/lay_du_lieu.ps1
  res/data/phim_vn_<year>.json   Vietnamese-language films, same format plus VN release dates
  res/data/title.ratings.tsv.gz  official IMDb ratings dataset (rating + votes only)
  res/exclusions.json            films excluded by hand, with a reason
  res/extra_films.json           films TMDB discovery missed, added by hand (TMDB data)
Output
  res/films.js                   window.FILMS = {built, keep, drop}; a script, so index.html also works from file://
"""
import datetime
import gzip
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "res"
DATA = RES / "data"
THIS_YEAR = datetime.date.today().year
YEARS = range(2016, THIS_YEAR + 1)
TODAY = datetime.date.today().isoformat()
VN_MIN_VOTES = 20

PROVIDERS = [("Netflix", "Netflix"), ("Apple TV+", "Apple TV"), ("Prime Video", "Amazon Prime Video"),
             ("Disney+", "Disney Plus"), ("Hulu", "Hulu"), ("Paramount+", "Paramount")]
GENRE_REASON = {"Horror": "Horror", "Documentary": "Documentary / concert", "TV Movie": "TV movie"}


def as_list(v):
    if v is None:
        return []
    if isinstance(v, (str, dict)):
        return [v]
    return [x for x in v if x]


def provider(m):
    for label, key in PROVIDERS:
        if any(p.startswith(key) for p in as_list(m.get("prov"))):
            return label
    return None


def load_json(p, default):
    return json.loads(p.read_text(encoding="utf-8-sig")) if p.exists() else default


def main():
    ratings = {}
    with gzip.open(DATA / "title.ratings.tsv.gz", "rt", encoding="utf-8") as f:
        next(f)
        for line in f:
            tid, r, n = line.rstrip("\n").split("\t")
            ratings[tid] = (float(r), int(n))

    films = {}
    for y in YEARS:
        for name in (f"phim_{y}.json", f"phim_vn_{y}.json"):
            for m in as_list(load_json(DATA / name, [])):
                old = films.get(m["id"])
                # older cached records have no "vn" dates; never let one replace a record that has them
                if not old or "vn" in m or "vn" not in old:
                    films[m["id"]] = m

    manual = load_json(RES / "exclusions.json", {}).get("exclude", {})
    keep, drop = [], []

    for m in films.values():
        us = as_list(m.get("us"))
        primary_year = int(m["date"][:4]) if m.get("date") else None
        # US theatrical dates (limited=2, wide=3), ignoring re-releases of older films
        theatrical = sorted(u["d"][:10] for u in us if u["t"] in (2, 3)
                            and (primary_year is None or int(u["d"][:4]) >= primary_year - 1))
        if m.get("lang") == "vi":
            vn = [u for u in as_list(m.get("vn"))
                  if primary_year is None or int(u["d"][:4]) >= primary_year - 1]
            # TMDB often lacks typed VN dates: fall back to the premiere date, then the primary release date
            vn_dates = (sorted(u["d"][:10] for u in vn if u["t"] in (2, 3))
                        or sorted(u["d"][:10] for u in vn if u["t"] == 1)
                        or ([m["date"]] if m.get("date") and not vn else []))
            if not vn_dates:
                continue
            kind, date = "Vietnam", vn_dates[0]
        elif theatrical:
            kind, date = "Theatrical", theatrical[0]
            # limited run + digital within 21 days on a streamer = streaming original
            wide = [u for u in us if u["t"] == 3]
            digital = sorted(u["d"][:10] for u in us if u["t"] == 4)
            pv = provider(m)
            if not wide and digital and pv:
                d0, d4 = datetime.date.fromisoformat(date), datetime.date.fromisoformat(digital[0])
                if abs((d4 - d0).days) <= 21:
                    kind = pv
        elif primary_year and provider(m):
            kind, date = provider(m), m["date"]
        else:
            continue
        year = int(date[:4])
        if year not in YEARS:
            continue

        rating, votes = ratings.get(m.get("imdb") or "", (None, 0))
        chinese = m.get("lang") in ("zh", "cn")
        if kind == "Theatrical":
            threshold = 500 if chinese else (2000 if year == THIS_YEAR else 5000)
            upcoming_buzz = date >= f"{THIS_YEAR}-10-01" and (m.get("pop") or 0) >= 7
            ok = upcoming_buzz or votes >= threshold
        elif kind == "Vietnam":
            ok = votes >= VN_MIN_VOTES
        else:
            ok = votes >= 10000
        if not ok:
            continue

        genres = as_list(m.get("genres"))
        reason = manual.get(f"{m['title']} ({year})") or manual.get(m["title"])
        if not reason:
            reason = next((GENRE_REASON[g] for g in genres if g in GENRE_REASON), None)
        if not reason and kind == "Vietnam" and 0 < (m.get("runtime") or 0) < 40:
            reason = "Re-release / short / TV special"

        directors = as_list(m.get("directors"))
        score = round(m["score"] * 10) if m.get("score") else None
        imdb, trailer, poster = (m.get(k) or "" for k in ("imdb", "trailer", "poster"))
        rec = dict(
            y=year, id=imdb if re.fullmatch(r"tt\d+", imdb) else f"t{int(m['id'])}", tm=int(m["id"]), t=m["title"], date=date, src=kind,
            g=genres[:3], r=rating, nv=votes, ts=score or None, d=m.get("overview") or "",
            c=", ".join(as_list(m.get("cast"))[:3]),
            dr=", ".join(directors[:3]) + (" et al." if len(directors) > 3 else ""),
            rt=m.get("runtime") or None, yt=trailer if re.fullmatch(r"[\w-]{11}", trailer) else "",
            p=poster if re.fullmatch(r"/[\w.-]+", poster) else "", why=reason,
        )
        (drop if reason else keep).append(rec)

    for e in load_json(RES / "extra_films.json", []):
        e = dict(e)
        e["r"], e["nv"] = ratings.get(e["id"], (None, 0))
        (drop if e.get("why") else keep).append(e)

    out = {"built": TODAY, "keep": keep, "drop": drop}
    js = "window.FILMS=" + json.dumps(out, ensure_ascii=False, separators=(",", ":")) + ";\n"
    (RES / "films.js").write_text(js, encoding="utf-8")
    print(f"kept {len(keep)}, excluded {len(drop)} -> res/films.js")


if __name__ == "__main__":
    main()
