$ErrorActionPreference='Stop'
if($PSDefaultParameterValues){$PSDefaultParameterValues.Clear()}
$PSDefaultParameterValues['Disabled']=$true

$Root='C:\MUBAKA\ORBIT_OS'
$Seal=Join-Path $Root '_MUBAKA_SEAL'
$Desktop=[Environment]::GetFolderPath('Desktop')
$Programs=[Environment]::GetFolderPath('Programs')
$StartMenu=Join-Path $Programs 'MUBAKA'
$Startup=[Environment]::GetFolderPath('Startup')
$PSExe=Join-Path $PSHOME 'powershell.exe'
New-Item -ItemType Directory -Path $Root,$Seal,$StartMenu -Force|Out-Null

# Build/refresh the active native appliance first.
iex (irm 'https://raw.githubusercontent.com/IamMUBAKA/TAE-by-MUBAKA/main/MUBAKA_ORBIT_BUILD.ps1')

$AppExe=Join-Path $Root 'MUBAKA_ORBIT_APP.exe'
if(!(Test-Path $AppExe)){throw 'MUBAKA_ORBIT_APP.exe missing after build.'}

# Two designated stable access positions: Desktop real EXE + Start Menu app identity.
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

# Behavior contract: non-disruptive, local-only, visible, uninstallable.
$Behavior=@"
MUBAKA ORBIT OS BEHAVIOR CONTRACT
ROOT=$Root
DESKTOP_REAL_EXE=$DesktopExe
DESKTOP_LINK=$(Join-Path $Desktop 'MUBAKA ORBIT OS.lnk')
START_MENU_APP=$(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')
STARTUP_ENTRY=$(Join-Path $Startup 'MUBAKA ORBIT OS.lnk')
PIN_TO_TASKBAR=WINDOWS_USER_CONTROLLED_NOT_FORCED
NETWORK=LOCAL_UI_ONLY
REMOTE_ACCESS=NONE
PASSWORD_COLLECTION=NONE
CREDENTIAL_STORAGE=NONE
BROWSER_PASSWORDS=NOT_TOUCHED
CACHE_PURGE=NOT_USED
VBS=REMOVED
CMD_WRAPPER=REMOVED
START_PROCESS=NOT_USED
UNINSTALL_PATH=$Root\UNINSTALL_MUBAKA_ORBIT_OS.ps1
RULE=Stable desktop and start-menu presence; no hostile persistence; only transparent restore and explicit uninstall.
SEALED_AT=$(Get-Date -Format o)
"@
Set-Content -Path (Join-Path $Seal 'BEHAVIOR_CONTRACT.txt') -Value $Behavior -Encoding UTF8

# Legitimate uninstall is the only provided removal path. Admin/OS/manual deletion still exist by Windows design.
$Uninstall=Join-Path $Root 'UNINSTALL_MUBAKA_ORBIT_OS.ps1'
@"
`$ErrorActionPreference='SilentlyContinue'
`$Root='C:\MUBAKA\ORBIT_OS'
`$Desktop=[Environment]::GetFolderPath('Desktop')
`$Programs=[Environment]::GetFolderPath('Programs')
`$StartMenu=Join-Path `$Programs 'MUBAKA'
`$Startup=[Environment]::GetFolderPath('Startup')
foreach(`$Task in 'MUBAKA_ORBIT_NATIVE_GUARDIAN','MUBAKA_ORBIT_NATIVE_STARTUP','MUBAKA_ORBIT_NATIVE_LOGON','MUBAKA_ORBIT_NATIVE_HOST','MUBAKA_ORBIT_CORE_TASK','MUBAKA_ORBIT_OS_APP_OPEN'){schtasks.exe /Delete /TN `$Task /F | Out-Null}
foreach(`$Name in 'MUBAKA_ORBIT_NATIVE_APP','MUBAKA_ORBIT_NATIVE_GUARDIAN','MUBAKA_ORBIT_APP','MUBAKA_ORBIT_CORE'){Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name `$Name -ErrorAction SilentlyContinue}
foreach(`$P in (Join-Path `$Desktop 'MUBAKA ORBIT OS.exe'),(Join-Path `$Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path `$StartMenu 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Startup 'MUBAKA ORBIT OS.lnk')){if(Test-Path `$P){Remove-Item `$P -Force}}
Write-Host 'MUBAKA ORBIT OS visible entries removed. Root preserved for manual archive/removal:' -ForegroundColor Yellow
Write-Host `$Root -ForegroundColor Cyan
"@|Set-Content -Path $Uninstall -Encoding UTF8

# Verification.
$Verify=Join-Path $Root 'VERIFY_MUBAKA_FINALIZE.ps1'
@"
`$Root='C:\MUBAKA\ORBIT_OS'
`$Desktop=[Environment]::GetFolderPath('Desktop')
`$Programs=[Environment]::GetFolderPath('Programs')
`$StartMenu=Join-Path `$Programs 'MUBAKA'
`$Startup=[Environment]::GetFolderPath('Startup')
Write-Host ''
Write-Host 'MUBAKA ORBIT OS FINALIZE VERIFY' -ForegroundColor Yellow
foreach(`$P in (Join-Path `$Desktop 'MUBAKA ORBIT OS.exe'),(Join-Path `$Desktop 'MUBAKA ORBIT OS.lnk'),(Join-Path `$StartMenu 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Startup 'MUBAKA ORBIT OS.lnk'),(Join-Path `$Root 'UNINSTALL_MUBAKA_ORBIT_OS.ps1'),(Join-Path `$Root '_MUBAKA_SEAL\BEHAVIOR_CONTRACT.txt')){if(Test-Path `$P){Write-Host "OK `$P" -ForegroundColor Green}else{Write-Host "MISSING `$P" -ForegroundColor Red}}
Write-Host 'TASKBAR PIN: Windows blocks reliable silent pinning; use right-click > Pin to taskbar after app appears.' -ForegroundColor Yellow
Write-Host 'POSTURE: transparent, local-only, non-disruptive, uninstallable.' -ForegroundColor Green
"@|Set-Content -Path $Verify -Encoding UTF8

$P=New-Object System.Diagnostics.ProcessStartInfo
$P.FileName=$AppExe
$P.WorkingDirectory=$Root
$P.UseShellExecute=$true
[System.Diagnostics.Process]::Start($P)|Out-Null

$P2=New-Object System.Diagnostics.ProcessStartInfo
$P2.FileName=$PSExe
$P2.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$Verify+'"'
$P2.WorkingDirectory=$Root
$P2.UseShellExecute=$true
[System.Diagnostics.Process]::Start($P2)|Out-Null

Write-Host ''
Write-Host 'MUBAKA ORBIT OS FINALIZED' -ForegroundColor Yellow
Write-Host "DESKTOP REAL EXE: $DesktopExe" -ForegroundColor Cyan
Write-Host "START MENU APP: $(Join-Path $StartMenu 'MUBAKA ORBIT OS.lnk')" -ForegroundColor Cyan
Write-Host "UNINSTALL: $Uninstall" -ForegroundColor Cyan
Write-Host 'TASKBAR PIN: Windows user-controlled; app must be pinned by right-click after opening.' -ForegroundColor Yellow
Write-Host 'NON-DISRUPTIVE LOCAL-ONLY POSTURE SEALED.' -ForegroundColor Green
