@echo off
chcp 1251 >nul
SETLOCAL ENABLEEXTENSIONS
NET FILE >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    PowerShell -Command "Start-Process cmd -ArgumentList '/c chcp 1251>nul & %~dpnx0' -Verb RunAs"
    EXIT /B
)
SET "SCRIPT_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/netupdate.cmd"
SET "SAVE_PATH=%TEMP%\keen_bypass.cmd"
PowerShell -Command "[IO.File]::WriteAllText('%SAVE_PATH%', (Invoke-WebRequest -Uri '%SCRIPT_URL%' -UseBasicParsing).Content, [Text.Encoding]::GetEncoding(1251))"
IF NOT EXIST "%SAVE_PATH%" (
    echo Îøèáêà çàãðóçêè
    PAUSE
    EXIT /B 1
)
cmd /c chcp 1251>nul & call "%SAVE_PATH%"
DEL /F /Q "%SAVE_PATH%" >NUL 2>&1
EXIT /B
