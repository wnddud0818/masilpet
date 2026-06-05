param(
  [Parameter(Mandatory = $true)]
  [string]$HostingUrl,
  [switch]$AllowHttp
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Normalize-HostingUrl {
  param([string]$Url)

  $Trimmed = $Url.Trim().TrimEnd("/")
  if ([string]::IsNullOrWhiteSpace($Trimmed)) {
    throw "HostingUrl must not be empty."
  }

  $Parsed = [Uri]$Trimmed
  if ($Parsed.Scheme -ne "https" -and -not $AllowHttp) {
    throw "HostingUrl must use https. Pass -AllowHttp only for local smoke checks."
  }

  return $Parsed.AbsoluteUri.TrimEnd("/")
}

function Invoke-CheckedRequest {
  param(
    [string]$BaseUrl,
    [string]$Path
  )

  $Uri = "$BaseUrl$Path"
  $Response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 20
  if ($Response.StatusCode -ne 200) {
    throw "$Uri returned HTTP $($Response.StatusCode)."
  }
  return $Response
}

function Get-HeaderValue {
  param(
    [object]$Response,
    [string]$Name
  )

  foreach ($Key in $Response.Headers.Keys) {
    if ($Key -ieq $Name) {
      return [string]$Response.Headers[$Key]
    }
  }
  return ""
}

function Assert-Contains {
  param(
    [string]$Value,
    [string]$Expected,
    [string]$Label
  )

  if (-not $Value.Contains($Expected)) {
    throw "$Label did not contain '$Expected'."
  }
}

function Assert-HeaderContains {
  param(
    [object]$Response,
    [string]$Name,
    [string]$Expected
  )

  $Value = Get-HeaderValue -Response $Response -Name $Name
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Missing response header: $Name."
  }
  Assert-Contains -Value $Value -Expected $Expected -Label $Name
}

function Assert-ManifestScreenshot {
  param(
    [hashtable]$ScreenshotsByFormFactor,
    [string]$FormFactor,
    [string]$Src,
    [string]$Sizes,
    [string]$BaseUrl
  )

  if (-not $ScreenshotsByFormFactor.ContainsKey($FormFactor)) {
    throw "manifest.json screenshots must include $FormFactor form_factor."
  }

  $Screenshot = $ScreenshotsByFormFactor[$FormFactor]
  if ([string]$Screenshot.src -ne $Src) {
    throw "manifest.json $FormFactor screenshot src must be $Src."
  }
  if ([string]$Screenshot.sizes -ne $Sizes) {
    throw "manifest.json $FormFactor screenshot sizes must be $Sizes."
  }
  if ([string]$Screenshot.type -ne "image/png") {
    throw "manifest.json $FormFactor screenshot type must be image/png."
  }

  $ScreenshotResponse = Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/$Src"
  Assert-HeaderContains `
    -Response $ScreenshotResponse `
    -Name "Content-Type" `
    -Expected "image/png"
}

$BaseUrl = Normalize-HostingUrl $HostingUrl

Write-Host ""
Write-Host "==> MasilPet Hosting smoke check" -ForegroundColor Cyan
Write-Host $BaseUrl

$Root = Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/"
Assert-Contains -Value $Root.Content -Expected "MasilPet" -Label "Root page"
Assert-Contains -Value $Root.Content -Expected "flutter_bootstrap.js" -Label "Root page"
Assert-Contains -Value $Root.Content -Expected "loading-shell" -Label "Root page"
Assert-Contains -Value $Root.Content -Expected "flutter-first-frame" -Label "Root page"
Assert-Contains -Value $Root.Content -Expected "<noscript>" -Label "Root page"

$Index = Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/index.html"
Assert-HeaderContains -Response $Index -Name "Cache-Control" -Expected "no-cache"
Assert-HeaderContains -Response $Index -Name "X-Content-Type-Options" -Expected "nosniff"
Assert-HeaderContains -Response $Index -Name "Referrer-Policy" -Expected "strict-origin-when-cross-origin"
Assert-HeaderContains -Response $Index -Name "X-Frame-Options" -Expected "DENY"
Assert-HeaderContains -Response $Index -Name "Permissions-Policy" -Expected "geolocation=(self)"

$Privacy = Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/privacy.html"
Assert-Contains -Value $Privacy.Content -Expected "MasilPet" -Label "Privacy page"
Assert-Contains -Value $Privacy.Content -Expected "TourAPI" -Label "Privacy page"
Assert-Contains -Value $Privacy.Content -Expected "Firebase" -Label "Privacy page"
Assert-HeaderContains -Response $Privacy -Name "Cache-Control" -Expected "no-cache"

$ManifestResponse = Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/manifest.json"
$Manifest = $ManifestResponse.Content | ConvertFrom-Json
if ($Manifest.name -notlike "*MasilPet*") {
  throw "manifest.json name must contain MasilPet."
}
if ($Manifest.short_name -ne "MasilPet") {
  throw "manifest.json short_name must be MasilPet."
}
if ($Manifest.display -ne "standalone") {
  throw "manifest.json display must be standalone."
}
if ($Manifest.start_url -ne "/") {
  throw "manifest.json start_url must be '/'."
}
if ($Manifest.icons.Count -lt 4) {
  throw "manifest.json must include standard and maskable icons."
}
if ($Manifest.id -ne "/") {
  throw "manifest.json id must be '/'."
}
if ($Manifest.lang -ne "ko-KR") {
  throw "manifest.json lang must be ko-KR."
}
if (-not $Manifest.shortcuts -or $Manifest.shortcuts.Count -lt 2) {
  throw "manifest.json must include app shortcuts."
}
$ShortcutUrls = @($Manifest.shortcuts | ForEach-Object { $_.url })
if ($ShortcutUrls -notcontains "/#/home") {
  throw "manifest.json shortcuts must include the app home route."
}
if ($ShortcutUrls -notcontains "/privacy.html") {
  throw "manifest.json shortcuts must include privacy.html."
}
$ScreenshotsByFormFactor = @{}
foreach ($Screenshot in @($Manifest.screenshots)) {
  $ScreenshotsByFormFactor[[string]$Screenshot.form_factor] = $Screenshot
}
Assert-ManifestScreenshot `
  -ScreenshotsByFormFactor $ScreenshotsByFormFactor `
  -FormFactor "wide" `
  -Src "screenshots/onboarding-wide.png" `
  -Sizes "1280x720" `
  -BaseUrl $BaseUrl
Assert-ManifestScreenshot `
  -ScreenshotsByFormFactor $ScreenshotsByFormFactor `
  -FormFactor "narrow" `
  -Src "screenshots/onboarding-mobile.png" `
  -Sizes "390x844" `
  -BaseUrl $BaseUrl
Assert-HeaderContains -Response $ManifestResponse -Name "Cache-Control" -Expected "no-cache"

Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/icons/Icon-192.png" | Out-Null
Invoke-CheckedRequest -BaseUrl $BaseUrl -Path "/icons/Icon-512.png" | Out-Null

Write-Host ""
Write-Host "Hosting smoke check passed for $BaseUrl." -ForegroundColor Green
