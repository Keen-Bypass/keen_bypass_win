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
set "DOMAIN_LIST=rr3---sn-n8v7kn7k.googlevideo.com www.youtube.com yt3.ggpht.com rutracker.org i.instagram.com facebook.com discordapp.com google.com yandex.ru"

:: Clash Mi настройки
set "CLASHMI_VERSION=1.0.17.300"
set "CLASHMI_DOWNLOAD_URL=https://github.com/KaringX/clashmi/releases/download/v%CLASHMI_VERSION%/clashmi_%CLASHMI_VERSION%_windows_x64.zip"
set "CLASHMI_INSTALL_DIR=C:\Program Files\Clash Mi"
set "CLASHMI_EXE_FILE=%CLASHMI_INSTALL_DIR%\clashmi.exe"
set "CLASHMI_SERVICE_EXE=%CLASHMI_INSTALL_DIR%\clashmiService.exe"
set "CLASHMI_SHORTCUT_NAME=Clash Mi"
set "CLASHMI_APPDATA_DIR=%APPDATA%\clashmi\clashmi"
set "CLASHMI_PROFILES_DIR=%CLASHMI_APPDATA_DIR%\profiles"
set "CLASHMI_CONFIG_URL1=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/refs/heads/main/clashmi/clashmi/setting.json"
set "CLASHMI_CONFIG_URL2=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/refs/heads/main/clashmi/clashmi/service_core_setting.json"
set "CLASHMI_CONFIG_URL3=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/refs/heads/main/clashmi/mihomo/config_tun.yaml"
set "CLASHMI_CONFIG_URL4=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/refs/heads/main/clashmi/mihomo/config.yaml"

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
echo 10. Clash Mi (Mihomo).
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
if "%CHOICE%"=="10" goto CLASHMI_MENU
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
setlocal
set "TEXT=%~1"
set "PADDING="
for /l %%i in (1,1,55) do set "PADDING=!PADDING! "
set "TEXT=!TEXT!!PADDING!"
set "TEXT=!TEXT:~0,55!"
echo !TEXT!
endlocal
exit /b 0

:PRINT_PROGRESS_WITH_STATUS
setlocal
set "TEXT=%~1"
set "STATUS=%~2"
set "PADDING="
for /l %%i in (1,1,55) do set "PADDING=!PADDING! "
set "TEXT=!TEXT!!PADDING!"
set "TEXT=!TEXT:~0,55!"
echo !TEXT! [!STATUS!]
endlocal
exit /b 0

