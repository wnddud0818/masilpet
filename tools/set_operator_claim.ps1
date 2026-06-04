param(
  [Parameter(Mandatory = $true)]
  [string]$Uid,
  [string]$ProjectId = "masilpet-6ff8d"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

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

$AdminPath = (Resolve-Path "functions\node_modules\firebase-admin").Path
$NodeScript = @'
const [adminPath, uid, projectId] = process.argv.slice(1);
const admin = require(adminPath);

(async () => {
  admin.initializeApp({ projectId });
  const user = await admin.auth().getUser(uid);
  const currentClaims = user.customClaims || {};
  const claims = { ...currentClaims, operator: true };
  await admin.auth().setCustomUserClaims(uid, claims);
  console.log(JSON.stringify({ uid, operator: true, preservedClaims: Object.keys(currentClaims).sort() }, null, 2));
})().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
'@

& node -e $NodeScript $AdminPath $Uid $ProjectId
if ($LASTEXITCODE -ne 0) {
  throw "Failed to set operator claim for $Uid."
}
