@echo off
setlocal EnableExtensions EnableDelayedExpansion
echo.
echo===============================================
echo Check for Admin rights...
echo===============================================
if not "%1"=="am_admin" powershell start -verb runas '%0' am_admin & exit /b

:gotAdmin
pushd "%CD%"
CD /D "%~dp0"
cls

title tiny11 builder beta
echo Welcome to the tiny11 image creator!
timeout /t 3 /nobreak > nul
cls

set DriveLetter=
set /p DriveLetter=Please enter the drive letter for the Windows 11 image: 
set "DriveLetter=%DriveLetter%:"
echo.
if not exist "%DriveLetter%\sources\boot.wim" (
	echo.Can't find Windows OS Installation files in the specified Drive Letter..
	echo.
	echo.Please enter the correct DVD Drive Letter..
	goto :Stop
)

if not exist "%DriveLetter%\sources\install.wim" (
	echo.Can't find Windows OS Installation files in the specified Drive Letter..
	echo.
	echo.Please enter the correct DVD Drive Letter..
	goto :Stop
)
md d:\tiny11
echo Copying Windows image...
xcopy.exe /E /I /H /R /Y /J %DriveLetter% d:\tiny11 >nul
echo Copy complete!
sleep 2
cls
echo Getting image information:
dism /Get-WimInfo /wimfile:d:\tiny11\sources\install.wim
set index=
set /p index=请输入映像索引:
set "index=%index%"
echo 正在挂载 Windows 映像。这可能需要等一会。
echo.
md d:\scratchdir
dism /mount-image /imagefile:d:\tiny11\sources\install.wim /index:%index% /mountdir:d:\scratchdir || echo.&echo 挂载映像错误，请按任意键退出。&pause>nul&exit
echo Mounting complete! Performing removal of applications...
:RemoveWindowsApps
REM 保留的Windows Apps列表
set "AppNames="
set "AppNames=!AppNames! Microsoft.DesktopAppInstaller"
set "AppNames=!AppNames! Microsoft.Paint"
set "AppNames=!AppNames! Microsoft.Windows.Photos"
set "AppNames=!AppNames! Microsoft.ScreenSketch"
set "AppNames=!AppNames! Microsoft.WindowsCalculator"
set "AppNames=!AppNames! Microsoft.WindowsCamera"
set "AppNames=!AppNames! Microsoft.ZuneMusic"
set "AppNames=!AppNames! Microsoft.VCLibs"
set "AppNames=!AppNames! Microsoft.SecHealthUI"
set "AppNames=!AppNames! Microsoft.WindowsNotepad"
set "AppNames=!AppNames! Microsoft.WindowsStore"
set "AppNames=!AppNames! Microsoft.WindowsTerminal"

echo.
echo ========= 等待移除 Windows Apps 应用包 =========
for /f "delims=_ tokens=1*" %%i in ('dism /image:d:\scratchdir /Get-ProvisionedAppxPackages^|findstr /v /i "!AppNames!"^|findstr /i "Package"') do (
	echo 正在移除:!%%i!... && set "PN=!%%i_%%j!" && set "PN=!PN:~1!"
	dism /image:d:\scratchdir /Remove-ProvisionedAppxPackage /PackageName:!PN!
)
sleep 2
cls
echo ======= 清理 Windows Apps 安装目录 =======
for /f "delims=_ tokens=1*" %%i in ('dir /b /ad "d:\scratchdir\Program Files\WindowsApps" ^|findstr /v /i "!AppNames! Native Deleted UI.Xaml"') do (
	echo 正在删除目录 d:\scratchdir\Program Files\WindowsApps\%%i...
	set "APPDIR=%%i_%%j" && if "!APPDIR:~-1!"=="_" set "APPDIR=!APPDIR:~0,-1!"
	takeown /f "d:\scratchdir\Program Files\WindowsApps\!APPDIR!" /a /r /d y 2>&1 >nul
	icacls "d:\scratchdir\Program Files\WindowsApps\!APPDIR!" /grant Administrators:F /T 2>&1 >nul
	rd /s /q "d:\scratchdir\Program Files\WindowsApps\!APPDIR!"
)
echo ======= 完成清理 Windows Apps 目录 =======
timeout /t 1 /nobreak > nul
cls

:RemoveSystemApps
REM 预移除的System Apps列表
set AppNames=
set AppNames=!AppNames! InternetExplorer
set AppNames=!AppNames! LA57
set AppNames=!AppNames! OCR
set AppNames=!AppNames! Speech
set AppNames=!AppNames! MediaPlayer
set AppNames=!AppNames! TabletPCMath
set AppNames=!AppNames! Wallpaper

echo [========= 等待移除 System Apps =========]
for /f "tokens=3" %%i in ('dism /image:d:\scratchdir /Get-Packages ^| findstr /i "!AppNames!"') do (
	dism /image:d:\scratchdir /Remove-Package /PackageName:%%i
)
echo [======== 移除 System Apps 完成 =========]
sleep 2
cls
echo ======== 清理 System Apps 安装目录 ========

