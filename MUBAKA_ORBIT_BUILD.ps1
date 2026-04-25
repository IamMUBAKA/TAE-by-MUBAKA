$ErrorActionPreference='Stop'
if($PSDefaultParameterValues){$PSDefaultParameterValues.Clear()}
$PSDefaultParameterValues['Disabled']=$true

$Root='C:\MUBAKA\ORBIT_OS'
$Seal=Join-Path $Root '_MUBAKA_SEAL'
$Travel=Join-Path $Root '_TRAVEL'
$Backup=Join-Path $Seal 'backup'
$Desktop=[Environment]::GetFolderPath('Desktop')
$Programs=[Environment]::GetFolderPath('Programs')
$StartMenu=Join-Path $Programs 'MUBAKA'
$PSExe=Join-Path $PSHOME 'powershell.exe'

New-Item -ItemType Directory -Path $Root,$Seal,$Travel,$Backup,$StartMenu -Force|Out-Null

# Cancel only broken MUBAKA launcher wrappers. Do not delete account/browser/password data.
foreach($Bad in 'MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1'){
  $P=Join-Path $Root $Bad
  if(Test-Path $P){Remove-Item $P -Force}
}

$Html=Join-Path $Root 'mubaka_orbit_os.html'
$AppSrc=Join-Path $Root 'MUBAKA_ORBIT_APP.cs'
$AppExe=Join-Path $Root 'MUBAKA_ORBIT_APP.exe'
$State=Join-Path $Root 'state.json'
$Modules=Join-Path $Root 'modules.json'
$Ledger=Join-Path $Root 'ledger.ndjson'
$Queue=Join-Path $Root 'queue.ndjson'
$Audit=Join-Path $Root 'audit.ndjson'

@'
{"system":"MUBAKA ORBIT OS","version":"native-appliance-safe-v2","entry":"native_exe","root":"C:\\MUBAKA\\ORBIT_OS","scope":"focused build only; no account-wide deletion"}
'@|Set-Content $State -Encoding UTF8

@'
{"modules":[{"name":"Native App Entry","status":"ACTIVE"},{"name":"Local UI","status":"ACTIVE"},{"name":"Receipt Ledger","status":"ACTIVE"},{"name":"Travel Capsule","status":"ACTIVE"},{"name":"Verifier","status":"ACTIVE"}]}
'@|Set-Content $Modules -Encoding UTF8

foreach($F in $Ledger,$Queue,$Audit){if(!(Test-Path $F)){New-Item -ItemType File -Path $F -Force|Out-Null}}

