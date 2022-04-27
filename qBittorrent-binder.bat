@echo off
setlocal enabledelayedexpansion

rem ------------------------Setup----------------------------
rem Select your network interface and current IP in the advanced tab of the qBittorent gui and save
rem Set interfaceName, expectedInterfaceIP & logFilePath below
rem You can get info about your interfaces by running: netsh interface ip show address
rem Add a scheduled task to repeat at desired interval i.e. every 2 minutes
rem Make sure the script has permissions to kill the qBittorent process

rem ------------------------Notes----------------------------
rem Before running, take a backup of your qBittorrent.ini from %appdata%\qBittorrent
rem qBittorrent should not be set to start up automatically, instead it is brought up by this script
rem If you are updating your config you may want to disable the script temporarily in case of conflicts
rem To change the interface you want to bind to you must update this in the gui first
rem expectedInterfaceIP is a pattern that your Interface IP should begin with when properly connected
rem in my case this is 10.117.*.*

rem ********************************************************************************************************
set interfaceName=Windscribe IKEv2
set expectedInterfaceIP=10.153
set logFilePath="C:\Scripts\Logs\qBittorrent-log.txt"
rem ********************************************************************************************************

set msgPrefix=[%date% - %time%]
echo %msgPrefix% interfaceName: %interfaceName%
echo %msgPrefix% expectedInterfaceIP: %expectedInterfaceIP%
echo %msgPrefix% logFilePath: %logFilePath%
set qBittorrentConfPath=%appdata%\qBittorrent
echo %msgPrefix% qBittorrentConfPath: %qBittorrentConfPath%
set qBittorrentConfFilePath=%qBittorrentConfPath%\qBittorrent.ini
echo %msgPrefix% qBittorrentConfFilePath: %qBittorrentConfFilePath%
set qBittorrentProcess=qbittorrent.exe
echo %msgPrefix% qBittorrentProcess: %qBittorrentProcess%
set qBittorrentExeFile="%ProgramFiles%\qbittorrent\%qBittorrentProcess%"
echo %msgPrefix% qBittorrentExeFile: %qBittorrentExeFile%

rem find the IP assigned to the interface
for /f "tokens=3" %%i in ('netsh interface ip show address "%interfaceName%" ^| findstr "IP Address"') do set InterfaceIP=%%i
echo %msgPrefix% InterfaceIP: %InterfaceIP%

rem check if the IP matches the pattern specified.. i.e. avoid updating for 169.*.*.*
echo.%InterfaceIP% | find /i "%expectedInterfaceIP%" >nul
if not errorlevel 1 (
	echo %msgPrefix% Interface IP %InterfaceIP% matches pattern %expectedInterfaceIP% :^)
	
	rem find the InterfaceAddress line specified in the qBittorrent.conf file
	for /f "tokens=1" %%i in ('findstr /i "Session\InterfaceAddress=" %qBittorrentConfFilePath%') do set qBittorrentConfInterfaceAddressLine=%%i
	echo %msgPrefix% qBittorrentConfInterfaceAddressLine: !qBittorrentConfInterfaceAddressLine!
	
	rem find the IP address specified in the InterfaceAddress line above
	for /f "tokens=2 delims=^=" %%a in ("!qBittorrentConfInterfaceAddressLine!") do set qBittorrentConfInterfaceAddress=%%a
	echo %msgPrefix% qBittorrentConfInterfaceAddress: !qBittorrentConfInterfaceAddress!
	
	rem find the InterfaceName line specified in the qBittorrent.conf file
	for /f "tokens=*" %%i in ('findstr /i "Session\InterfaceName=" %qBittorrentConfFilePath%') do set qBittorrentConfInterfaceNameLine=%%i
	echo %msgPrefix% qBittorrentConfInterfaceNameLine: !qBittorrentConfInterfaceNameLine!
	
	rem find the interface name specified in the InterfaceAddress line above
	for /f "tokens=2* delims=^=" %%a in ("!qBittorrentConfInterfaceNameLine!") do set qBittorrentConfInterfaceName=%%a
	echo %msgPrefix% qBittorrentConfInterfaceName: !qBittorrentConfInterfaceName!
	
	rem check if the specified IP matches the current IP
	if !qBittorrentConfInterfaceAddress! == %InterfaceIP% (
		rem IPs match
		echo %msgPrefix% qBittorrentConf IP is correct :^)
		
		rem check if the qBittorrent process is running
		for /f %%x in ('tasklist /nh /fi "imagename eq %qBittorrentProcess%"') do (
			if %%x == %qBittorrentProcess% (
				rem qBittorrent is running.. nothing to do
				set msg=%msgPrefix% qBittorrent is ok :^)
				echo !msg!
				rem log to file
				>> %logFilePath% echo !msg!
			) else (
				rem qBittorrent is not running.. kill it then start it
				taskkill /f /im "%qBittorrentProcess%"
				start "" %qBittorrentExeFile%
				set msg=%msgPrefix% qBittorrent was not running.. just booted? ..starting it now^^!
				echo !msg!
				rem log to file
				>> %logFilePath% echo !msg!
			)
		)
	) else (
		rem IPs do not match
		echo %msgPrefix% qBittorrentConfInterfaceAddress is incorrect.. updating from !qBittorrentConfInterfaceAddress! to %InterfaceIP%
		
		set dateStamp=%DATE:~6,4%_%DATE:~3,2%_%DATE:~0,2%__%TIME:~0,2%_%TIME:~3,2%_%TIME:~6,2%
		rem replace spaces with 0s
		set dateStamp=!dateStamp: =0!
		echo %msgPrefix% dateStamp: !dateStamp!
		
		set backupFilePath=%qBittorrentConfPath%\backups\qBittorrent_backup_!dateStamp!.ini
		echo %msgPrefix% backupFilePath: !backupFilePath!
		
		set tempFilePath=%qBittorrentConfPath%\backups\qBittorrent_temp_!dateStamp!.ini
		echo %msgPrefix% tempFilePath: !tempFilePath!
		
		rem kill qBittorrent
		taskkill /f /im %qBittorrentProcess%
		
		rem create a timestamped backup of the qBittorrent.conf file before we update it
		xcopy /Y %qBittorrentConfFilePath% !backupFilePath!*
		
		rem loop through each line of the temp file
		(for /f "tokens=*" %%a in (!backupFilePath!) do (
			set line=%%a
			
			if /i "!line!"=="!qBittorrentConfInterfaceAddressLine!" (
				rem found the Interface Address line.. replace it with the new IP
				echo Session\InterfaceAddress=!InterfaceIP!
			) else (
				rem not the interface address line.. just add the line
				echo !line!
			)
		rem output to a temp file
		)) > !tempFilePath!
		
		rem replace qBittorrent.conf with the temp file
		xcopy /Y !tempFilePath! %qBittorrentConfFilePath%*
		rem delete the temp file
		del !tempFilePath!
		rem start qBittorrent
		start "" %qBittorrentExeFile%
		set msg=%msgPrefix% Interface IP changed from !qBittorrentConfInterfaceAddress! to %InterfaceIP% .. updating config and restarting^^!
		echo !msg!
		rem log to file
		>> %logFilePath% echo !msg!
	)
) else (
	rem interface assigned IP is invalid.. kill qBittorrent
  	echo Interface IP.. %InterfaceIP% is invalid :(
	taskkill /f /im %qBittorrentProcess%
	set msg=%msgPrefix% Interface IP %InterfaceIP% doesn't match pattern %expectedInterfaceIP% .. stopping qBittorrent :^(
	echo !msg!
	rem log to file
	>> %logFilePath% echo !msg!
)
exit
