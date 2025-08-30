@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Конфигурация
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "LOCAL_VERSION_FILE=C:\keen_bypass_win\keen_bypass_win\sys\version.txt"
set "REMOTE_VERSION_FILE=%TEMP%\remote_version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/netupdate.cmd"
set "SAVE_PATH=%TEMP%\keen_bypass.cmd"

:: Проверка прав администратора
net file >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c chcp 1251>nul & %~dpnx0' -Verb RunAs"
    exit /b
)

:: Основной процесс
call :Main
exit /b %errorlevel%

:Main
    :: Получение удаленной версии
    call :GetRemoteVersion
    if !errorlevel! neq 0 (
        echo [ОШИБКА] Не удалось проверить версию. Обновление пропущено.
        exit /b 0
    )

    :: Получение локальной версии
    set "LOCAL_VERSION=unknown"
    if exist "%LOCAL_VERSION_FILE%" (
        set /p LOCAL_VERSION= < "%LOCAL_VERSION_FILE%"
    )

    :: Сравнение версий
    if "!REMOTE_VERSION!" == "!LOCAL_VERSION!" (
        echo Версия актуальна: !LOCAL_VERSION!
        exit /b 0
    )

    :: Загрузка и запуск обновления
    echo Обнаружена новая версия: !REMOTE_VERSION! (текущая: !LOCAL_VERSION!).
    echo Запуск обновления...

    powershell -Command "[IO.File]::WriteAllText('%SAVE_PATH%', (Invoke-WebRequest -Uri '%SCRIPT_URL%' -UseBasicParsing).Content, [Text.Encoding]::GetEncoding(1251))"

    if not exist "%SAVE_PATH%" (
        echo [ОШИБКА] Не удалось загрузить netupdate.cmd
        exit /b 1
    )

    :: Запуск обновления
    cmd /c chcp 1251>nul & call "%SAVE_PATH%"
    del /f /q "%SAVE_PATH%" >nul 2>&1

    exit /b 0

:GetRemoteVersion
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%REMOTE_VERSION_FILE%')" >nul 2>&1
    
    if not exist "%REMOTE_VERSION_FILE%" exit /b 1
    
    set /p REMOTE_VERSION= < "%REMOTE_VERSION_FILE%"
    del /q "%REMOTE_VERSION_FILE%" >nul 2>&1
    exit /b 0
