param(
  [Parameter(Mandatory = $true)]
  [string]$Uid,
  [ValidateSet("seedStarterRegionData", "syncBusanPois")]
  [string]$FunctionName = "seedStarterRegionData",
  [string]$ProjectId = "masilpet-6ff8d",
  [string]$Region = "asia-northeast3",
  [string]$DataJson = "{}"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

function Get-RequiredEnvironmentValue {
  param([string]$Name)

  $Value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Required environment variable missing: $Name"
  }
  return $Value
}

function Test-AdminCredentials {
  $ServiceAccount = [Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS")
  $GcloudAdc = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"

  if (-not [string]::IsNullOrWhiteSpace($ServiceAccount) -and
      (Test-Path -LiteralPath $ServiceAccount)) {
    return
  }

  if (Test-Path -LiteralPath $GcloudAdc) {
    return
  }

  throw "Firebase Admin credentials not found. Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file or run 'gcloud auth application-default login'."
}

function Test-FunctionsDependencies {
  if (-not (Test-Path -LiteralPath "functions\node_modules\firebase-admin")) {
    throw "functions/node_modules/firebase-admin is missing. Run 'npm --prefix functions ci' first."
  }
}

Test-AdminCredentials
Test-FunctionsDependencies
$ApiKey = Get-RequiredEnvironmentValue "FIREBASE_WEB_API_KEY"

$AdminPath = (Resolve-Path "functions\node_modules\firebase-admin").Path
$NodeScript = @'
const [adminPath, uid, projectId] = process.argv.slice(1);
const admin = require(adminPath);

(async () => {
  admin.initializeApp({ projectId });
  const token = await admin.auth().createCustomToken(uid, { operator: true });
  process.stdout.write(token);
})().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
'@

$CustomToken = & node -e $NodeScript $AdminPath $Uid $ProjectId
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CustomToken)) {
  throw "Failed to create an operator custom token for $Uid."
}

$SignInBody = @{
  token = $CustomToken
  returnSecureToken = $true
} | ConvertTo-Json -Depth 4

$SignInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$ApiKey"
$SignInResponse = Invoke-RestMethod -Method Post -Uri $SignInUrl -ContentType "application/json" -Body $SignInBody
$IdToken = $SignInResponse.idToken

if ([string]::IsNullOrWhiteSpace($IdToken)) {
  throw "Failed to exchange custom token for an ID token."
}

$CallableData = ConvertFrom-Json $DataJson
$CallableBody = @{ data = $CallableData } | ConvertTo-Json -Depth 20
$FunctionUrl = "https://$Region-$ProjectId.cloudfunctions.net/$FunctionName"

$Response = Invoke-RestMethod `
  -Method Post `
  -Uri $FunctionUrl `
  -ContentType "application/json" `
  -Headers @{ Authorization = "Bearer $IdToken" } `
  -Body $CallableBody

$Response | ConvertTo-Json -Depth 20
