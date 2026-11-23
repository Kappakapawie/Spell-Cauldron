@echo off
rem Starts the game straight away (no editor). Needs Godot 4 installed via winget.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path "%~dp0."
