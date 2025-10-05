@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

set "PROJECT_NAME=Keen Bypass for Windows"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "TARGET_DIR=C:\ProgramData\keen_bypass_win"
set "KEEN_BYPASS_DIR=%TARGET_DIR%\keen_bypass"
set "ZAPRET_DIR=%TARGET_DIR%\zapret-win-bundle-master"
set "SYS_DIR=%TARGET_DIR%\sys"
set "AUTOUPDATE_DIR=%SYS_DIR%\autoupdate"
set "LOGS_DIR=%SYS_DIR%\logs"
set "BACKUP_DIR=%SYS_DIR%\backup"
set "AUTOUPDATE_TASK=keen_bypass_win_autoupdate"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "BLOCKCHECK_PATH=%ZAPRET_DIR%\blockcheck\blockcheck.cmd"
set "VERSION_FILE=%AUTOUPDATE_DIR%\version.txt"
set "DOMAIN_LIST=rr3---sn-n8v7kn7k.googlevideo.com bbc.com rutracker.org www.youtube.com yt3.ggpht.com i.instagram.com facebook.com discordapp.com google.com yandex.ru"

set "LINES=50"
if %LINES% gtr 85 set "LINES=85"
powershell -command "&{$H=get-host;$W=$H.ui.rawui;$B=$W.buffersize;$B.width=120;$B.height=85;$W.buffersize=$B;$S=$W.windowsize;$S.width=120;$S.height=%LINES%;$W.windowsize=$S;}"

call :CHECK_ADMIN_RIGHTS
if errorlevel 1 exit /b 1

call :GET_PROJECT_VERSION
if errorlevel 1 (
    call :PRINT_ERROR "Не удалось получить версию Keen Bypass"
    set "PROJECT_VERSION=unknown"
)

:MENU_MAIN
cls
call :GET_SYSTEM_INFO

call :PRINT_MENU_HEADER
echo.
echo 1.  Установить Keen Bypass.
echo 2.  Обновить Keen Bypass.
echo.
echo 3.  Пресеты (Выбор пресета из заранее подготовленных стратегий).
echo 4.  Запустить blockcheck.
echo.
echo 5.  Остановить Zapret.
echo 6.  Запустить Zapret.
echo.
echo 7.  Выключить автообновление.
echo 8.  Включить автообновление.
echo.
echo 9.  Быстрая проверка доменов.
echo.
echo 99. Деинсталлировать Keen Bypass.
echo 00. Выход.
echo.
set /p CHOICE="Выберите действие: "

if "%CHOICE%"=="1" goto INSTALL_KEEN_BYPASS
if "%CHOICE%"=="2" goto UPDATE_KEEN_BYPASS
if "%CHOICE%"=="3" goto PRESETS_MENU
if "%CHOICE%"=="4" goto RUN_BLOCKCHECK
if "%CHOICE%"=="5" goto STOP_ZAPRET
if "%CHOICE%"=="6" goto START_ZAPRET
if "%CHOICE%"=="7" goto DISABLE_AUTO_UPDATE
if "%CHOICE%"=="8" goto ENABLE_AUTO_UPDATE
if "%CHOICE%"=="9" goto FAST_DOMAIN_CHECK_MENU
if "%CHOICE%"=="99" goto UNINSTALL_KEEN_BYPASS
if "%CHOICE%"=="00" exit /b 0

call :PRINT_ERROR "Неверный выбор: %CHOICE%"
pause
goto MENU_MAIN

:PRINT_HEADER
echo.
echo ====================================================================================================
echo                                 %PROJECT_NAME% v%PROJECT_VERSION%
echo ====================================================================================================
exit /b 0

:PRINT_MENU_HEADER
echo.
echo ========================================= Меню Keen Bypass =========================================
exit /b 0

:PRINT_SECTION
echo.
echo %~1
echo ----------------------------------------------------------------------------------------------------
exit /b 0

:PRINT_SUCCESS
echo [УСПЕХ] %~1
exit /b 0

:PRINT_ERROR
echo [ОШИБКА] %~1
exit /b 0

:PRINT_INFO
echo [ИНФО] %~1
exit /b 0

:PRINT_WARNING
echo [ПРЕДУПРЕЖДЕНИЕ] %~1
exit /b 0

:PRINT_PROGRESS
echo [ПРОЦЕСС] %~1
exit /b 0

