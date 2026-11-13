# MovieDB — notes for Claude

Static site (`index.html`) that loads `res/films.js` with a `<script>` tag. Data pipeline is described in `docs/DATA.md`.

## Rules
- IMDb is used **only** for rating + votes (`res/data/title.ratings.tsv.gz`). Every other field comes from TMDB.
- Never print, log or commit the TMDB API key. It lives in `scripts/tmdb_key.txt` (git-ignored); scripts read it from there or from `$env:TMDB_API_KEY`.
- Do not commit `res/data/` or `res/posters/` (git-ignored).
- `index.html` must keep working from `file://` (no server), from `http://localhost` (scripts/xem_phim.bat) and from GitHub Pages. Do not load data with `fetch()`, because browsers block it on `file://`. On `file://`, the trailer popup embeds https://nguyenpqp.github.io/movie-db/player.html, because YouTube rejects embeds from `file://` (Error 153).

- The repo https://github.com/nguyenpqp/movie-db is **public**. GitHub Pages serves `main` / root at https://nguyenpqp.github.io/movie-db/. Every push to `main` goes live.
- Before each commit, verify no key is staged: `git grep --cached -n -I -E "[0-9a-f]{32}"` must return nothing.
- To add new films, run `scripts\cap_nhat.bat`, then commit and push `res/films.js`.