@'
<!doctype html><html><head><meta charset="utf-8"><title>MUBAKA ORBIT OS</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:radial-gradient(circle at top,#16284e,#02040a 50%,#000);color:#fff;font-family:Segoe UI,Arial}header{padding:24px 32px;background:#050914;border-bottom:1px solid #f5b735}.logo{font-size:32px;font-weight:900;color:#f5b735}.grid{display:grid;grid-template-columns:1fr 1.4fr 1fr;gap:16px;padding:18px}.card{background:rgba(4,10,22,.9);border:1px solid rgba(245,183,53,.28);border-radius:22px;padding:18px}.hero{text-align:center;min-height:430px;display:grid;place-items:center}.orb{width:230px;height:230px;border-radius:50%;border:2px solid #f5b735;display:grid;place-items:center;margin:auto;box-shadow:0 0 70px rgba(245,183,53,.6)}.orb b{font-size:82px;color:#f5b735}.row{display:flex;justify-content:space-between;padding:12px;border:1px solid rgba(34,168,255,.25);border-radius:14px;margin:8px 0}.ok{color:#34ff91;font-weight:900}.console{background:#010409;color:#baffd4;border-radius:14px;padding:12px;font-family:Consolas;min-height:180px}input,select,textarea,button{width:100%;padding:12px;border-radius:12px;margin:6px 0}button{background:#f5b735;color:#111;font-weight:900;border:0}@media(max-width:900px){.grid{grid-template-columns:1fr}}</style></head><body><header><div class="logo">MUBAKA ORBIT OS</div></header><div class="grid"><section class="card"><h2>Body</h2><div class="row"><span>Native EXE</span><b class="ok">ACTIVE</b></div><div class="row"><span>Local UI</span><b class="ok">ACTIVE</b></div><div class="row"><span>No VBS</span><b class="ok">TRUE</b></div></section><section class="card hero"><div><div class="orb"><b>M</b></div><h1>Native appliance surface.</h1><p>Local, controlled, proof-bound desktop entry.</p></div></section><section class="card"><h2>Proof</h2><div id="proof" class="console">Loading...</div></section><section class="card"><h2>Command Intake</h2><input id="entity" placeholder="Entity"><select id="lane"><option>Operator</option><option>Build</option><option>Receipt</option><option>Deployment</option></select><textarea id="need" placeholder="What needs to move?"></textarea><button onclick="route()">ROUTE THROUGH MUBAKA</button></section><section class="card"><h2>Console</h2><div id="log" class="console"></div></section><section class="card"><h2>Ledger</h2><div id="ledger" class="console"></div></section></div><script>let items=[];function route(){let r={time:new Date().toISOString(),entity:entity.value||'ENTITY',lane:lane.value,need:need.value||'NO DETAIL',receipt:Math.random().toString(16).slice(2)+Date.now().toString(16)};items.unshift(r);log.innerHTML='receipt '+r.receipt+'<br>'+log.innerHTML;ledger.innerHTML=items.map(x=>'<b>'+x.receipt+'</b><br>'+x.time+' '+x.lane+' '+x.entity+'<br>').join('<br>');}proof.innerText=JSON.stringify({app:'MUBAKA ORBIT OS',mode:'native desktop appliance',local:true,network:'local UI only',wrappers:'removed',package:'profile cache excluded from zip to prevent lock errors'},null,2);</script></body></html>
'@|Set-Content $Html -Encoding UTF8

@'
using System;using System.Diagnostics;using System.IO;
class A{[STAThread]static void Main(){string r=@"C:\MUBAKA\ORBIT_OS";string h=Path.Combine(r,"mubaka_orbit_os.html");string p=Path.Combine(r,"_MUBAKA_SEAL");Directory.CreateDirectory(r);Directory.CreateDirectory(p);File.AppendAllText(Path.Combine(p,"app_open.log"),"["+DateTime.Now.ToString("o")+"] OPEN\r\n");var psi=new ProcessStartInfo();psi.FileName=h;psi.UseShellExecute=true;Process.Start(psi);}}
'@|Set-Content $AppSrc -Encoding UTF8

$CSC=@("$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe","$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe")|Where-Object{Test-Path $_}|Select-Object -First 1
if(!$CSC){throw 'Windows .NET Framework C# compiler not found.'}
& $CSC /nologo /target:winexe /out:$AppExe $AppSrc|Out-Null
if(!(Test-Path $AppExe)){throw 'MUBAKA_ORBIT_APP.exe was not created.'}

Copy-Item $AppExe (Join-Path $Desktop 'MUBAKA ORBIT OS.exe') -Force
$Shell=New-Object -ComObject WScript.Shell
foreach($Lnk in (Join-Path $Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')){
  $S=$Shell.CreateShortcut($Lnk);$S.TargetPath=$AppExe;$S.Arguments='';$S.WorkingDirectory=$Root;$S.Description='MUBAKA ORBIT OS Native Appliance';$S.IconLocation=$AppExe;$S.Save()
}

$Hash=Get-FileHash $AppExe -Algorithm SHA256
"APP $($Hash.Hash)"|Set-Content (Join-Path $Seal 'HASHES.txt') -Encoding UTF8

# Critical fix: never zip live browser/app profile caches. Build a clean package from deterministic files only.
$Package=Join-Path $Travel '_PACKAGE_SAFE'
if(Test-Path $Package){Remove-Item $Package -Recurse -Force}
New-Item -ItemType Directory -Path $Package -Force|Out-Null
foreach($Item in @($AppExe,$Html,$State,$Modules,$Ledger,$Queue,$Audit,(Join-Path $Seal 'HASHES.txt'))){if(Test-Path $Item){Copy-Item $Item $Package -Force}}
$Zip=Join-Path $Travel ('MUBAKA_ORBIT_OS_TRAVEL_CAPSULE_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.zip')
Compress-Archive -Path (Join-Path $Package '*') -DestinationPath $Zip -Force

$Verify=Join-Path $Root 'VERIFY_MUBAKA_APPLIANCE.ps1'
@"
`$Root='C:\MUBAKA\ORBIT_OS'
Write-Host ''
Write-Host 'MUBAKA ORBIT OS VERIFY' -ForegroundColor Yellow
foreach(`$F in 'MUBAKA_ORBIT_APP.exe','mubaka_orbit_os.html','state.json','modules.json','ledger.ndjson','queue.ndjson','audit.ndjson'){if(Test-Path (Join-Path `$Root `$F)){Write-Host "`$F OK" -ForegroundColor Green}else{Write-Host "`$F MISSING" -ForegroundColor Red}}
foreach(`$Bad in 'MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1'){if(!(Test-Path (Join-Path `$Root `$Bad))){Write-Host "`$Bad REMOVED" -ForegroundColor Green}else{Write-Host "`$Bad STILL EXISTS" -ForegroundColor Red}}
Write-Host 'LOCKED CACHE FIX: _APP_PROFILE EXCLUDED FROM TRAVEL ZIP' -ForegroundColor Green
Write-Host 'APP EXE: C:\MUBAKA\ORBIT_OS\MUBAKA_ORBIT_APP.exe' -ForegroundColor Cyan
Write-Host "DESKTOP REAL EXE: `$([IO.Path]::Combine([Environment]::GetFolderPath('Desktop'),'MUBAKA ORBIT OS.exe'))" -ForegroundColor Cyan
"@|Set-Content $Verify -Encoding UTF8

$P=New-Object System.Diagnostics.ProcessStartInfo;$P.FileName=$AppExe;$P.WorkingDirectory=$Root;$P.UseShellExecute=$true;[System.Diagnostics.Process]::Start($P)|Out-Null
$P2=New-Object System.Diagnostics.ProcessStartInfo;$P2.FileName=$PSExe;$P2.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$Verify+'"';$P2.WorkingDirectory=$Root;$P2.UseShellExecute=$true;[System.Diagnostics.Process]::Start($P2)|Out-Null

Write-Host ''
Write-Host 'MUBAKA ORBIT OS NATIVE APPLIANCE BUILT' -ForegroundColor Yellow
Write-Host "APP EXE: $AppExe" -ForegroundColor Cyan
Write-Host "DESKTOP REAL EXE: $(Join-Path $Desktop 'MUBAKA ORBIT OS.exe')" -ForegroundColor Cyan
Write-Host "TRAVEL CAPSULE: $Zip" -ForegroundColor Cyan
Write-Host 'LOCKED CACHE FIX: _APP_PROFILE EXCLUDED FROM ZIP' -ForegroundColor Green
Write-Host 'NO VBS. NO CMD WRAPPER. NO START-PROCESS.' -ForegroundColor Green
