# Runs the headless smoke tests.
#   tools/check.ps1 -Import                  re-import assets (run after adding audio or fonts)
#   tools/check.ps1 -All                     phases 1-7
#   tools/check.ps1 res://tests/phase4_smoke.tscn
# Fails when a test fails or when Godot prints a script error, even if Godot
# itself exits with 0. Saves and settings go to .runtime/, not your real ones.
param([string]$Scene = 'res://tests/phase4_smoke.tscn', [switch]$Import, [switch]$All)
$root = Split-Path -Parent $PSScriptRoot
$engine = $env:GODOT
if (-not $engine) {
    $found = Get-Command 'Godot_v4*_console.exe', 'godot' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) { Write-Error 'Godot not found. Put it on PATH or set $env:GODOT to the console executable.'; exit 2 }
    $engine = $found.Source
}
$env:APPDATA = Join-Path $root '.runtime'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$failed = $false
$runs = if ($Import) { @('--import') } elseif ($All) { 1..7 | ForEach-Object { "res://tests/phase$($_)_smoke.tscn" } } else { @($Scene) }
foreach ($run in $runs) {
    $lines = & $engine --headless --path $root $run 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $lines | Write-Output
    # Godot cannot read the Windows certificate store when sandboxed. No test uses the network.
    $errors = $lines | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:|Parse Error|  FAIL|SMOKE: FAIL' -and $_ -notmatch 'root certificate store' }
    if ($code -ne 0 -or $errors) { $failed = $true; Write-Output "FAILED: $run (exit code $code)" }
}
if ($failed) { exit 1 }
Write-Output 'ALL OK'
exit 0
