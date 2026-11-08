# Local factory release entry point: dry-run unless explicitly -Live and approved.
param([switch]$Live)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$approval = Join-Path $root 'APPROVED-GITHUB-REPO.txt'
if (!$Live) { & (Join-Path $root 'go-live.ps1') -DryRun; exit $LASTEXITCODE }
if (!(Test-Path -LiteralPath $approval) -or (Get-Content -LiteralPath $approval -Raw).Trim() -ne 'evenpagedigital/evenpage-ios') {
 throw 'Live release needs successful go-live approval in the project folder.'
}
& (Join-Path $root 'go-live.ps1')
exit $LASTEXITCODE
