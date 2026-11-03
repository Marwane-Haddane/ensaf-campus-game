@echo off
setlocal
cd /d "%~dp0"
start "ENSA Incident Response editor" "%~dp0runtime\Godot.exe" --editor --path "%~dp0."
exit /b 0
