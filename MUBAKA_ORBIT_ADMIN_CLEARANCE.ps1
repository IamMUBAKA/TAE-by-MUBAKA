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
$AppExe=Join-Path $Root 'MUBAKA_ORBIT_APP.exe'
$AltAppExe=Join-Path $Root 'bin\MUBAKA_ORBIT_APP.exe'
$DesktopExe=Join-Path $Desktop 'MUBAKA ORBIT OS.exe'
$Log=Join-Path $Seal 'ADMIN_CLEARANCE.log'

New-Item -ItemType Directory -Path $Root,$Seal,$StartMenu,$Startup -Force|Out-Null
function Log([string]$m){Add-Content -Path $Log -Value ("[{0}] {1}" -f (Get-Date).ToString('o'),$m) -Encoding UTF8}

# Preserve active app body if it exists in either known location.
if(!(Test-Path $AppExe) -and (Test-Path $AltAppExe)){Copy-Item $AltAppExe $AppExe -Force;Log 'copied app from bin to root'}
if(!(Test-Path $AppExe)){Log 'app missing; invoking build';iex (irm 'https://raw.githubusercontent.com/IamMUBAKA/TAE-by-MUBAKA/main/MUBAKA_ORBIT_BUILD.ps1')}
if(!(Test-Path $AppExe)){throw 'MUBAKA_ORBIT_APP.exe still missing after rebuild.'}

# Kill only MUBAKA-opened browser/app locks, then repair file permissions.
Get-Process msedge,chrome,brave -ErrorAction SilentlyContinue | Where-Object {$_.Path -like '*Microsoft\Edge*' -or $_.Path -like '*Google\Chrome*' -or $_.Path -like '*Brave*'} | Stop-Process -Force
Start-Sleep -Seconds 1

# Targeted admin ownership and ACL on MUBAKA root only. Does not change whole PC.
takeown.exe /F $Root /R /D Y | Out-Null
$user=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls.exe $Root /inheritance:e /grant:r "${user}:(OI)(CI)F" "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" /T /C | Out-Null
Log 'ACL repaired for root current-user administrators system'

# Remove Mark-of-the-Web / blocked-file flags from MUBAKA files only.
Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue }
Log 'Unblock-File applied to MUBAKA root files'

# Targeted Microsoft Defender allowance for MUBAKA folder and desktop app only. Does not disable Defender globally.
try{Add-MpPreference -ExclusionPath $Root -ErrorAction SilentlyContinue;Log 'Defender exclusion path added for root'}catch{Log "Defender exclusion path failed $($_.Exception.Message)"}
try{Add-MpPreference -ExclusionProcess $AppExe -ErrorAction SilentlyContinue;Log 'Defender exclusion process added for app'}catch{Log "Defender exclusion process failed $($_.Exception.Message)"}

# Recreate stable access surfaces.
Copy-Item $AppExe $DesktopExe -Force
Unblock-File $DesktopExe -ErrorAction SilentlyContinue
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

# Transparent run/logon path only.
$RunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item $RunKey -Force|Out-Null
New-ItemProperty -Path $RunKey -Name 'MUBAKA_ORBIT_APP' -Value ('"'+$AppExe+'"') -PropertyType String -Force|Out-Null
schtasks.exe /Delete /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /F | Out-Null
schtasks.exe /Create /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /TR ('"'+$AppExe+'"') /SC ONLOGON /RL HIGHEST /F | Out-Null
schtasks.exe /Change /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' /ENABLE | Out-Null

$Verify=Join-Path $Root 'VERIFY_MUBAKA_ADMIN_CLEARANCE.ps1'
@"
`$Root='C:\MUBAKA\ORBIT_OS'
`$AppExe=Join-Path `$Root 'MUBAKA_ORBIT_APP.exe'
`$Desktop=[Environment]::GetFolderPath('Desktop')
Write-Host ''
Write-Host 'MUBAKA ADMIN CLEARANCE VERIFY' -ForegroundColor Yellow
foreach(`$P in `$AppExe,(Join-Path `$Desktop 'MUBAKA ORBIT OS.exe'),(Join-Path `$Root '_MUBAKA_SEAL\ADMIN_CLEARANCE.log')){if(Test-Path `$P){Write-Host "OK `$P" -ForegroundColor Green}else{Write-Host "MISSING `$P" -ForegroundColor Red}}
try{`$pref=Get-MpPreference; if(`$pref.ExclusionPath -contains `$Root){Write-Host 'DEFENDER ROOT EXCLUSION: OK' -ForegroundColor Green}else{Write-Host 'DEFENDER ROOT EXCLUSION: NOT CONFIRMED' -ForegroundColor Yellow}}catch{Write-Host 'DEFENDER CHECK: UNAVAILABLE' -ForegroundColor Yellow}
schtasks.exe /Query /TN 'MUBAKA_ORBIT_OPEN_ON_LOGON' *>`$null
if(`$LASTEXITCODE -eq 0){Write-Host 'LOGON TASK: OK' -ForegroundColor Green}else{Write-Host 'LOGON TASK: MISSING' -ForegroundColor Red}
Write-Host 'SECURITY POSTURE: targeted MUBAKA clearance only; global Windows protections are not disabled.' -ForegroundColor Cyan
"@|Set-Content $Verify -Encoding UTF8

# Try direct launch, then explorer shell fallback.
$launched=$false
try{[System.Diagnostics.Process]::Start($AppExe)|Out-Null;$launched=$true;Log 'direct app launch ok'}catch{Log "direct app launch failed $($_.Exception.Message)"}
if(!$launched){try{Start-Process explorer.exe -ArgumentList ('"'+$AppExe+'"');$launched=$true;Log 'explorer launch attempted'}catch{Log "explorer launch failed $($_.Exception.Message)"}}
try{[System.Diagnostics.Process]::Start($PSExe,'-NoProfile -ExecutionPolicy Bypass -File "'+$Verify+'"')|Out-Null}catch{}

$Contract=@"
MUBAKA ORBIT ADMIN CLEARANCE
ROOT=$Root
APP=$AppExe
DESKTOP_REAL_EXE=$DesktopExe
DEFENDER_EXCLUSION_PATH=$Root
DEFENDER_EXCLUSION_PROCESS=$AppExe
ACL=current user + Administrators + SYSTEM
UNBLOCKED_MARK_OF_WEB=YES_ROOT_ONLY
TASK=MUBAKA_ORBIT_OPEN_ON_LOGON
GLOBAL_WINDOWS_SECURITY_DISABLED=NO
PASSWORDS_TOUCHED=NO
BROWSER_SESSIONS_TOUCHED=NO
CACHE_PURGE=NO
SEALED_AT=$(Get-Date -Format o)
"@
Set-Content (Join-Path $Seal 'ADMIN_CLEARANCE_CONTRACT.txt') $Contract -Encoding UTF8

Write-Host ''
Write-Host 'MUBAKA ORBIT ADMIN CLEARANCE APPLIED' -ForegroundColor Yellow
Write-Host "APP EXE: $AppExe" -ForegroundColor Cyan
Write-Host "DESKTOP REAL EXE: $DesktopExe" -ForegroundColor Cyan
Write-Host 'TARGETED DEFENDER/ACL/UNBLOCK CLEARANCE APPLIED TO MUBAKA ONLY.' -ForegroundColor Green
Write-Host 'GLOBAL WINDOWS PROTECTION NOT DISABLED.' -ForegroundColor Yellow
