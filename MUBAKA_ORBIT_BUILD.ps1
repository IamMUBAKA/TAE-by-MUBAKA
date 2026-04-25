$ErrorActionPreference='Stop'
if($PSDefaultParameterValues){$PSDefaultParameterValues.Clear()}
$PSDefaultParameterValues['Disabled']=$true
$Root='C:\MUBAKA\ORBIT_OS'
$Seal=Join-Path $Root '_MUBAKA_SEAL'
$Travel=Join-Path $Root '_TRAVEL'
$Profile=Join-Path $Root '_APP_PROFILE'
$Desktop=[Environment]::GetFolderPath('Desktop')
$Programs=[Environment]::GetFolderPath('Programs')
$StartMenu=Join-Path $Programs 'MUBAKA'
New-Item -ItemType Directory -Path $Root,$Seal,$Travel,$Profile,$StartMenu -Force|Out-Null
foreach($Bad in 'MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1'){ $P=Join-Path $Root $Bad; if(Test-Path $P){Remove-Item $P -Force}}
$Html=Join-Path $Root 'mubaka_orbit_os.html'
@'
<!doctype html><html><head><meta charset="utf-8"><title>MUBAKA ORBIT OS</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:radial-gradient(circle at top,#16284e,#02040a 50%,#000);color:#fff;font-family:Segoe UI,Arial}header{padding:24px 32px;background:#050914;border-bottom:1px solid #f5b735}.logo{font-size:32px;font-weight:900;color:#f5b735}.grid{display:grid;grid-template-columns:1fr 1.4fr 1fr;gap:16px;padding:18px}.card{background:rgba(4,10,22,.9);border:1px solid rgba(245,183,53,.28);border-radius:22px;padding:18px}.hero{text-align:center;min-height:430px;display:grid;place-items:center}.orb{width:230px;height:230px;border-radius:50%;border:2px solid #f5b735;display:grid;place-items:center;margin:auto;box-shadow:0 0 70px rgba(245,183,53,.6)}.orb b{font-size:82px;color:#f5b735}.row{display:flex;justify-content:space-between;padding:12px;border:1px solid rgba(34,168,255,.25);border-radius:14px;margin:8px 0}.ok{color:#34ff91;font-weight:900}.console{background:#010409;color:#baffd4;border-radius:14px;padding:12px;font-family:Consolas;min-height:180px}input,select,textarea,button{width:100%;padding:12px;border-radius:12px;margin:6px 0}button{background:#f5b735;color:#111;font-weight:900;border:0}@media(max-width:900px){.grid{grid-template-columns:1fr}}</style></head><body><header><div class="logo">MUBAKA ORBIT OS</div></header><div class="grid"><section class="card"><h2>Body</h2><div class="row"><span>Native EXE</span><b class="ok">ACTIVE</b></div><div class="row"><span>Local UI</span><b class="ok">ACTIVE</b></div><div class="row"><span>No VBS</span><b class="ok">TRUE</b></div></section><section class="card hero"><div><div class="orb"><b>M</b></div><h1>Native appliance surface.</h1><p>Local, controlled, proof-bound desktop entry.</p></div></section><section class="card"><h2>Proof</h2><div id="proof" class="console">Loading...</div></section><section class="card"><h2>Command Intake</h2><input id="entity" placeholder="Entity"><select id="lane"><option>Operator</option><option>Build</option><option>Receipt</option><option>Deployment</option></select><textarea id="need" placeholder="What needs to move?"></textarea><button onclick="route()">ROUTE THROUGH MUBAKA</button></section><section class="card"><h2>Console</h2><div id="log" class="console"></div></section><section class="card"><h2>Ledger</h2><div id="ledger" class="console"></div></section></div><script>let items=[];function route(){let r={time:new Date().toISOString(),entity:entity.value||'ENTITY',lane:lane.value,need:need.value||'NO DETAIL',receipt:Math.random().toString(16).slice(2)+Date.now().toString(16)};items.unshift(r);log.innerHTML='receipt '+r.receipt+'<br>'+log.innerHTML;ledger.innerHTML=items.map(x=>'<b>'+x.receipt+'</b><br>'+x.time+' '+x.lane+' '+x.entity+'<br>').join('<br>');}proof.innerText=JSON.stringify({app:'MUBAKA ORBIT OS',mode:'native desktop appliance',local:true,network:'local UI only',wrappers:'removed'},null,2);</script></body></html>
'@|Set-Content $Html -Encoding UTF8
$AppSrc=Join-Path $Root 'MUBAKA_ORBIT_APP.cs'
$AppExe=Join-Path $Root 'MUBAKA_ORBIT_APP.exe'
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
foreach($Lnk in (Join-Path $Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')){ $S=$Shell.CreateShortcut($Lnk); $S.TargetPath=$AppExe; $S.Arguments=''; $S.WorkingDirectory=$Root; $S.Description='MUBAKA ORBIT OS Native Appliance'; $S.IconLocation=$AppExe; $S.Save() }
$State=Join-Path $Root 'state.json'
'{"system":"MUBAKA ORBIT OS","version":"native-appliance-safe-v1","entry":"native_exe","root":"C:\\MUBAKA\\ORBIT_OS"}'|Set-Content $State -Encoding UTF8
foreach($F in 'ledger.ndjson','queue.ndjson','audit.ndjson'){ $P=Join-Path $Root $F; if(!(Test-Path $P)){New-Item -ItemType File -Path $P -Force|Out-Null}}
$Hash=Get-FileHash $AppExe -Algorithm SHA256
"APP $($Hash.Hash)"|Set-Content (Join-Path $Seal 'HASHES.txt') -Encoding UTF8
$Zip=Join-Path $Travel ('MUBAKA_ORBIT_OS_TRAVEL_CAPSULE_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.zip')
Compress-Archive -Path (Join-Path $Root '*') -DestinationPath $Zip -Force
$Verify=Join-Path $Root 'VERIFY_MUBAKA_APPLIANCE.ps1'
@"
`$Root='C:\MUBAKA\ORBIT_OS'
Write-Host ''
Write-Host 'MUBAKA ORBIT OS VERIFY' -ForegroundColor Yellow
foreach(`$F in 'MUBAKA_ORBIT_APP.exe','mubaka_orbit_os.html','state.json','ledger.ndjson','queue.ndjson','audit.ndjson') { if(Test-Path (Join-Path `$Root `$F)){Write-Host "`$F OK" -ForegroundColor Green}else{Write-Host "`$F MISSING" -ForegroundColor Red} }
foreach(`$Bad in 'MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1'){ if(!(Test-Path (Join-Path `$Root `$Bad))){Write-Host "`$Bad REMOVED" -ForegroundColor Green}else{Write-Host "`$Bad STILL EXISTS" -ForegroundColor Red} }
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
Write-Host 'NO VBS. NO CMD WRAPPER. NO START-PROCESS.' -ForegroundColor Green