:PRINT_DOWNLOAD
echo [ЗАГРУЗКА] %~1
exit /b 0

:GET_SYSTEM_INFO
    setlocal enabledelayedexpansion
    
    :: СБОР ИНФОРМАЦИИ О СИСТЕМЕ
    
    :: СЕТЕВАЯ ИНФОРМАЦИЯ
    set "PROVIDER_INFO=Не определено"
    set "CITY_INFO=Не определено"
    
    :: Получение информации о провайдере и городе через ipinfo.io
    powershell -Command "$ProgressPreference='SilentlyContinue'; try {$response = Invoke-RestMethod -Uri 'https://ipinfo.io/json'; $response.org + '|' + $response.city} catch {'Не доступно|Не доступно'}" > "%TEMP%\provider.txt" 2>nul
    
    if exist "%TEMP%\provider.txt" (
        for /f "tokens=1,2 delims=|" %%a in (%TEMP%\provider.txt) do (
            set "PROVIDER_INFO=%%a"
            set "CITY_INFO=%%b"
        )
        del "%TEMP%\provider.txt" 2>nul
    )
    
    :: СИСТЕМНАЯ ИНФОРМАЦИЯ
    :: Получение названия операционной системы
    for /f "tokens=*" %%i in ('powershell -Command "Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption"') do set "OS_NAME=%%i"
    
    :: ИНФОРМАЦИЯ О KEEN BYPASS
    set "GITHUB_VERSION=!PROJECT_VERSION!"
    
    :: Проверка установки Keen Bypass
    set "KB_STATUS=Не установлен"
    set "KB_VERSION=N/A"
    set "KB_DATE=N/A"
    
    if exist "%VERSION_FILE%" (
        set "KB_STATUS=Установлен"
        for /f "delims=" %%i in ('type "%VERSION_FILE%" 2^>nul') do set "KB_VERSION=%%i"
        for /f "tokens=1,2,3,4,5" %%a in ('dir "%VERSION_FILE%" /TC ^| find /i "version.txt"') do (
            if "%%c" neq "" set "KB_DATE=%%a"
        )
    )
    
    :: СТАТУС АВТООБНОВЛЕНИЯ
    set "AUTOUPDATE_STATUS=Не установлен"
    if exist "%TARGET_DIR%" (
        set "AUTOUPDATE_STATUS=Не активно"
        schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
        if !errorlevel! equ 0 set "AUTOUPDATE_STATUS=Активно"
    )
    
    :: СТАТУС СЛУЖБ
    set "WINWS_STATUS=Не установлен"
    sc query %SERVICE_NAME% >nul 2>&1
    if !errorlevel! equ 0 (
        net start | find /i "%SERVICE_NAME%" >nul 2>&1
        if !errorlevel! equ 0 (set "WINWS_STATUS=Запущен") else (set "WINWS_STATUS=Остановлен")
    )
    
    set "WINDIVERT_STATUS=Не установлен"
    sc query %WINDIVERT_SERVICE% >nul 2>&1
    if !errorlevel! equ 0 set "WINDIVERT_STATUS=Установлен"
    
    :: ТЕКУЩИЙ ПРЕСЕТ
    set "CURRENT_PRESET=N/A"
    if exist "%BACKUP_DIR%" (
        for /f "delims=" %%f in ('dir /b "%BACKUP_DIR%\*.cmd" 2^>nul') do (
            set "FILENAME=%%~nf"
            set "CURRENT_PRESET=!FILENAME:preset=!"
        )
    )
    
    :: ФОРМАТИРОВАННЫЙ ВЫВОД ИНФОРМАЦИИ
    
    echo.
    echo ====================================================================================================
    echo                                 %PROJECT_NAME% v%PROJECT_VERSION%
    echo ====================================================================================================
    
    :: ВЫВОД СЕТЕВОЙ ИНФОРМАЦИИ
    call :PRINT_SECTION "Сеть"
    echo Провайдер:            !PROVIDER_INFO! ^| !CITY_INFO!
    
    :: ВЫВОД СИСТЕМНОЙ ИНФОРМАЦИИ  
    call :PRINT_SECTION "Система"
    echo ОС:                   !OS_NAME!
    
    :: ВЫВОД ИНФОРМАЦИИ О DPI BYPASS
    call :PRINT_SECTION "DPI bypass multi platform"
    echo Keen Bypass:          !KB_STATUS! ^| !KB_VERSION! ^| !KB_DATE!     /     Доступен на GitHub: !GITHUB_VERSION!
    echo Автообновление:       !AUTOUPDATE_STATUS!
    echo Статус WINWS:         !WINWS_STATUS!
    echo Статус WINDIVERT:     !WINDIVERT_STATUS!
    echo Текущий пресет:       !CURRENT_PRESET!
    
    :: ВЫВОД ПРОВЕРКИ ДОМЕНОВ
    call :PRINT_SECTION "Быстрый результат по ключевым доменам"
    echo.
    set "COUNT=0"
    for %%D in (%DOMAIN_LIST%) do (
        set /a COUNT+=1
        if !COUNT! leq 2 (
            call :CHECK_DOMAIN "%%D"
        )
    )
    
    endlocal
    exit /b 0