:PRINT_DOWNLOAD
setlocal
set "FILENAME=%~1"
set "PADDING="
for /l %%i in (1,1,45) do set "PADDING=!PADDING! "
set "FILENAME=!FILENAME!!PADDING!"
set "FILENAME=!FILENAME:~0,45!"
echo !FILENAME! [OK]
endlocal
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
    
    :: СТАТУС CLASH MI
    set "CLASHMI_STATUS=Не установлен"
    if exist "%CLASHMI_INSTALL_DIR%" (
        tasklist | find /i "clashmi.exe" >nul 2>&1
        if !errorlevel! equ 0 (set "CLASHMI_STATUS=Запущен") else (set "CLASHMI_STATUS=Установлен")
    )
    
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
    echo Clash Mi:             !CLASHMI_STATUS!
    
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
        curl --tls-max 1.2 --max-time 3 -sSL "https://!DOMAIN!" -o nul >nul 2>&1
        if !errorlevel! equ 0 set "TLS_ICON=[V]"
    ) else (
        powershell -Command "$ProgressPreference='SilentlyContinue'; try {[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; $request = [System.Net.WebRequest]::Create('https://!DOMAIN!'); $request.Timeout = 5000; $response = $request.GetResponse(); $response.Close(); exit 0} catch {exit 1}" >nul 2>&1
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
    call :PRINT_PROGRESS_WITH_STATUS "Привилегии администратора подтверждены" "OK"
    exit /b 0

:GET_PROJECT_VERSION
    set "VERSION_FILE_TMP=%TEMP%\keen_version.txt"
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE_TMP%')" >nul 2>&1

    if exist "%VERSION_FILE_TMP%" (
        for /f "delims=" %%i in ('type "%VERSION_FILE_TMP%" ^| powershell -Command "$input.Trim()"') do set "PROJECT_VERSION=%%i"
        del /q "%VERSION_FILE_TMP%" >nul 2>&1
        call :PRINT_PROGRESS_WITH_STATUS "Получение актуальной версии" "OK"
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
    call :PRINT_PROGRESS_WITH_STATUS "Служба %1 остановлена и удалена" "OK"
    exit /b 0

:STOP_SERVICE_ONLY
    call :PRINT_PROGRESS "Остановка службы %1..."
    net stop %1 >nul 2>&1
    call :PRINT_PROGRESS_WITH_STATUS "Служба %1 остановлена" "OK"
    exit /b 0

:START_SERVICE
    call :PRINT_PROGRESS "Запуск службы %1..."
    sc start %1 >nul 2>&1
    call :PRINT_PROGRESS_WITH_STATUS "Служба %1 запущена" "OK"
    exit /b 0

:REMOVE_AUTOUPDATE_TASK
    schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :PRINT_PROGRESS "Удаление задачи автообновления..."
        schtasks /Delete /TN "%AUTOUPDATE_TASK%" /F >nul 2>&1
        call :PRINT_PROGRESS_WITH_STATUS "Задача автообновления удалена" "OK"
    ) else (
        call :PRINT_PROGRESS_WITH_STATUS "Задача автообновления не найдена" "SKIP"
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
    call :PRINT_PROGRESS_WITH_STATUS "Задача автообновления создана" "OK"
    exit /b 0

:DOWNLOAD_FILE
    set "URL=%~1"
    set "DEST=%~2"
    set "FILENAME=%~n2%~x2"
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    if exist "!DEST!" (
        call :PRINT_DOWNLOAD "!FILENAME!"
        exit /b 0
    ) else (
        echo !FILENAME! [ERROR]
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
    call :PRINT_PROGRESS_WITH_STATUS "Zapret остановлен" "OK"
    
    echo.
    call :PRINT_PROGRESS "Запуск blockcheck..."
    cd /d "%ZAPRET_DIR%\blockcheck"
    call "%BLOCKCHECK_PATH%"

    goto MENU_MAIN

:STOP_ZAPRET
    call :PRINT_SECTION "Остановка Zapret"
    
    call :STOP_SERVICE_ONLY %SERVICE_NAME%
    call :STOP_SERVICE_ONLY %WINDIVERT_SERVICE%
    call :PRINT_PROGRESS_WITH_STATUS "Службы остановлены" "OK"

    goto MENU_MAIN

:START_ZAPRET
    call :PRINT_SECTION "Запуск Zapret"
    
    call :START_SERVICE %SERVICE_NAME%
    call :START_SERVICE %WINDIVERT_SERVICE%
    call :PRINT_PROGRESS_WITH_STATUS "Службы запущены" "OK"

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
    echo 1. Пресет 1 (skip googlevideo) (обновлено).
    echo.
    echo 2. Пресет 2 (обновлено).
    echo 3. Пресет 3 (обновлено).
    echo 4. Пресет 4 (обновлено).
    echo 5. Пресет 5 (обновлено).
    echo 6. Пресет 6 (обновлено).
    echo 7. Пресет 7 (обновлено).
    echo.
    echo 8. Пресет 8 (wssize 1:6) (обновлено).
    echo 9. Пресет 9 (wssize 1:6) (обновлено).
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
    if "!PRESET_CHOICE!"=="6" set "PRESET=6" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="7" set "PRESET=7" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="8" set "PRESET=8" & goto APPLY_PRESET_SILENT
    if "!PRESET_CHOICE!"=="9" set "PRESET=9" & goto APPLY_PRESET_SILENT
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
        call :PRINT_PROGRESS_WITH_STATUS "Пресет !PRESET! применен" "OK"
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
        call :PRINT_PROGRESS_WITH_STATUS "Все компоненты удалены" "OK"
    )
    echo.
    echo ====================================================================================================
    echo                                   УДАЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО!
    echo ====================================================================================================
    echo.
    pause
    if exist "%TEMP%\k.cmd" (
        del /q "%TEMP%\k.cmd" >nul 2>&1
    )
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
    
    call :PRINT_PROGRESS "Остановка процессов и удаление директории..."
    if exist "%KEEN_BYPASS_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%KEEN_BYPASS_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%KEEN_BYPASS_DIR%" 2>nul
        if not exist "%KEEN_BYPASS_DIR%" (
            call :PRINT_PROGRESS_WITH_STATUS "Папка keen_bypass удалена" "OK"
        )
    )
    
    if exist "%ZAPRET_DIR%" (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%ZAPRET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%ZAPRET_DIR%" 2>nul
        if not exist "%ZAPRET_DIR%" (
            call :PRINT_PROGRESS_WITH_STATUS "Папка zapret-win-bundle-master удалена" "OK"
        )
    )

    call :PRINT_SECTION "Создание структуры папок"
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" >nul 2>&1
    if not exist "%KEEN_BYPASS_DIR%" mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    if not exist "%SYS_DIR%" mkdir "%SYS_DIR%" >nul 2>&1
    if not exist "%AUTOUPDATE_DIR%" mkdir "%AUTOUPDATE_DIR%" >nul 2>&1
    if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" >nul 2>&1
    if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1
    call :PRINT_PROGRESS_WITH_STATUS "Структура папок создана" "OK"

    call :PRINT_SECTION "Настройка автообновления"
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        call :PRINT_ERROR "Не удалось настроить автообновление"
        pause
        exit /b 1
    )

    call :PRINT_SECTION "Загрузка и распаковка"
    call :DOWNLOAD_AND_EXTRACT
    if errorlevel 1 (
        pause
        exit /b 1
    )
    
    call :DOWNLOAD_FILES
    if errorlevel 1 (
        call :PRINT_WARNING "Не все файлы пресетов загружены"
    )

    call :PRINT_SECTION "Установка"
    set "PRESET=2"
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
        call :PRINT_PROGRESS_WITH_STATUS "Установка Zapret завершена" "OK"
        exit /b 0
    ) else (
        call :PRINT_ERROR "Не удалось распаковать архив"
        exit /b 1
    )

