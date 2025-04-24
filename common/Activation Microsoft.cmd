@echo off
SETLOCAL ENABLEEXTENSIONS

fltmc >nul 2>&1 || (
    PowerShell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Основная часть скрипта
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$Host.UI.RawUI.WindowTitle = 'Activation Microsoft'; [Console]::OutputEncoding = [Text.Encoding]::UTF8; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $scriptBlock = { iex (irm -Uri 'https://get.activated.win') }; Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command & { [Console]::OutputEncoding = [Text.Encoding]::UTF8; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (irm -Uri ''https://get.activated.win'') }' -WindowStyle Hidden"

exit
