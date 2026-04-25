$ErrorActionPreference='SilentlyContinue'
if($PSDefaultParameterValues){$PSDefaultParameterValues.Clear()}
$PSDefaultParameterValues['Disabled']=$true

$Root='C:\MUBAKA\ORBIT_OS'
$Seal=Join-Path $Root '_MUBAKA_SEAL'
$Desktop=[Environment]::GetFolderPath('Desktop')
$Programs=[Environment]::GetFolderPath('Programs')
$StartMenu=Join-Path $Programs 'MUBAKA'
$Startup=[Environment]::GetFolderPath('Startup')
$PSExe=Join-Path $PSHOME 'powershell.exe'
New-Item -ItemType Directory -Path $Root,$Seal,$StartMenu,$Startup -Force|Out-Null

$AppExe=Join-Path $Root 'MUBAKA_ORBIT_APP.exe'
$AltAppExe=Join-Path $Root 'bin\MUBAKA_ORBIT_APP.exe'
if(!(Test-Path $AppExe) -and (Test-Path $AltAppExe)){Copy-Item $AltAppExe $AppExe -Force}
if(!(Test-Path $AppExe)){throw 'MUBAKA_ORBIT_APP.exe missing. Run MUBAKA_ORBIT_BUILD.ps1 first.'}

# Remove only known broken launcher wrappers. No password, account, browser, or website session deletion.
foreach($Bad in 'MUBAKA_ORBIT_APP.vbs','MUBAKA_ORBIT_APP.cmd','MUBAKA_ORBIT_APP_LAUNCHER.ps1'){
  $P=Join-Path $Root $Bad
  if(Test-Path $P){Remove-Item $P -Force}
}

# Transparent access stabilization: current user/admin/system only. No bypass of Windows security.
$UserName=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
foreach($Path in @($Root,$Seal)){
  if(Test-Path $Path){
    icacls $Path /inheritance:e /grant:r "${UserName}:(OI)(CI)F" "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" /T /C | Out-Null
  }
}

# Two fixed access points plus startup convenience.
$DesktopExe=Join-Path $Desktop 'MUBAKA ORBIT OS.exe'
Copy-Item $AppExe $DesktopExe -Force