:FAST_DOMAIN_CHECK
    setlocal enabledelayedexpansion
    call :PRINT_SECTION "Быстрая проверка всех доменов"
    
    echo.
    echo Проверяются домены: !DOMAIN_LIST!
    echo.
    
    for %%D in (%DOMAIN_LIST%) do (
        call :CHECK_DOMAIN "%%D"
    )
    
    endlocal
    exit /b 0

:FAST_DOMAIN_CHECK_MENU
    call :PRINT_HEADER
    call :FAST_DOMAIN_CHECK
    echo.
    pause
    goto MENU_MAIN

:CHECK_DOMAIN
    setlocal
    set "DOMAIN=%~1"
    set "PING_ICON=[X]"
    set "TLS_ICON=[X]"
    
    ping -n 1 -w 1000 "!DOMAIN!" >nul 2>&1
    if !errorlevel! equ 0 set "PING_ICON=[V]"
    
    where curl >nul 2>&1
    if !errorlevel! equ 0 (
        curl --tls-max 1.2 --max-time 1 -sSL "https://!DOMAIN!" -o nul >nul 2>&1
        if !errorlevel! equ 0 set "TLS_ICON=[V]"
    ) else (
        powershell -Command "$ProgressPreference='SilentlyContinue'; try {[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; $request = [System.Net.WebRequest]::Create('https://!DOMAIN!'); $request.Timeout = 1000; $response = $request.GetResponse(); $response.Close(); exit 0} catch {exit 1}" >nul 2>&1
        if !errorlevel! equ 0 set "TLS_ICON=[V]"
    )
    
    set "DOMAIN_DISPLAY=!DOMAIN!"
    if "!DOMAIN_DISPLAY:~50!" neq "" set "DOMAIN_DISPLAY=!DOMAIN_DISPLAY:~0,47!..."
    
    set "SPACES="
    for /l %%i in (1,1,55) do set "SPACES=!SPACES! "
    set "DOMAIN_DISPLAY=!DOMAIN!!SPACES!"
    set "DOMAIN_DISPLAY=!DOMAIN_DISPLAY:~0,55!"
    
    echo !DOMAIN_DISPLAY! : PING !PING_ICON! ^| TLS 1.2 !TLS_ICON!
    
    endlocal
    exit /b 0

:CHECK_ADMIN_RIGHTS
    call :PRINT_SECTION "Проверка прав администратора"
    net session >nul 2>&1
    if !errorlevel! neq 0 (
        echo Запрос прав администратора...
        powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\"" 
        exit /b 1
    )
    call :PRINT_SUCCESS "Привилегии администратора подтверждены"
    exit /b 0

:GET_PROJECT_VERSION
    set "VERSION_FILE_TMP=%TEMP%\keen_version.txt"
    call :PRINT_PROGRESS "Получение актуальной версии..."
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE_TMP%')" >nul 2>&1

    if exist "%VERSION_FILE_TMP%" (
        for /f "delims=" %%i in ('type "%VERSION_FILE_TMP%" ^| powershell -Command "$input.Trim()"') do set "PROJECT_VERSION=%%i"
        del /q "%VERSION_FILE_TMP%" >nul 2>&1
        call :PRINT_SUCCESS "Версия получена: %PROJECT_VERSION%"
        exit /b 0
    ) else (
        exit /b 1
    )

:VALIDATE_PROJECT_INSTALLED
    if not exist "%TARGET_DIR%" (
        call :PRINT_ERROR "Keen Bypass не установлен!"
        call :PRINT_INFO "Установите его через пункт 1"
        pause
        goto MENU_MAIN
    )
    exit /b 0

