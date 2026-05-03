$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-BlockedReceipt {
  param(
    [string]$Reason,
    [string]$RootPath,
    [string]$ReceiptPath,
    [hashtable]$Evidence
  )
  $payload = [ordered]@{
    status = 'BLOCKED_REVIEW_REQUIRED'
    reason = $Reason
    root_path = $RootPath
    utc = [DateTime]::UtcNow.ToString('o')
    evidence = $Evidence
    next_action = 'Review failure evidence and rerun after correction.'
  }
  $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
  Write-Output 'BLOCKED_REVIEW_REQUIRED'
  Write-Output (Get-Content -LiteralPath $ReceiptPath -Raw)
  exit 1
}

function Assert-Path {
  param(
    [string]$Path,
    [string]$Reason,
    [string]$RootPath,
    [string]$ReceiptPath,
    [hashtable]$Evidence
  )
  if (-not (Test-Path -LiteralPath $Path)) {
    $Evidence['missing_path'] = $Path
    Write-BlockedReceipt -Reason $Reason -RootPath $RootPath -ReceiptPath $ReceiptPath -Evidence $Evidence
  }
}

function Invoke-NativeChecked {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$Label,
    [string]$RootPath,
    [string]$ReceiptPath,
    [hashtable]$Evidence,
    [switch]$AllowFailure
  )
  if (-not (Get-Command $FilePath -ErrorAction SilentlyContinue)) {
    if ($AllowFailure) {
      $Evidence[$Label] = 'command_missing_allowed'
      return
    }
    $Evidence[$Label] = 'command_missing'
    Write-BlockedReceipt -Reason "Missing command for $Label" -RootPath $RootPath -ReceiptPath $ReceiptPath -Evidence $Evidence
  }

  & $FilePath @Arguments
  $exit = $LASTEXITCODE
  if ($null -eq $exit) { $exit = 0 }

  if ($exit -ne 0 -and -not $AllowFailure) {
    $Evidence[$Label] = "exit_$exit"
    Write-BlockedReceipt -Reason "Native command failed for $Label" -RootPath $RootPath -ReceiptPath $ReceiptPath -Evidence $Evidence
  }

  if ($exit -ne 0 -and $AllowFailure) {
    $Evidence[$Label] = "allowed_exit_$exit"
    return
  }

  $Evidence[$Label] = 'ok'
}

$root = 'C:\MUBAKA\ORBIT_OS'
$receiptPath = Join-Path $root 'FINAL_RECEIPT.json'
$evidence = @{}

$repoRoot = (Resolve-Path '.').Path
$expectedPublic = Join-Path $repoRoot 'public'
$expectedNetlify = Join-Path $repoRoot 'netlify.toml'

