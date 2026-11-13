# MovieDB — notes for Claude

Static site (`index.html`) that loads `res/films.js` with a `<script>` tag. Data pipeline is described in `docs/DATA.md`.

## Rules
- IMDb is used **only** for rating + votes (`res/data/title.ratings.tsv.gz`). Every other field comes from TMDB.
- Never print, log or commit the TMDB API key. It lives in `scripts/tmdb_key.txt` (git-ignored); scripts read it from there or from `$env:TMDB_API_KEY`.
- Do not commit `res/data/` or `res/posters/` (git-ignored).
- `index.html` must keep working from `file://` (no server), from `http://localhost` (scripts/xem_phim.bat) and from GitHub Pages. Do not load data with `fetch()`, because browsers block it on `file://`. On `file://`, the trailer popup embeds https://nguyenpqp.github.io/movie-db/player.html, because YouTube rejects embeds from `file://` (Error 153).

## Open tasks (handoff, 2026-11-13)
1. Refresh TMDB data so directors and TMDB score come straight from the API:
   delete `res\data\cache` and `res\data\phim_*.json`, then run `scripts\lay_du_lieu.bat` (2020–2026).
   The new script saves `directors` and `score` per film; `build_data.py` prefers those over `res/tmdb_web.json`.
   After that, `res/tmdb_web.json` can be deleted.
2. `python scripts\build_data.py` → `res/films.json`. Expect roughly 1,821 kept / 597 excluded.
   Check the page via `scripts\xem_phim.bat` (filters, paging, trailers, posters).
3. `scripts\tai_poster.bat` for local posters (optional).
4. Git: `git init -b main`, add remote `https://github.com/nguyenpqp/movie-db` (empty, private), commit, push.
   Before committing, verify no key is staged: `git grep -n -I -E "[0-9a-f]{32}"` must return nothing.
5. The user chose: make the repo **public** and enable **GitHub Pages** from `main` / root.
   Site URL: https://nguyenpqp.github.io/movie-db/