:VALIDATE_SERVICE_EXISTS
    sc query %SERVICE_NAME% >nul 2>&1
    if !errorlevel! neq 0 (
        call :PRINT_ERROR "Служба %SERVICE_NAME% не найдена!"
        call :PRINT_INFO "Установите Keen Bypass через пункт 1"
        pause
        goto MENU_MAIN
    )
    exit /b 0

:STOP_SERVICE
    call :PRINT_PROGRESS "Остановка службы %1..."
    net stop %1 >nul 2>&1
    sc delete %1 >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%1" /f >nul 2>&1
    call :PRINT_SUCCESS "Служба %1 остановлена и удалена"
    exit /b 0

:STOP_SERVICE_ONLY
    call :PRINT_PROGRESS "Остановка службы %1..."
    net stop %1 >nul 2>&1
    call :PRINT_SUCCESS "Служба %1 остановлена"
    exit /b 0

:START_SERVICE
    call :PRINT_PROGRESS "Запуск службы %1..."
    sc start %1 >nul 2>&1
    call :PRINT_SUCCESS "Служба %1 запущена"
    exit /b 0

:REMOVE_AUTOUPDATE_TASK
    schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :PRINT_PROGRESS "Удаление задачи автообновления..."
        schtasks /Delete /TN "%AUTOUPDATE_TASK%" /F >nul 2>&1
        call :PRINT_SUCCESS "Задача автообновления удалена"
    ) else (
        call :PRINT_INFO "Задача автообновления не найдена"
    )
    exit /b 0

:CREATE_AUTOUPDATE_TASK
    set "INTERVAL=%~1"
    if "!INTERVAL!"=="" set "INTERVAL=5"
    
    call :PRINT_PROGRESS "Создание задачи автообновления (интервал: !INTERVAL! минут)..."
    schtasks /Create /TN "%AUTOUPDATE_TASK%" /SC MINUTE /MO !INTERVAL! ^
        /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '%AUTOUPDATE_DIR%\autoupdate.cmd' -ArgumentList '-silent'\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    
    if !errorlevel! neq 0 exit /b 1
    call :PRINT_SUCCESS "Задача автообновления создана"
    exit /b 0

:DOWNLOAD_FILE
    set "URL=%~1"
    set "DEST=%~2"
    
    call :PRINT_DOWNLOAD "%~2"
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    if exist "!DEST!" (
        call :PRINT_SUCCESS "Файл загружен: %~2"
        exit /b 0
    ) else (
        call :PRINT_ERROR "Ошибка загрузки: %~2"
        exit /b 1
    )

:GET_DOCUMENTS_FOLDER
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    exit /b 0

:INSTALL_KEEN_BYPASS
    call :PRINT_HEADER
    call :PRINT_SECTION "Установка Keen Bypass"
    
    if exist "%TARGET_DIR%" (
        call :PRINT_INFO "Keen Bypass уже установлен"
        call :PRINT_INFO "Используйте пункт 2 для обновления"
        pause
        goto MENU_MAIN
    )
    
    call :FULL_INSTALLATION
    goto MENU_MAIN

:UPDATE_KEEN_BYPASS
    call :PRINT_SECTION "Обновление Keen Bypass"
    
    call :FULL_INSTALLATION
    goto MENU_MAIN

:RUN_BLOCKCHECK
    call :PRINT_SECTION "Запуск Blockcheck"
    
    call :VALIDATE_PROJECT_INSTALLED
    if not exist "%BLOCKCHECK_PATH%" (
        call :PRINT_ERROR "Файл blockcheck.cmd не найден"
        pause
        goto MENU_MAIN
    )
    
    call :PRINT_PROGRESS "Останавливаю Zapret для проверки блокировок..."
    call :STOP_SERVICE_ONLY %SERVICE_NAME%
    call :STOP_SERVICE_ONLY %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    call :PRINT_SUCCESS "Zapret остановлен"
    
    echo.
    call :PRINT_PROGRESS "Запуск blockcheck..."
    cd /d "%ZAPRET_DIR%\blockcheck"
    call "%BLOCKCHECK_PATH%"

    goto MENU_MAIN

:STOP_ZAPRET
    call :PRINT_SECTION "Остановка Zapret"
    
    call :STOP_SERVICE_ONLY %SERVICE_NAME%
    call :STOP_SERVICE_ONLY %WINDIVERT_SERVICE%
    call :PRINT_SUCCESS "Службы остановлены"

    goto MENU_MAIN

