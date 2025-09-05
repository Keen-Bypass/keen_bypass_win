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
call :DOWNLOAD_PRESET_FILES
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

echo Очистка старых каталогов...
call :CLEANUP_OLD >nul 2>&1

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
    set "PRESET=1"
    if exist "%BACKUP_DIR%" (
        for /f "delims=" %%f in ('dir /b "%BACKUP_DIR%\*.cmd" 2^>nul') do (
            set "FILENAME=%%~nf"
            for /f "tokens=2 delims=y" %%n in ("!FILENAME!") do set "PRESET=%%n"
        )
    )
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

:DOWNLOAD_PRESET_FILES
    set "GITHUB_PRESET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/presets/"
    set "GITHUB_IPSET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/ipset/"
    
    set "FILES[1]=strategy1.cmd"
    set "FILES[2]=strategy2.cmd"
    set "FILES[3]=strategy3.cmd"
    set "FILES[4]=strategy4.cmd"
    set "FILES[5]=strategy5.cmd"
    set "FILES[6]=hosts-antifilter.txt"
    set "FILES[7]=hosts-rkn.txt"
    set "FILES[8]=hosts-exclude.txt"
    
    mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    mkdir "%KEEN_BYPASS_DIR%\files" >nul 2>&1
    
    set "ERROR_FLAG=0"
    
    for /L %%i in (1,1,8) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 5 (
            set "SAVE_PATH=%KEEN_BYPASS_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_PRESET%!FILE!"
        ) else (
            set "SAVE_PATH=%KEEN_BYPASS_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_IPSET%!FILE!"
        )
        
        call :DOWNLOAD_SINGLE_FILE "!DOWNLOAD_URL!" "!SAVE_PATH!" >nul 2>&1
        if errorlevel 1 (
            set "ERROR_FLAG=1"
        )
    )
    
    if !ERROR_FLAG! equ 1 (
        exit /b 1
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
    
    set "PRESET_FILE=%KEEN_BYPASS_DIR%\strategy%PRESET%.cmd"
    
    if not exist "%PRESET_FILE%" (
        exit /b 1
    )
    
    copy "%PRESET_FILE%" "%BACKUP_DIR%\strategy%PRESET%.cmd" >nul 2>&1
    
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
    
    exit /b 0

:CLEANUP_TEMP_FILES
    if exist "%ARCHIVE%" (
        del /q "%ARCHIVE%" >nul 2>&1
    )
    exit /b 0

:: ============ МИГРАЦИЯ СТАРЫХ КАТАЛОГОВ ============

:CLEANUP_OLD
    set "OLD_TARGET_DIR=C:\keen_bypass_win"
    if exist "!OLD_TARGET_DIR!" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '!OLD_TARGET_DIR!\*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
        timeout /t 2 >nul
        rmdir /s /q "!OLD_TARGET_DIR!" 2>nul
    )
    
    set "DOCUMENTS_PATH="
    for /f "skip=2 tokens=2*" %%i in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v "Personal" 2^>nul') do (
        set "DOCUMENTS_PATH=%%j"
    )
    
    if "!DOCUMENTS_PATH!"=="" (
        for /f "tokens=2*" %%i in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal" 2^>nul') do (
            set "DOCUMENTS_PATH=%%j"
        )
    )
    
    if "!DOCUMENTS_PATH!"=="" (
        set "DOCUMENTS_PATH=%USERPROFILE%\Documents"
    )
    
    set "OLD_DOCUMENTS_DIR=!DOCUMENTS_PATH!\keen_bypass_win"
    if exist "!OLD_DOCUMENTS_DIR!" (
        rmdir /s /q "!OLD_DOCUMENTS_DIR!" 2>nul
    )
    
    exit /b 0