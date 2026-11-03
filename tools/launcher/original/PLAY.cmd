@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0runtime\Godot.exe" (
  echo The bundled Godot runtime is missing. Please restore the runtime folder.
  pause
  exit /b 1
)
set "NEED_IMPORT=0"
if not exist "%~dp0.godot\imported\campus.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\gamer_setup_pack.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\office_chair.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\office_desk_140x60.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\server_rack.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\server_rack_1.glb-*.scn" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\folder.svg-*.ctex" set "NEED_IMPORT=1"
if "%NEED_IMPORT%"=="1" (
  echo Preparing the campus for its first launch. This may take a moment.
  "%~dp0runtime\Godot.exe" --headless --editor --path "%~dp0." --import
)
start "ENSA Incident Response" "%~dp0runtime\Godot.exe" --path "%~dp0."
exit /b 0