for /f "delims=" %%i in ('dir /b /ad "d:\scratchdir\*Files*"') do (
	for /f "delims=" %%j in ('dir /b /ad "d:\scratchdir\%%i" ^|findstr /i "Internet Media"') do (
		echo 正在删除目录 d:\scratchdir\%%i\%%j
		takeown /f "d:\scratchdir\%%i\%%j" /r >nul 2>&1
		icacls "d:\scratchdir\%%i\%%j" /grant Administrators:F /T /C >nul 2>&1
		rd "d:\scratchdir\%%i\%%j" /s /q
    )
)
echo ======== 清理 System Apps 安装目录完成 ========
echo 移除 OneDrive:
takeown /f d:\scratchdir\Windows\System32\OneDriveSetup.exe >nul 2>&1
icacls d:\scratchdir\Windows\System32\OneDriveSetup.exe /grant Administrators:F >nul 2>&1
del /f /q /s "d:\scratchdir\Windows\System32\OneDriveSetup.exe"
echo 移除 OneDrive完成。
timeout /t 2 /nobreak > nul
cls
echo Loading registry...
reg load HKLM\zCOMPONENTS "d:\scratchdir\Windows\System32\config\COMPONENTS" >nul
reg load HKLM\zDEFAULT "d:\scratchdir\Windows\System32\config\default" >nul
reg load HKLM\zNTUSER "d:\scratchdir\Users\Default\ntuser.dat" >nul
reg load HKLM\zSOFTWARE "d:\scratchdir\Windows\System32\config\SOFTWARE" >nul
reg load HKLM\zSYSTEM "d:\scratchdir\Windows\System32\config\SYSTEM" >nul
echo Bypassing system requirements(on the system image):
			Reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d "1" /f >nul 2>&1
echo Disabling Teams:
Reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v "ConfigureChatAutoInstall" /t REG_DWORD /d "0" /f >nul 2>&1
echo Delete OneDrive Items:
Reg delete "HKLM\zDEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f >nul 2>&1
Reg delete "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f >nul 2>&1
echo Disabling Sponsored Apps:
Reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "OemPreInstalledAppsEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "ConfigureStartPins" /t REG_SZ /d "{\"pinnedList\": [{}]}" /f >nul 2>&1
echo Enabling Local Accounts on OOBE:
Reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d "1" /f >nul 2>&1
copy /y %~dp0autounattend.xml d:\scratchdir\Windows\System32\Sysprep\autounattend.xml
echo Disabling Reserved Storage:
Reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v "ShippedWithReserves" /t REG_DWORD /d "0" /f >nul 2>&1
echo Disabling Chat icon:
Reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v "ChatIcon" /t REG_DWORD /d "3" /f >nul 2>&1
Reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarMn" /t REG_DWORD /d "0" /f >nul 2>&1
echo Tweaking complete!
echo Unmounting Registry...
reg unload HKLM\zCOMPONENTS >nul 2>&1
reg unload HKLM\zDRIVERS >nul 2>&1
reg unload HKLM\zDEFAULT >nul 2>&1
reg unload HKLM\zNTUSER >nul 2>&1
reg unload HKLM\zSCHEMA >nul 2>&1
reg unload HKLM\zSOFTWARE >nul 2>&1
reg unload HKLM\zSYSTEM >nul 2>&1
echo Cleaning up image...
dism /image:d:\scratchdir /Cleanup-Image /StartComponentCleanup /ResetBase
echo 清理完成。
echo 正在卸载映像...
dism /unmount-image /mountdir:d:\scratchdir /commit
echo Exporting image...
Dism /Export-Image /SourceImageFile:d:\tiny11\sources\install.wim /SourceIndex:%index% /DestinationImageFile:d:\tiny11\sources\install2.wim /compress:max
del d:\tiny11\sources\install.wim
ren d:\tiny11\sources\install2.wim install.wim
echo Windows image completed. Continuing with boot.wim.
timeout /t 2 /nobreak > nul
cls
echo Mounting boot image:
dism /mount-image /imagefile:d:\tiny11\sources\boot.wim /index:2 /mountdir:d:\scratchdir
echo Loading registry...
reg load HKLM\zCOMPONENTS "d:\scratchdir\Windows\System32\config\COMPONENTS" >nul
reg load HKLM\zDEFAULT "d:\scratchdir\Windows\System32\config\default" >nul
reg load HKLM\zNTUSER "d:\scratchdir\Users\Default\ntuser.dat" >nul
reg load HKLM\zSOFTWARE "d:\scratchdir\Windows\System32\config\SOFTWARE" >nul
reg load HKLM\zSYSTEM "d:\scratchdir\Windows\System32\config\SYSTEM" >nul
echo Bypassing system requirements(on the setup image):
			Reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d "1" /f >nul 2>&1
			Reg add "HKLM\zSYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d "1" /f >nul 2>&1
echo Tweaking complete! 
echo Unmounting Registry...
reg unload HKLM\zCOMPONENTS >nul 2>&1
reg unload HKLM\zDRIVERS >nul 2>&1
reg unload HKLM\zDEFAULT >nul 2>&1
reg unload HKLM\zNTUSER >nul 2>&1
reg unload HKLM\zSCHEMA >nul 2>&1
reg unload HKLM\zSOFTWARE >nul 2>&1
reg unload HKLM\zSYSTEM >nul 2>&1
echo Unmounting image...
dism /unmount-image /mountdir:d:\scratchdir /commit 
cls
echo the tiny11 image is now completed. Proceeding with the making of the ISO...
echo Copying unattended file for bypassing MS account on OOBE...
copy /y %~dp0autounattend.xml d:\tiny11\autounattend.xml
echo.
echo Creating ISO image...
%~dp0oscdimg.exe -m -o -u2 -udfver102 -bootdata:2#p0,e,bd:\tiny11\boot\etfsboot.com#pEF,e,bd:\tiny11\efi\microsoft\boot\efisys.bin d:\tiny11 %~dp0tiny11.iso
echo Creation completed! Press any key to exit the script...
pause 
echo Performing Cleanup...
rd d:\tiny11 /s /q 
rd d:\scratchdir /s /q 
exit

