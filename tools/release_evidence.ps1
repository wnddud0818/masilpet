param(
  [string]$ProjectId = "masilpet-6ff8d",
  [string]$HostingUrl = "",
  [string]$OutputPath = "build/release-evidence.md",
  [switch]$AllowDirtyWorktree,
  [switch]$AllowDraftEvidence
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

$Checks = @()
$Failures = @()

function Add-Check {
  param(
    [string]$Name,
    [ValidateSet("PASS", "WARN", "FAIL")]
    [string]$Status,
    [string]$Detail
  )

  $script:Checks += [PSCustomObject]@{
    Name = $Name
    Status = $Status
    Detail = $Detail
  }

  if ($Status -eq "FAIL") {
    $script:Failures += "${Name}: $Detail"
  }
}

function Test-RequiredFile {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.Substring(0, 12)
    Add-Check -Name "Required file: $Path" -Status "PASS" -Detail "sha256:$Hash"
    return $true
  }

  Add-Check -Name "Required file: $Path" -Status "FAIL" -Detail "missing"
  return $false
}

function Get-JsonFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "JSON file missing: $Path"
  }
  return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Get-TextFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Text file missing: $Path"
  }
  return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

function Get-PubspecVersion {
  $Pubspec = Get-TextFile "pubspec.yaml"
  $Match = [regex]::Match($Pubspec, "(?m)^version:\s*(.+?)\s*$")
  if (-not $Match.Success) {
    Add-Check -Name "pubspec version" -Status "FAIL" -Detail "missing version field"
    return "unknown"
  }
  Add-Check -Name "pubspec version" -Status "PASS" -Detail $Match.Groups[1].Value.Trim()
  return $Match.Groups[1].Value.Trim()
}

function Assert-Condition {
  param(
    [string]$Name,
    [bool]$Condition,
    [string]$PassDetail,
    [string]$FailDetail
  )

  if ($Condition) {
    Add-Check -Name $Name -Status "PASS" -Detail $PassDetail
  } else {
    Add-Check -Name $Name -Status "FAIL" -Detail $FailDetail
  }
}

function Assert-TextContains {
  param(
    [string]$Name,
    [string]$Text,
    [string[]]$Needles
  )

  $Missing = @($Needles | Where-Object { -not $Text.Contains($_) })
  Assert-Condition `
    -Name $Name `
    -Condition ($Missing.Count -eq 0) `
    -PassDetail ("contains " + ($Needles -join ", ")) `
    -FailDetail ("missing " + ($Missing -join ", "))
}