:DOWNLOAD_FILES
    set "GITHUB_PRESET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/presets/"
    set "GITHUB_IPSET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/ipset/"
    
    mkdir "%KEEN_BYPASS_DIR%" >nul 2>&1
    mkdir "%KEEN_BYPASS_DIR%\files" >nul 2>&1
    
    :: Все пресеты загружаем из папки presets
    for %%i in (1 2 3 4 5 6 7 8 9) do (
        call :DOWNLOAD_FILE "!GITHUB_PRESET!preset%%i.cmd" "%KEEN_BYPASS_DIR%\preset%%i.cmd"
    )
    
    :: Файлы ipset загружаем из папки ipset
    for %%i in (hosts-antifilter.txt hosts-rkn.txt hosts-exclude.txt) do (
        call :DOWNLOAD_FILE "!GITHUB_IPSET!%%i" "%KEEN_BYPASS_DIR%\files\%%i"
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
        call :PRINT_PROGRESS_WITH_STATUS "Применение пресета %PRESET%" "OK"
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
    call :PRINT_PROGRESS_WITH_STATUS "Сохранение версии Keen Bypass" "OK"

    netsh interface tcp set global timestamps=enabled

    echo.
    call :PRINT_SECTION "Запуск служб"
    call :START_SERVICE %SERVICE_NAME%
    call :START_SERVICE %WINDIVERT_SERVICE%

    call :CLEANUP_TEMP_FILES
    echo.
    echo ====================================================================================================
    echo                              Keen Bypass готов к работе!
    echo ====================================================================================================
    echo.
    pause
    exit /b 0

:CLEANUP_TEMP_FILES
    if exist "%TEMP%\master.zip" (
        del /q "%TEMP%\master.zip" >nul 2>&1
    )
    exit /b 0

:CLEANUP_OLD_STRATEGY_FILES
    del /Q "%ZAPRET_DIR%\config\*.txt" 2>nul
    del /Q "%ZAPRET_DIR%\config\*.ipset" 2>nul
    del /Q "%ZAPRET_DIR%\config\*.exe" 2>nul
    exit /b 0

:CLASHMI_MENU
    cls
    call :PRINT_SECTION "Clash Mi (Mihomo)"
    
    echo.
    echo 1. Установить.
    echo 2. Запустить.
    echo.
    echo 99. Удалить.
    echo.
    echo 0. Назад.
    echo 00. Выход.
    echo.
    set /p CLASHMI_CHOICE="Выберите действие: "

    if "!CLASHMI_CHOICE!"=="1" goto INSTALL_CLASHMI
    if "!CLASHMI_CHOICE!"=="2" goto START_CLASHMI
    if "!CLASHMI_CHOICE!"=="99" goto UNINSTALL_CLASHMI
    if "!CLASHMI_CHOICE!"=="0" goto MENU_MAIN
    if "!CLASHMI_CHOICE!"=="00" exit /b 0

    call :PRINT_ERROR "Неверный выбор: !CLASHMI_CHOICE!"
    pause
    goto CLASHMI_MENU

:INSTALL_CLASHMI
    call :PRINT_SECTION "Установка Clash Mi"
    
    echo Установка Clash MI...
    echo Версия: v%CLASHMI_VERSION%
    call :GET_USER_INFO
    echo.
    
    call :CLASHMI_STOP_PROCESSES
    call :CLASHMI_CLEANUP
    call :CLASHMI_DOWNLOAD
    call :CLASHMI_EXTRACT
    call :CLASHMI_SETUP_FIREWALL
    call :CLASHMI_DOWNLOAD_CONFIGS
    call :CLASHMI_CREATE_SHORTCUTS
    call :CLASHMI_CLEANUP_TEMP
    
    echo.
    call :PRINT_SECTION "Установка завершена"
    echo Установка Clash MI завершена!
    echo.
    echo Версия: v%CLASHMI_VERSION%
    echo Программа: %CLASHMI_INSTALL_DIR%
    echo Конфигурация: %CLASHMI_APPDATA_DIR%
    echo.
    pause
    goto CLASHMI_MENU

:GET_USER_INFO
    setlocal enabledelayedexpansion
    
    for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
        for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
    )
    
    if not "!DETECTED_USER!"=="" (
        set "CHECK_USER=!DETECTED_USER!"
    ) else (
        set "CHECK_USER=%USERNAME%"
    )
    
    echo Учетная запись: !CHECK_USER!
    
    set "USER_TYPE=Стандартная"
    net user "!CHECK_USER!" | findstr /r /c:"Администраторы" /c:"Administrators" >nul && set "USER_TYPE=Администратор"
    
    echo Тип учетной записи: !USER_TYPE!
    
    endlocal & (
        set "DETECTED_USER=%DETECTED_USER%"
        set "USER_TYPE=%USER_TYPE%"
    )
    exit /b 0

