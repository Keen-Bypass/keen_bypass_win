@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

set "PROJECT_NAME=Keen Bypass для Windows"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\ProgramData\keen_bypass_win"
set "KEEN_BYPASS_DIR=%TARGET_DIR%\keen_bypass"
set "ZAPRET_DIR=%TARGET_DIR%\zapret-win-bundle-master"
set "SYS_DIR=%TARGET_DIR%\sys"
set "AUTOUPDATE_DIR=%SYS_DIR%\autoupdate"
set "LOGS_DIR=%SYS_DIR%\logs"
set "BACKUP_DIR=%SYS_DIR%\backup"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "MAX_RETRIES=3"
set "FILE_RETRIES=3"

echo %PROJECT_NAME% - Автоматическое обновление
echo ===================================
echo.

call :CHECK_ADMIN_RIGHTS
if errorlevel 1 exit /b 1

call :GET_PROJECT_VERSION
if errorlevel 1 (
    echo [ОШИБКА] Не удалось получить версию.
    set "PROJECT_VERSION=unknown"
)

call :GET_CURRENT_PRESET

echo Удаление предыдущих установок...
call :CLEANUP_PREVIOUS_INSTALLATION

echo Загрузка Zapret...
call :DOWNLOAD_PROJECT
if errorlevel 1 (
    echo [ОШИБКА] Загрузка не удалась
    exit /b 1
)

echo Распаковка...
call :EXTRACT_ARCHIVE
if errorlevel 1 (
    echo [ОШИБКА] Распаковка не удалась
    exit /b 1
)

echo Создание структуры системных папок...
mkdir "%SYS_DIR%" >nul 2>&1
mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
mkdir "%LOGS_DIR%" >nul 2>&1
mkdir "%BACKUP_DIR%" >nul 2>&1

echo Настройка пресета %PRESET%...
call :DOWNLOAD_FILES
if errorlevel 1 (
    echo [ОШИБКА] Загрузка файлов пресета не удалась
    exit /b 1
)

echo Применение пресета %PRESET%...
call :APPLY_PRESET
if errorlevel 1 (
    echo [ОШИБКА] Не удалось применить пресет
    exit /b 1
)

echo Настройка автообновления...
call :SETUP_AUTO_UPDATE >nul 2>&1

call :SAVE_VERSION_INFO
call :CLEANUP_TEMP_FILES

echo.
echo [УСПЕХ] Пресет %PRESET% активирован.
echo.
exit /b 0

:: ============ ОСНОВНЫЕ ФУНКЦИИ ============

:CHECK_ADMIN_RIGHTS
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
        exit /b 1
    )
    exit /b 0

:GET_PROJECT_VERSION
    set "VERSION_FILE=%TEMP%\keen_version.txt"
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE%')" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        for /f "delims=" %%i in ('type "%VERSION_FILE%" ^| powershell -Command "$input.Trim()"') do (
            set "PROJECT_VERSION=%%i"
        )
        del /q "%VERSION_FILE%" >nul 2>&1
        exit /b 0
    )
    exit /b 1

:GET_CURRENT_PRESET
    set "PRESET=3"
::    if exist "%BACKUP_DIR%" (
::        for /f "delims=" %%f in ('dir /b "%BACKUP_DIR%\*.cmd" 2^>nul') do (
::            set "FILENAME=%%~nf"
::            set "PRESET=!FILENAME:preset=!"
::        )
::    )
    exit /b 0

:CLEANUP_PREVIOUS_INSTALLATION
    call :STOP_SERVICE %SERVICE_NAME% >nul 2>&1
    call :STOP_SERVICE %WINDIVERT_SERVICE% >nul 2>&1
    
    if exist "%KEEN_BYPASS_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%KEEN_BYPASS_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
        timeout /t 2 >nul
        rmdir /s /q "%KEEN_BYPASS_DIR%" 2>nul
    )
    
    if exist "%ZAPRET_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%ZAPRET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
        timeout /t 2 >nul
        rmdir /s /q "%ZAPRET_DIR%" 2>nul
    )
    
    exit /b 0

:STOP_SERVICE
    net stop %1 >nul 2>&1
    sc delete %1 >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%1" /f >nul 2>&1
    exit /b 0

