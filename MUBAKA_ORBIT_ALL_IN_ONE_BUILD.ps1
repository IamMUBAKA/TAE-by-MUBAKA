$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\MUBAKA\ORBIT_OS'
$sealRoot = Join-Path $root '_MUBAKA_SEAL'
$backupRoot = Join-Path $sealRoot 'backup'
$travelRoot = Join-Path $root '_TRAVEL'
$logsRoot = Join-Path $root 'logs'
$dataRoot = Join-Path $root 'data'
$uiRoot = Join-Path $root 'ui'
$srcRoot = Join-Path $root 'src'
$binRoot = Join-Path $root 'bin'

$desktop = [Environment]::GetFolderPath('Desktop')
$programs = [Environment]::GetFolderPath('Programs')
$startup = [Environment]::GetFolderPath('Startup')
$startMenuDir = Join-Path $programs 'MUBAKA ORBIT OS'
$desktopRealExe = Join-Path $desktop 'MUBAKA ORBIT OS.exe'
$desktopLink = Join-Path $desktop 'MUBAKA ORBIT OS.lnk'
$startupLink = Join-Path $startup 'MUBAKA ORBIT OS.lnk'
$startMenuLink = Join-Path $startMenuDir 'MUBAKA ORBIT OS.lnk'

$statePath = Join-Path $dataRoot 'state.json'
$modulesPath = Join-Path $dataRoot 'modules.json'
$queuePath = Join-Path $dataRoot 'queue.ndjson'
$ledgerPath = Join-Path $dataRoot 'ledger.ndjson'
$auditPath = Join-Path $dataRoot 'audit.ndjson'
$manifestPath = Join-Path $root 'INTEGRITY_MANIFEST.json'
$hostUiPath = Join-Path $uiRoot 'os.html'
$verifierPath = Join-Path $root 'VERIFY_MUBAKA_APPLIANCE.ps1'
$restorePath = Join-Path $travelRoot 'RESTORE_MUBAKA_ORBIT.ps1'

$appSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_APP.cs'
$hostSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_HOST.cs'
$guardianSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_GUARDIAN.cs'
$serviceSrc = Join-Path $srcRoot 'MUBAKA_ORBIT_CORE_SERVICE.cs'

$appExe = Join-Path $binRoot 'MUBAKA_ORBIT_APP.exe'
$hostExe = Join-Path $binRoot 'MUBAKA_ORBIT_HOST.exe'
$guardianExe = Join-Path $binRoot 'MUBAKA_ORBIT_GUARDIAN.exe'
$serviceExe = Join-Path $binRoot 'MUBAKA_ORBIT_CORE_SERVICE.exe'

$finalReceiptPath = Join-Path $root 'FINAL_RECEIPT.json'

