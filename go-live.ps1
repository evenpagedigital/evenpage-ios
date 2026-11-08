# Local factory tooling. Only Ben runs the live path after reviewing the public allowlist.
[CmdletBinding()]
param([switch]$DryRun, [ValidateRange(1,120)][int]$TimeoutMinutes = 30)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'evenpagedigital/evenpage-ios'
$remote = "https://github.com/$repo.git"
$sourceUrl = "https://raw.githubusercontent.com/$repo/main/source/apps.json"
$allow = @(
 'package.json','capacitor.config.json','www/index.html',
 '.github/workflows/ios-unsigned.yml',
 'scripts/check_ipa.py','scripts/validate_source.py','scripts/ios_health.py',
 'scripts/ios_release.ps1','scripts/make_source.py','go-live.ps1',
 'README.md','BEN-CHECKLIST.md','SHORTCUT-RECIPE.md',
 'DASHBOARD-INTEGRATION-SPEC.md','APPROVED-GITHUB-REPO.example.txt','source/icon.png'
)
# No credential contents are read, displayed or stored here. Only status and account name.
function Invoke-GhChecked {
 param([string[]]$Arguments)
 $result = @(& gh @Arguments)
 if ($LASTEXITCODE -ne 0) { throw "GitHub command failed ($($Arguments[0])); stopped. No automatic retry." }
 return $result
}
function Invoke-GitChecked {
 param([string[]]$Arguments)
 # Ask the installed CLI's sanctioned credential helper; never extract a token.
 $result = @(& git -c credential.helper= -c 'credential.helper=!gh auth git-credential' @Arguments)
 if ($LASTEXITCODE -ne 0) { throw "Git command failed ($($Arguments[0])); stopped. No force-push or reset." }
 return $result
}
function Assert-SafeFiles {
 foreach ($file in $allow) {
  $path = Join-Path $root $file
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required allowlist file missing: $file" }
  $item = Get-Item -LiteralPath $path
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing linked file: $file" }
  $item = $item.Directory
  while ($item) {
   if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing linked file/directory: $file" }
   if ($item.FullName -eq $root) { break }
   $item = $item.Parent
  }
  if ($file -eq 'source/icon.png') { continue }
  $text = [IO.File]::ReadAllText((Join-Path $root $file))
  # Report filenames only, never matching values. Also rejects credential-bearing URLs.
  $patterns = @(
   '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
   '(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})',
   'AKIA[0-9A-Z]{16}', 'sk-(?:proj-)?[A-Za-z0-9_-]{20,}',
   'https?://[^\s/]+:[^\s/@]+@',
   '(?im)^\s*(?:api[_-]?key|password|client[_-]?secret|access[_-]?token)\s*[:=]\s*["\x27]?[A-Za-z0-9_/-]{12,}'
  )
  foreach ($pattern in $patterns) {
   if ($text -match $pattern) { throw "Secret scan requires review: $file (value suppressed)" }
  }
 }
}
$approvalCheck = Join-Path $root 'APPROVED-GITHUB-REPO.txt'
if ((Test-Path -LiteralPath $approvalCheck) -and ([IO.File]::ReadAllText($approvalCheck)).Trim() -ne $repo) {
 throw 'Approval file names another repo; stopped without changing it.'
}
Assert-SafeFiles
Write-Host 'Allowlist and secret scan: PASS. Public files:'
$allow | ForEach-Object { Write-Host "  $_" }
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
 Write-Host 'STOP: gh is missing. Install GitHub.cli and reopen PowerShell. No changes made.'
 exit 2
}
# Capture status: some CLI versions include masked token details; do not print it.
$oldPreference = $ErrorActionPreference
try { $ErrorActionPreference = 'Continue'; $status = @(& gh auth status --hostname github.com 2>&1); $authCode = $LASTEXITCODE }
finally { $ErrorActionPreference = $oldPreference }
if ($authCode -ne 0) { throw 'GitHub CLI is not signed in. Run gh auth login. No changes made.' }
$login = ((Invoke-GhChecked -Arguments @('api','user','--jq','.login')) -join '').Trim()
if ($login -cne 'evenpagedigital' -or (($status -join "`n") -notmatch '\bevenpagedigital\b')) {
 throw 'Wrong active GitHub account. Expected evenpagedigital. No changes made.'
}
if (Test-Path -LiteralPath (Join-Path $root '.git')) {
 if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Existing local repo needs Git to verify origin; stopped without changing it.' }
 $existing = (Invoke-GitChecked -Arguments @('-C',$root,'remote','get-url','origin')) -join ''
 if ($existing.TrimEnd('/') -notin @($remote,$remote.Replace('.git',''),'git@github.com:evenpagedigital/evenpage-ios.git')) {
  throw 'Existing project origin differs from the intended repo; no configuration was changed.'
 }
}
if ($DryRun) {
 Write-Host 'DRY RUN: preflight passed; zero writes, repo creation, fetches, pushes or workflow dispatches.'
 Write-Host "LIVE PLAN: use an isolated allowlisted publication folder; create PUBLIC $repo only if absent; update main via Git Data API without force; record approval; dispatch and wait up to $TimeoutMinutes minutes."
 Write-Host $sourceUrl
 exit 0
}
# The following path is deliberately not exercised during preparation.
# A read-only API request distinguishes a genuinely absent repo (404) from an auth/network failure.
$oldPreference = $ErrorActionPreference
try { $ErrorActionPreference = 'Continue'; $view = @(& gh api "repos/$repo" 2>&1); $viewCode = $LASTEXITCODE }
finally { $ErrorActionPreference = $oldPreference }
if ($viewCode -ne 0) {
 if (($view -join "`n") -notmatch 'HTTP 404') { throw 'Repository lookup failed; refusing to assume it is absent.' }
 Invoke-GhChecked -Arguments @('repo','create',$repo,'--public','--description','Factory iOS SideStore build pipeline') | Out-Null
}
$info = ((Invoke-GhChecked -Arguments @('api',"repos/$repo")) -join "`n") | ConvertFrom-Json
if ($info.private -or $info.fork -or $info.archived) { throw 'Target must be a public, non-fork, writable repo; stopped to protect $0 policy.' }
if ($info.size -gt 0 -and $info.default_branch -ne 'main') { throw 'Existing default branch is not main; manual review required.' }
# Use only GitHub CLI + Git Data API: Git for Windows is not required for a new project.
# No local repository is initialized or reconfigured. Requests contain only allowlisted source.
$stage = Join-Path $root ('.publish-work\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
function ApiWrite {
 param([string]$Endpoint, [string]$Method, [object]$Body)
 $request = Join-Path $stage ([guid]::NewGuid().ToString('N') + '.json')
 [IO.File]::WriteAllText($request, ($Body | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
 return (((Invoke-GhChecked -Arguments @('api',$Endpoint,'--method',$Method,'--input',$request)) -join "`n") | ConvertFrom-Json)
}
$branchText = (Invoke-GhChecked -Arguments @('api',"repos/$repo/branches")) -join "`n"
$branches = ConvertFrom-Json -InputObject $branchText
if (@($branches).Count -eq 0) {
 # Git Data API cannot create blobs in a completely empty repo. Initialize using one allowlisted file.
 $readme = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root 'README.md')))
 ApiWrite -Endpoint "repos/$repo/contents/README.md" -Method PUT -Body @{message='Initialize Factory iOS';branch='main';content=$readme} | Out-Null
} elseif (@($branches | Where-Object { $_.name -eq 'main' }).Count -ne 1) {
 throw 'Existing remote has branches but no main; stopped for review.'
}
$ref = ((Invoke-GhChecked -Arguments @('api',"repos/$repo/git/ref/heads/main")) -join "`n") | ConvertFrom-Json
$parentSha = $ref.object.sha
$commit = ((Invoke-GhChecked -Arguments @('api',"repos/$repo/git/commits/$parentSha")) -join "`n") | ConvertFrom-Json
$tree = ((Invoke-GhChecked -Arguments @('api',"repos/$repo/git/trees/$($commit.tree.sha)?recursive=1")) -join "`n") | ConvertFrom-Json
if ($tree.truncated) { throw 'Remote tree is truncated; stopped for review.' }
foreach ($entry in $tree.tree) {
 if ($entry.type -eq 'tree') { continue }
 if ($entry.path -notin ($allow + @('source/apps.json')) -or $entry.mode -notin @('100644','100755')) {
  throw "Unexpected remote file or mode requires review: $($entry.path)"
 }
}
$entries = @()
foreach ($file in $allow) {
 $bytes = [IO.File]::ReadAllBytes((Join-Path $root $file))
 $blob = ApiWrite -Endpoint "repos/$repo/git/blobs" -Method POST -Body @{encoding='base64';content=[Convert]::ToBase64String($bytes)}
 $entries += @{path=$file;mode='100644';type='blob';sha=$blob.sha}
}
$newTree = ApiWrite -Endpoint "repos/$repo/git/trees" -Method POST -Body @{base_tree=$commit.tree.sha;tree=$entries}
if ($newTree.sha -ne $commit.tree.sha) {
 $newCommit = ApiWrite -Endpoint "repos/$repo/git/commits" -Method POST -Body @{message='Factory iOS pipeline';tree=$newTree.sha;parents=@($parentSha)}
 # Non-forced fast-forward only: concurrent changes cause a loud failure, never overwrite history.
 ApiWrite -Endpoint "repos/$repo/git/refs/heads/main" -Method PATCH -Body @{sha=$newCommit.sha;force=$false} | Out-Null
}
$confirmed = ((Invoke-GhChecked -Arguments @('api',"repos/$repo/git/ref/heads/main")) -join "`n") | ConvertFrom-Json
$expected = $parentSha
if ($newTree.sha -ne $commit.tree.sha) { $expected = $newCommit.sha }
if ($confirmed.object.sha -ne $expected) { throw 'Main moved concurrently; stopped before approval or dispatch.' }
# Approval is local-only, in this project, and is written ONLY after push succeeds.
$approval = Join-Path $root 'APPROVED-GITHUB-REPO.txt'
if (Test-Path -LiteralPath $approval) {
 if (([IO.File]::ReadAllText($approval)).Trim() -ne $repo) { throw 'Approval file names another repo; left untouched.' }
} else { [IO.File]::WriteAllText($approval, "$repo`n", (New-Object Text.UTF8Encoding($false))) }
$marker = 'go-live-' + [guid]::NewGuid().ToString('N')
# run-name includes this unique marker; never wait on somebody else's run.
Invoke-GhChecked -Arguments @('workflow','run','ios-unsigned.yml','--repo',$repo,'--ref','main','-f',"notes=$marker") | Out-Null
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$runId = $null
while ((Get-Date) -lt $deadline) {
 if (!$runId) {
  $runs = ((Invoke-GhChecked -Arguments @('run','list','--repo',$repo,'--workflow','ios-unsigned.yml','--branch','main','--event','workflow_dispatch','--limit','50','--json','databaseId,displayTitle')) -join "`n") | ConvertFrom-Json
  $matches = @($runs | Where-Object { $_.displayTitle -eq "Factory iOS - $marker" })
  if ($matches.Count -gt 1) { throw 'Ambiguous workflow run; stopped.' }
  if ($matches.Count -eq 1) { $runId = $matches[0].databaseId }
 }
 if ($runId) {
  $run = ((Invoke-GhChecked -Arguments @('run','view',"$runId",'--repo',$repo,'--json','status,conclusion,url')) -join "`n") | ConvertFrom-Json
  if ($run.status -eq 'completed') {
   if ($run.conclusion -ne 'success') { throw "BUILD FAILED: $($run.conclusion). $($run.url)" }
   Write-Host "BUILD SUCCESS: $($run.url)"
   Write-Host "SideStore source: $sourceUrl"
   exit 0
  }
 }
 Start-Sleep -Seconds 10
}
throw "Timed out after $TimeoutMinutes minutes. Check Actions on GitHub; no automatic redispatch. Run ID: $runId"
