param(
  [int]$Port = 8082,
  [int]$DebugPort = 9232,
  [string]$OutputDir = "build/verification",
  [string]$ChromePath = "",
  [switch]$KeepServer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

function Get-AbsoluteRepoPath {
  param([string]$Path)

  $Combined = if ([System.IO.Path]::IsPathRooted($Path)) {
    $Path
  } else {
    Join-Path $RepoRoot $Path
  }
  return [System.IO.Path]::GetFullPath($Combined)
}

function Assert-InRepo {
  param([string]$Path)

  $FullPath = Get-AbsoluteRepoPath $Path
  $RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)
  if (-not $FullPath.StartsWith($RepoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the repository: $FullPath"
  }
  return $FullPath
}

function Find-Chrome {
  if (-not [string]::IsNullOrWhiteSpace($ChromePath)) {
    if (Test-Path -LiteralPath $ChromePath) {
      return $ChromePath
    }
    throw "ChromePath does not exist: $ChromePath"
  }

  $Candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  )

  foreach ($Candidate in $Candidates) {
    if (Test-Path -LiteralPath $Candidate) {
      return $Candidate
    }
  }

  throw "Chrome or Edge was not found. Pass -ChromePath to run the local judging smoke check."
}

function Test-PortListening {
  param([int]$LocalPort)

  $Existing = Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue
  return $null -ne $Existing
}

if (-not (Test-Path -LiteralPath "build/web/index.html")) {
  throw "build/web/index.html is missing. Run flutter build web --release first."
}

$OutputFullPath = Assert-InRepo $OutputDir
if (-not (Test-Path -LiteralPath $OutputFullPath)) {
  New-Item -ItemType Directory -Path $OutputFullPath | Out-Null
}

$ProfilePath = Assert-InRepo (Join-Path $OutputFullPath "chrome-profile-local-judging-smoke")
if (Test-Path -LiteralPath $ProfilePath) {
  Remove-Item -LiteralPath $ProfilePath -Recurse -Force
}

$Chrome = Find-Chrome
$StartedServer = $null

