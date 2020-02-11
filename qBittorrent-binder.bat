@echo off
setlocal enabledelayedexpansion

rem *****************************************************************************************************************************
rem Update the following constants to match your needs
rem Get adapter info using the following: netsh interface ip show address
rem Add a scheduled task to repeat at desired interval i.e. every 2 minutes
rem qBittorrent should not be set to start up automatically, instead it is brought up by this script
rem expectedAdapterIP is a pattern that your Adapter IP should begin with when properly connected..
rem in my case this is 10.153.*.*
rem Before running, take a backup of your qBittorrent.ini from %appdata%\qBittorrent
set interfaceName="Windscribe IKEv2"
set expectedAdapterIP=10.153
set qBittorrentLogFilePath="C:\Scripts\Logs\qbittorrent-log.txt"
rem *****************************************************************************************************************************

set qBittorrentExeFile="%ProgramFiles%\qbittorrent\qbittorrent.exe"
set qBittorrentConfPath=%appdata%\qBittorrent
set msgPrefix=[%date% - %time%]
echo %msgPrefix% qBittorrentConfPath: %qBittorrentConfPath%
set qBittorrentConfFilePath=%qBittorrentConfPath%\qBittorrent.ini
echo %msgPrefix% qBittorrentConfFilePath: %qBittorrentConfFilePath%
set qbittorrentProcess=qbittorrent.exe

rem find the ip assigned to the interface
for /f "tokens=3" %%i in ('netsh interface ip show address %interfaceName% ^| findstr "IP Address"') do set adapterIP=%%i
echo %msgPrefix% adapterIP: %adapterIP%

rem check if the IP matches the pattern specified.. i.e. avoid updating for 169.*.*.*
echo.%adapterIP% | find /i "%expectedAdapterIP%" >nul
if not errorlevel 1 (
	echo %msgPrefix% Adapter IP %adapterIP% matches pattern %expectedAdapterIP% :^)
	
	rem find the InterfaceAddress line specified in the qBittorrent.conf file
	for /f "tokens=1" %%i in ('findstr /i "Connection\InterfaceAddress=" %qBittorrentConfFilePath%') do set qBittorrentConfLine=%%i
	echo %msgPrefix% qBittorrentConfLine: !qBittorrentConfLine!
	
	rem find the ip address specified in the InterfaceAddress line above
	for /f "tokens=2 delims=^= " %%a in ("!qBittorrentConfLine!") do set qBittorrentConfIP=%%a
	echo %msgPrefix% qBittorrentConfIP: !qBittorrentConfIP!
	
	rem check if the specified ip matches the current ip
	if !qBittorrentConfIP! == %adapterIP% (
		rem ips match
		echo %msgPrefix% qBittorrentConf IP is correct :^)
		
		rem check if the qbittorrent process is running
		FOR /f %%x IN ('tasklist /nh /fi "imagename eq %qbittorrentProcess%"') do (
			if %%x == %qbittorrentProcess% (
				rem qbittorrent is running.. nothing to do
				set msg=%msgPrefix% qBittorrent is ok :^)
				echo !msg!
				rem log to file
				>> %qBittorrentLogFilePath% echo !msg!
				exit
			) else (
				rem qbittorrent is not running.. kill it then start it
				taskkill /f /im "%qbittorrentProcess%"
				start "" %qBittorrentExeFile%
				set msg=%msgPrefix% qBittorrent was not running.. just booted? ..starting it now!
				echo !msg!
				rem log to file
				>> %qBittorrentLogFilePath% echo !msg!
				exit
			)
		)
	) else (
		rem ips do not match
		echo %msgPrefix% qBittorrentConf IP Incorrect.. updating from !qBittorrentConfIP! to %adapterIP% !
		
		set dateStamp=%DATE:~6,4%_%DATE:~3,2%_%DATE:~0,2%__%TIME:~0,2%_%TIME:~3,2%_%TIME:~6,2%
		echo %msgPrefix% dateStamp: !dateStamp!
		
		set backupFilePath=%qBittorrentConfPath%\backups\qBittorrent_backup_!dateStamp!.ini
		echo %msgPrefix% backupFilePath: !backupFilePath!
		
		set tempFilePath=%qBittorrentConfPath%\backups\qBittorrent_temp_!dateStamp!.ini
		echo %msgPrefix% tempFilePath: !tempFilePath!
		
		rem kill qBittorrent
		taskkill /f /im %qbittorrentProcess%
		
		rem create a timestamped backup of the qBittorrent.conf file before we update it
		xcopy /Y %qBittorrentConfFilePath% !backupFilePath!*
		
		rem loop through each line of the temp file
		(for /f "tokens=*" %%a in (!backupFilePath!) do (
			set line=%%a
			
			if /i "!line!"=="!qBittorrentConfLine!" (
				rem found the Interface Address line.. replace it with the new ip
				echo Connection\InterfaceAddress=!adapterIP!
			) else (
				rem not the interface line.. just add the line
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
		set msg=%msgPrefix% Adapter IP changed from !qBittorrentConfIP! to %adapterIP% .. updating config and restarting!
		echo !msg!
		rem log to file
		>> %qBittorrentLogFilePath% echo !msg!
		exit
	)
) else (
	rem adapters assigned ip is invalid.. kill qBittorrent
  	echo Adapter IP.. %adapterIP% is invalid :(
	taskkill /f /im %qbittorrentProcess%
	set msg=%msgPrefix% Adapter IP %adapterIP% doesn't match pattern %expectedAdapterIP% .. stopping qBittorrent :^(
	echo !msg!
	rem log to file
	>> %qBittorrentLogFilePath% echo !msg!
	exit
)