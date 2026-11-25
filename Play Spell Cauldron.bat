@echo off
rem Starts the game straight away (no editor). Looks for Godot 4 in this folder,
rem in the folder above it, in the winget install, and on the PATH; without Godot, SummerEngine (tools\find_godot.bat).
setlocal
call "%~dp0tools\find_godot.bat"
if not defined GODOT (
	echo Could not find Godot 4 or SummerEngine.
	echo Put Godot_v4..._win64.exe in this folder or the folder above it, then try again.
	pause
	exit /b 1
)
call "%~dp0tools\prepare.bat" "%GODOT%"
start "" "%GODOT%" --path "%~dp0."
