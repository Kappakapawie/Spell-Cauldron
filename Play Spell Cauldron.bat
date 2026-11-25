@echo off
rem Starts the game straight away (no editor). Looks for Godot 4 in this folder,
rem in the folder above it, in the winget install, and on the PATH (first one found wins).
setlocal
set "GODOT="
for %%G in ("%~dp0Godot_v4*_win64.exe" "%~dp0..\Godot_v4*_win64.exe") do if not defined GODOT set "GODOT=%%~fG"
if not defined GODOT if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not defined GODOT for %%G in (godot.exe) do set "GODOT=%%~$PATH:G"
if not defined GODOT (
	echo Could not find Godot 4.
	echo Put Godot_v4..._win64.exe in this folder or the folder above it, then try again.
	pause
	exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
