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

echo Очистка старых каталогов...
call :CLEANUP_OLD

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
    if exist "%BACKUP_DIR%" (
        for /f "delims=" %%f in ('dir /b "%BACKUP_DIR%\*.cmd" 2^>nul') do (
            set "FILENAME=%%~nf"
            for /f "tokens=2 delims=y" %%n in ("!FILENAME!") do set "PRESET=%%n"
        )
    )
    echo Текущий пресет: !PRESET!
    exit /b 0

:CLEANUP_PREVIOUS_INSTALLATION
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    echo Удаление папок keen_bypass и zapret-win-bundle-master...
    
    if exist "%KEEN_BYPASS_DIR%" (
        echo Остановка процессов и удаление папки keen_bypass...
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%KEEN_BYPASS_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%KEEN_BYPASS_DIR%" 2>nul
        if not exist "%KEEN_BYPASS_DIR%" (
            echo [УСПЕХ] Папка keen_bypass удалена
        )
    )
    
    if exist "%ZAPRET_DIR%" (
        echo Остановка процессов и удаление папки zapret...
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%ZAPRET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%ZAPRET_DIR%" 2>nul
        if not exist "%ZAPRET_DIR%" (
            echo [УСПЕХ] Папка zapret-win-bundle-master удалена
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
    
    if not exist "%ZAPRET_DIR%" (
        echo Исправление структуры папок...
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
        )
    )
    
    if exist "%ZAPRET_DIR%" (
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

:APPLY_PRESET
    echo Применение пресета %PRESET%...
    cd /d "%KEEN_BYPASS_DIR%"
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    
    echo Очистка предыдущих резервных копий...
    del /Q "%BACKUP_DIR%\*.cmd" 2>nul
    
    echo Запуск скрипта пресета...
    set "PRESET_FILE=%KEEN_BYPASS_DIR%\strategy%PRESET%.cmd"
    
    echo Создание резервной копии стратегии...
    copy "%PRESET_FILE%" "%BACKUP_DIR%\strategy%PRESET%.cmd" >nul 2>&1
    
    powershell -Command "Start-Process -Verb RunAs -FilePath '%PRESET_FILE%' -Wait"
    exit /b 0

:SETUP_AUTO_UPDATE
    echo Настройка автообновления...
    
    set "AUTOUPDATE_TASK=keen_bypass_win_autoupdate"
    set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
    
    schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
    if %errorlevel% equ 0 (
        schtasks /Delete /TN "%AUTOUPDATE_TASK%" /F >nul 2>&1
    )
    
    mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    
    echo Загрузка скрипта автообновления...
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('!GITHUB_URL!', '%AUTOUPDATE_DIR%\autoupdate.cmd')" >nul 2>&1
    
    schtasks /Create /TN "%AUTOUPDATE_TASK%" /SC MINUTE /MO 10 ^
        /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '%AUTOUPDATE_DIR%\autoupdate.cmd' -ArgumentList '-silent'\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    
    if %errorlevel% equ 0 (
        echo [УСПЕХ] Автообновление настроено
    ) else (
        echo [ОШИБКА] Не удалось создать задачу автообновления
    )
    exit /b 0

:SAVE_VERSION_INFO
    set "VERSION_FILE=%AUTOUPDATE_DIR%\version.txt"
    
    echo Сохранение версии Keen Bypass...
    mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    
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

:: ============ МИГРАЦИЯ СТАРЫХ КАТАЛОГОВ ============

:CLEANUP_OLD
    echo Очистка старых каталогов для миграции...
    
    :: Старая основная папка
    set "OLD_TARGET_DIR=C:\keen_bypass_win"
    if exist "!OLD_TARGET_DIR!" (
        echo Удаление старой папки: !OLD_TARGET_DIR!
        powershell -Command "Get-Process | Where-Object { $_.Path -like '!OLD_TARGET_DIR!\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "!OLD_TARGET_DIR!" 2>nul
        if not exist "!OLD_TARGET_DIR!" (
            echo [УСПЕХ] Старая папка удалена: !OLD_TARGET_DIR!
        ) else (
            echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось удалить: !OLD_TARGET_DIR!
        )
    )
    
    :: Старая папка в документах
    set "DOCUMENTS_PATH="
    for /f "skip=2 tokens=2*" %%i in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v "Personal" 2^>nul') do (
        set "DOCUMENTS_PATH=%%j"
    )
    
    if "!DOCUMENTS_PATH!"=="" (
        for /f "tokens=2*" %%i in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal" 2^>nul') do (
            set "DOCUMENTS_PATH=%%j"
        )
    )
    
    :: Если не нашли через реестр, используем стандартный путь
    if "!DOCUMENTS_PATH!"=="" (
        set "DOCUMENTS_PATH=%USERPROFILE%\Documents"
    )
    
    set "OLD_DOCUMENTS_DIR=!DOCUMENTS_PATH!\keen_bypass_win"
    if exist "!OLD_DOCUMENTS_DIR!" (
        echo Удаление старой папки в документах: !OLD_DOCUMENTS_DIR!
        rmdir /s /q "!OLD_DOCUMENTS_DIR!" 2>nul
        if not exist "!OLD_DOCUMENTS_DIR!" (
            echo [УСПЕХ] Старая папка в документах удалена
        ) else (
            echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось удалить папку в документах
        )
    )
    
    exit /b 0