param([string]$Scene, [string]$Res = '1920x1080', [string]$Extra = '', [int]$Seconds = 90)
# Runs a windowed Godot scene with a time limit, so a script error cannot hang the caller.
$root = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $root '.runtime'
$engine = (Get-Command 'Godot_v4*_console.exe', 'godot' -ErrorAction SilentlyContinue | Select-Object -First 1).Source
$out = Join-Path $env:TEMP 'godot_run_out.txt'; $err = Join-Path $env:TEMP 'godot_run_err.txt'
$args = "--path `"$root`" --resolution $Res $Scene"
if ($Extra) { $args += " -- $Extra" }
$p = Start-Process -FilePath $engine -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
if (-not $p.WaitForExit($Seconds * 1000)) { $p.Kill(); 'TIMED OUT' }
Get-Content $out, $err | Where-Object { $_ -notmatch 'certificate|get_system_ca|^$|Godot Engine|Vulkan' } | Select-Object -Last 20