:DOWNLOAD_PROJECT
    set "RETRY_COUNT=0"
    
    :download_retry
    set /a RETRY_COUNT+=1
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip', '%ARCHIVE%')" >nul 2>&1
    
    if exist "%ARCHIVE%" (
        exit /b 0
    ) else (
        if !RETRY_COUNT! lss !MAX_RETRIES! (
            timeout /t 5 >nul
            goto download_retry
        ) else (
            exit /b 1
        )
    )

:EXTRACT_ARCHIVE
    mkdir "%TARGET_DIR%" >nul 2>&1
    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force" >nul 2>&1
    
    if not exist "%ZAPRET_DIR%" (
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master" >nul 2>&1
        )
    )
    
    if exist "%ZAPRET_DIR%" (
        exit /b 0
    ) else (
        exit /b 1
    )

:DOWNLOAD_FILES
    set "GITHUB_PRESET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/presets/"
    set "GITHUB_IPSET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/ipset/"
    
    mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    mkdir "%KEEN_BYPASS_DIR%\files" >nul 2>&1
    
    :: Все пресеты загружаем из папки presets
    for %%i in (1 2 3 4 5 6 7 8 9) do (
        call :DOWNLOAD_SINGLE_FILE "!GITHUB_PRESET!preset%%i.cmd" "%KEEN_BYPASS_DIR%\preset%%i.cmd"
    )
    
    :: Файлы ipset загружаем из папки ipset
    for %%i in (hosts-antifilter.txt hosts-rkn.txt hosts-exclude.txt) do (
        call :DOWNLOAD_SINGLE_FILE "!GITHUB_IPSET!%%i" "%KEEN_BYPASS_DIR%\files\%%i"
    )
    
    exit /b 0

:DOWNLOAD_SINGLE_FILE
    set "URL=%~1"
    set "DEST=%~2"
    set "FILE_RETRY_COUNT=0"
    
    :file_download_retry
    set /a FILE_RETRY_COUNT+=1
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    
    if exist "%DEST%" (
        exit /b 0
    ) else (
        if !FILE_RETRY_COUNT! lss !FILE_RETRIES! (
            timeout /t 2 >nul
            goto file_download_retry
        )
        exit /b 1
    )

:APPLY_PRESET
    cd /d "%KEEN_BYPASS_DIR%" >nul 2>&1
    
    call :STOP_SERVICE %SERVICE_NAME% >nul 2>&1
    call :STOP_SERVICE %WINDIVERT_SERVICE% >nul 2>&1
    timeout /t 2 >nul
    
    if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1
    
    del /Q "%BACKUP_DIR%\*.cmd" 2>nul
    
    set "PRESET_FILE=%KEEN_BYPASS_DIR%\preset%PRESET%.cmd"
    
    if not exist "%PRESET_FILE%" (
        exit /b 1
    )
    
    copy "%PRESET_FILE%" "%BACKUP_DIR%\preset%PRESET%.cmd" >nul 2>&1
    
    powershell -Command "Start-Process -Verb RunAs -FilePath '%PRESET_FILE%' -Wait" >nul 2>&1
    exit /b 0

:SETUP_AUTO_UPDATE
    set "AUTOUPDATE_TASK=keen_bypass_win_autoupdate"
    set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
    
    schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
    if %errorlevel% equ 0 (
        schtasks /Delete /TN "%AUTOUPDATE_TASK%" /F >nul 2>&1
    )
    
    mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('!GITHUB_URL!', '%AUTOUPDATE_DIR%\autoupdate.cmd')" >nul 2>&1
    
    schtasks /Create /TN "%AUTOUPDATE_TASK%" /SC MINUTE /MO 10 ^
        /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '%AUTOUPDATE_DIR%\autoupdate.cmd' -ArgumentList '-silent'\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1

    exit /b 0

:SAVE_VERSION_INFO
    set "VERSION_FILE=%AUTOUPDATE_DIR%\version.txt"
    
    mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1

    netsh interface tcp set global timestamps=enabled

    exit /b 0

:CLEANUP_TEMP_FILES
    if exist "%TEMP%\master.zip" (
        del /q "%TEMP%\master.zip" >nul 2>&1
    )
    if exist "%TEMP%\k.cmd" (
        del /q "%TEMP%\k.cmd" >nul 2>&1
    )
    exit /b 0
