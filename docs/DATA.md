# Data: selection rules, fields and updating

## Pipeline

```
lay_du_lieu.ps1  ──►  res/data/phim_<year>.json  (TMDB)
                      res/data/title.ratings.tsv.gz  (IMDb)
                              │
build_data.py  ◄── res/exclusions.json, res/extra_films.json
      │
      ▼
res/films.js  ──►  index.html (<script src>, so file:// works)
```

### 1. Candidates (`lay_du_lieu.ps1`)

For each year, TMDB `/discover/movie` is queried for:

- **US theatrical:** `region=US`, `with_release_type=2|3` (limited or wide) and ≥ 30 TMDB votes, up to 25 pages.
- **Chinese-language films in US theaters:** the same filter with `with_original_language=zh` and no TMDB vote minimum, up to 5 pages.
- **Streaming films:** `watch_region=US` on Netflix, Apple TV+, Prime Video, Disney+, Hulu and Paramount+ (flatrate), premiering that year, ≥ 100 TMDB votes, up to 15 pages.
- **Upcoming:** current year only, US theatrical releases from today to Dec 31, sorted by popularity.

Each candidate's details (`/movie/{id}` with release dates, credits, videos and watch providers) are cached in `res/data/cache/{id}.json`. Delete a cache file to re-download that film.

### 2. Classification (`build_data.py`)

- **Theatrical:** has a US limited or wide release date. Re-releases are ignored: dates earlier than the film's primary year − 1 don't count. The first such date becomes the release date and decides the year.
  - A film with only a limited release, plus a digital release within 21 days on one of the streamers above, is counted as a **streaming original** (e.g. *Netflix*).
- **Streaming:** no US theatrical date, but available on one of the streamers above.
- Anything else is dropped.

### 3. Thresholds (IMDb votes)

| Type | Minimum IMDb votes |
|---|---|
| Theatrical | 5,000 |
| Theatrical, current year | 2,000 |
| Theatrical, Chinese-language | 500 |
| Theatrical, releasing from Oct 1 of the current year | none if TMDB popularity ≥ 7 (shown as *Upcoming*) |
| Streaming | 10,000 |

### 4. Exclusions (shown in the *Excluded* list with a reason)

- **Automatic, by TMDB genre:** Horror, Documentary (incl. concert films), TV Movie.
- **By hand** (`res/exclusions.json`, matched by title):
  - Faith-based
  - US sports (American football, baseball, basketball)
  - US politics
  - Concert, stand-up and stage recordings
  - Re-releases, shorts and TV specials

To exclude or restore a film, edit `res/exclusions.json` and rebuild. TMDB tags some international hits as Horror (e.g. *Godzilla Minus One*, *Meg 2*). To keep one of those, add special handling in `build_data.py`.

## Field reference (`res/films.js`)

`window.FILMS = { "built": "YYYY-MM-DD", "keep": [film…], "drop": [film…] };`

| Field | Meaning | Source |
|---|---|---|
| `y` | year (from the US release date) | TMDB |
| `id` | IMDb id (`tt…`), or `t<tmdbid>` if none | TMDB |
| `tm` | TMDB id | TMDB |
| `t` | title | TMDB |
| `date` | US release date (theatrical) or premiere date (streaming) | TMDB |
| `src` | `Theatrical` or the streaming platform | TMDB |
| `g` | up to 3 genres | TMDB |
| `r`, `nv` | IMDb rating, IMDb votes | IMDb dataset |
| `ts` | TMDB user score (%) | TMDB |
| `d` | description (TMDB overview, English) | TMDB |
| `dr` | director(s), max 3 then "et al." | TMDB |
| `c` | top 3 cast | TMDB |
| `rt` | runtime in minutes | TMDB |
| `yt` | YouTube trailer key | TMDB |
| `p` | poster path (`https://image.tmdb.org/t/p/w342` + `p`) | TMDB |
| `why` | exclusion reason (only in `drop`) | rules above |

## Updating

1. `scripts\cap_nhat.bat`. It re-downloads the film list and film details for last year and this year, downloads new IMDb ratings, and rebuilds `res/films.js`. Older years keep their saved data. A new year is picked up automatically.
2. Optionally, `scripts\tai_poster.bat`.
3. Commit `res/films.js` (and any changed `res/*.json`) and push.

`scripts\lay_du_lieu.bat` skips years already downloaded. Add `-Refresh` to re-download them, e.g. `lay_du_lieu.bat 2024 2024 -Refresh`. Then run `python scripts\build_data.py`.

## Notes and limitations

- For streaming films, the platform is the one the film is on in the US now, which may not be where it premiered.
- Posters and trailers on the hosted site load from TMDB and YouTube. Locally, posters in `res/posters` are used when present.
