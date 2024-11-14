@echo off
REM Launch WSL and run the connect_to_machines.sh script with an indicator
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
cd /d %SCRIPT_DIR%\..
for /f %%i in ('wsl wslpath "%cd%\connect_to_machines.sh"') do set WSL_SCRIPT_PATH=%%i

set WIN_USER=%USERNAME%
wsl -e bash -c "export FROM_WINDOWS=true WIN_USER=%WIN_USER% && %WSL_SCRIPT_PATH%"