$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = 'C:\MUBAKA\ORBIT_OS'
$Bin = Join-Path $Root 'bin'
$Src = Join-Path $Root 'src'
$Data = Join-Path $Root 'data'
$Logs = Join-Path $Root 'logs'
$UiDir = Join-Path $Root 'ui'
$ProfileDir = Join-Path $Root '_APP_PROFILE'
$SealDir = Join-Path $Root '_MUBAKA_SEAL'
$BackupDir = Join-Path $SealDir 'backup'
$TravelDir = Join-Path $Root '_TRAVEL'
$ProofDir = Join-Path $Root 'proof'
$HostUrl = 'http://127.0.0.1:43110/'
$OsUrl = 'http://127.0.0.1:43110/os'

$DesktopDir = [Environment]::GetFolderPath('Desktop')
$StartupDir = [Environment]::GetFolderPath('Startup')
$StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MUBAKA ORBIT OS'

$AppExe = Join-Path $Bin 'MUBAKA_ORBIT_APP.exe'
$HostExe = Join-Path $Bin 'MUBAKA_ORBIT_HOST.exe'
$GuardianExe = Join-Path $Bin 'MUBAKA_ORBIT_GUARDIAN.exe'
$ServiceExe = Join-Path $Bin 'MUBAKA_ORBIT_CORE_SERVICE.exe'
$DesktopRealExe = Join-Path $DesktopDir 'MUBAKA ORBIT OS.exe'
$DesktopShortcut = Join-Path $DesktopDir 'MUBAKA ORBIT OS.url'
$StartMenuExe = Join-Path $StartMenuDir 'MUBAKA ORBIT OS.exe'
$StartupExe = Join-Path $StartupDir 'MUBAKA ORBIT OS.exe'
$VerifierPath = Join-Path $Root 'VERIFY_MUBAKA_APPLIANCE.ps1'
$ManifestPath = Join-Path $Root 'INTEGRITY_MANIFEST.json'
$HashesPath = Join-Path $Root 'HASHES.txt'
$SealNotePath = Join-Path $Root 'NATIVE_APPLIANCE_SEAL.txt'
$StatePath = Join-Path $Data 'state.json'
$ModulesPath = Join-Path $Data 'modules.json'
$QueuePath = Join-Path $Data 'queue.ndjson'
$LedgerPath = Join-Path $Data 'ledger.ndjson'
$AuditPath = Join-Path $Data 'audit.ndjson'
$CompileProofPath = Join-Path $ProofDir 'compile_status.json'
$ServiceProofPath = Join-Path $ProofDir 'service_status.json'
$TamperLogPath = Join-Path $Logs 'tamper_watch.log'

$dirs = @($Root,$Bin,$Src,$Data,$Logs,$UiDir,$ProfileDir,$SealDir,$BackupDir,$TravelDir,$ProofDir,$StartMenuDir)
foreach ($d in $dirs) { if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null } }

$WrapperRemoval = [System.Collections.Generic.List[string]]::new()
$wrapperTargets = @($Root,$DesktopDir,$StartMenuDir,$StartupDir)
$wrapperPatterns = @('MUBAKA*.vbs','MUBAKA*.cmd','MUBAKA*.bat','MUBAKA*launcher*')
foreach ($t in $wrapperTargets) {
    if (Test-Path $t) {
        foreach ($pat in $wrapperPatterns) {
            Get-ChildItem -Path $t -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                $WrapperRemoval.Add($_.FullName)
            }
        }
    }
}