foreach ($dir in @(
  $root,
  (Join-Path $root '_MUBAKA_SEAL'),
  (Join-Path $root '_MUBAKA_SEAL\backup'),
  (Join-Path $root '_TRAVEL'),
  (Join-Path $root 'logs'),
  (Join-Path $root 'data'),
  (Join-Path $root 'ui'),
  (Join-Path $root 'src'),
  (Join-Path $root 'bin')
)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$backupRoot = Join-Path $root '_MUBAKA_SEAL\backup'
$travelRoot = Join-Path $root '_TRAVEL'
$dataRoot = Join-Path $root 'data'
$srcRoot = Join-Path $root 'src'
$binRoot = Join-Path $root 'bin'
$logsRoot = Join-Path $root 'logs'
$manifestPath = Join-Path $root 'INTEGRITY_MANIFEST.json'
$verifierPath = Join-Path $root 'VERIFY_MUBAKA_APPLIANCE.ps1'
$restorePath = Join-Path $travelRoot 'RESTORE_MUBAKA_ORBIT.ps1'

$statePath = Join-Path $dataRoot 'state.json'
$modulesPath = Join-Path $dataRoot 'modules.json'
$queuePath = Join-Path $dataRoot 'queue.ndjson'
$ledgerPath = Join-Path $dataRoot 'ledger.ndjson'
$auditPath = Join-Path $dataRoot 'audit.ndjson'
$uiPath = Join-Path $root 'ui\os.html'

$appSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_APP.cs'
$hostSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_HOST.cs'
$guardianSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_GUARDIAN.cs'
$serviceSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_CORE_SERVICE.cs'

$appExe = Join-Path $binRoot 'MUBAKA_ORBIT_APP.exe'
$hostExe = Join-Path $binRoot 'MUBAKA_ORBIT_HOST.exe'
$guardianExe = Join-Path $binRoot 'MUBAKA_ORBIT_GUARDIAN.exe'
$serviceExe = Join-Path $binRoot 'MUBAKA_ORBIT_CORE_SERVICE.exe'

$desktop = [Environment]::GetFolderPath('Desktop')
$programs = [Environment]::GetFolderPath('Programs')
$startup = [Environment]::GetFolderPath('Startup')
$startMenuDir = Join-Path $programs 'MUBAKA ORBIT OS'
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
$desktopRealExe = Join-Path $desktop 'MUBAKA ORBIT OS.exe'
$desktopConvenienceExe = Join-Path $desktop 'MUBAKA ORBIT OS Launcher.exe'
$startMenuExe = Join-Path $startMenuDir 'MUBAKA ORBIT OS.exe'
$startupExe = Join-Path $startup 'MUBAKA ORBIT OS.exe'

foreach ($wrapper in @('MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1')) {
  $candidate = Join-Path $root $wrapper
  if (Test-Path -LiteralPath $candidate) {
    Remove-Item -LiteralPath $candidate -Force
    $evidence["wrapper_$wrapper"] = 'removed'
  } else {
    $evidence["wrapper_$wrapper"] = 'not_present'
  }
}

$state = [ordered]@{
  system = 'MUBAKA ORBIT OS'
  version = '2.0.0'
  realm = 'inside+outside'
  mode = 'localhost-only'
  operating_posture = 'founder-governed closed cadence'
}
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
Assert-Path -Path $statePath -Reason 'state.json generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

$modules = [ordered]@{
  modules = @(
    [ordered]@{name='MUBAKA_ORBIT_APP';status='active';purpose='Native app opener';launch_path=$appExe;verify_path='app_open.log';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_APP.exe')},
    [ordered]@{name='MUBAKA_ORBIT_HOST';status='active';purpose='Localhost host';launch_path=$hostExe;verify_path='http://127.0.0.1:48721/api/health';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_HOST.exe')},
    [ordered]@{name='MUBAKA_ORBIT_GUARDIAN';status='active';purpose='Health and restore guardian';launch_path=$guardianExe;verify_path='native_guardian.log';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_GUARDIAN.exe')},
    [ordered]@{name='MUBAKA_ORBIT_CORE_SERVICE';status='active';purpose='Service-grade core loop';launch_path=$serviceExe;verify_path='sc.exe query';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_CORE_SERVICE.exe')}
  )
}
$modules | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $modulesPath -Encoding UTF8
Assert-Path -Path $modulesPath -Reason 'modules.json generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

foreach ($stream in @($queuePath,$ledgerPath,$auditPath)) {
  if (-not (Test-Path -LiteralPath $stream)) { New-Item -ItemType File -Path $stream -Force | Out-Null }
  Assert-Path -Path $stream -Reason 'stream file creation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

@'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MUBAKA ORBIT OS</title>
<style>
body{background:#080b16;color:#d8e3ff;font-family:Segoe UI;padding:2rem}
.eye{font-size:2rem;color:#7aff66}
.panel{border:1px solid #6d78a8;border-radius:12px;padding:1rem;margin-bottom:1rem;background:#12182d}
</style>
</head>
<body>
<div class="panel"><div class="eye">O-O MUBAKA • green 1</div><div>ORBIS guidance and founder cadence are active.</div></div>
<div class="panel">Phone truth and website truth share one public posture.</div>
<div class="panel">Private control room mechanics are excluded from public surface.</div>
</body>
</html>
'@ | Set-Content -LiteralPath $uiPath -Encoding UTF8
Assert-Path -Path $uiPath -Reason 'UI generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

$appCode = @"
using System;
using System.Diagnostics;
using System.IO;
class Program {
  [STAThread]
  static void Main() {
    string root = @\"$root\";
    string log = Path.Combine(root, "logs", "app_open.log");
    string guardian = Path.Combine(root, "bin", "MUBAKA_ORBIT_GUARDIAN.exe");
    string url = "http://127.0.0.1:48721/os";
    Directory.CreateDirectory(Path.Combine(root, "logs"));
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] app_open\\n");
    if (File.Exists(guardian)) {
      var gp = new ProcessStartInfo(guardian) { UseShellExecute = true, WorkingDirectory = Path.Combine(root, "bin") };
      Process.Start(gp);
    }
    var psi = new ProcessStartInfo(url) { UseShellExecute = true };
    Process.Start(psi);
  }
}
"@

$hostCode = @"
using System;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
class Host {
  static string root = @\"$root\";
  static string log = Path.Combine(root, "logs", "native_host.log");
  static string data = Path.Combine(root, "data");
  static void Main() {
    Directory.CreateDirectory(Path.Combine(root, "logs"));
    HttpListener listener = new HttpListener();
    listener.Prefixes.Add("http://127.0.0.1:48721/");
    listener.Start();
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] host_start\\n");
    while(true) { Route(listener.GetContext()); }
  }
  static void Route(HttpListenerContext ctx) {
    string p = ctx.Request.Url.AbsolutePath;
    if (p == "/os") { Write(ctx, File.ReadAllText(Path.Combine(root, "ui", "os.html")), "text/html"); return; }
    if (p == "/api/health") { Write(ctx, "{\"status\":\"ok\",\"bind\":\"127.0.0.1\"}", "application/json"); return; }
    if (p == "/api/modules") { Write(ctx, File.ReadAllText(Path.Combine(data, "modules.json")), "application/json"); return; }
    if (p == "/api/ledger") { Write(ctx, File.ReadAllText(Path.Combine(data, "ledger.ndjson")), "application/x-ndjson"); return; }
    if (p == "/api/queue") { Write(ctx, File.ReadAllText(Path.Combine(data, "queue.ndjson")), "application/x-ndjson"); return; }
    if (p == "/api/proof") {
      string body = JsonSerializer.Serialize(new { state = File.Exists(Path.Combine(data, "state.json")), modules = File.Exists(Path.Combine(data, "modules.json")), queue = File.Exists(Path.Combine(data, "queue.ndjson")), ledger = File.Exists(Path.Combine(data, "ledger.ndjson")) });
      Write(ctx, body, "application/json"); return;
    }
    if (p == "/api/route") {
      string payload = new StreamReader(ctx.Request.InputStream).ReadToEnd();
      if (string.IsNullOrWhiteSpace(payload)) payload = "{}";
      string receipt = DateTime.UtcNow.ToString("yyyyMMddHHmmssfff");
      string eventLine = "{\"receipt_id\":\"" + receipt + "\",\"event\":" + payload + ",\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\"}";
      File.AppendAllText(Path.Combine(data, "queue.ndjson"), eventLine + "\\n");
      using var sha = SHA256.Create();
      string hash = Convert.ToHexString(sha.ComputeHash(Encoding.UTF8.GetBytes(eventLine)));
      string ledgerLine = "{\"receipt_id\":\"" + receipt + "\",\"hash\":\"" + hash + "\",\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\"}";
      File.AppendAllText(Path.Combine(data, "ledger.ndjson"), ledgerLine + "\\n");
      Write(ctx, "{\"receipt_id\":\"" + receipt + "\",\"hash\":\"" + hash + "\"}", "application/json");
      return;
    }
    ctx.Response.StatusCode = 404;
    Write(ctx, "not_found", "text/plain");
  }
  static void Write(HttpListenerContext ctx, string body, string contentType) {
    var data = Encoding.UTF8.GetBytes(body);
    ctx.Response.ContentType = contentType;
    ctx.Response.ContentLength64 = data.Length;
    ctx.Response.OutputStream.Write(data, 0, data.Length);
    ctx.Response.OutputStream.Close();
  }
}
"@

$guardianCode = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
class Guardian {
  static string root = @\"$root\";
  static void Main() {
    string bin = Path.Combine(root, "bin");
    string backup = Path.Combine(root, "_MUBAKA_SEAL", "backup");
    string host = Path.Combine(bin, "MUBAKA_ORBIT_HOST.exe");
    string log = Path.Combine(root, "logs", "native_guardian.log");
    Directory.CreateDirectory(Path.Combine(root, "logs"));
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] guardian_start\\n");
    if (!File.Exists(host)) {
      string backupHost = Path.Combine(backup, "MUBAKA_ORBIT_HOST.exe");
      if (File.Exists(backupHost)) { File.Copy(backupHost, host, true); }
    }
    if (!Health()) {
      var psi = new ProcessStartInfo(host) { UseShellExecute = true, WorkingDirectory = bin };
      Process.Start(psi);
      File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] host_started\\n");
    }
  }
  static bool Health() {
    try {
      var req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:48721/api/health");
      req.Method = "GET";
      using var resp = (HttpWebResponse)req.GetResponse();
      return resp.StatusCode == HttpStatusCode.OK;
    } catch { return false; }
  }
}
"@

$serviceCode = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
class ServiceMain {
  static void Main() {
    string root = @\"$root\";
    string guardian = Path.Combine(root, "bin", "MUBAKA_ORBIT_GUARDIAN.exe");
    string log = Path.Combine(root, "logs", "core_service.log");
    Directory.CreateDirectory(Path.Combine(root, "logs"));
    while(true) {
      File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] service_tick\\n");
      if (File.Exists(guardian)) {
        var psi = new ProcessStartInfo(guardian) { UseShellExecute = true, WorkingDirectory = Path.Combine(root, "bin") };
        Process.Start(psi);
      }
      Thread.Sleep(30000);
    }
  }
}
"@

$appCode | Set-Content -LiteralPath $appSrc -Encoding UTF8
$hostCode | Set-Content -LiteralPath $hostSrc -Encoding UTF8
$guardianCode | Set-Content -LiteralPath $guardianSrc -Encoding UTF8
$serviceCode | Set-Content -LiteralPath $serviceSrc -Encoding UTF8

foreach ($src in @($appSrc,$hostSrc,$guardianSrc,$serviceSrc)) {
  Assert-Path -Path $src -Reason 'C# source generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

$cscCandidates = @(
  "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
  "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
  Write-BlockedReceipt -Reason 'Compiler missing' -RootPath $root -ReceiptPath $receiptPath -Evidence @{compiler='missing';proof='COMPILER_REQUIRED_FOR_EXE_ARTIFACTS'}
}

Invoke-NativeChecked -FilePath $csc -Arguments @('/nologo','/target:winexe',"/out:$appExe",$appSrc) -Label 'compile_app' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Assert-Path -Path $appExe -Reason 'App exe missing after compile' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Invoke-NativeChecked -FilePath $csc -Arguments @('/nologo','/target:exe',"/out:$hostExe",$hostSrc) -Label 'compile_host' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Assert-Path -Path $hostExe -Reason 'Host exe missing after compile' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Invoke-NativeChecked -FilePath $csc -Arguments @('/nologo','/target:exe',"/out:$guardianExe",$guardianSrc) -Label 'compile_guardian' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Assert-Path -Path $guardianExe -Reason 'Guardian exe missing after compile' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Invoke-NativeChecked -FilePath $csc -Arguments @('/nologo','/target:exe',"/out:$serviceExe",$serviceSrc) -Label 'compile_service' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Assert-Path -Path $serviceExe -Reason 'Service exe missing after compile' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

foreach ($artifact in @($appExe,$hostExe,$guardianExe,$serviceExe,$uiPath,$statePath,$modulesPath,$queuePath,$ledgerPath,$auditPath)) {
  Copy-Item -LiteralPath $artifact -Destination (Join-Path $backupRoot ([IO.Path]::GetFileName($artifact))) -Force
  Assert-Path -Path (Join-Path $backupRoot ([IO.Path]::GetFileName($artifact))) -Reason 'Backup copy failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

Copy-Item -LiteralPath $appExe -Destination $desktopRealExe -Force
Copy-Item -LiteralPath $appExe -Destination $desktopConvenienceExe -Force
Copy-Item -LiteralPath $appExe -Destination $startMenuExe -Force
Copy-Item -LiteralPath $appExe -Destination $startupExe -Force
foreach ($entry in @($desktopRealExe,$desktopConvenienceExe,$startMenuExe,$startupExe)) {
  Assert-Path -Path $entry -Reason 'Desktop/startup/start menu entry missing' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item -Path $runKey -Force | Out-Null
Set-ItemProperty -Path $runKey -Name 'MUBAKA_ORBIT_APP' -Value ('"' + $appExe + '"')
Set-ItemProperty -Path $runKey -Name 'MUBAKA_ORBIT_GUARDIAN' -Value ('"' + $guardianExe + '"')
$runValues = Get-ItemProperty -Path $runKey
if (-not $runValues.MUBAKA_ORBIT_APP) {
  Write-BlockedReceipt -Reason 'Run key for app missing' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

$serviceName = 'MUBAKA_ORBIT_CORE_SERVICE'
Invoke-NativeChecked -FilePath 'sc.exe' -Arguments @('query',$serviceName) -Label 'service_query_initial' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
if ($evidence['service_query_initial'] -ne 'ok') {
  Invoke-NativeChecked -FilePath 'sc.exe' -Arguments @('create',$serviceName,"binPath= `"$serviceExe`"",'start= auto') -Label 'service_create' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
}
Invoke-NativeChecked -FilePath 'sc.exe' -Arguments @('failure',$serviceName,'reset= 0','actions= restart/60000/restart/60000/restart/60000') -Label 'service_failure_policy' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
Invoke-NativeChecked -FilePath 'sc.exe' -Arguments @('start',$serviceName) -Label 'service_start' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
Invoke-NativeChecked -FilePath 'sc.exe' -Arguments @('query',$serviceName) -Label 'service_query_final' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure

foreach ($task in @(
  @{Name='MUBAKA_ORBIT_GUARDIAN_MINUTE';Schedule=@('/SC','MINUTE','/MO','1')},
  @{Name='MUBAKA_ORBIT_GUARDIAN_STARTUP';Schedule=@('/SC','ONSTART')},
  @{Name='MUBAKA_ORBIT_GUARDIAN_LOGON';Schedule=@('/SC','ONLOGON')}
)) {
  Invoke-NativeChecked -FilePath 'schtasks.exe' -Arguments @('/Create','/F','/TN',$task.Name) + $task.Schedule + @('/TR',('"' + $guardianExe + '"')) -Label ("task_create_" + $task.Name) -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
  Invoke-NativeChecked -FilePath 'schtasks.exe' -Arguments @('/Query','/TN',$task.Name) -Label ("task_query_" + $task.Name) -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence -AllowFailure
}

$manifestEntries = @()
foreach ($artifact in @($appExe,$hostExe,$guardianExe,$serviceExe,$uiPath,$statePath,$modulesPath,$queuePath,$ledgerPath,$auditPath)) {
  $manifestEntries += [ordered]@{path=$artifact;sha256=(Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash}
}
([ordered]@{generated_utc=[DateTime]::UtcNow.ToString('o');files=$manifestEntries}) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Assert-Path -Path $manifestPath -Reason 'Manifest generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $backupRoot 'INTEGRITY_MANIFEST.json') -Force

$restoreContent = @"
`$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
`$root='$root'
`$backup=Join-Path `$root '_MUBAKA_SEAL\\backup'
`$bin=Join-Path `$root 'bin'
`$ui=Join-Path `$root 'ui'
`$data=Join-Path `$root 'data'
foreach(`$d in @(`$root,`$bin,`$ui,`$data)){New-Item -ItemType Directory -Path `$d -Force|Out-Null}
foreach(`$f in @('MUBAKA_ORBIT_APP.exe','MUBAKA_ORBIT_HOST.exe','MUBAKA_ORBIT_GUARDIAN.exe','MUBAKA_ORBIT_CORE_SERVICE.exe')){Copy-Item -LiteralPath (Join-Path `$backup `$f) -Destination (Join-Path `$bin `$f) -Force}
Copy-Item -LiteralPath (Join-Path `$backup 'os.html') -Destination (Join-Path `$ui 'os.html') -Force
foreach(`$f in @('state.json','modules.json','queue.ndjson','ledger.ndjson','audit.ndjson')){Copy-Item -LiteralPath (Join-Path `$backup `$f) -Destination (Join-Path `$data `$f) -Force}
Write-Output 'RESTORE_CONFIRMED'
"@
$restoreContent | Set-Content -LiteralPath $restorePath -Encoding UTF8
Assert-Path -Path $restorePath -Reason 'Restore script generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

$verifyContent = @"
`$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
`$root='$root'
`$checks=[ordered]@{}
`$checks.app_exe=Test-Path (Join-Path `$root 'bin\\MUBAKA_ORBIT_APP.exe')
`$checks.host_exe=Test-Path (Join-Path `$root 'bin\\MUBAKA_ORBIT_HOST.exe')
`$checks.guardian_exe=Test-Path (Join-Path `$root 'bin\\MUBAKA_ORBIT_GUARDIAN.exe')
`$checks.service_exe=Test-Path (Join-Path `$root 'bin\\MUBAKA_ORBIT_CORE_SERVICE.exe')
`$checks.state=Test-Path (Join-Path `$root 'data\\state.json')
`$checks.modules=Test-Path (Join-Path `$root 'data\\modules.json')
`$checks.ledger=Test-Path (Join-Path `$root 'data\\ledger.ndjson')
`$checks.queue=Test-Path (Join-Path `$root 'data\\queue.ndjson')
`$checks.audit=Test-Path (Join-Path `$root 'data\\audit.ndjson')
`$checks.manifest=Test-Path (Join-Path `$root 'INTEGRITY_MANIFEST.json')
`$checks.sealed_backup=Test-Path (Join-Path `$root '_MUBAKA_SEAL\\backup')
`$checks.travel_capsule=Test-Path (Join-Path `$root '_TRAVEL')
`$checks.desktop_real_exe=Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'MUBAKA ORBIT OS.exe')
`$checks.start_menu_exe=Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'MUBAKA ORBIT OS\\MUBAKA ORBIT OS.exe')
`$checks.startup_exe=Test-Path (Join-Path ([Environment]::GetFolderPath('Startup')) 'MUBAKA ORBIT OS.exe')
`$checks.run_key=((Get-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' -ErrorAction SilentlyContinue).MUBAKA_ORBIT_APP -ne `$null)
foreach(`$bad in @('MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1')){`$checks[`$bad]= -not (Test-Path (Join-Path `$root `$bad))}
try { `$h = Invoke-RestMethod -Uri 'http://127.0.0.1:48721/api/health' -Method GET -TimeoutSec 2; `$checks.localhost_health = (`$h.status -eq 'ok') } catch { `$checks.localhost_health = `$false }
`$checks | ConvertTo-Json -Depth 10 | Write-Output
"@
$verifyContent | Set-Content -LiteralPath $verifierPath -Encoding UTF8
Assert-Path -Path $verifierPath -Reason 'Verifier generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

$travelPayload = Join-Path $travelRoot 'capsule_payload'
if (Test-Path -LiteralPath $travelPayload) { Remove-Item -LiteralPath $travelPayload -Recurse -Force }
New-Item -ItemType Directory -Path $travelPayload -Force | Out-Null
foreach ($item in @($binRoot,(Join-Path $root 'ui'),$dataRoot,$manifestPath,$restorePath,$verifierPath)) {
  Copy-Item -LiteralPath $item -Destination $travelPayload -Recurse -Force
}
$travelZip = Join-Path $travelRoot ('MUBAKA_ORBIT_OS_TRAVEL_CAPSULE_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
Compress-Archive -Path (Join-Path $travelPayload '*') -DestinationPath $travelZip -Force
Assert-Path -Path $travelZip -Reason 'Travel capsule generation failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence

$guardianProcess = New-Object System.Diagnostics.ProcessStartInfo
$guardianProcess.FileName = $guardianExe
$guardianProcess.WorkingDirectory = $binRoot
$guardianProcess.UseShellExecute = $true
[System.Diagnostics.Process]::Start($guardianProcess) | Out-Null

Start-Sleep -Seconds 2
$health = 'down'
try {
  $h = Invoke-RestMethod -Uri 'http://127.0.0.1:48721/api/health' -Method GET -TimeoutSec 2
  if ($h.status -eq 'ok') { $health = 'ok' }
} catch {
  $health = 'down'
}
if ($health -ne 'ok') {
  Write-BlockedReceipt -Reason 'Host health verification failed' -RootPath $root -ReceiptPath $receiptPath -Evidence $evidence
}

$appProcess = New-Object System.Diagnostics.ProcessStartInfo
$appProcess.FileName = $appExe
$appProcess.WorkingDirectory = $binRoot
$appProcess.UseShellExecute = $true
[System.Diagnostics.Process]::Start($appProcess) | Out-Null

$verifyProcess = New-Object System.Diagnostics.ProcessStartInfo
$verifyProcess.FileName = Join-Path $PSHOME 'powershell.exe'
$verifyProcess.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $verifierPath + '"'
$verifyProcess.UseShellExecute = $true
[System.Diagnostics.Process]::Start($verifyProcess) | Out-Null

$hashMap = [ordered]@{}
foreach ($artifact in @($appExe,$hostExe,$guardianExe,$serviceExe,$manifestPath,$travelZip)) {
  $hashMap[$artifact] = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
}

$serviceStatus = if ($evidence['service_query_final'] -eq 'ok') { 'verified' } else { 'fallback_without_service_verification' }

$receipt = [ordered]@{
  root_path = $root
  app_exe_path = $appExe
  host_exe_path = $hostExe
  guardian_exe_path = $guardianExe
  service_exe_path = $serviceExe
  desktop_real_exe_path = $desktopRealExe
  start_menu_path = $startMenuExe
  startup_path = $startupExe
  travel_capsule_path = $travelZip
  manifest_path = $manifestPath
  verifier_path = $verifierPath
  service_status = $serviceStatus
  health_status = $health
  wrapper_removal_status = $evidence.Keys | Where-Object { $_ -like 'wrapper_*' } | ForEach-Object { [ordered]@{name=$_;status=$evidence[$_]} }
  sha256_hashes = $hashMap
  command_evidence = $evidence
  final_impossible_statement = 'Impossible to prevent disk wipe, administrator deletion, OS reset, malware compromise, or policy removal.'
  next_action = 'Review FINAL_RECEIPT.json and run verifier for confirmation cadence.'
}
$receipt | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $receiptPath -Encoding UTF8

Write-Output (Get-Content -LiteralPath $receiptPath -Raw)
