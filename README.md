# MovieDB — International Films from 2020

A browsable catalogue of films released in North American theaters (plus standout standalone streaming films) from 2020 to the current year, filtered to titles with international appeal. Horror, documentaries and US-domestic genres are excluded.

**Live site:** https://nguyenpqp.github.io/movie-db/

Each film card shows the title, release date, runtime, genres, IMDb rating and votes, TMDB score, director, main cast and description. It also has a trailer that plays in the page and a poster. You can filter by year, release type (theatrical or streaming platform), genre and text search, sort by several fields, and switch to the **Excluded** list to see dropped films with the reason. The page shows 100 films at a time.

## Data sources

| What | Source |
|---|---|
| IMDb rating, IMDb votes | [IMDb Non-Commercial Datasets](https://developer.imdb.com/non-commercial-datasets/) (`title.ratings.tsv.gz`) |
| Everything else: film list, US release dates, release type, genres, runtime, description, director, cast, poster, trailer, TMDB score | [TMDB](https://www.themoviedb.org) |

This product uses the TMDB API but is not endorsed or certified by TMDB.

## Repository layout

```
index.html            the site; loads res/films.js
player.html           trailer player that index.html embeds when opened as a file
res/
  films.js            the dataset the page reads (built by scripts/build_data.py)
  exclusions.json     films excluded by hand, with reasons
  extra_films.json    films TMDB discovery missed, added by hand (TMDB data)
  data/               raw TMDB downloads + IMDb ratings      (local only, git-ignored)
  posters/            downloaded posters for offline viewing (local only, git-ignored)
scripts/
  cap_nhat.bat/.ps1      update: re-download last year and this year, then rebuild
  lay_du_lieu.bat/.ps1   download TMDB data + IMDb ratings into res/data
  build_data.py          apply the selection rules -> res/films.js
  tai_poster.bat/.ps1    download posters into res/posters
  xem_phim.bat/.ps1      serve the folder at http://localhost:8765 and open the site
docs/
  DATA.md             selection rules, fields, and how to update the data
```

## Quick start (Windows)

1. Put your TMDB API key (v3) in `scripts\tmdb_key.txt`. It's one line and is git-ignored.
2. `scripts\lay_du_lieu.bat` downloads the data. The default range is 2020 to the current year; for other years, run e.g. `lay_du_lieu.bat 2018 2019`.
3. `python scripts\build_data.py` rebuilds `res\films.js`.
4. Optionally, `scripts\tai_poster.bat` downloads posters for offline use.
5. Open `index.html` in a browser. No web server is needed.

YouTube refuses to play trailers embedded in a `file://` page (Error 153). So when you open `index.html` as a file, the trailer popup loads `player.html` from the GitHub Pages site, and that page embeds the trailer. This needs an internet connection and the deployed site. `scripts\xem_phim.bat` (http://localhost:8765) also works.

To add new films later, run `scripts\cap_nhat.bat`, then commit and push the new `res/films.js`. GitHub Pages redeploys automatically.

See [docs/DATA.md](docs/DATA.md) for the selection rules and the data format.
