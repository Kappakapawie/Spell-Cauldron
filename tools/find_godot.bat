@echo off
rem Called by the launchers: sets GODOT to the program that runs the game (first one found wins).
rem 1. Godot 4 in the project folder or the folder above it, the winget install, or godot.exe on the PATH.
rem 2. If there is no Godot: SummerEngine (Godot with extra AI tools), in the same two folders,
rem    in the usual install folders, or on the PATH.
set "GODOT="
for %%G in ("%~dp0..\Godot_v4*_win64.exe" "%~dp0..\..\Godot_v4*_win64.exe") do if not defined GODOT set "GODOT=%%~fG"
if not defined GODOT if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not defined GODOT for %%G in (godot.exe) do set "GODOT=%%~$PATH:G"
if defined GODOT exit /b 0
for %%G in ("%~dp0..\Summer*.exe" "%~dp0..\..\Summer*.exe") do if not defined GODOT set "GODOT=%%~fG"
for %%D in ("%LOCALAPPDATA%\Programs" "%LOCALAPPDATA%" "%ProgramFiles%" "%ProgramFiles(x86)%" "%~dp0..\.." "%~dp0..\..\..") do (
	if not defined GODOT for /d %%S in ("%%~D\Summer*") do (
		if not defined GODOT for %%G in ("%%~fS\Summer*.exe" "%%~fS\Godot*.exe") do if not defined GODOT set "GODOT=%%~fG"
	)
)
if not defined GODOT for %%G in (summerengine.exe summer.exe) do if not defined GODOT set "GODOT=%%~$PATH:G"
exit /b 0
