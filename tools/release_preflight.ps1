param(
  [string]$ProjectId = "masilpet-6ff8d",
  [switch]$SkipFirebase,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

function Test-RequiredFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Required file missing: $Path"
  }
}

function Get-RequiredEnvironmentValue {
  param([string]$Name)

  $Value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Required environment variable missing: $Name"
  }
  return $Value
}

function Get-PubspecVersion {
  $Pubspec = Get-Content -Raw -Encoding UTF8 "pubspec.yaml"
  $Match = [regex]::Match($Pubspec, "(?m)^version:\s*(.+?)\s*$")
  if (-not $Match.Success) {
    throw "pubspec.yaml version is missing."
  }
  return $Match.Groups[1].Value.Trim()
}

function Get-AppDartDefineArgs {
  Write-Host ""
  Write-Host "==> MasilPet build identity" -ForegroundColor Cyan

  $AppVersion = Get-PubspecVersion
  $BuildChannel = [Environment]::GetEnvironmentVariable("MASILPET_BUILD_CHANNEL")
  if ([string]::IsNullOrWhiteSpace($BuildChannel)) {
    $BuildChannel = "release"
  }
  $BuildTimeUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  Write-Host "Version: $AppVersion" -ForegroundColor Green
  Write-Host "Channel: $BuildChannel" -ForegroundColor Green

  return @(
    "--dart-define=MASILPET_APP_VERSION=$AppVersion",
    "--dart-define=MASILPET_BUILD_CHANNEL=$BuildChannel",
    "--dart-define=MASILPET_BUILD_TIME_UTC=$BuildTimeUtc"
  )
}

function Get-FirebaseDartDefineArgs {
  Write-Host ""
  Write-Host "==> Firebase Web build configuration" -ForegroundColor Cyan

  $RequiredNames = @(
    "FIREBASE_WEB_API_KEY",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_MESSAGING_SENDER_ID"
  )
  $OptionalNames = @(
    "FIREBASE_AUTH_DOMAIN",
    "FIREBASE_STORAGE_BUCKET"
  )
  $Args = @()

  foreach ($Name in $RequiredNames) {
    $Value = Get-RequiredEnvironmentValue $Name
    $Args += "--dart-define=$Name=$Value"
  }

  foreach ($Name in $OptionalNames) {
    $Value = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
      $Args += "--dart-define=$Name=$Value"
    }
  }

  Write-Host "Firebase Web dart-defines are present." -ForegroundColor Green
  return $Args
}

function Test-FirebaseLogin {
  Write-Host ""
  Write-Host "==> Firebase login and project access" -ForegroundColor Cyan
  firebase projects:list --json | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Firebase authentication failed. Run 'firebase login' and retry."
  }

  $firebaserc = Get-Content -Raw -Encoding UTF8 ".firebaserc" | ConvertFrom-Json
  if ($firebaserc.projects.default -ne $ProjectId) {
    throw ".firebaserc default project is '$($firebaserc.projects.default)', expected '$ProjectId'."
  }
}

function Test-TourApiSecret {
  Write-Host ""
  Write-Host "==> Firebase TOUR_API_KEY secret" -ForegroundColor Cyan
  firebase functions:secrets:access TOUR_API_KEY --project $ProjectId | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "TOUR_API_KEY secret is not accessible. Run 'firebase functions:secrets:set TOUR_API_KEY'."
  }
}

$AppDartDefineArgs = Get-AppDartDefineArgs
$FirebaseDartDefineArgs = @()
if (-not $SkipFirebase) {
  Test-FirebaseLogin
  Test-TourApiSecret
  $FirebaseDartDefineArgs = Get-FirebaseDartDefineArgs
}

if (-not $SkipBuild) {
  Invoke-Step "Flutter dependencies" { flutter pub get }
  Invoke-Step "Dart format check" { dart format --set-exit-if-changed lib test }
  Invoke-Step "Flutter analyze" { flutter analyze }
  Invoke-Step "Flutter tests" { flutter test }
  Invoke-Step "Functions clean install" { npm --prefix functions ci }
  Invoke-Step "Functions build" { npm --prefix functions run build }
  Invoke-Step "Functions high audit gate" { npm --prefix functions audit --audit-level=high }
  Invoke-Step "Flutter release web build" { flutter build web --release --no-wasm-dry-run @AppDartDefineArgs @FirebaseDartDefineArgs }
}

Write-Host ""
Write-Host "==> Release artifact checks" -ForegroundColor Cyan
Test-RequiredFile "build/web/index.html"
Test-RequiredFile "build/web/flutter_bootstrap.js"
Test-RequiredFile "build/web/manifest.json"
Test-RequiredFile "build/web/privacy.html"
Test-RequiredFile "build/web/icons/Icon-192.png"
Test-RequiredFile "build/web/icons/Icon-512.png"
Test-RequiredFile "firebase.json"
Test-RequiredFile "firestore.rules"
Test-RequiredFile "firestore.indexes.json"
Test-RequiredFile "functions/lib/index.js"

Write-Host ""
Write-Host "Release preflight passed for project $ProjectId." -ForegroundColor Green
