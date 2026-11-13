# Downloads posters for every film in res\films.js into res\posters (skips ones already there)
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$res = Join-Path $PSScriptRoot "..\res"
$dir = Join-Path $res "posters"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$js = Get-Content (Join-Path $res "films.js") -Raw -Encoding UTF8
$films = ($js -replace '^\s*window\.FILMS=', '' -replace ';\s*$', '') | ConvertFrom-Json
$ok=0; $skip=0; $fail=0
foreach ($f in @($films.keep) + @($films.drop)) {
  if (-not $f.p) { continue }
  $out = Join-Path $dir "$($f.id).jpg"
  if (Test-Path $out) { $skip++; continue }
  try { Invoke-WebRequest -UseBasicParsing -Uri "https://image.tmdb.org/t/p/w342$($f.p)" -OutFile $out; $ok++ } catch { $fail++; Write-Host "Error: $($f.id)" }
}
Write-Host "Downloaded $ok new posters, skipped $skip existing, $fail errors."
Read-Host "Press Enter to close"
