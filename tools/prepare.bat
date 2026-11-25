@echo off
rem Called by the launchers with the path of Godot. On a new computer, or when git brought new scripts or
rem pictures, Godot has to import the project once (about 5 seconds); otherwise the game does not start.
setlocal
set "ROOT=%~dp0.."
set "CACHE=%ROOT%\.godot\global_script_class_cache.cfg"
set "NEW="
if not exist "%CACHE%" set "NEW=1"
if not defined NEW for %%F in ("%ROOT%\scripts\*.gd") do if /i not "%%~nxF"=="main.gd" if not defined NEW findstr /l /c:"scripts/%%~nxF" "%CACHE%" >nul || set "NEW=1"
if not defined NEW for %%F in ("%ROOT%\art\pictures\*.svg") do if not exist "%ROOT%\.godot\imported\%%~nxF-*.ctex" set "NEW=1"
if not defined NEW exit /b 0
echo Preparing Spell Cauldron, this takes a few seconds...
"%~1" --headless --path "%ROOT%" --import >nul 2>&1
exit /b 0