:START_CLASHMI
    call :PRINT_SECTION "Запуск Clash Mi"
    
    if not exist "%CLASHMI_EXE_FILE%" (
        call :PRINT_ERROR "Clash Mi не установлен!"
        call :PRINT_INFO "Установите его через пункт 1"
        pause
        goto CLASHMI_MENU
    )
    
    echo Set WshShell = CreateObject("WScript.Shell") > "%TEMP%\start_clashmi.vbs"
    echo WshShell.Run """%CLASHMI_EXE_FILE%""", 0, False >> "%TEMP%\start_clashmi.vbs"
    cscript //nologo "%TEMP%\start_clashmi.vbs"
    del "%TEMP%\start_clashmi.vbs" 2>nul
    timeout /t 3 /nobreak >nul
    
    tasklist | find /i "clashmi.exe" >nul 2>&1
    if !errorlevel! equ 0 (
        call :PRINT_PROGRESS_WITH_STATUS "Clash Mi запущен" "OK"
        call :PRINT_INFO "Программа работает в фоновом режиме"
    ) else (
        call :PRINT_WARNING "Clash Mi может запускаться медленно"
    )
    
    pause
    goto CLASHMI_MENU

:UNINSTALL_CLASHMI
    call :PRINT_SECTION "Удаление Clash Mi"
    
    call :CLASHMI_STOP_PROCESSES
    call :CLASHMI_CLEANUP
    
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmi.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="sing-tun (C:\Program Files\Clash Mi\clashmiService.exe)" >nul 2>&1
    
    call :PRINT_PROGRESS_WITH_STATUS "Удаление Clash Mi завершено" "OK"
    pause
    goto CLASHMI_MENU

:CLASHMI_STOP_PROCESSES
    call :PRINT_PROGRESS "Остановка процессов..."
    
    tasklist | find /i "clashmi.exe" >nul && taskkill /F /IM "clashmi.exe" >nul 2>&1
    tasklist | find /i "clashmiService.exe" >nul && taskkill /F /IM "clashmiService.exe" >nul 2>&1
    timeout /t 2 /nobreak >nul
    
    call :PRINT_PROGRESS_WITH_STATUS "Остановка процессов" "OK"
    exit /b 0

