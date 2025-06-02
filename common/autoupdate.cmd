@echo off
chcp 1251 >nul
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

:: Проверка прав администратора
NET FILE >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    PowerShell -Command "Start-Process cmd -ArgumentList '/c chcp 1251>nul & %~dpnx0' -Verb RunAs"
    EXIT /B
)

:: ############################
:: ## ПРОВЕРКА ВЕРСИИ ##
:: ############################
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "LOCAL_VERSION_FILE=C:\keen_bypass_win\keen_bypass_win\sys\version.txt"
set "REMOTE_VERSION_FILE=%TEMP%\remote_version.txt"

:: Загрузка удаленной версии
powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%REMOTE_VERSION_FILE%')" >nul 2>&1

if not exist "%REMOTE_VERSION_FILE%" (
    echo [ОШИБКА] Не удалось проверить версию. Обновление пропущено.
    exit /b 0
)

set /p REMOTE_VERSION= < "%REMOTE_VERSION_FILE%"
del /q "%REMOTE_VERSION_FILE%" >nul 2>&1

:: Чтение локальной версии
set "LOCAL_VERSION=unknown"
if exist "%LOCAL_VERSION_FILE%" (
    set /p LOCAL_VERSION= < "%LOCAL_VERSION_FILE%"
)

:: Сравнение версий
if "!REMOTE_VERSION!" == "!LOCAL_VERSION!" (
    echo Версия актуальна: !LOCAL_VERSION!
    exit /b 0
)

:: ############################
:: ## ЗАПУСК ОБНОВЛЕНИЯ ##
:: ############################
SET "SCRIPT_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/netupdate.cmd"
SET "SAVE_PATH=%TEMP%\keen_bypass.cmd"

echo Обнаружена новая версия: !REMOTE_VERSION! (текущая: !LOCAL_VERSION!).
echo Запуск обновления...

powershell -Command "[IO.File]::WriteAllText('%SAVE_PATH%', (Invoke-WebRequest -Uri '%SCRIPT_URL%' -UseBasicParsing).Content, [Text.Encoding]::GetEncoding(1251))"

IF NOT EXIST "%SAVE_PATH%" (
    echo [ОШИБКА] Не удалось загрузить netupdate.cmd
    exit /B 1
)

cmd /c chcp 1251>nul & call "%SAVE_PATH%"
DEL /F /Q "%SAVE_PATH%" >NUL 2>&1

exit /b 0
