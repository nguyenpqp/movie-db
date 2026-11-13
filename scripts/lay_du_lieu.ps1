# ==========================================================
#  Fetch film data from TMDB (+ official IMDb ratings dataset)
#  Usage: put your TMDB API key in scripts\tmdb_key.txt (one line, never committed)
#         then double-click lay_du_lieu.bat
#  Optional: lay_du_lieu.bat 2020 2022   (year range; default 2020 to this year; add -Refresh to re-download saved years)
# ==========================================================
param([int]$FromYear = 2020, [int]$ToYear = (Get-Date).Year, [switch]$Refresh)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location -Path $PSScriptRoot

$ApiKey = $env:TMDB_API_KEY
if (-not $ApiKey -and (Test-Path "tmdb_key.txt")) { $ApiKey = (Get-Content "tmdb_key.txt" -Raw).Trim() }
if (-not $ApiKey) { Write-Host "Missing TMDB API key: create scripts\tmdb_key.txt with your key."; exit 1 }

$data = Join-Path $PSScriptRoot "..\res\data"
$cacheDir = Join-Path $data "cache"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$base = "https://api.themoviedb.org/3"
function Get-Tmdb($path, $query) {
  $url = "$base$path`?api_key=$ApiKey&$query"
  for ($i = 0; $i -lt 4; $i++) {
    try { return Invoke-RestMethod -Uri $url -TimeoutSec 30 }
    catch { Start-Sleep -Seconds (2 * ($i + 1)) }
  }
  Write-Host "  Skipped (network error): $path"
  return $null
}

function Discover($query, $maxPages) {
  $ids = @()
  for ($p = 1; $p -le $maxPages; $p++) {
    $r = Get-Tmdb "/discover/movie" "$query&page=$p"
    if ($r -eq $null -or $r.results.Count -eq 0) { break }
    $ids += $r.results | ForEach-Object { $_.id }
    if ($p -ge $r.total_pages) { break }
  }
  return $ids
}

$providers = "8|350|9|119|337|15|531"   # Netflix, Apple TV+, Prime Video, Disney+, Hulu, Paramount+
$today = (Get-Date).ToString("yyyy-MM-dd")

for ($y = $FromYear; $y -le $ToYear; $y++) {
  $out = Join-Path $data "phim_$y.json"
  if ((Test-Path $out) -and -not $Refresh) { Write-Host "Year $y already downloaded, skipping."; continue }
  Write-Host "=== $y ==="
  $range = "release_date.gte=$y-01-01&release_date.lte=$y-12-31"
  $ids  = @()
  # 1) US theatrical (limited + wide)
  $ids += Discover "region=US&with_release_type=2|3&$range&vote_count.gte=30&sort_by=vote_count.desc&include_adult=false" 25
  # 2) Chinese-language films released in US theaters (lower threshold)
  $ids += Discover "region=US&with_release_type=2|3&$range&with_original_language=zh&sort_by=vote_count.desc&include_adult=false" 5
  # 3) Streaming films premiering this year
  $ids += Discover "watch_region=US&with_watch_providers=$providers&with_watch_monetization_types=flatrate&primary_release_date.gte=$y-01-01&primary_release_date.lte=$y-12-31&vote_count.gte=100&sort_by=vote_count.desc&include_adult=false" 15
  # 4) Upcoming releases (current year only)
  if ($y -eq (Get-Date).Year) {
    $ids += Discover "region=US&with_release_type=2|3&release_date.gte=$today&release_date.lte=$y-12-31&sort_by=popularity.desc&include_adult=false" 3
  }
  $ids = $ids | Select-Object -Unique
  Write-Host "  $($ids.Count) candidates, fetching details..."

  $list = New-Object System.Collections.ArrayList
  $n = 0
  foreach ($id in $ids) {
    $n++
    $cache = Join-Path $cacheDir "$id.json"
    if ((Test-Path $cache) -and -not $Refresh) { $m = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json }
    else {
      $m = Get-Tmdb "/movie/$id" "language=en-US&append_to_response=release_dates,credits,videos,watch/providers"
      if ($m -eq $null) { continue }
      $us = @($m.release_dates.results | Where-Object { $_.iso_3166_1 -eq "US" } | ForEach-Object { $_.release_dates } | ForEach-Object { @{ t = $_.type; d = $_.release_date } })
      $tr = @($m.videos.results | Where-Object { $_.site -eq "YouTube" -and $_.type -eq "Trailer" } | Sort-Object -Property official -Descending)
      $prov = @()
      try { $prov = @($m.'watch/providers'.results.US.flatrate | ForEach-Object { $_.provider_name }) } catch {}
      $rec = [ordered]@{
        id = $m.id; imdb = $m.imdb_id; title = $m.title; orig = $m.original_title; lang = $m.original_language
        date = $m.release_date; genres = @($m.genres | ForEach-Object { $_.name }); overview = $m.overview
        runtime = $m.runtime; countries = @($m.production_countries | ForEach-Object { $_.iso_3166_1 })
        us = $us; cast = @($m.credits.cast | Select-Object -First 3 | ForEach-Object { $_.name })
        directors = @($m.credits.crew | Where-Object { $_.job -eq "Director" } | ForEach-Object { $_.name })
        trailer = $(if ($tr.Count -gt 0) { $tr[0].key } else { "" }); poster = $m.poster_path
        prov = $prov; votes = $m.vote_count; score = $m.vote_average; pop = $m.popularity
      }
      $m = [pscustomobject]$rec
      ($m | ConvertTo-Json -Depth 5 -Compress) | Out-File -FilePath $cache -Encoding UTF8
    }
    [void]$list.Add($m)
    if ($n % 50 -eq 0) { Write-Host "  ... $n / $($ids.Count)" }
  }
  ($list | ConvertTo-Json -Depth 5 -Compress) | Out-File -FilePath $out -Encoding UTF8
  Write-Host "  Done $y : $($list.Count) films"
}

# IMDb ratings from the official dataset (datasets.imdbws.com) - refreshed every run
Write-Host "Downloading IMDb ratings dataset..."
Invoke-WebRequest -UseBasicParsing -Uri "https://datasets.imdbws.com/title.ratings.tsv.gz" -OutFile (Join-Path $data "title.ratings.tsv.gz")
Write-Host ""
Write-Host "DONE. Tell Claude: xong"