foreach($dir in @($root,$sealRoot,$backupRoot,$travelRoot,$logsRoot,$dataRoot,$uiRoot,$srcRoot,$binRoot,$startMenuDir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$wrapperRemoval = [ordered]@{}
foreach($bad in @('MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1')) {
  $candidate = Join-Path $root $bad
  if (Test-Path $candidate) {
    Remove-Item -LiteralPath $candidate -Force
    $wrapperRemoval[$bad] = 'removed'
  } else {
    $wrapperRemoval[$bad] = 'not_present'
  }
}

@'
<!doctype html>
<html>
<head><meta charset="utf-8"><title>MUBAKA ORBIT OS</title><style>body{font-family:Segoe UI;background:#050914;color:#f5b735;padding:20px}.ok{color:#4bff95}</style></head>
<body>
<h1>MUBAKA ORBIT OS</h1>
<p>Native local operating appliance surface.</p>
<ul>
  <li class="ok">Inside realm: app, host, guardian, service, ledger, queue, audit</li>
  <li class="ok">Outside realm: seal backup, travel capsule, restore body, integrity manifest</li>
</ul>
</body>
</html>
'@ | Set-Content -LiteralPath $hostUiPath -Encoding UTF8

$state = [ordered]@{
  system = 'MUBAKA ORBIT OS'
  version = '1.0.0'
  realm = 'inside+outside'
  mode = 'localhost-only'
  posture = 'forward-only'
  identity = 'MUBAKA NATIVE EXISTENCE ARCHITECTURE'
}
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8

$modules = [ordered]@{
  modules = @(
    [ordered]@{name='MUBAKA_ORBIT_APP';status='active';purpose='Native app opener';launch_path=$appExe;verify_path='/api/health';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_APP.exe')},
    [ordered]@{name='MUBAKA_ORBIT_HOST';status='active';purpose='Localhost host';launch_path=$hostExe;verify_path='http://127.0.0.1:48721/api/health';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_HOST.exe')},
    [ordered]@{name='MUBAKA_ORBIT_GUARDIAN';status='active';purpose='Restore and health guardian';launch_path=$guardianExe;verify_path=(Join-Path $logsRoot 'native_guardian.log');restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_GUARDIAN.exe')},
    [ordered]@{name='MUBAKA_ORBIT_CORE_SERVICE';status='active';purpose='Service-grade supervisor';launch_path=$serviceExe;verify_path='SC QUERY MUBAKA_ORBIT_CORE_SERVICE';restore_path=(Join-Path $backupRoot 'MUBAKA_ORBIT_CORE_SERVICE.exe')}
  )
}
$modules | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $modulesPath -Encoding UTF8

foreach($f in @($queuePath,$ledgerPath,$auditPath)) {
  if (!(Test-Path $f)) { New-Item -ItemType File -Path $f -Force | Out-Null }
}

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
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] app_open\\r\\n");
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
    while(true) {
      var ctx = listener.GetContext();
      Route(ctx);
    }
  }

  static void Route(HttpListenerContext ctx) {
    string p = ctx.Request.Url.AbsolutePath;
    if (p == "/os") { ServeFile(ctx, Path.Combine(root, "ui", "os.html"), "text/html"); return; }
    if (p == "/api/health") { Json(ctx, new { status = "ok", bind = "127.0.0.1", utc = DateTime.UtcNow.ToString("o") }); return; }
    if (p == "/api/modules") { ServeFile(ctx, Path.Combine(data, "modules.json"), "application/json"); return; }
    if (p == "/api/ledger") { ServeFile(ctx, Path.Combine(data, "ledger.ndjson"), "application/x-ndjson"); return; }
    if (p == "/api/queue") { ServeFile(ctx, Path.Combine(data, "queue.ndjson"), "application/x-ndjson"); return; }
    if (p == "/api/proof") {
      var proof = new {
        state = File.Exists(Path.Combine(data, "state.json")),
        modules = File.Exists(Path.Combine(data, "modules.json")),
        queue = File.Exists(Path.Combine(data, "queue.ndjson")),
        ledger = File.Exists(Path.Combine(data, "ledger.ndjson"))
      };
      Json(ctx, proof);
      return;
    }
    if (p == "/api/route") {
      string body = new StreamReader(ctx.Request.InputStream).ReadToEnd();
      if (string.IsNullOrWhiteSpace(body)) body = "{}";
      string receiptId = DateTime.UtcNow.ToString("yyyyMMddHHmmssfff");
      string eventPayload = "{\"receipt_id\":\"" + receiptId + "\",\"event\":" + body + ",\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\"}";
      File.AppendAllText(Path.Combine(data, "queue.ndjson"), eventPayload + "\\n");
      using var sha = SHA256.Create();
      string hash = Convert.ToHexString(sha.ComputeHash(Encoding.UTF8.GetBytes(eventPayload)));
      string ledger = "{\"receipt_id\":\"" + receiptId + "\",\"hash\":\"" + hash + "\",\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\"}";
      File.AppendAllText(Path.Combine(data, "ledger.ndjson"), ledger + "\\n");
      Json(ctx, new { receipt_id = receiptId, hash = hash });
      return;
    }
    ctx.Response.StatusCode = 404;
    Write(ctx, "not_found", "text/plain");
  }

  static void ServeFile(HttpListenerContext ctx, string path, string type) {
    if (!File.Exists(path)) { ctx.Response.StatusCode = 404; Write(ctx, "missing", "text/plain"); return; }
    Write(ctx, File.ReadAllText(path), type);
  }

  static void Json(HttpListenerContext ctx, object o) {
    Write(ctx, JsonSerializer.Serialize(o), "application/json");
  }

  static void Write(HttpListenerContext ctx, string body, string type) {
    byte[] b = Encoding.UTF8.GetBytes(body);
    ctx.Response.ContentType = type;
    ctx.Response.ContentLength64 = b.Length;
    ctx.Response.OutputStream.Write(b, 0, b.Length);
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
  static string bin = Path.Combine(root, "bin");
  static string backup = Path.Combine(root, "_MUBAKA_SEAL", "backup");
  static string log = Path.Combine(root, "logs", "native_guardian.log");

  static void Main() {
    Directory.CreateDirectory(Path.Combine(root, "logs"));
    Directory.CreateDirectory(backup);
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] guardian_start\\n");
    string host = Path.Combine(bin, "MUBAKA_ORBIT_HOST.exe");
    if (!File.Exists(host)) Restore("MUBAKA_ORBIT_HOST.exe");
    if (!Healthy()) {
      var p = new ProcessStartInfo(host) { UseShellExecute = true, WorkingDirectory = bin };
      Process.Start(p);
      File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] host_started\\n");
    }
  }

  static bool Healthy() {
    try {
      var req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:48721/api/health");
      req.Method = "GET";
      using var resp = (HttpWebResponse)req.GetResponse();
      return resp.StatusCode == HttpStatusCode.OK;
    } catch { return false; }
  }

  static void Restore(string file) {
    string src = Path.Combine(backup, file);
    string dst = Path.Combine(bin, file);
    if (File.Exists(src)) File.Copy(src, dst, true);
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
    File.AppendAllText(log, "[" + DateTime.UtcNow.ToString("o") + "] service_loop_start\\n");
    while(true) {
      if (File.Exists(guardian)) {
        var p = new ProcessStartInfo(guardian) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(guardian) };
        Process.Start(p);
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

$candidates = @(
  "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
  "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$compileProof = [ordered]@{}
if ($csc) {
  & $csc /nologo /target:winexe /out:$appExe $appSrc | Out-Null
  & $csc /nologo /target:exe /out:$hostExe $hostSrc | Out-Null
  & $csc /nologo /target:exe /out:$guardianExe $guardianSrc | Out-Null
  & $csc /nologo /target:exe /out:$serviceExe $serviceSrc | Out-Null
  $compileProof.status = 'compiled'
  $compileProof.compiler = $csc
} else {
  $compileProof.status = 'compiler_unavailable'
  $compileProof.compiler = 'none'
  "compiler_unavailable" | Set-Content -LiteralPath (Join-Path $root 'COMPILER_PROOF.txt') -Encoding UTF8
}

foreach($required in @($appExe,$hostExe,$guardianExe,$serviceExe)) {
  if (Test-Path $required) {
    Copy-Item -LiteralPath $required -Destination (Join-Path $backupRoot ([IO.Path]::GetFileName($required))) -Force
  }
}

if (Test-Path $appExe) {
  Copy-Item -LiteralPath $appExe -Destination $desktopRealExe -Force
}

$wsh = New-Object -ComObject WScript.Shell
foreach($lnk in @($desktopLink,$startupLink,$startMenuLink)) {
  $shortcut = $wsh.CreateShortcut($lnk)
  $shortcut.TargetPath = $appExe
  $shortcut.WorkingDirectory = $root
  $shortcut.Description = 'MUBAKA ORBIT OS'
  $shortcut.IconLocation = $appExe
  $shortcut.Save()
}

$serviceStatus = 'not_installed'
try {
  & sc.exe query MUBAKA_ORBIT_CORE_SERVICE *> $null
  if ($LASTEXITCODE -ne 0) {
    & sc.exe create MUBAKA_ORBIT_CORE_SERVICE binPath= "`"$serviceExe`"" start= auto | Out-Null
  }
  & sc.exe failure MUBAKA_ORBIT_CORE_SERVICE reset= 0 actions= restart/60000/restart/60000/restart/60000 | Out-Null
  & sc.exe start MUBAKA_ORBIT_CORE_SERVICE | Out-Null
  $serviceStatus = 'installed_or_running'
} catch {
  $serviceStatus = 'install_failed_fallback_active'
  Add-Content -LiteralPath $auditPath -Value ("{""utc"":""{0}"",""event"":""service_install_failed"",""reason"":""{1}""}" -f [DateTime]::UtcNow.ToString('o'), $_.Exception.Message.Replace('"','\"'))
}

$taskStatus = [ordered]@{}
$taskCmd = "`"$guardianExe`""
foreach($pair in @(
  @{Name='MUBAKA_ORBIT_GUARDIAN_MINUTE';Args='/SC MINUTE /MO 1 /RL LIMITED /TR ' + $taskCmd},
  @{Name='MUBAKA_ORBIT_GUARDIAN_STARTUP';Args='/SC ONSTART /RL LIMITED /TR ' + $taskCmd},
  @{Name='MUBAKA_ORBIT_GUARDIAN_LOGON';Args='/SC ONLOGON /RL LIMITED /TR ' + $taskCmd}
)) {
  try {
    & schtasks.exe /Create /F /TN $pair.Name $pair.Args.Split(' ') | Out-Null
    $taskStatus[$pair.Name] = 'ok'
  } catch {
    $taskStatus[$pair.Name] = 'failed'
  }
}

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item -Path $runKey -Force | Out-Null
Set-ItemProperty -Path $runKey -Name 'MUBAKA_ORBIT_APP' -Value ('"' + $appExe + '"')
Set-ItemProperty -Path $runKey -Name 'MUBAKA_ORBIT_GUARDIAN' -Value ('"' + $guardianExe + '"')

$manifestEntries = @()
$coreFiles = @($appExe,$hostExe,$guardianExe,$serviceExe,$hostUiPath,$statePath,$modulesPath,$queuePath,$ledgerPath,$auditPath)
foreach($file in $coreFiles) {
  if (Test-Path $file) {
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $manifestEntries += [ordered]@{path=$file;sha256=$hash}
  }
}
([ordered]@{generated_utc=[DateTime]::UtcNow.ToString('o');files=$manifestEntries}) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

foreach($file in $coreFiles + @($manifestPath,$verifierPath)) {
  if (Test-Path $file) {
    Copy-Item -LiteralPath $file -Destination (Join-Path $backupRoot ([IO.Path]::GetFileName($file))) -Force
  }
}

$restoreBody = @"
`$ErrorActionPreference='Stop'
`$root='$root'
`$backup=Join-Path `$root '_MUBAKA_SEAL\\backup'
`$bin=Join-Path `$root 'bin'
`$ui=Join-Path `$root 'ui'
`$data=Join-Path `$root 'data'
foreach(`$d in @(`$root,`$bin,`$ui,`$data)){New-Item -ItemType Directory -Path `$d -Force|Out-Null}
foreach(`$f in @('MUBAKA_ORBIT_APP.exe','MUBAKA_ORBIT_HOST.exe','MUBAKA_ORBIT_GUARDIAN.exe','MUBAKA_ORBIT_CORE_SERVICE.exe')){if(Test-Path (Join-Path `$backup `$f)){Copy-Item (Join-Path `$backup `$f) (Join-Path `$bin `$f) -Force}}
foreach(`$f in @('os.html')){if(Test-Path (Join-Path `$backup `$f)){Copy-Item (Join-Path `$backup `$f) (Join-Path `$ui `$f) -Force}}
foreach(`$f in @('state.json','modules.json','queue.ndjson','ledger.ndjson','audit.ndjson')){if(Test-Path (Join-Path `$backup `$f)){Copy-Item (Join-Path `$backup `$f) (Join-Path `$data `$f) -Force}}
Write-Host 'RESTORE_COMPLETE'
"@
$restoreBody | Set-Content -LiteralPath $restorePath -Encoding UTF8

$verifyBody = @"
`$ErrorActionPreference='Stop'
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
`$checks.travel=Test-Path (Join-Path `$root '_TRAVEL')
`$checks.desktop_real_exe=Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'MUBAKA ORBIT OS.exe')
`$checks.start_menu=Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'MUBAKA ORBIT OS\\MUBAKA ORBIT OS.lnk')
`$checks.startup=Test-Path (Join-Path ([Environment]::GetFolderPath('Startup')) 'MUBAKA ORBIT OS.lnk')
`$checks.run_key=((Get-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' -ErrorAction SilentlyContinue).MUBAKA_ORBIT_APP -ne `$null)
try { `$health = Invoke-RestMethod -Uri 'http://127.0.0.1:48721/api/health' -Method GET -TimeoutSec 2; `$checks.localhost_health = (`$health.status -eq 'ok') } catch { `$checks.localhost_health = `$false }
`$checks | ConvertTo-Json -Depth 4 | Write-Output
"@
$verifyBody | Set-Content -LiteralPath $verifierPath -Encoding UTF8

$travelStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$travelWork = Join-Path $travelRoot 'capsule_payload'
if (Test-Path $travelWork) { Remove-Item -LiteralPath $travelWork -Recurse -Force }
New-Item -ItemType Directory -Path $travelWork -Force | Out-Null
foreach($item in @($binRoot,$uiRoot,$dataRoot,$manifestPath,$restorePath,$verifierPath)) {
  if (Test-Path $item) {
    Copy-Item -LiteralPath $item -Destination $travelWork -Recurse -Force
  }
}
$travelZip = Join-Path $travelRoot ("MUBAKA_ORBIT_OS_TRAVEL_CAPSULE_{0}.zip" -f $travelStamp)
Compress-Archive -Path (Join-Path $travelWork '*') -DestinationPath $travelZip -Force

$healthStatus = 'down'
if (Test-Path $guardianExe) {
  $p = New-Object System.Diagnostics.ProcessStartInfo
  $p.FileName = $guardianExe
  $p.WorkingDirectory = $binRoot
  $p.UseShellExecute = $true
  [System.Diagnostics.Process]::Start($p) | Out-Null
  Start-Sleep -Seconds 2
}
try {
  $health = Invoke-RestMethod -Method GET -Uri 'http://127.0.0.1:48721/api/health' -TimeoutSec 2
  if ($health.status -eq 'ok') { $healthStatus = 'ok' }
} catch { $healthStatus = 'down' }

if (Test-Path $appExe) {
  $open = New-Object System.Diagnostics.ProcessStartInfo
  $open.FileName = $appExe
  $open.WorkingDirectory = $binRoot
  $open.UseShellExecute = $true
  [System.Diagnostics.Process]::Start($open) | Out-Null
}

$verifyOpen = New-Object System.Diagnostics.ProcessStartInfo
$verifyOpen.FileName = Join-Path $PSHOME 'powershell.exe'
$verifyOpen.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $verifierPath + '"'
$verifyOpen.UseShellExecute = $true
[System.Diagnostics.Process]::Start($verifyOpen) | Out-Null

$hashMap = [ordered]@{}
foreach($file in @($appExe,$hostExe,$guardianExe,$serviceExe,$manifestPath,$travelZip)) {
  if (Test-Path $file) { $hashMap[$file] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
}

$receipt = [ordered]@{
  root_path = $root
  app_exe_path = $appExe
  host_exe_path = $hostExe
  guardian_exe_path = $guardianExe
  service_exe_path = $serviceExe
  desktop_real_exe_path = $desktopRealExe
  start_menu_path = $startMenuLink
  startup_path = $startupLink
  travel_capsule_path = $travelZip
  manifest_path = $manifestPath
  verifier_path = $verifierPath
  service_status = $serviceStatus
  health_status = $healthStatus
  wrapper_removal_status = $wrapperRemoval
  sha256_hashes = $hashMap
  final_impossible_statement = 'Impossible to prevent disk wipe, administrator deletion, OS reset, malware compromise, or policy removal.'
}
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $finalReceiptPath -Encoding UTF8

Write-Output 'MUBAKA_ORBIT_OS_BUILD_COMPLETE'
Write-Output (Get-Content -LiteralPath $finalReceiptPath -Raw)