$uiHtml = @"
<!doctype html>
<html>
<head>
<meta charset='utf-8' />
<title>MUBAKA ORBIT OS</title>
<style>
body { font-family: Segoe UI, Arial; background: #0b0e13; color: #e5ecf5; margin: 20px; }
.panel { background: #151b24; padding: 16px; border-radius: 8px; }
code { color: #87d5ff; }
</style>
</head>
<body>
<h1>MUBAKA ORBIT OS</h1>
<div class='panel'>
<p>Native localhost appliance is online.</p>
<pre id='health'>loading health</pre>
</div>
<script>
fetch('/api/health').then(r => r.json()).then(x => {
  document.getElementById('health').textContent = JSON.stringify(x, null, 2);
});
</script>
</body>
</html>
"@
Set-Content -Path (Join-Path $UiDir 'index.html') -Value $uiHtml -Encoding UTF8

$appCs = @"
using System;
using System.Diagnostics;
using System.IO;
class MUBAKA_ORBIT_APP {
  static void Main() {
    string root = @"C:\\MUBAKA\\ORBIT_OS";
    string logs = Path.Combine(root, "logs");
    Directory.CreateDirectory(logs);
    string log = Path.Combine(logs, "app_open.log");
    string url = "http://127.0.0.1:43110/os";
    File.AppendAllText(log, DateTime.UtcNow.ToString("o") + " open_request " + url + Environment.NewLine);

    string[] candidates = new string[] {
      Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft\\Edge\\Application\\msedge.exe"),
      Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google\\Chrome\\Application\\chrome.exe"),
      Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "BraveSoftware\\Brave-Browser\\Application\\brave.exe")
    };

    foreach (string exe in candidates) {
      if (File.Exists(exe)) {
        Process.Start(new ProcessStartInfo(exe, "--app=" + url){UseShellExecute=false});
        File.AppendAllText(log, DateTime.UtcNow.ToString("o") + " app_mode " + exe + Environment.NewLine);
        return;
      }
    }

    Process.Start(new ProcessStartInfo(url){UseShellExecute=true});
    File.AppendAllText(log, DateTime.UtcNow.ToString("o") + " default_browser" + Environment.NewLine);
  }
}
"@

$hostCs = @"
using System;
using System.IO;
using System.Net;
using System.Text;
using System.Security.Cryptography;
class MUBAKA_ORBIT_HOST {
  static string Root = @"C:\\MUBAKA\\ORBIT_OS";
  static string Data = Path.Combine(Root, "data");
  static string Logs = Path.Combine(Root, "logs");
  static string Ui = Path.Combine(Root, "ui", "index.html");
  static string Queue = Path.Combine(Data, "queue.ndjson");
  static string Ledger = Path.Combine(Data, "ledger.ndjson");
  static string Audit = Path.Combine(Data, "audit.ndjson");
  static string Modules = Path.Combine(Data, "modules.json");
  static string Manifest = Path.Combine(Root, "INTEGRITY_MANIFEST.json");

  static void Main() {
    Directory.CreateDirectory(Data);
    Directory.CreateDirectory(Logs);
    var listener = new HttpListener();
    listener.Prefixes.Add("http://127.0.0.1:43110/");
    listener.Start();
    Log("host_started_127.0.0.1");
    while (true) {
      var ctx = listener.GetContext();
      Handle(ctx);
    }
  }

  static void Handle(HttpListenerContext c) {
    try {
      string p = c.Request.Url.AbsolutePath;
      if (p == "/os") { Reply(c, File.Exists(Ui) ? File.ReadAllText(Ui) : "ui_missing", "text/html"); return; }
      if (p == "/api/health") { Reply(c, "{\"status\":\"ok\",\"host\":\"127.0.0.1\",\"utc\":\""+DateTime.UtcNow.ToString("o")+"\"}", "application/json"); return; }
      if (p == "/api/modules") { Reply(c, File.Exists(Modules)?File.ReadAllText(Modules):"[]", "application/json"); return; }
      if (p == "/api/queue") { Reply(c, File.Exists(Queue)?File.ReadAllText(Queue):"", "application/x-ndjson"); return; }
      if (p == "/api/ledger") { Reply(c, File.Exists(Ledger)?File.ReadAllText(Ledger):"", "application/x-ndjson"); return; }
      if (p == "/api/proof") { Reply(c, "{\"manifest\":\"" + Manifest.Replace("\\", "\\\\") + "\"}", "application/json"); return; }
      if (p == "/api/route" && c.Request.HttpMethod == "POST") {
        using (var reader = new StreamReader(c.Request.InputStream)) {
          string body = reader.ReadToEnd();
          File.AppendAllText(Queue, body + "\n");
          string hash = Sha256(body);
          File.AppendAllText(Ledger, "{\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\",\"sha256\":\"" + hash + "\"}\n");
          File.AppendAllText(Audit, "{\"event\":\"route\",\"utc\":\"" + DateTime.UtcNow.ToString("o") + "\"}\n");
          Reply(c, "{\"ok\":true,\"sha256\":\""+hash+"\"}", "application/json");
          return;
        }
      }
      c.Response.StatusCode = 404;
      Reply(c, "not_found", "text/plain");
    } catch (Exception ex) {
      Log("error " + ex.Message);
      c.Response.StatusCode = 500;
      Reply(c, "error", "text/plain");
    }
  }

  static string Sha256(string text) {
    using (var sha = SHA256.Create()) {
      var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(text));
      var sb = new StringBuilder();
      foreach (var b in bytes) sb.Append(b.ToString("x2"));
      return sb.ToString();
    }
  }

  static void Reply(HttpListenerContext c, string content, string type) {
    byte[] bytes = Encoding.UTF8.GetBytes(content);
    c.Response.ContentType = type;
    c.Response.ContentEncoding = Encoding.UTF8;
    c.Response.OutputStream.Write(bytes, 0, bytes.Length);
    c.Response.Close();
  }

  static void Log(string msg) {
    File.AppendAllText(Path.Combine(Logs, "native_host.log"), DateTime.UtcNow.ToString("o") + " " + msg + Environment.NewLine);
  }
}
"@

$guardianCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
class MUBAKA_ORBIT_GUARDIAN {
  static string Root = @"C:\\MUBAKA\\ORBIT_OS";
  static string Bin = Path.Combine(Root, "bin");
  static string Backup = Path.Combine(Root, "_MUBAKA_SEAL", "backup");
  static string Logs = Path.Combine(Root, "logs");

  static void Main() {
    Directory.CreateDirectory(Logs);
    EnsureFromBackup("MUBAKA_ORBIT_APP.exe");
    EnsureFromBackup("MUBAKA_ORBIT_HOST.exe");
    EnsureFromBackup("MUBAKA_ORBIT_GUARDIAN.exe");
    EnsureFromBackup("MUBAKA_ORBIT_CORE_SERVICE.exe");
    EnsureHost();
    CheckHealth();
  }

  static void EnsureFromBackup(string name) {
    string live = Path.Combine(Bin, name);
    string sealedCopy = Path.Combine(Backup, name);
    if (!File.Exists(live) && File.Exists(sealedCopy)) {
      File.Copy(sealedCopy, live, true);
      Log("restored " + name);
    }
  }

  static void EnsureHost() {
    bool hostRunning = Process.GetProcessesByName("MUBAKA_ORBIT_HOST").Length > 0;
    string hostExe = Path.Combine(Bin, "MUBAKA_ORBIT_HOST.exe");
    if (!hostRunning && File.Exists(hostExe)) {
      Process.Start(new ProcessStartInfo(hostExe){UseShellExecute=false,CreateNoWindow=true});
      Log("host_started");
    }
  }

  static void CheckHealth() {
    try {
      var req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:43110/api/health");
      req.Method = "GET";
      using (var res = (HttpWebResponse)req.GetResponse()) {
        Log("health_" + ((int)res.StatusCode));
      }
    } catch (Exception ex) {
      Log("health_fail " + ex.Message);
    }
  }

  static void Log(string msg) {
    File.AppendAllText(Path.Combine(Logs, "native_guardian.log"), DateTime.UtcNow.ToString("o") + " " + msg + Environment.NewLine);
  }
}
"@

$serviceCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Timers;
public class MUBAKA_ORBIT_CORE_SERVICE : ServiceBase {
  private Timer timer;
  private string root = @"C:\\MUBAKA\\ORBIT_OS";

  protected override void OnStart(string[] args) {
    timer = new Timer(30000);
    timer.Elapsed += (s,e) => Pulse();
    timer.AutoReset = true;
    timer.Start();
    Pulse();
  }

  private void Pulse() {
    string exe = Path.Combine(root, "bin", "MUBAKA_ORBIT_GUARDIAN.exe");
    if (File.Exists(exe)) {
      Process.Start(new ProcessStartInfo(exe){UseShellExecute=false,CreateNoWindow=true});
      File.AppendAllText(Path.Combine(root, "logs", "core_service.log"), DateTime.UtcNow.ToString("o") + " pulse" + Environment.NewLine);
    }
  }

  protected override void OnStop() {
    if (timer != null) { timer.Stop(); timer.Dispose(); }
  }

  public static void Main() {
    ServiceBase.Run(new MUBAKA_ORBIT_CORE_SERVICE(){ ServiceName = "MUBAKAOrbitCore" });
  }
}
"@

Set-Content -Path (Join-Path $Src 'MUBAKA_ORBIT_APP.cs') -Value $appCs -Encoding UTF8
Set-Content -Path (Join-Path $Src 'MUBAKA_ORBIT_HOST.cs') -Value $hostCs -Encoding UTF8
Set-Content -Path (Join-Path $Src 'MUBAKA_ORBIT_GUARDIAN.cs') -Value $guardianCs -Encoding UTF8
Set-Content -Path (Join-Path $Src 'MUBAKA_ORBIT_CORE_SERVICE.cs') -Value $serviceCs -Encoding UTF8

$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
if (Get-Command csc.exe -ErrorAction SilentlyContinue) { $cscCandidates = @((Get-Command csc.exe).Source) + $cscCandidates }
$csc = $cscCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$compileStatus = [ordered]@{ compiler=''; status='not_run'; outputs=@{} }
if ($csc) {
    & $csc /nologo /target:winexe /out:$AppExe (Join-Path $Src 'MUBAKA_ORBIT_APP.cs') | Out-Null
    & $csc /nologo /target:exe /out:$HostExe (Join-Path $Src 'MUBAKA_ORBIT_HOST.cs') | Out-Null
    & $csc /nologo /target:exe /out:$GuardianExe (Join-Path $Src 'MUBAKA_ORBIT_GUARDIAN.cs') | Out-Null
    & $csc /nologo /target:exe /reference:System.ServiceProcess.dll /out:$ServiceExe (Join-Path $Src 'MUBAKA_ORBIT_CORE_SERVICE.cs') | Out-Null
    $compileStatus.compiler = $csc
    $compileStatus.status = 'compiled'
} else {
    $compileStatus.status = 'compiler_unavailable'
    $compileStatus.outputs = @{ required='csc.exe not found; existing binaries required in sealed backup' }
}
$compileStatus.outputs = @{
    app = (Test-Path $AppExe)
    host = (Test-Path $HostExe)
    guardian = (Test-Path $GuardianExe)
    service = (Test-Path $ServiceExe)
}
$compileStatus | ConvertTo-Json -Depth 5 | Set-Content -Path $CompileProofPath -Encoding UTF8

$state = [ordered]@{
    system_identity = 'MUBAKA ORBIT OS'
    version = '1.0.0'
    realm = 'inside+outside'
    mode = 'native_appliance'
    posture = 'binary_fused'
    host_binding = '127.0.0.1'
    updated_utc = (Get-Date).ToUniversalTime().ToString('o')
}
$state | ConvertTo-Json -Depth 5 | Set-Content -Path $StatePath -Encoding UTF8

$modules = @(
    [ordered]@{ name='MUBAKA_ORBIT_APP'; status='active'; purpose='Native app opener'; launch_path=$AppExe; verify_path='app_open.log'; restore_path=(Join-Path $BackupDir 'MUBAKA_ORBIT_APP.exe') },
    [ordered]@{ name='MUBAKA_ORBIT_HOST'; status='active'; purpose='127.0.0.1 localhost host'; launch_path=$HostExe; verify_path='http://127.0.0.1:43110/api/health'; restore_path=(Join-Path $BackupDir 'MUBAKA_ORBIT_HOST.exe') },
    [ordered]@{ name='MUBAKA_ORBIT_GUARDIAN'; status='active'; purpose='Restore and health guardian'; launch_path=$GuardianExe; verify_path='native_guardian.log'; restore_path=(Join-Path $BackupDir 'MUBAKA_ORBIT_GUARDIAN.exe') },
    [ordered]@{ name='MUBAKA_ORBIT_CORE_SERVICE'; status='active'; purpose='Service-grade guardian pulse'; launch_path=$ServiceExe; verify_path='sc query MUBAKAOrbitCore'; restore_path=(Join-Path $BackupDir 'MUBAKA_ORBIT_CORE_SERVICE.exe') }
)
$modules | ConvertTo-Json -Depth 7 | Set-Content -Path $ModulesPath -Encoding UTF8

foreach ($f in @($QueuePath,$LedgerPath,$AuditPath,$TamperLogPath)) { if (-not (Test-Path $f)) { New-Item -Path $f -ItemType File | Out-Null } }

$serviceStatus = 'not_attempted'
try {
    sc.exe query MUBAKAOrbitCore | Out-Null
    if ($LASTEXITCODE -ne 0) {
        sc.exe create MUBAKAOrbitCore binPath= "`"$ServiceExe`"" start= auto | Out-Null
        sc.exe failure MUBAKAOrbitCore reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
    }
    sc.exe start MUBAKAOrbitCore | Out-Null
    $serviceStatus = 'installed_or_running'
} catch {
    $serviceStatus = 'install_failed_fallback_active'
}
[ordered]@{ service_status=$serviceStatus; utc=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -Path $ServiceProofPath -Encoding UTF8

$taskGuardianCmd = "`"$GuardianExe`""
schtasks.exe /Create /TN 'MUBAKA_ORBIT_GUARDIAN_MINUTE' /SC MINUTE /MO 1 /TR $taskGuardianCmd /F | Out-Null
schtasks.exe /Create /TN 'MUBAKA_ORBIT_GUARDIAN_STARTUP' /SC ONSTART /TR $taskGuardianCmd /F | Out-Null
schtasks.exe /Create /TN 'MUBAKA_ORBIT_GUARDIAN_LOGON' /SC ONLOGON /TR $taskGuardianCmd /F | Out-Null

reg.exe add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' /v 'MUBAKAOrbitApp' /t REG_SZ /d "`"$AppExe`"" /f | Out-Null
reg.exe add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' /v 'MUBAKAOrbitGuardian' /t REG_SZ /d "`"$GuardianExe`"" /f | Out-Null

if (Test-Path $AppExe) { Copy-Item -Path $AppExe -Destination $DesktopRealExe -Force }
Set-Content -Path $DesktopShortcut -Value "[InternetShortcut]`r`nURL=$OsUrl`r`nIconFile=$DesktopRealExe`r`nIconIndex=0" -Encoding ASCII
if (Test-Path $AppExe) { Copy-Item -Path $AppExe -Destination $StartMenuExe -Force }
if (Test-Path $AppExe) { Copy-Item -Path $AppExe -Destination $StartupExe -Force }

$sealNote = @"
MUBAKA ORBIT OS Native Appliance Seal
Root: $Root
Sealed UTC: $((Get-Date).ToUniversalTime().ToString('o'))
Scope: app, host, guardian, core_service, ui, state, modules, queue, ledger, audit, manifest, hashes, verifier
Removal reality: disk wipe, administrator deletion, Windows reset, active malware, or policy removal can remove this appliance.
"@
Set-Content -Path $SealNotePath -Value $sealNote -Encoding UTF8

$restoreScript = @"
param([string]`$Root = 'C:\MUBAKA\ORBIT_OS')
`$Backup = Join-Path `$Root '_MUBAKA_SEAL\\backup'
`$Bin = Join-Path `$Root 'bin'
`$Data = Join-Path `$Root 'data'
`$Ui = Join-Path `$Root 'ui'
New-Item -Path `$Bin,`$Data,`$Ui -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path `$Backup 'MUBAKA_ORBIT_APP.exe') (Join-Path `$Bin 'MUBAKA_ORBIT_APP.exe') -Force
Copy-Item (Join-Path `$Backup 'MUBAKA_ORBIT_HOST.exe') (Join-Path `$Bin 'MUBAKA_ORBIT_HOST.exe') -Force
Copy-Item (Join-Path `$Backup 'MUBAKA_ORBIT_GUARDIAN.exe') (Join-Path `$Bin 'MUBAKA_ORBIT_GUARDIAN.exe') -Force
Copy-Item (Join-Path `$Backup 'MUBAKA_ORBIT_CORE_SERVICE.exe') (Join-Path `$Bin 'MUBAKA_ORBIT_CORE_SERVICE.exe') -Force
Copy-Item (Join-Path `$Backup 'index.html') (Join-Path `$Ui 'index.html') -Force
Copy-Item (Join-Path `$Backup 'state.json') (Join-Path `$Data 'state.json') -Force
Copy-Item (Join-Path `$Backup 'modules.json') (Join-Path `$Data 'modules.json') -Force
Copy-Item (Join-Path `$Backup 'queue.ndjson') (Join-Path `$Data 'queue.ndjson') -Force
Copy-Item (Join-Path `$Backup 'ledger.ndjson') (Join-Path `$Data 'ledger.ndjson') -Force
Copy-Item (Join-Path `$Backup 'audit.ndjson') (Join-Path `$Data 'audit.ndjson') -Force
Copy-Item (Join-Path `$Backup 'INTEGRITY_MANIFEST.json') (Join-Path `$Root 'INTEGRITY_MANIFEST.json') -Force
"@
$RestorePath = Join-Path $TravelDir 'RESTORE_MUBAKA_ORBIT.ps1'
Set-Content -Path $RestorePath -Value $restoreScript -Encoding UTF8
Set-Content -Path (Join-Path $TravelDir 'REHYDRATION_COMMAND.txt') -Value 'powershell -ExecutionPolicy Bypass -File .\RESTORE_MUBAKA_ORBIT.ps1' -Encoding UTF8
Set-Content -Path (Join-Path $TravelDir 'BOOTABLE_VM_ARCHITECTURE.txt') -Value 'Portable target: Windows 10/11 x64 VM or physical host with .NET Framework runtime.' -Encoding UTF8

$verifyScript = @"
`$ErrorActionPreference='Continue'
`$Root='C:\MUBAKA\ORBIT_OS'
`$Bin=Join-Path `$Root 'bin'
`$Data=Join-Path `$Root 'data'
`$Seal=Join-Path `$Root '_MUBAKA_SEAL\\backup'
`$Travel=Join-Path `$Root '_TRAVEL'
`$Desktop=[Environment]::GetFolderPath('Desktop')
`$Startup=[Environment]::GetFolderPath('Startup')
`$StartMenu=Join-Path `$env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MUBAKA ORBIT OS\MUBAKA ORBIT OS.exe'
`$checks=[ordered]@{}
`$checks.app_exe=Test-Path (Join-Path `$Bin 'MUBAKA_ORBIT_APP.exe')
`$checks.host_exe=Test-Path (Join-Path `$Bin 'MUBAKA_ORBIT_HOST.exe')
`$checks.guardian_exe=Test-Path (Join-Path `$Bin 'MUBAKA_ORBIT_GUARDIAN.exe')
`$checks.service_exe=Test-Path (Join-Path `$Bin 'MUBAKA_ORBIT_CORE_SERVICE.exe')
`$checks.state=Test-Path (Join-Path `$Data 'state.json')
`$checks.modules=Test-Path (Join-Path `$Data 'modules.json')
`$checks.ledger=Test-Path (Join-Path `$Data 'ledger.ndjson')
`$checks.queue=Test-Path (Join-Path `$Data 'queue.ndjson')
`$checks.audit=Test-Path (Join-Path `$Data 'audit.ndjson')
`$checks.manifest=Test-Path (Join-Path `$Root 'INTEGRITY_MANIFEST.json')
`$checks.hashes=Test-Path (Join-Path `$Root 'HASHES.txt')
`$checks.sealed_backup=Test-Path `$Seal
`$checks.travel_capsule=((Get-ChildItem `$Travel -Filter '*.zip' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
`$checks.bad_wrappers_removed=((Get-ChildItem `$Desktop -Filter 'MUBAKA*.vbs' -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) -and ((Get-ChildItem `$Desktop -Filter 'MUBAKA*.cmd' -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) -and ((Get-ChildItem `$Desktop -Filter 'MUBAKA*.bat' -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)
try { `$h=Invoke-RestMethod 'http://127.0.0.1:43110/api/health' -TimeoutSec 3; `$checks.localhost_health_ok = (`$h.status -eq 'ok') } catch { `$checks.localhost_health_ok = `$false }
`$checks.service_installed_running=((sc.exe query MUBAKAOrbitCore 2>`$null | Out-String) -match 'STATE')
`$checks.task_minute=((schtasks.exe /Query /TN 'MUBAKA_ORBIT_GUARDIAN_MINUTE' 2>`$null | Out-String) -match 'MUBAKA_ORBIT_GUARDIAN_MINUTE')
`$checks.task_startup=((schtasks.exe /Query /TN 'MUBAKA_ORBIT_GUARDIAN_STARTUP' 2>`$null | Out-String) -match 'MUBAKA_ORBIT_GUARDIAN_STARTUP')
`$checks.task_logon=((schtasks.exe /Query /TN 'MUBAKA_ORBIT_GUARDIAN_LOGON' 2>`$null | Out-String) -match 'MUBAKA_ORBIT_GUARDIAN_LOGON')
`$run=(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' 2>`$null | Out-String)
`$checks.run_keys=((`$run -match 'MUBAKAOrbitApp') -and (`$run -match 'MUBAKAOrbitGuardian'))
`$checks.desktop_real_exe=Test-Path (Join-Path `$Desktop 'MUBAKA ORBIT OS.exe')
`$checks.start_menu_entry=Test-Path `$StartMenu
`$checks.startup_entry=Test-Path (Join-Path `$Startup 'MUBAKA ORBIT OS.exe')
`$checks | ConvertTo-Json -Depth 4
"@
Set-Content -Path $VerifierPath -Value $verifyScript -Encoding UTF8

$coreArtifacts = @(
    $AppExe,$HostExe,$GuardianExe,$ServiceExe,
    (Join-Path $UiDir 'index.html'),
    $StatePath,$ModulesPath,$QueuePath,$LedgerPath,$AuditPath,
    $VerifierPath,$SealNotePath
)
$hashRecords = [System.Collections.Generic.List[object]]::new()
foreach ($file in $coreArtifacts) {
    if (Test-Path $file) {
        $h = Get-FileHash -Path $file -Algorithm SHA256
        $hashRecords.Add([ordered]@{ file=$file; sha256=$h.Hash })
    }
}
$hashRecords | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestPath -Encoding UTF8
$manifestHash = Get-FileHash -Path $ManifestPath -Algorithm SHA256
$hashRecords.Add([ordered]@{ file=$ManifestPath; sha256=$manifestHash.Hash })
$hashRecords | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestPath -Encoding UTF8
$hashLines = $hashRecords | ForEach-Object { "{0}  {1}" -f $_.sha256, $_.file }
Set-Content -Path $HashesPath -Value $hashLines -Encoding UTF8

$sealCopies = @($AppExe,$HostExe,$GuardianExe,$ServiceExe,(Join-Path $UiDir 'index.html'),$StatePath,$ModulesPath,$LedgerPath,$QueuePath,$AuditPath,$ManifestPath,$HashesPath,$SealNotePath,$VerifierPath)
foreach ($f in $sealCopies) { if (Test-Path $f) { Copy-Item -Path $f -Destination (Join-Path $BackupDir ([IO.Path]::GetFileName($f))) -Force } }

Copy-Item -Path $ManifestPath -Destination (Join-Path $BackupDir 'INTEGRITY_MANIFEST.json') -Force

$TravelCapsule = Join-Path $TravelDir ('MUBAKA_ORBIT_TRAVEL_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
if (Test-Path $TravelCapsule) { Remove-Item -Path $TravelCapsule -Force }
Compress-Archive -Path (Join-Path $Root '*') -DestinationPath $TravelCapsule -Force

$userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
foreach ($p in @($Root,$Bin,$Data,$Logs,$UiDir,$SealDir,$TravelDir,$ProfileDir)) {
    icacls $p /inheritance:r /grant:r "$userName:(OI)(CI)F" "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" /T /C | Out-Null
}

if (Test-Path $GuardianExe) { [System.Diagnostics.Process]::Start($GuardianExe) | Out-Null }
Start-Sleep -Seconds 2
if (Test-Path $AppExe) { [System.Diagnostics.Process]::Start($AppExe) | Out-Null }
[System.Diagnostics.Process]::Start('powershell.exe', "-ExecutionPolicy Bypass -File `"$VerifierPath`"") | Out-Null

$health = 'down'
try {
    $h = Invoke-RestMethod -Uri 'http://127.0.0.1:43110/api/health' -TimeoutSec 3
    if ($h.status -eq 'ok') { $health = 'ok' }
} catch { $health = 'down' }

$FinalReceipt = [ordered]@{
    root_path = $Root
    app_exe_path = $AppExe
    host_exe_path = $HostExe
    guardian_exe_path = $GuardianExe
    service_exe_path = $ServiceExe
    desktop_real_exe_path = $DesktopRealExe
    start_menu_path = $StartMenuExe
    startup_path = $StartupExe
    travel_capsule_path = $TravelCapsule
    manifest_path = $ManifestPath
    hashes_path = $HashesPath
    verifier_path = $VerifierPath
    service_status = $serviceStatus
    health_status = $health
    wrapper_removal_status = $(if ($WrapperRemoval.Count -gt 0) { 'removed:' + ($WrapperRemoval -join ';') } else { 'none_found' })
    sha256_hashes = $hashRecords
    impossible_statement = 'Disk wipe, administrator deletion, Windows reset, active malware, or policy removal can still remove this appliance.'
}
$FinalReceipt | ConvertTo-Json -Depth 7