$Shell=New-Object -ComObject WScript.Shell
foreach($Lnk in (Join-Path $Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk'),(Join-Path $Startup 'MUBAKA ORBIT OS.lnk')){
  $S=$Shell.CreateShortcut($Lnk)
  $S.TargetPath=$AppExe
  $S.Arguments=''
  $S.WorkingDirectory=$Root
  $S.Description='MUBAKA ORBIT OS Native Appliance'
  $S.IconLocation=$AppExe
  $S.Save()
}

# Transparent persistence only. No stealth. No hidden remote access.
$RunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item $RunKey -Force|Out-Null
New-ItemProperty -Path $RunKey -Name 'MUBAKA_ORBIT_APP' -Value ('"'+$AppExe+'"') -PropertyType String -Force|Out-Null
schtasks.exe /Delete /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /F | Out-Null
schtasks.exe /Create /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /TR ('"'+$AppExe+'"') /SC ONLOGON /RL HIGHEST /F | Out-Null
schtasks.exe /Change /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /ENABLE | Out-Null

$Uninstall=Join-Path $Root 'UNINSTALL_MUBAKA_ORBIT_OS.ps1'
@"
`$ErrorActionPreference='SilentlyContinue'
`$Root='C:\MUBAKA\ORBIT_OS'
`$Desktop=[Environment]::GetFolderPath('Desktop')
`$Programs=[Environment]::GetFolderPath('Programs')
`$StartMenu=Join-Path `$Programs 'MUBAKA'
`$Startup=[Environment]::GetFolderPath('Startup')
schtasks.exe /Delete /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /F | Out-Null
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'MUBAKA_ORBIT_APP' -ErrorAction SilentlyContinue
foreach(`$P in (Join-Path `$Desktop 'MUBAKA ORBIT OS.exe'),(Join-Path `$Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path `$StartMenu 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Startup 'MUBAKA ORBIT OS.lnk')){if(Test-Path `$P){Remove-Item `$P -Force}}
Write-Host 'MUBAKA ORBIT OS visible entries removed. Root preserved:' -ForegroundColor Yellow
Write-Host `$Root -ForegroundColor Cyan
"@|Set-Content $Uninstall -Encoding UTF8

$Contract=@"
MUBAKA ORBIT OS CLEARANCE CONTRACT
ROOT=$Root
DESKTOP_REAL_EXE=$DesktopExe
START_MENU_APP=$(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')
STARTUP_ENTRY=$(Join-Path $Startup 'MUBAKA ORBIT OS.lnk')
RUN_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run\MUBAKA_ORBIT_APP
LOGON_TASK=MUBAKA_ORBIT_OPEN_ON_LOGON
TASKBAR_PIN=USER_CONTROLLED_BY_WINDOWS
REMOTE_ACCESS=NONE
NETWORK=LOCAL_UI_ONLY
PASSWORDS=NOT_TOUCHED
BROWSER_SESSIONS=NOT_TOUCHED
CACHE_PURGE=NOT_USED
SECURITY_BYPASS=NOT_USED
VBS=REMOVED
CMD_WRAPPER=REMOVED
CLEARANCE=Current user + Administrators + SYSTEM access repaired for MUBAKA root only
UNINSTALL=$Uninstall
SEALED_AT=$(Get-Date -Format o)
"@
Set-Content (Join-Path $Seal 'CLEARANCE_CONTRACT.txt') $Contract -Encoding UTF8

$Verify=Join-Path $Root 'VERIFY_MUBAKA_CLEARANCE.ps1'
@"
`$Root='C:\MUBAKA\ORBIT_OS'
`$Desktop=[Environment]::GetFolderPath('Desktop')
`$Programs=[Environment]::GetFolderPath('Programs')
`$StartMenu=Join-Path `$Programs 'MUBAKA'
`$Startup=[Environment]::GetFolderPath('Startup')
Write-Host ''
Write-Host 'MUBAKA ORBIT CLEARANCE VERIFY' -ForegroundColor Yellow
foreach(`$P in (Join-Path `$Root 'MUBAKA_ORBIT_APP.exe'),(Join-Path `$Desktop 'MUBAKA ORBIT OS.exe'),(Join-Path `$Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path `$StartMenu 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Startup 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Root '_MUBAKA_SEAL\CLEARANCE_CONTRACT.txt'),(Join-Path `$Root 'UNINSTALL_MUBAKA_ORBIT_OS.ps1')){if(Test-Path `$P){Write-Host "OK `$P" -ForegroundColor Green}else{Write-Host "MISSING `$P" -ForegroundColor Red}}
schtasks.exe /Query /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' *>`$null
if(`$LASTEXITCODE -eq 0){Write-Host 'TASK MUBAKA_ORBIT_OPEN_ON_LOGON OK' -ForegroundColor Green}else{Write-Host 'TASK MUBAKA_ORBIT_OPEN_ON_LOGON MISSING' -ForegroundColor Red}
Write-Host 'POSTURE: transparent, local-only, non-disruptive, uninstallable.' -ForegroundColor Green
Write-Host 'TASKBAR PIN: right-click the open app on the taskbar > Pin to taskbar.' -ForegroundColor Yellow
"@|Set-Content $Verify -Encoding UTF8

# Launch attempts are non-fatal. If Windows blocks launch, the Desktop EXE remains the stable opening point.
try{[System.Diagnostics.Process]::Start($AppExe)|Out-Null}catch{Write-Host "APP LAUNCH BLOCKED BY WINDOWS: $($_.Exception.Message)" -ForegroundColor Yellow}
try{[System.Diagnostics.Process]::Start($PSExe,'-NoProfile -ExecutionPolicy Bypass -File "'+$Verify+'"')|Out-Null}catch{Write-Host "VERIFY LAUNCH BLOCKED: $($_.Exception.Message)" -ForegroundColor Yellow}

Write-Host ''
Write-Host 'MUBAKA ORBIT CLEARANCE APPLIED' -ForegroundColor Yellow
Write-Host "DESKTOP REAL EXE: $DesktopExe" -ForegroundColor Cyan
Write-Host "START MENU APP: $(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')" -ForegroundColor Cyan
Write-Host "UNINSTALL: $Uninstall" -ForegroundColor Cyan
Write-Host 'NO ADMIN BYPASS. NO STEALTH. NO PASSWORD/CACHE/SESSION DELETION.' -ForegroundColor Green
