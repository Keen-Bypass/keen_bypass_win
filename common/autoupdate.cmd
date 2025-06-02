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
:: ## СОХРАНЕНИЕ ТЕКУЩЕЙ СТРАТЕГИИ ##
:: ############################
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('LocalApplicationData')"`) do set "LOCALAPPDATA_PATH=%%i"
set "STRATEGY_FOLDER=%LOCALAPPDATA_PATH%\keen_bypass_win"
set "STRATEGY=1"
set "BASE_DIR=C:\keen_bypass_win\keen_bypass_win"

:: Определение текущей стратегии
if exist "%BASE_DIR%\1_easy.cmd" (
    for /f %%F in ('sc query winws1 ^| findstr "RUNNING"') do set "STRATEGY=1"
)
if exist "%BASE_DIR%\2_medium.cmd" (
    for /f %%F in ('sc query winws1 ^| findstr "RUNNING"') do (
        if exist "%BASE_DIR%\2_medium.cmd" set "STRATEGY=2"
    )
)
if exist "%BASE_DIR%\3_hard.cmd" (
    for /f %%F in ('sc query winws1 ^| findstr "RUNNING"') do (
        if exist "%BASE_DIR%\3_hard.cmd" set "STRATEGY=3"
    )
)
if exist "%BASE_DIR%\4_extreme.cmd" (
    for /f %%F in ('sc query winws1 ^| findstr "RUNNING"') do (
        if exist "%BASE_DIR%\4_extreme.cmd" set "STRATEGY=4"
    )
)

:: Сохранение стратегии
mkdir "%STRATEGY_FOLDER%" >nul 2>&1
del /Q /F "%STRATEGY_FOLDER%\*.txt" >nul 2>&1
echo. > "%STRATEGY_FOLDER%\%STRATEGY%.txt"
echo [ИНФО] Сохранена стратегия: %STRATEGY%

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