:START_ZAPRET
    call :PRINT_SECTION "Запуск Zapret"
    
    call :START_SERVICE %SERVICE_NAME%
    call :START_SERVICE %WINDIVERT_SERVICE%
    call :PRINT_SUCCESS "Службы запущены"

    goto MENU_MAIN

:PRESETS_MENU
    cls
    call :PRINT_SECTION "Меню выбора пресетов (Выбор пресета из заранее подготовленных стратегий)."
    
    call :VALIDATE_PROJECT_INSTALLED
    call :VALIDATE_SERVICE_EXISTS
    
    call :GET_CURRENT_STATUS
    
    echo.
    echo Статус WINWS:         !WINWS_STATUS!
    echo Статус WINDIVERT:     !WINDIVERT_STATUS!
    echo Текущий пресет:       !CURRENT_PRESET!
    echo.

    set "COUNT=0"
    for %%D in (%DOMAIN_LIST%) do (
        set /a COUNT+=1
        if !COUNT! leq 2 (
            call :CHECK_DOMAIN "%%D"
        )
    )
    echo.
    
    :PRESET_SELECTION
    echo ====================================================================================================
    echo  Выберите пресет
    echo ====================================================================================================
    echo.
    echo 1. Пресет 1 (Обычный, листы HOSTLIST+AUTOHOSTLIST+HOSTLIST-EXCLUDE).
    echo.
    echo 2. Пресет 2 (Альтернативный, листы HOSTLIST+AUTOHOSTLIST+HOSTLIST-EXCLUDE).
    echo 3. Пресет 3 (Альтернативный2, листы HOSTLIST+AUTOHOSTLIST+HOSTLIST-EXCLUDE).
    echo.
    echo 4. Пресет 4 (Сложный, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
    echo 5. Пресет 5 (Сложный2, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
    echo.
    echo 0. Вернуться в главное меню.
    echo 00. Выход.
    echo.
    set /p PRESET_CHOICE="Выберите пресет: "

    if "!PRESET_CHOICE!"=="1" set "PRESET=1" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="2" set "PRESET=2" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="3" set "PRESET=3" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="4" set "PRESET=4" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="5" set "PRESET=5" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="0" goto MENU_MAIN
    if "!PRESET_CHOICE!"=="00" exit /b 0

    call :PRINT_ERROR "Неверный выбор: !PRESET_CHOICE!"
    pause
    goto PRESET_SELECTION

:APPLY_PRESET_SILENT
    call :PRINT_PROGRESS "Применяю пресет !PRESET!..."
    net stop %SERVICE_NAME% >nul 2>&1
    net stop %WINDIVERT_SERVICE% >nul 2>&1
    timeout /t 1 >nul
    
    set "PRESET_FILE=%KEEN_BYPASS_DIR%\preset!PRESET!.cmd"
    if exist "!PRESET_FILE!" (
        cd /d "%KEEN_BYPASS_DIR%"
        
        del /Q "%BACKUP_DIR%\*.cmd" 2>nul
        call :CLEANUP_OLD_STRATEGY_FILES
        copy "!PRESET_FILE!" "%BACKUP_DIR%\preset!PRESET!.cmd" >nul 2>&1
        
        powershell -Command "Start-Process -Verb RunAs -FilePath '!PRESET_FILE!' -WindowStyle Hidden -Wait"
        
        set "CURRENT_PRESET=!PRESET!"
        call :PRINT_SUCCESS "Пресет !PRESET! применен"
    ) else (
        call :PRINT_ERROR "Файл пресета не найден: !PRESET_FILE!"
    )
    
    goto PRESETS_MENU

:DISABLE_AUTO_UPDATE
    call :PRINT_SECTION "Выключение автообновления"
    
    call :REMOVE_AUTOUPDATE_TASK

    goto MENU_MAIN

:ENABLE_AUTO_UPDATE
    call :PRINT_SECTION "Включение автообновления"
    
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        call :PRINT_ERROR "Ошибка при создании задачи. Проверьте права."
    ) else (
        call :PRINT_SUCCESS "Автообновление настроено (проверка каждые 10 минут)"
    )

    goto MENU_MAIN

:UNINSTALL_KEEN_BYPASS
    call :PRINT_SECTION "Деинсталляция Keen Bypass"
    
    call :PRINT_PROGRESS "Остановка служб..."
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    call :PRINT_PROGRESS "Удаление автообновления..."
    call :REMOVE_AUTOUPDATE_TASK
    
    call :PRINT_PROGRESS "Удаление файлов..."
    powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
    call :CLEANUP_OLD_STRATEGY_FILES
    timeout /t 2 >nul
    rmdir /s /q "%TARGET_DIR%" 2>nul
    
    if exist "%TARGET_DIR%" (
        call :PRINT_ERROR "Не удалось удалить папку %TARGET_DIR%"
        pause
        goto MENU_MAIN
    ) else (
        call :PRINT_SUCCESS "Все компоненты удалены"
    )
    
    echo.
    echo ====================================================================================================
    echo                                   УДАЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО!
    echo ====================================================================================================
    echo.
    pause
    exit /b 0

:FULL_INSTALLATION
    call :PRINT_SECTION "Проверка существующей установки"
    
    set "SERVICE_EXISTS=0"
    set "FOLDER_EXISTS=0"
    set "WINDIVERT_EXISTS=0"
    
    sc query %SERVICE_NAME% >nul 2>&1 && set "SERVICE_EXISTS=1"
    sc query %WINDIVERT_SERVICE% >nul 2>&1 && set "WINDIVERT_EXISTS=1"
    if exist "%TARGET_DIR%" set "FOLDER_EXISTS=1"
    
    call :PRINT_SECTION "Удаление предыдущих установок"
    if !SERVICE_EXISTS! equ 1 call :STOP_SERVICE %SERVICE_NAME%
    if !WINDIVERT_EXISTS! equ 1 call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    call :PRINT_PROGRESS "Остановка процессов и удаление папок keen_bypass и zapret..."
    
    if exist "%KEEN_BYPASS_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%KEEN_BYPASS_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%KEEN_BYPASS_DIR%" 2>nul
        if not exist "%KEEN_BYPASS_DIR%" (
            call :PRINT_SUCCESS "Папка keen_bypass удалена"
        )
    )
    
    if exist "%ZAPRET_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%ZAPRET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%ZAPRET_DIR%" 2>nul
        if not exist "%ZAPRET_DIR%" (
            call :PRINT_SUCCESS "Папка zapret-win-bundle-master удалена"
        )
    )

    call :PRINT_SECTION "Создание структуры папок"
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" >nul 2>&1
    if not exist "%KEEN_BYPASS_DIR%" mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    if not exist "%SYS_DIR%" mkdir "%SYS_DIR%" >nul 2>&1
    if not exist "%AUTOUPDATE_DIR%" mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" >nul 2>&1
    if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1
    call :PRINT_SUCCESS "Структура папок создана"

    call :PRINT_SECTION "Настройка автообновления"
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        call :PRINT_ERROR "Не удалось настроить автообновление"
        pause
        exit /b 1
    )

    call :PRINT_SECTION "Загрузка и установка"
    call :DOWNLOAD_AND_EXTRACT
    if errorlevel 1 (
        pause
        exit /b 1
    )
    
    call :DOWNLOAD_PRESET_FILES
    if errorlevel 1 (
        call :PRINT_WARNING "Не все файлы пресетов загружены"
    )

    set "PRESET=1"
    call :APPLY_PRESET
    exit /b 0