:CLASHMI_CLEANUP
    call :PRINT_PROGRESS "Очистка предыдущей версии..."
    
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "" /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc\Parameters" /v ProxySettingsPerUser /t REG_DWORD /d 1 /f >nul 2>&1
    netsh winhttp reset proxy >nul 2>&1
    
    powershell -Command "Get-ChildItem -Path 'C:\Users\*\AppData\Roaming\clashmi' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
    
    if defined DETECTED_USER (
        set "USER_APPDATA=C:\Users\%DETECTED_USER%\AppData\Roaming"
        set "USER_CLASHMI_DIR=%USER_APPDATA%\clashmi\clashmi"
        if exist "!USER_CLASHMI_DIR!" rmdir /s /q "!USER_CLASHMI_DIR!" 2>nul
    )
    
    if exist "%CLASHMI_APPDATA_DIR%" rmdir /s /q "%CLASHMI_APPDATA_DIR%" 2>nul
    if exist "%CLASHMI_INSTALL_DIR%" (
        rmdir /s /q "%CLASHMI_INSTALL_DIR%" 2>nul
        timeout /t 1 >nul
        if exist "%CLASHMI_INSTALL_DIR%" (
            powershell -Command "Remove-Item -Path '%CLASHMI_INSTALL_DIR%' -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
        )
    )
    
    if defined DETECTED_USER (
        del "C:\Users\%DETECTED_USER%\Desktop\Clash Mi.lnk" 2>nul
        del "C:\Users\%DETECTED_USER%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Clash Mi.lnk" 2>nul
        del "C:\Users\%DETECTED_USER%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Clash Mi.lnk" 2>nul
    )
    
    call :PRINT_PROGRESS_WITH_STATUS "Очистка предыдущей версии" "OK"
    exit /b 0

:CLASHMI_DOWNLOAD
    call :PRINT_PROGRESS "Загрузка Clash Mi..."
    
    set "CLASHMI_ZIP_FILE=%TEMP%\clashmi_latest.zip"
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_DOWNLOAD_URL%' -OutFile '%CLASHMI_ZIP_FILE%' -UseBasicParsing" >nul 2>&1
    
    if !errorlevel! equ 0 (
        if exist "!CLASHMI_ZIP_FILE!" (
            call :PRINT_PROGRESS_WITH_STATUS "Загрузка Clash Mi" "OK"
            exit /b 0
        )
    )
    
    call :PRINT_PROGRESS_WITH_STATUS "Загрузка Clash Mi" "FAIL"
    exit /b 1

:CLASHMI_EXTRACT
    call :PRINT_PROGRESS "Распаковка архива..."
    
    mkdir "%CLASHMI_INSTALL_DIR%" 2>nul
    powershell -Command "Expand-Archive -Path '%CLASHMI_ZIP_FILE%' -DestinationPath '%CLASHMI_INSTALL_DIR%' -Force" >nul 2>&1
    
    if not exist "%CLASHMI_EXE_FILE%" (
        call :PRINT_PROGRESS_WITH_STATUS "Распаковка архива" "FAIL"
        exit /b 1
    )
    
    call :PRINT_PROGRESS_WITH_STATUS "Распаковка архива" "OK"
    exit /b 0