function Format-MarkdownCell {
  param([string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  return ([string]$Value).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

function Get-CommandOutput {
  param([string[]]$Command)

  try {
    $Output = & $Command[0] @($Command | Select-Object -Skip 1) 2>$null
    if ($LASTEXITCODE -ne 0) {
      return @()
    }
    return @($Output)
  } catch {
    return @()
  }
}

function Get-HeaderValues {
  param(
    [object[]]$Headers,
    [string]$Source
  )

  $Entry = @($Headers | Where-Object { $_.source -eq $Source } | Select-Object -First 1)
  if ($Entry.Count -eq 0) {
    return @{}
  }

  $Values = @{}
  foreach ($Header in @($Entry[0].headers)) {
    $Values[[string]$Header.key] = [string]$Header.value
  }
  return $Values
}

$GeneratedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Version = Get-PubspecVersion

$RequiredFiles = @(
  "pubspec.yaml",
  "firebase.json",
  "firestore.rules",
  "firestore.indexes.json",
  "functions/package.json",
  "functions/src/index.ts",
  "functions/lib/index.js",
  "web/index.html",
  "web/manifest.json",
  "web/privacy.html",
  "web/screenshots/onboarding-wide.png",
  "build/web/index.html",
  "build/web/flutter_bootstrap.js",
  "build/web/main.dart.js",
  "build/web/manifest.json",
  "build/web/privacy.html",
  "build/web/icons/Icon-192.png",
  "build/web/icons/Icon-512.png",
  "build/web/screenshots/onboarding-wide.png"
)

foreach ($Path in $RequiredFiles) {
  Test-RequiredFile $Path | Out-Null
}

$GitCommit = (Get-CommandOutput @("git", "rev-parse", "--short", "HEAD") | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($GitCommit)) {
  $GitCommit = "unknown"
  Add-Check -Name "Git revision" -Status "WARN" -Detail "git revision unavailable"
} else {
  Add-Check -Name "Git revision" -Status "PASS" -Detail $GitCommit
}

$GitStatus = @(Get-CommandOutput @("git", "status", "--short"))
if ($GitStatus.Count -eq 0) {
  Add-Check -Name "Git worktree" -Status "PASS" -Detail "clean"
} elseif ($AllowDirtyWorktree) {
  Add-Check -Name "Git worktree" -Status "WARN" -Detail "$($GitStatus.Count) changed paths recorded"
} else {
  Add-Check -Name "Git worktree" -Status "FAIL" -Detail "$($GitStatus.Count) changed paths; pass -AllowDirtyWorktree only for local draft evidence"
}

if ([string]::IsNullOrWhiteSpace($HostingUrl)) {
  if ($AllowDraftEvidence) {
    Add-Check -Name "Hosting URL" -Status "WARN" -Detail "not provided; draft evidence only"
  } else {
    Add-Check -Name "Hosting URL" -Status "FAIL" -Detail "required for submission evidence; pass -HostingUrl after Firebase deploy or -AllowDraftEvidence for local drafts"
  }
} else {
  $ParsedHostingUrl = [Uri]$HostingUrl
  Assert-Condition `
    -Name "Hosting URL" `
    -Condition ($ParsedHostingUrl.Scheme -eq "https") `
    -PassDetail $ParsedHostingUrl.AbsoluteUri `
    -FailDetail "must use https for submission evidence"
}

if (Test-Path -LiteralPath "build/web/manifest.json") {
  $Manifest = Get-JsonFile "build/web/manifest.json"
  Assert-Condition -Name "PWA manifest name" -Condition ($Manifest.name -like "*MasilPet*") -PassDetail $Manifest.name -FailDetail "name must contain MasilPet"
  Assert-Condition -Name "PWA manifest short_name" -Condition ($Manifest.short_name -eq "MasilPet") -PassDetail $Manifest.short_name -FailDetail "short_name must be MasilPet"
  Assert-Condition -Name "PWA manifest id" -Condition ($Manifest.id -eq "/") -PassDetail $Manifest.id -FailDetail "id must be /"
  Assert-Condition -Name "PWA manifest lang" -Condition ($Manifest.lang -eq "ko-KR") -PassDetail $Manifest.lang -FailDetail "lang must be ko-KR"
  Assert-Condition -Name "PWA manifest display" -Condition ($Manifest.display -eq "standalone") -PassDetail $Manifest.display -FailDetail "display must be standalone"
  Assert-Condition -Name "PWA manifest orientation" -Condition ($Manifest.orientation -eq "any") -PassDetail $Manifest.orientation -FailDetail "orientation must allow responsive portrait and landscape use"
  Assert-Condition -Name "PWA manifest start_url" -Condition ($Manifest.start_url -eq "/") -PassDetail $Manifest.start_url -FailDetail "start_url must be /"

  $ShortcutUrls = @($Manifest.shortcuts | ForEach-Object { [string]$_.url })
  Assert-Condition -Name "PWA shortcuts" -Condition (($ShortcutUrls -contains "/#/home") -and ($ShortcutUrls -contains "/privacy.html")) -PassDetail ($ShortcutUrls -join ", ") -FailDetail "shortcuts must include /#/home and /privacy.html"

  $ScreenshotSources = @($Manifest.screenshots | ForEach-Object { [string]$_.src })
  Assert-Condition -Name "PWA screenshots" -Condition ($ScreenshotSources -contains "screenshots/onboarding-wide.png") -PassDetail ($ScreenshotSources -join ", ") -FailDetail "manifest screenshots must include onboarding-wide.png"

  $IconSources = @($Manifest.icons | ForEach-Object { [string]$_.src })
  Assert-Condition -Name "PWA icons" -Condition (($IconSources -contains "icons/Icon-192.png") -and ($IconSources -contains "icons/Icon-512.png") -and ($IconSources -contains "icons/Icon-maskable-192.png") -and ($IconSources -contains "icons/Icon-maskable-512.png")) -PassDetail ($IconSources -join ", ") -FailDetail "standard and maskable icons are required"
}

if (Test-Path -LiteralPath "firebase.json") {
  $FirebaseConfig = Get-JsonFile "firebase.json"
  $Hosting = $FirebaseConfig.hosting
  Assert-Condition -Name "Firebase Hosting public directory" -Condition ($Hosting.public -eq "build/web") -PassDetail $Hosting.public -FailDetail "hosting.public must be build/web"

  $Headers = @($Hosting.headers)
  $GlobalHeaders = Get-HeaderValues -Headers $Headers -Source "**"
  Assert-Condition -Name "Security headers" -Condition (($GlobalHeaders["X-Content-Type-Options"] -eq "nosniff") -and ($GlobalHeaders["Referrer-Policy"] -eq "strict-origin-when-cross-origin") -and ($GlobalHeaders["X-Frame-Options"] -eq "DENY") -and ($GlobalHeaders["Permissions-Policy"] -like "*geolocation=(self)*")) -PassDetail "nosniff, referrer policy, frame denial, geolocation permission policy" -FailDetail "required global security headers missing"

  $NoCacheSources = @("/index.html", "/flutter_bootstrap.js", "/manifest.json", "/privacy.html")
  $NoCacheMissing = @()
  foreach ($Source in $NoCacheSources) {
    $HeaderValues = Get-HeaderValues -Headers $Headers -Source $Source
    if ($HeaderValues["Cache-Control"] -ne "no-cache") {
      $NoCacheMissing += $Source
    }
  }
  Assert-Condition -Name "No-cache HTML shell assets" -Condition ($NoCacheMissing.Count -eq 0) -PassDetail ($NoCacheSources -join ", ") -FailDetail ("missing no-cache on " + ($NoCacheMissing -join ", "))
}

if (Test-Path -LiteralPath "build/web/index.html") {
  $IndexHtml = Get-TextFile "build/web/index.html"
  Assert-TextContains -Name "Web loading shell" -Text $IndexHtml -Needles @("id=`"loading-shell`"", "role=`"status`"", "flutter-first-frame", "<noscript>", "/privacy.html")
}

if (Test-Path -LiteralPath "build/web/privacy.html") {
  $PrivacyHtml = Get-TextFile "build/web/privacy.html"
  Assert-TextContains -Name "Privacy page" -Text $PrivacyHtml -Needles @("MasilPet", "TourAPI", "Firebase")
}

if (Test-Path -LiteralPath "firestore.rules") {
  $Rules = Get-TextFile "firestore.rules"
  Assert-TextContains -Name "Firestore server-owned progress rules" -Text $Rules -Needles @("match /users/{uid}", "allow read: if isOwner(uid);", "allow create, update, delete: if false;")
}

if (Test-Path -LiteralPath "functions/src/index.ts") {
  $FunctionsSource = Get-TextFile "functions/src/index.ts"
  Assert-TextContains -Name "Callable production controls" -Text $FunctionsSource -Needles @("export const deleteUserProgress = onCall", "function requireOperator", "const maxDailyCheckIns = 20", "checkInDocumentId")
  Assert-TextContains -Name "Check-in reward evidence fields" -Text $FunctionsSource -Needles @("rewardApplied: true", "reward,", "eggProgress,")
}

if (Test-Path -LiteralPath "functions/lib/index.js") {
  $FunctionsBuild = Get-TextFile "functions/lib/index.js"
  Assert-TextContains -Name "Compiled Functions reward evidence fields" -Text $FunctionsBuild -Needles @("rewardApplied: true", "reward,", "eggProgress,")
}

if ((Test-Path -LiteralPath "lib/src/models.dart") -and
    (Test-Path -LiteralPath "lib/src/screens/profile_screen.dart")) {
  $ModelsSource = Get-TextFile "lib/src/models.dart"
  $ProfileSource = Get-TextFile "lib/src/screens/profile_screen.dart"
  Assert-TextContains -Name "Client reward snapshot model" -Text $ModelsSource -Needles @("final CheckInReward? reward;", "extension CheckInRewardSummary")
  Assert-TextContains -Name "Profile visit reward breakdown" -Text $ProfileSource -Needles @("checkIn.reward ??", "RewardChipRow(reward: reward)")
}

$EmbeddedBuildTime = "not found"
if (Test-Path -LiteralPath "build/web/main.dart.js") {
  $MainJs = Get-TextFile "build/web/main.dart.js"
  Assert-Condition -Name "Build embeds app version" -Condition ($MainJs.Contains($Version)) -PassDetail $Version -FailDetail "main.dart.js did not contain pubspec version $Version"
  $BuildTimeMatch = [regex]::Match($MainJs, "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
  if ($BuildTimeMatch.Success) {
    $EmbeddedBuildTime = $BuildTimeMatch.Value
    Add-Check -Name "Build embeds UTC build time" -Status "PASS" -Detail $EmbeddedBuildTime
  } else {
    Add-Check -Name "Build embeds UTC build time" -Status "FAIL" -Detail "MASILPET_BUILD_TIME_UTC value not found in main.dart.js"
  }
}

$OverallStatus = if ($Failures.Count -eq 0) { "PASS" } else { "FAIL" }
$OutputFullPath = Join-Path $RepoRoot $OutputPath
$OutputDirectory = Split-Path -Parent $OutputFullPath
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
  New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

$Rows = @($Checks | ForEach-Object {
  "| $(Format-MarkdownCell $_.Name) | $(Format-MarkdownCell $_.Status) | $(Format-MarkdownCell $_.Detail) |"
})

$GitStatusText = if ($GitStatus.Count -eq 0) { "clean" } else { $GitStatus -join "`n" }
$HostingUrlText = if ([string]::IsNullOrWhiteSpace($HostingUrl)) { "not provided" } else { $HostingUrl }

$Report = @"
# MasilPet Release Evidence

- Generated at: $GeneratedAt
- Project ID: $ProjectId
- Hosting URL: $HostingUrlText
- App version: $Version
- Git commit: $GitCommit
- Embedded build time: $EmbeddedBuildTime
- Overall status: $OverallStatus

## Gate Results

| Gate | Status | Detail |
| --- | --- | --- |
$($Rows -join "`n")

## Git Status

````text
$GitStatusText
````

## Submission Attachments

- Firebase Hosting URL
- Privacy URL: `$HostingUrlText/privacy.html`
- `tools/release_preflight.ps1` terminal result
- `tools/hosting_smoke.ps1` terminal result
- This evidence report
- Profile screen screenshot showing app version, build channel, and build time
- Profile screen screenshot showing recent visit reward breakdown from the stored check-in record
- Map/check-in screenshots showing location permission, 150m gate, success, and duplicate rejection
"@

Set-Content -LiteralPath $OutputFullPath -Value $Report -Encoding UTF8

Write-Host ""
Write-Host "Release evidence written to $OutputPath" -ForegroundColor Green
Write-Host "Overall status: $OverallStatus" -ForegroundColor $(if ($OverallStatus -eq "PASS") { "Green" } else { "Red" })

if ($Failures.Count -gt 0) {
  throw "Release evidence failed: $($Failures -join '; ')"
}