:SETUP_AUTO_UPDATE
    set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
    
    call :PRINT_PROGRESS "Проверка существующей задачи..."
    call :REMOVE_AUTOUPDATE_TASK >nul
    
    call :PRINT_PROGRESS "Загрузка скрипта автообновления..."
    call :DOWNLOAD_FILE "!GITHUB_URL!" "%AUTOUPDATE_DIR%\autoupdate.cmd"
    if errorlevel 1 exit /b 1
    
    call :PRINT_PROGRESS "Создание задачи..."
    call :CREATE_AUTOUPDATE_TASK 10
    exit /b !errorlevel!

:DOWNLOAD_AND_EXTRACT
    set "ARCHIVE=%TEMP%\master.zip"
    
    call :PRINT_PROGRESS "Загрузка Zapret..."
    call :DOWNLOAD_FILE "https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip" "%ARCHIVE%"
    if errorlevel 1 (
        call :PRINT_ERROR "Не удалось загрузить Zapret"
        exit /b 1
    )

    call :PRINT_PROGRESS "Распаковка архива..."
    mkdir "%TARGET_DIR%" >nul 2>&1
    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"
    
    if not exist "%ZAPRET_DIR%" (
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
        )
    )
    
    if exist "%ZAPRET_DIR%" (
        call :PRINT_SUCCESS "Установка Zapret завершена"
        exit /b 0
    ) else (
        call :PRINT_ERROR "Не удалось распаковать архив"
        exit /b 1
    )

