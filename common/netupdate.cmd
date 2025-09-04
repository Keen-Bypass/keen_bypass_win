@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

set "PROJECT_NAME=Keen Bypass для Windows"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_win"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
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
    pause
    exit /b 1
)

echo Распаковка...
call :EXTRACT_ARCHIVE
if errorlevel 1 (
    echo [ОШИБКА] Распаковка не удалась
    pause
    exit /b 1
)

echo Настройка пресета %PRESET%...
call :DOWNLOAD_PRESET_FILES
if errorlevel 1 (
    echo [ОШИБКА] Загрузка файлов пресета не удалась
    pause
    exit /b 1
)

echo Применение пресета %PRESET%...
call :APPLY_PRESET

echo Настройка автообновления...
call :SETUP_AUTO_UPDATE

call :SAVE_VERSION_INFO
call :CLEANUP_TEMP_FILES

echo.
echo [УСПЕХ] Пресет %PRESET% активирован.
echo.
exit /b 0

:: ============ ОСНОВНЫЕ ФУНКЦИИ ============

:CHECK_ADMIN_RIGHTS
    echo Проверка прав администратора...
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo Запрос прав администратора...
        powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
        exit /b 1
    )
    echo [УСПЕХ] Права администратора подтверждены
    exit /b 0

:GET_PROJECT_VERSION
    set "VERSION_FILE=%TEMP%\keen_version.txt"
    echo Получение актуальной версии...
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE%')" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        for /f "delims=" %%i in ('type "%VERSION_FILE%" ^| powershell -Command "$input.Trim()"') do (
            set "PROJECT_VERSION=%%i"
        )
        del /q "%VERSION_FILE%" >nul 2>&1
        echo [УСПЕХ] Версия получена: !PROJECT_VERSION!
        exit /b 0
    )
    exit /b 1

:GET_CURRENT_PRESET
    set "PRESET=1"
    echo Принудительно выбран пресет: 1
    exit /b 0

:: :GET_CURRENT_PRESET
::     for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
::         set "DOCUMENTS_PATH=%%i"
::     )
::     set "PRESET_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
::     set "PRESET=1"
::     
::     if exist "!PRESET_FOLDER!\*.txt" (
::         for /f %%F in ('dir /b "!PRESET_FOLDER!\*.txt"') do (
::             set "FILENAME=%%~nF"
::             set "PRESET=!FILENAME:~0,1!"
::         )
::     )
::     echo Текущий пресет: !PRESET!
::     exit /b 0

:CLEANUP_PREVIOUS_INSTALLATION
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    if exist "%TARGET_DIR%" (
        echo Остановка процессов и удаление директории...
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%TARGET_DIR%" 2>nul
        if not exist "%TARGET_DIR%" (
            echo [УСПЕХ] Директория удалена
        )
    )
    exit /b 0

:STOP_SERVICE
    echo Остановка службы %1...
    net stop %1 >nul 2>&1
    sc delete %1 >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%1" /f >nul 2>&1
    exit /b 0

:DOWNLOAD_PROJECT
    set "RETRY_COUNT=0"
    
    :download_retry
    set /a RETRY_COUNT+=1
    echo Попытка !RETRY_COUNT! из !MAX_RETRIES!...
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip', '%ARCHIVE%')"
    
    if exist "%ARCHIVE%" (
        echo [УСПЕХ] Архив загружен
        exit /b 0
    ) else (
        if !RETRY_COUNT! lss !MAX_RETRIES! (
            echo Пауза перед повторной попыткой...
            timeout /t 5 >nul
            goto download_retry
        ) else (
            echo [ОШИБКА] Не удалось загрузить архив после !MAX_RETRIES! попыток
            exit /b 1
        )
    )

