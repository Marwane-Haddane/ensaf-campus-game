@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0runtime\Godot.exe" (
  echo The bundled Godot runtime is missing. Please restore the runtime folder.
  pause
  exit /b 1
)
rem Normal play starts the lightweight launcher immediately. Source projects
rem require the existing EDIT.cmd import preparation; exported/prepared builds
rem already include imported resources. Never block Play on a whole-world import.
start "ENSA Games" "%~dp0runtime\Godot.exe" --path "%~dp0."
exit /b 0