:CLASHMI_SETUP_FIREWALL
    call :PRINT_PROGRESS "Настройка брандмауэра..."
    
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmi.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="sing-tun (C:\Program Files\Clash Mi\clashmiService.exe)" >nul 2>&1
    timeout /t 1 /nobreak >nul
    
    :: Создаем правила для clashmi.exe
    netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmi.exe" dir=in action=allow program="%CLASHMI_EXE_FILE%" protocol=tcp localport=any remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmi.exe" dir=in action=allow program="%CLASHMI_EXE_FILE%" protocol=udp localport=any remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    
    :: Создаем правила для clashmiService.exe если существует
    if exist "%CLASHMI_SERVICE_EXE%" (
        netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmiService.exe" dir=in action=allow program="%CLASHMI_SERVICE_EXE%" protocol=udp localport=any remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
        netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmiService.exe" dir=in action=allow program="%CLASHMI_SERVICE_EXE%" protocol=tcp localport=any remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
        netsh advfirewall firewall add rule name="sing-tun (C:\Program Files\Clash Mi\clashmiService.exe)" dir=in action=allow program="%CLASHMI_SERVICE_EXE%" protocol=tcp localport=any remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    )
    
    :: Создаем правила для портов
    netsh advfirewall firewall add rule name="clashmiService.exe" dir=in action=allow protocol=tcp localport=9090 remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    netsh advfirewall firewall add rule name="clashmiService.exe" dir=in action=allow protocol=udp localport=9090 remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    netsh advfirewall firewall add rule name="clashmiService.exe" dir=in action=allow protocol=udp localport=7890 remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    netsh advfirewall firewall add rule name="clashmiService.exe" dir=in action=allow protocol=tcp localport=7890 remoteport=any localip=any remoteip=any profile=any enable=yes >nul 2>&1 || goto FIREWALL_FAIL
    
    call :PRINT_PROGRESS_WITH_STATUS "Настройка брандмауэра" "OK"
    exit /b 0
    
:FIREWALL_FAIL
    call :PRINT_PROGRESS_WITH_STATUS "Настройка брандмауэра" "FAIL"
    exit /b 1

:CLASHMI_DOWNLOAD_CONFIGS
    call :PRINT_PROGRESS "Загрузка конфигурации..."
    
    if defined DETECTED_USER (
        set "USER_APPDATA=C:\Users\%DETECTED_USER%\AppData\Roaming"
    ) else (
        set "USER_APPDATA=%APPDATA%"
    )
    
    set "USER_CLASHMI_DIR=%USER_APPDATA%\clashmi\clashmi"
    set "USER_PROFILES_DIR=%USER_CLASHMI_DIR%\profiles"
    
    if not exist "%USER_CLASHMI_DIR%" mkdir "%USER_CLASHMI_DIR%" 2>nul
    if not exist "%USER_PROFILES_DIR%" mkdir "%USER_PROFILES_DIR%" 2>nul
    
    :: Загружаем setting.json
    call :PRINT_PROGRESS "Загрузка setting.json..."
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL1%' -OutFile '%TEMP%\setting.json' -UseBasicParsing" >nul 2>&1
    if exist "%TEMP%\setting.json" (
        copy "%TEMP%\setting.json" "%USER_CLASHMI_DIR%\" >nul 2>&1
        call :PRINT_PROGRESS_WITH_STATUS "Загрузка setting.json" "OK"
    ) else (
        call :PRINT_PROGRESS_WITH_STATUS "Загрузка setting.json" "FAIL"
    )
    
    :: Загружаем service_core_setting.json
    call :PRINT_PROGRESS "Загрузка service_core_setting.json..."
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL2%' -OutFile '%TEMP%\service_core_setting.json' -UseBasicParsing" >nul 2>&1
    if exist "%TEMP%\service_core_setting.json" (
        copy "%TEMP%\service_core_setting.json" "%USER_CLASHMI_DIR%\" >nul 2>&1
        call :PRINT_PROGRESS_WITH_STATUS "Загрузка service_core_setting.json" "OK"
    ) else (
        call :PRINT_PROGRESS_WITH_STATUS "Загрузка service_core_setting.json" "FAIL"
    )
    
    :: Загружаем конфиг в зависимости от типа учетной записи
    if defined USER_TYPE (
        if /i "%USER_TYPE%"=="Стандартная" (
            call :PRINT_PROGRESS "Загрузка config.yaml..."
            powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL4%' -OutFile '%TEMP%\config.yaml' -UseBasicParsing" >nul 2>&1
            if exist "%TEMP%\config.yaml" (
                copy "%TEMP%\config.yaml" "%USER_PROFILES_DIR%\" >nul 2>&1
                call :PRINT_PROGRESS_WITH_STATUS "Загрузка config.yaml" "OK"
            ) else (
                call :PRINT_PROGRESS_WITH_STATUS "Загрузка config.yaml" "FAIL"
            )
        ) else (
            call :PRINT_PROGRESS "Загрузка config_tun.yaml..."
            powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL3%' -OutFile '%TEMP%\config_tun.yaml' -UseBasicParsing" >nul 2>&1
            if exist "%TEMP%\config_tun.yaml" (
                copy "%TEMP%\config_tun.yaml" "%USER_PROFILES_DIR%\" >nul 2>&1
                call :PRINT_PROGRESS_WITH_STATUS "Загрузка config_tun.yaml" "OK"
            ) else (
                call :PRINT_PROGRESS_WITH_STATUS "Загрузка config_tun.yaml" "FAIL"
            )
        )
    )
    
    call :PRINT_PROGRESS "Проверка созданных файлов..."
    set "CHECK_OK=1"
    if not exist "%USER_CLASHMI_DIR%\setting.json" set "CHECK_OK=0"
    if not exist "%USER_CLASHMI_DIR%\service_core_setting.json" set "CHECK_OK=0"
    if defined USER_TYPE (
        if /i "%USER_TYPE%"=="Стандартная" (
            if not exist "%USER_PROFILES_DIR%\config.yaml" set "CHECK_OK=0"
        ) else (
            if not exist "%USER_PROFILES_DIR%\config_tun.yaml" set "CHECK_OK=0"
        )
    )
    
    if "!CHECK_OK!"=="1" (
        call :PRINT_PROGRESS_WITH_STATUS "Проверка созданных файлов" "OK"
    ) else (
        call :PRINT_PROGRESS_WITH_STATUS "Проверка созданных файлов" "FAIL"
    )
    
    exit /b 0