:EXTRACT_ARCHIVE
    echo Распаковка архива...
    mkdir "%TARGET_DIR%" >nul 2>&1
    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"
    
    if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
        echo Исправление структуры папок...
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
        )
    )
    
    if exist "%TARGET_DIR%\zapret-win-bundle-master" (
        echo [УСПЕХ] Архив распакован
        exit /b 0
    ) else (
        echo [ОШИБКА] Не удалось распаковать архив
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
    
    mkdir "%BASE_DIR%" >nul 2>&1
    mkdir "%BASE_DIR%\files" >nul 2>&1
    
    set "ERROR_FLAG=0"
    
    for /L %%i in (1,1,8) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 5 (
            set "SAVE_PATH=%BASE_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_PRESET%!FILE!"
        ) else (
            set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_IPSET%!FILE!"
        )
        
        echo Загрузка: !FILE!
        call :DOWNLOAD_SINGLE_FILE "!DOWNLOAD_URL!" "!SAVE_PATH!"
        if errorlevel 1 (
            echo [ОШИБКА] Не удалось загрузить !FILE!
            set "ERROR_FLAG=1"
        ) else (
            echo [OK] !FILE!
        )
    )
    
    if !ERROR_FLAG! equ 1 (
        echo [КРИТИЧЕСКАЯ ОШИБКА] Отсутствуют необходимые файлы
        exit /b 1
    )
    exit /b 0

:DOWNLOAD_SINGLE_FILE
    set "URL=%~1"
    set "DEST=%~2"
    set "FILE_RETRY_COUNT=0"
    
    :file_download_retry
    set /a FILE_RETRY_COUNT+=1
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%DEST%')"
    
    if exist "%DEST%" (
        exit /b 0
    ) else (
        if !FILE_RETRY_COUNT! lss !FILE_RETRIES! (
            timeout /t 2 >nul
            goto file_download_retry
        )
        exit /b 1
    )

:GET_DOCUMENTS_FOLDER
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    exit /b 0

:APPLY_PRESET
    echo Применение пресета %PRESET%...
    cd /d "%BASE_DIR%"
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    
    echo Сохранение выбора пресета...
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    set "PRESET_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    
    mkdir "!PRESET_FOLDER!" >nul 2>&1
    del /Q /F "!PRESET_FOLDER!\*.txt" >nul 2>&1
    echo. > "!PRESET_FOLDER!\%PRESET%.txt"
    
    echo Запуск скрипта пресета...
    set "PRESET_FILE=%BASE_DIR%\strategy%PRESET%.cmd"
    powershell -Command "Start-Process -Verb RunAs -FilePath '%PRESET_FILE%' -Wait"
    exit /b 0

:SETUP_AUTO_UPDATE
    echo Настройка автообновления...
    
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    set "AUTOUPDATE_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    set "AUTOUPDATE_SCRIPT=!AUTOUPDATE_FOLDER!\autoupdate.cmd"
    set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
    
    schtasks /Query /TN "keen_bypass_win_autoupdate" >nul 2>&1
    if %errorlevel% equ 0 (
        schtasks /Delete /TN "keen_bypass_win_autoupdate" /F >nul 2>&1
    )
    
    mkdir "!AUTOUPDATE_FOLDER!" >nul 2>&1
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('!GITHUB_URL!', '!AUTOUPDATE_SCRIPT!')" >nul 2>&1
    
    schtasks /Create /TN "keen_bypass_win_autoupdate" /SC MINUTE /MO 10 ^
        /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '!AUTOUPDATE_SCRIPT!' -ArgumentList '-silent'\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    
    if %errorlevel% equ 0 (
        echo [УСПЕХ] Автообновление настроено
    ) else (
        echo [ОШИБКА] Не удалось создать задачу автообновления
    )
    exit /b 0

:SAVE_VERSION_INFO
    set "VERSION_PATH=%TARGET_DIR%\keen_bypass_win\sys"
    set "VERSION_FILE=%VERSION_PATH%\version.txt"
    
    echo Сохранение версии Keen Bypass...
    mkdir "%VERSION_PATH%" >nul 2>&1
    
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        echo [УСПЕХ] Версия сохранена: %PROJECT_VERSION%
    )
    exit /b 0

:CLEANUP_TEMP_FILES
    if exist "%ARCHIVE%" (
        echo Очистка временных файлов...
        del /q "%ARCHIVE%" >nul 2>&1
    )
    exit /b 0
