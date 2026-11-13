# Update the site with new films: re-download last year and this year from TMDB, refresh IMDb ratings, rebuild res\films.js
$ErrorActionPreference = "Stop"
$y = (Get-Date).Year
& (Join-Path $PSScriptRoot "lay_du_lieu.ps1") -FromYear ($y - 1) -ToYear $y -Refresh
if ($LASTEXITCODE) { exit $LASTEXITCODE }
python (Join-Path $PSScriptRoot "build_data.py")
if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host "Next: commit and push res/films.js to publish."