:CLASHMI_CREATE_SHORTCUTS
    call :PRINT_PROGRESS "Создание ярлыков..."
    
    if not defined DETECTED_USER (
        call :PRINT_PROGRESS_WITH_STATUS "Создание ярлыков" "FAIL"
        exit /b 1
    )

    set "USER_HOME=C:\Users\%DETECTED_USER%"
    set "APPDATA_USER=%USER_HOME%\AppData\Roaming"
    set "START_MENU=%APPDATA_USER%\Microsoft\Windows\Start Menu\Programs"
    set "STARTUP=%APPDATA_USER%\Microsoft\Windows\Start Menu\Programs\Startup"
    set "SHORTCUT_MAIN=%START_MENU%\%CLASHMI_SHORTCUT_NAME%.lnk"
    set "SHORTCUT_STARTUP=%STARTUP%\%CLASHMI_SHORTCUT_NAME%.lnk"

    if /i "%USER_TYPE%"=="Администратор" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_MAIN%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save();$b=[IO.File]::ReadAllBytes('%SHORTCUT_MAIN%');$b[0x15]=$b[0x15]-bor 0x20;[IO.File]::WriteAllBytes('%SHORTCUT_MAIN%',$b)" >nul 2>&1
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_MAIN%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save()" >nul 2>&1
    )

    if /i "%USER_TYPE%"=="Администратор" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_STARTUP%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.Arguments='--minimized';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save();$b=[IO.File]::ReadAllBytes('%SHORTCUT_STARTUP%');$b[0x15]=$b[0x15]-bor 0x20;[IO.File]::WriteAllBytes('%SHORTCUT_STARTUP%',$b)" >nul 2>&1
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_STARTUP%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.Arguments='--minimized';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save()" >nul 2>&1
    )

    if exist "%SHORTCUT_MAIN%" (
        if exist "%SHORTCUT_STARTUP%" (
            call :PRINT_PROGRESS_WITH_STATUS "Создание ярлыков" "OK"
        ) else (
            call :PRINT_PROGRESS_WITH_STATUS "Создание ярлыков" "PARTIAL"
        )
    ) else (
        call :PRINT_PROGRESS_WITH_STATUS "Создание ярлыков" "FAIL"
    )

    exit /b 0

:CLASHMI_CLEANUP_TEMP
    call :PRINT_PROGRESS "Очистка временных файлов..."
    
    if exist "%TEMP%\clashmi_latest.zip" del /q "%TEMP%\clashmi_latest.zip" >nul 2>&1
    if exist "%TEMP%\setting.json" del /q "%TEMP%\setting.json" >nul 2>&1
    if exist "%TEMP%\service_core_setting.json" del /q "%TEMP%\service_core_setting.json" >nul 2>&1
    if exist "%TEMP%\config_tun.yaml" del /q "%TEMP%\config_tun.yaml" >nul 2>&1
    if exist "%TEMP%\config.yaml" del /q "%TEMP%\config.yaml" >nul 2>&1
    
    call :PRINT_PROGRESS_WITH_STATUS "Очистка временных файлов" "OK"
    exit /b 0

:END
exit /b 0
