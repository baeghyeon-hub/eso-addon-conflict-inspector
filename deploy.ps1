# deploy.ps1 — sync ZZZ_AddOnInspector from repo to ESO live AddOns folder.
#
# Usage (from repo root):
#   .\deploy.ps1
#
# Mirrors the dev copy over the live copy with robocopy /MIR. Files in the
# live folder that no longer exist in dev are removed, so stale files from
# a previous build can never leak into the game.
#
# After running, fully QUIT ESO (not /reloadui — it does not reload Lua)
# and relaunch to pick up the new code.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $repoRoot "ZZZ_AddOnInspector"
$dst = Join-Path $env:USERPROFILE "Documents\Elder Scrolls Online\live\AddOns\ZZZ_AddOnInspector"

if (-not (Test-Path $src)) {
    Write-Host "ERROR: source not found: $src" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Split-Path $dst))) {
    Write-Host "ERROR: ESO AddOns folder not found: $(Split-Path $dst)" -ForegroundColor Red
    Write-Host "Is ESO installed for this user?"
    exit 1
}

Write-Host "Source: $src"
Write-Host "Target: $dst"
Write-Host ""

robocopy $src $dst /MIR /NFL /NDL /NP /NJH /NJS | Out-Null
$rc = $LASTEXITCODE

# robocopy exit codes: 0 = no change, 1 = copied OK, 2 = extra files removed,
# 3 = copied + extras. Anything >= 8 is a real error.
if ($rc -ge 8) {
    Write-Host "ERROR: robocopy failed with exit code $rc" -ForegroundColor Red
    exit $rc
}

Write-Host "Deployed. File listing:" -ForegroundColor Green
Get-ChildItem $dst | Select-Object Name, LastWriteTime, Length | Format-Table -AutoSize

Write-Host ""
Write-Host "REMINDER: /reloadui does not reload Lua. Fully quit ESO and relaunch." -ForegroundColor Yellow