:DOWNLOAD_PRESET_FILES
    set "GITHUB_PRESET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/presets/"
    set "GITHUB_IPSET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/ipset/"
    
    mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    mkdir "%KEEN_BYPASS_DIR%\files" >nul 2>&1
    
    set "FILES[1]=preset1.cmd"
    set "FILES[2]=preset2.cmd"
    set "FILES[3]=preset3.cmd"
    set "FILES[4]=preset4.cmd"
    set "FILES[5]=preset5.cmd"
    set "FILES[6]=hosts-antifilter.txt"
    set "FILES[7]=hosts-rkn.txt"
    set "FILES[8]=hosts-exclude.txt"
    
    for /L %%i in (1,1,8) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 5 (
            set "SAVE_PATH=%KEEN_BYPASS_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_PRESET%!FILE!"
        ) else (
            set "SAVE_PATH=%KEEN_BYPASS_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_IPSET%!FILE!"
        )
        
        call :DOWNLOAD_FILE "!DOWNLOAD_URL!" "!SAVE_PATH!"
        if errorlevel 1 (
            call :PRINT_ERROR "Не удалось загрузить !FILE!"
        ) else (
            call :PRINT_SUCCESS "Загружен !FILE!"
        )
    )
    exit /b 0

:APPLY_PRESET
    set "PRESET_FILE=%KEEN_BYPASS_DIR%\preset%PRESET%.cmd"
    if exist "%PRESET_FILE%" (
        cd /d "%KEEN_BYPASS_DIR%"
        
        del /Q "%BACKUP_DIR%\*.cmd" 2>nul
        call :CLEANUP_OLD_STRATEGY_FILES
        copy "%PRESET_FILE%" "%BACKUP_DIR%\preset%PRESET%.cmd" >nul 2>&1
        
        powershell -Command "Start-Process -Verb RunAs -FilePath '%PRESET_FILE%' -WindowStyle Hidden -Wait"
        call :PRINT_SUCCESS "Пресет %PRESET% применен"
    )
    goto FINAL_SETUP

:GET_CURRENT_STATUS
    set "CURRENT_PRESET=N/A"
    if exist "%BACKUP_DIR%" (
        for /f "delims=" %%f in ('dir /b "%BACKUP_DIR%\*.cmd" 2^>nul') do (
            set "FILENAME=%%~nf"
            set "CURRENT_PRESET=!FILENAME:preset=!"
        )
    )
    
    set "WINWS_STATUS=Не установлен"
    sc query %SERVICE_NAME% >nul 2>&1
    if !errorlevel! equ 0 (
        net start | find /i "%SERVICE_NAME%" >nul 2>&1
        if !errorlevel! equ 0 (
            set "WINWS_STATUS=Запущен"
        ) else (
            set "WINWS_STATUS=Остановлен"
        )
    )
    
    set "WINDIVERT_STATUS=Не установлен"
    sc query %WINDIVERT_SERVICE% >nul 2>&1
    if !errorlevel! equ 0 (
        set "WINDIVERT_STATUS=Установлен"
    )
    
    exit /b 0

:FINAL_SETUP
    echo.
    echo ====================================================================================================
    echo                                   УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!
    echo ====================================================================================================
    
    call :PRINT_PROGRESS "Сохранение версии Keen Bypass..."
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1
    
    call :PRINT_PROGRESS "Запуск служб..."
    call :START_SERVICE %SERVICE_NAME%
    call :START_SERVICE %WINDIVERT_SERVICE%
    
    echo.
    echo ====================================================================================================
    echo                              Keen Bypass готов к работе!
    echo ====================================================================================================
    echo.
    pause
    exit /b 0

:CLEANUP_OLD_STRATEGY_FILES
    del /Q "%ZAPRET_DIR%\config\*.txt" 2>nul
    del /Q "%ZAPRET_DIR%\config\*.ipset" 2>nul
    del /Q "%ZAPRET_DIR%\config\*.exe" 2>nul
    exit /b 0

:END
exit /b 0