if (Test-PortListening $Port) {
  Write-Host "Using existing local server on port $Port." -ForegroundColor Yellow
} else {
  $StartedServer = Start-Process `
    -FilePath python `
    -ArgumentList @("-m", "http.server", $Port, "-d", "build\web") `
    -WorkingDirectory $RepoRoot `
    -PassThru `
    -WindowStyle Hidden
  Start-Sleep -Seconds 2
  Write-Host "Started local build/web server on port $Port (PID $($StartedServer.Id))." -ForegroundColor Green
}

$ChromeProcess = $null
try {
  $ChromeProcess = Start-Process `
    -FilePath $Chrome `
    -ArgumentList @(
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      "--user-data-dir=$ProfilePath",
      "--remote-debugging-port=$DebugPort",
      "--window-size=1280,720",
      "about:blank"
    ) `
    -PassThru `
    -WindowStyle Hidden

  $env:MASILPET_SMOKE_DEBUG_PORT = "$DebugPort"
  $env:MASILPET_SMOKE_URL = "http://127.0.0.1:$Port/#/onboarding"
  $env:MASILPET_SMOKE_OUTPUT_DIR = $OutputFullPath.Replace("\", "/")

@'
const fs = await import("node:fs");

if (typeof WebSocket === "undefined") {
  throw new Error("This smoke check requires a Node.js runtime with global WebSocket support.");
}

const debugPort = Number(process.env.MASILPET_SMOKE_DEBUG_PORT);
const appUrl = process.env.MASILPET_SMOKE_URL;
const outputDir = process.env.MASILPET_SMOKE_OUTPUT_DIR;
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function getJson(url, options) {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const response = await fetch(url, options);
      if (response.ok) {
        return await response.json();
      }
    } catch (_) {}
    await wait(250);
  }
  throw new Error(`Timed out waiting for ${url}`);
}

const target = await getJson(
  `http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(appUrl)}`,
  { method: "PUT" },
);
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let nextId = 0;
const pending = new Map();
socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) {
      reject(new Error(`${message.error.message}: ${message.error.data || ""}`));
    } else {
      resolve(message.result || {});
    }
  }
});

function send(method, params = {}) {
  const id = ++nextId;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

async function click(x, y) {
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await send("Input.dispatchMouseEvent", {
    type: "mousePressed",
    x,
    y,
    button: "left",
    clickCount: 1,
  });
  await send("Input.dispatchMouseEvent", {
    type: "mouseReleased",
    x,
    y,
    button: "left",
    clickCount: 1,
  });
}

async function screenshot(name) {
  const shot = await send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
  });
  fs.writeFileSync(`${outputDir}/${name}.png`, Buffer.from(shot.data, "base64"));
}

await send("Page.enable");
await send("Runtime.enable");
await send("Emulation.setDeviceMetricsOverride", {
  width: 1280,
  height: 720,
  deviceScaleFactor: 1,
  mobile: false,
});
await send("Page.navigate", { url: appUrl });
await wait(6500);

await click(640, 684); // onboarding start
await wait(3000);
await click(470, 417); // local judging fallback
await wait(1000);
await screenshot("local-judging-after-fallback");

await send("Input.dispatchMouseEvent", {
  type: "mouseWheel",
  x: 640,
  y: 690,
  deltaY: 520,
  deltaX: 0,
});
await wait(800);
await click(1010, 621); // first POI check-in
await wait(1600);
await screenshot("local-judging-after-checkin");

await click(90, 108); // pet navigation rail item
await wait(1600);
await click(342, 573); // talk action
await wait(1400);
await screenshot("local-judging-after-talk");

const result = await send("Runtime.evaluate", {
  expression: `(() => {
    const raw = localStorage.getItem("masilpet.local_progress.v1") ||
      localStorage.getItem("flutter.masilpet.local_progress.v1");
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch (_) {}
    return JSON.stringify({
      href: location.href,
      hasProgress: !!raw,
      checkIns: parsed?.checkIns?.length ?? 0,
      dialogueCountToday: parsed?.dialogueCountToday ?? 0,
      lastVisitedCategory: parsed?.lastVisitedCategory ?? null,
      activePetId: parsed?.activePetId ?? null,
      pets: parsed?.pets?.length ?? 0,
    });
  })()`,
  returnByValue: true,
});

const summary = JSON.parse(result.result.value);
fs.writeFileSync(
  `${outputDir}/local-judging-smoke-result.json`,
  JSON.stringify(summary, null, 2),
);

if (!summary.hasProgress) {
  throw new Error("Local progress was not saved.");
}
if (summary.checkIns < 1) {
  throw new Error(`Expected at least one check-in, found ${summary.checkIns}.`);
}
if (summary.dialogueCountToday < 1) {
  throw new Error(`Expected at least one pet dialogue, found ${summary.dialogueCountToday}.`);
}
if (!summary.lastVisitedCategory) {
  throw new Error("Expected a last visited category after check-in.");
}

socket.close();
console.log(JSON.stringify(summary));
'@ | node --input-type=module

  if ($LASTEXITCODE -ne 0) {
    throw "Local judging smoke check failed with exit code $LASTEXITCODE"
  }

  Write-Host ""
  Write-Host "Local judging smoke check passed." -ForegroundColor Green
  Write-Host "Screenshots and summary written to $OutputFullPath" -ForegroundColor Green
} finally {
  if ($ChromeProcess -ne $null) {
    Stop-Process -Id $ChromeProcess.Id -Force -ErrorAction SilentlyContinue
  }
  if ($StartedServer -ne $null -and -not $KeepServer) {
    Stop-Process -Id $StartedServer.Id -Force -ErrorAction SilentlyContinue
  }
}
