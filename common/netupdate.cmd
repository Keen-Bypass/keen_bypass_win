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

:: Clash Mi настройки
set "CLASHMI_VERSION=1.0.18.403"
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

echo.
echo ===================================
echo Проверка установки Clash Mi...
if exist "%CLASHMI_EXE_FILE%" (
    echo Clash Mi обнаружен, выполняю обновление...
    call :INSTALL_CLASHMI
) else (
    echo Clash Mi уже установлен, пропускаем установку.
)

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
    set "PRESET=2"
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

:CREATE_AUTOUPDATE_TASK
    set "INTERVAL=%~1"
    if "!INTERVAL!"=="" set "INTERVAL=5"
    
    call :PRINT_PROGRESS "Создание задачи автообновления (интервал: !INTERVAL! минут)..."
    
    :: Используем cmd.exe напрямую без PowerShell
    schtasks /Create /TN "%AUTOUPDATE_TASK%" /SC MINUTE /MO !INTERVAL! ^
        /TR "cmd.exe /c \"call \"%AUTOUPDATE_DIR%\autoupdate.cmd\" -silent\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    
    if !errorlevel! neq 0 exit /b 1
    call :PRINT_PROGRESS_WITH_STATUS "Задача автообновления создана" "OK"
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

:: ============ CLASH MI ФУНКЦИИ ============

:INSTALL_CLASHMI
    echo.
    echo ===================================
    echo Установка Clash Mi...
    echo Версия: v%CLASHMI_VERSION%
    echo.
    
    call :GET_USER_INFO
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось определить пользователя
        exit /b 1
    )
    
    call :CLASHMI_CLEANUP
    call :CLASHMI_DOWNLOAD
    if errorlevel 1 exit /b 1
    call :CLASHMI_EXTRACT
    if errorlevel 1 exit /b 1
    call :CLASHMI_SETUP_FIREWALL
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Ошибка настройки брандмауэра
    )
    call :CLASHMI_DOWNLOAD_CONFIGS
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Ошибка загрузки конфигурации
    )
    call :CLASHMI_CREATE_SHORTCUTS
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Ошибка создания ярлыков
    )
    call :CLASHMI_AUTORUN
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Ошибка настройки автозапуска
    )
    call :CLASHMI_START_AUTO
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Ошибка запуска Clash Mi
    )
    call :CLASHMI_CLEANUP_TEMP
    
    echo.
    echo ===================================
    echo Установка Clash Mi завершена!
    echo Программа: %CLASHMI_INSTALL_DIR%
    echo Конфигурация: %CLASHMI_APPDATA_DIR%
    echo.
    
    exit /b 0

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

:CLASHMI_CLEANUP
    echo   [ИНФО] Выполнение полной очистки системы...
    
    :: 1. Остановка всех процессов Clash Mi
    echo   [ИНФО] Остановка процессов Clash Mi...
    tasklist | find /i "clashmi.exe" >nul && taskkill /F /IM "clashmi.exe" >nul 2>&1
    tasklist | find /i "clashmiService.exe" >nul && taskkill /F /IM "clashmiService.exe" >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo   [OK] Остановка процессов
    
    :: 2. Полная очистка прокси-настроек Windows
    echo   [ИНФО] Сброс системных прокси-настроек...
    
    :: Сначала определяем вошедшего пользователя, если еще не определили
    if not defined DETECTED_USER (
        for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
            for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
        )
        if not defined DETECTED_USER set "DETECTED_USER=%USERNAME%"
    )
    
    :: Получаем SID вошедшего пользователя
    set "USER_SID="
    for /f "tokens=2 delims==" %%s in ('wmic useraccount where name^="%DETECTED_USER%" get sid /value 2^>nul ^| find "SID="') do (
        set "USER_SID=%%s"
    )
    
    :: 1. Очищаем прокси для ВОШЕДШЕГО пользователя через HKU
    if defined USER_SID (
        reg add "HKU\%USER_SID%\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "HKU\%USER_SID%\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "" /f >nul 2>&1
        reg add "HKU\%USER_SID%\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>&1
        reg add "HKU\%USER_SID%\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "" /f >nul 2>&1
        echo   [OK] Для вошедшего пользователя %DETECTED_USER%
    )
    
    :: 2. Очищаем прокси для ТЕКУЩЕГО пользователя (админа через UAC)
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "" /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "" /f >nul 2>&1
    echo   [OK] Для текущего пользователя
    
    :: 3. Очищаем системные настройки (только с правами админа)
    net session >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /f >nul 2>&1
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc\Parameters" /v ProxySettingsPerUser /t REG_DWORD /d 1 /f >nul 2>&1
        netsh winhttp reset proxy >nul 2>&1
        echo   [OK] Системные настройки
    )
    
    :: 3. Удаление всех правил брандмауэра, связанных с Clash Mi
    echo   [ИНФО] Очистка правил брандмауэра...
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmi.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="clashmiService.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="sing-tun (C:\Program Files\Clash Mi\clashmiService.exe)" >nul 2>&1
    echo   [OK] Очистка брандмауэра

    :: 6. Удаление установочных файлов программы
    echo   [ИНФО] Удаление файлов программы...
    if exist "%CLASHMI_INSTALL_DIR%" (
        :: Первая попытка - стандартная
        rmdir /s /q "%CLASHMI_INSTALL_DIR%" 2>nul
        timeout /t 1 >nul
        
        :: Вторая попытка - через PowerShell если не удалось
        if exist "%CLASHMI_INSTALL_DIR%" (
            powershell -Command "Remove-Item -Path '%CLASHMI_INSTALL_DIR%' -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
            timeout /t 1 >nul
        )
        
        :: Третья попытка - через takeown и icacls если файлы заблокированы
        if exist "%CLASHMI_INSTALL_DIR%" (
            takeown /f "%CLASHMI_INSTALL_DIR%" /r /d y >nul 2>&1
            icacls "%CLASHMI_INSTALL_DIR%" /grant Everyone:F /t /c /q >nul 2>&1
            rmdir /s /q "%CLASHMI_INSTALL_DIR%" 2>nul
        )
    )
    
    if exist "%CLASHMI_INSTALL_DIR%" (
        echo   [FAIL] Удаление файлов программы
    ) else (
        echo   [OK] Удаление файлов программы
    )
    
    :: 7. Удаление пользовательских данных и конфигураций
    echo   [ИНФО] Удаление пользовательских данных...
    
    :: Получаем информацию о пользователе если не определена
    if not defined DETECTED_USER (
        setlocal enabledelayedexpansion
        for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
            for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
        )
        if not "!DETECTED_USER!"=="" (
            set "CHECK_USER=!DETECTED_USER!"
        ) else (
            set "CHECK_USER=%USERNAME%"
        )
        endlocal & set "DETECTED_USER=%DETECTED_USER%"
    )
    
    :: Удаляем данные текущего пользователя
    if defined DETECTED_USER (
        set "USER_APPDATA=C:\Users\%DETECTED_USER%\AppData\Roaming"
        
        :: Удаляем основную папку конфигурации
        set "USER_CLASHMI_DIR=%USER_APPDATA%\clashmi\clashmi"
        if exist "!USER_CLASHMI_DIR!" (
            rmdir /s /q "!USER_CLASHMI_DIR!" 2>nul
            timeout /t 1 >nul
        )
        
        :: Удаляем все возможные папки clashmi в AppData пользователя
        powershell -Command "Get-ChildItem -Path 'C:\Users\%DETECTED_USER%\AppData\Roaming' -Filter '*clashmi*' -Directory -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
        
        :: Удаляем ярлыки пользователя
        del "C:\Users\%DETECTED_USER%\Desktop\Clash Mi.lnk" 2>nul
        del "C:\Users\%DETECTED_USER%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Clash Mi.lnk" 2>nul
        del "C:\Users\%DETECTED_USER%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Clash Mi.lnk" 2>nul
        del "C:\Users\%DETECTED_USER%\Desktop\Clash Mi.url" 2>nul
    )
    
    :: Удаляем данные из общей папки AppData
    if exist "%CLASHMI_APPDATA_DIR%" (
        rmdir /s /q "%CLASHMI_APPDATA_DIR%" 2>nul
    )
    
    :: Удаляем данные для всех пользователей (глобальная очистка)
    powershell -Command "Get-ChildItem -Path 'C:\Users\*\AppData\Roaming\clashmi' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
    
    echo   [OK] Удаление пользовательских данных
    
    :: 8. Заключительная проверка и сообщение
    echo   [ИНФО] Проверка результатов очистки...
    
    set "CLEANUP_SUCCESS=1"
    
    :: Проверяем, остались ли процессы
    tasklist | find /i "clashmi.exe" >nul && set "CLEANUP_SUCCESS=0"
    tasklist | find /i "clashmiService.exe" >nul && set "CLEANUP_SUCCESS=0"
    
    :: Проверяем, осталась ли папка программы
    if exist "%CLASHMI_INSTALL_DIR%" set "CLEANUP_SUCCESS=0"
    
    if "!CLEANUP_SUCCESS!"=="1" (
        echo   [OK] Проверка результатов
        echo [УСПЕХ] Полная деинсталяция Clash Mi прошла успешно
    ) else (
        echo   [WARN] Проверка результатов
        echo [ВНИМАНИЕ] Некоторые элементы могут быть не удалены. Перезагрузите компьютер и повторите.
    )
    
    exit /b 0

:CLASHMI_DOWNLOAD
    echo   [ИНФО] Загрузка...
    
    set "CLASHMI_ZIP_FILE=%TEMP%\clashmi_latest.zip"
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_DOWNLOAD_URL%' -OutFile '%CLASHMI_ZIP_FILE%' -UseBasicParsing" >nul 2>&1
    
    if !errorlevel! equ 0 (
        if exist "!CLASHMI_ZIP_FILE!" (
            echo   [OK] Загрузка Clash Mi
            exit /b 0
        )
    )
    
    echo   [FAIL] Загрузка Clash Mi
    exit /b 1

:CLASHMI_EXTRACT
    echo   [ИНФО] Распаковка архива...
    
    mkdir "%CLASHMI_INSTALL_DIR%" 2>nul
    powershell -Command "Expand-Archive -Path '%CLASHMI_ZIP_FILE%' -DestinationPath '%CLASHMI_INSTALL_DIR%' -Force" >nul 2>&1
    
    if not exist "%CLASHMI_EXE_FILE%" (
        echo   [FAIL] Распаковка архива
        exit /b 1
    )
    
    echo   [OK] Распаковка архива
    exit /b 0

:CLASHMI_SETUP_FIREWALL
    echo   [ИНФО] Настройка брандмауэра...
    
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
    
    echo   [OK] Настройка брандмауэра
    exit /b 0
    
:FIREWALL_FAIL
    echo   [FAIL] Настройка брандмауэра
    exit /b 1

:CLASHMI_DOWNLOAD_CONFIGS
    echo   [ИНФО] Загрузка конфигурации...
    
    if defined DETECTED_USER (
        set "USER_APPDATA=C:\Users\%DETECTED_USER%\AppData\Roaming"
    ) else (
        set "USER_APPDATA=%APPDATA%"
    )
    
    set "USER_CLASHMI_DIR=%USER_APPDATA%\clashmi\clashmi"
    set "USER_PROFILES_DIR=%USER_CLASHMI_DIR%\profiles"
    
    if not exist "%USER_CLASHMI_DIR%" mkdir "%USER_CLASHMI_DIR%" 2>nul
    if not exist "%USER_PROFILES_DIR%" mkdir "%USER_PROFILES_DIR%" 2>nul
    
    :: Загружаем setting.json (всегда одинаковый для всех)
    echo   [ИНФО] Загрузка setting.json...
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL1%' -OutFile '%TEMP%\setting.json' -UseBasicParsing" >nul 2>&1
    if exist "%TEMP%\setting.json" (
        copy "%TEMP%\setting.json" "%USER_CLASHMI_DIR%\" >nul 2>&1
        echo   [OK] Загрузка setting.json
    ) else (
        echo   [FAIL] Загрузка setting.json
    )
    
    :: Загружаем service_core_setting.json в зависимости от типа учетной записи
    echo   [ИНФО] Загрузка service_core_setting.json...
    
    if defined USER_TYPE (
        if /i "%USER_TYPE%"=="Администратор" (
            :: Для админа - специальная tun версия
            set "SERVICE_CORE_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/refs/heads/main/clashmi/clashmi/service_core_setting_tun.json"
        ) else (
            :: Для обычного пользователя - стандартная версия
            set "SERVICE_CORE_URL=%CLASHMI_CONFIG_URL2%"
        )
    ) else (
        :: Если тип не определен - используем стандартную
        set "SERVICE_CORE_URL=%CLASHMI_CONFIG_URL2%"
    )
    
    powershell -Command "Invoke-WebRequest -Uri '!SERVICE_CORE_URL!' -OutFile '%TEMP%\service_core_setting.json' -UseBasicParsing" >nul 2>&1
    if exist "%TEMP%\service_core_setting.json" (
        copy "%TEMP%\service_core_setting.json" "%USER_CLASHMI_DIR%\service_core_setting.json" >nul 2>&1
        echo   [OK] Загрузка service_core_setting.json (!USER_TYPE!)
    ) else (
        echo   [FAIL] Загрузка service_core_setting.json
    )
    
    :: Загружаем config.yaml (всегда один файл для всех пользователей)
    echo   [ИНФО] Загрузка config.yaml...
    powershell -Command "Invoke-WebRequest -Uri '%CLASHMI_CONFIG_URL4%' -OutFile '%TEMP%\config.yaml' -UseBasicParsing" >nul 2>&1
    if exist "%TEMP%\config.yaml" (
        copy "%TEMP%\config.yaml" "%USER_PROFILES_DIR%\" >nul 2>&1
        echo   [OK] Загрузка config.yaml
    ) else (
        echo   [FAIL] Загрузка config.yaml
    )
    
    echo   [ИНФО] Проверка созданных файлов...
    set "CHECK_OK=1"
    if not exist "%USER_CLASHMI_DIR%\setting.json" set "CHECK_OK=0"
    if not exist "%USER_CLASHMI_DIR%\service_core_setting.json" set "CHECK_OK=0"
    if not exist "%USER_PROFILES_DIR%\config.yaml" set "CHECK_OK=0"
    
    if "!CHECK_OK!"=="1" (
        echo   [OK] Проверка созданных файлов
    ) else (
        echo   [FAIL] Проверка созданных файлов
    )
    
    exit /b 0

:CLASHMI_CREATE_SHORTCUTS
    echo   [ИНФО] Создание ярлыков...
    
    if not defined DETECTED_USER (
        echo   [FAIL] Создание ярлыков
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

    rem Закомментировано создание ярлыка в автозагрузку - временно отключено
    rem if /i "%USER_TYPE%"=="Администратор" (
    rem     powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_STARTUP%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.Arguments='--launch_startup';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save();$b=[IO.File]::ReadAllBytes('%SHORTCUT_STARTUP%');$b[0x15]=$b[0x15]-bor 0x20;[IO.File]::WriteAllBytes('%SHORTCUT_STARTUP%',$b)" >nul 2>&1
    rem ) else (
    rem     powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$sc=$ws.CreateShortcut('%SHORTCUT_STARTUP%');$sc.TargetPath='%CLASHMI_EXE_FILE%';$sc.Arguments='--launch_startup';$sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%';$sc.IconLocation='%CLASHMI_EXE_FILE%';$sc.Save()" >nul 2>&1
    rem )

    if exist "%SHORTCUT_MAIN%" (
        rem Закомментирована проверка ярлыка в автозагрузке
        rem if exist "%SHORTCUT_STARTUP%" (
        rem     echo   [OK] Создание ярлыков
        rem ) else (
        rem     echo   [PARTIAL] Создание ярлыков
        rem )
        echo   [OK] Создание ярлыков
    ) else (
        echo   [FAIL] Создание ярлыков
    )

    exit /b 0

:CLASHMI_AUTORUN
    echo   [ИНФО] Настройка автозапуска
    
    :: Проверяем, установлен ли Clash Mi
    if not exist "%CLASHMI_EXE_FILE%" (
        echo [ОШИБКА] Clash Mi не установлен!
        pause
        goto CLASHMI_MENU
    )
    
    :: Получаем информацию о текущем пользователе
    setlocal enabledelayedexpansion
    set "DETECTED_USER="
    for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
        for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
    )
    if not "!DETECTED_USER!"=="" (
        set "CHECK_USER=!DETECTED_USER!"
    ) else (
        set "CHECK_USER=%USERNAME%"
    )
    set "USER_TYPE=Стандартная"
    net user "!CHECK_USER!" | findstr /r /c:"Администраторы" /c:"Administrators" >nul && set "USER_TYPE=Администратор"
    
    :: Получаем SID пользователя
    set "USER_SID="
    for /f "tokens=2 delims= " %%s in (
        'powershell -NoProfile -ExecutionPolicy Bypass -Command "([System.Security.Principal.NTAccount]'%USERDOMAIN%\%DETECTED_USER%').Translate([System.Security.Principal.SecurityIdentifier]).Value" 2^>nul'
    ) do set "USER_SID=%%s"
    
    if "!USER_SID!"=="" (
        for /f "tokens=2 delims==" %%s in (
            'wmic useraccount where name^="%DETECTED_USER%" get sid /value 2^>nul ^| find "SID="'
        ) do set "USER_SID=%%s"
    )
    
    if "!USER_SID!"=="" (
        echo [ОШИБКА] Не удалось получить SID пользователя!
        endlocal
        pause
        goto CLASHMI_MENU
    )
    
    :: Создаем XML файл задачи
    set "TASK_NAME=Clash Mi Autorun"
    set "TASK_XML=%TEMP%\clashmi_autorun.xml"
    
    (
        echo ^<?xml version="1.0" encoding="UTF-16"?^>
        echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
        echo   ^<RegistrationInfo^>
        echo     ^<Author^>%USERDOMAIN%\%DETECTED_USER%^</Author^>
        echo     ^<URI^>\Clash Mi Autorun^</URI^>
        echo   ^</RegistrationInfo^>
        echo   ^<Triggers^>
        echo     ^<LogonTrigger id="Trigger1"^>
        echo       ^<Enabled^>true^</Enabled^>
        echo       ^<UserId^>%USERDOMAIN%\%DETECTED_USER%^</UserId^>
        echo       ^<Delay^>PT3S^</Delay^>
        echo     ^</LogonTrigger^>
        echo   ^</Triggers^>
        echo   ^<Principals^>
        echo     ^<Principal id="Principal1"^>
        echo       ^<UserId^>%USER_SID%^</UserId^>
        echo       ^<LogonType^>InteractiveToken^</LogonType^>
        echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
        echo     ^</Principal^>
        echo   ^</Principals^>
        echo   ^<Settings^>
        echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
        echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
        echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
        echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
        echo     ^<StartWhenAvailable^>false^</StartWhenAvailable^>
        echo     ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
        echo     ^<IdleSettings^>
        echo       ^<Duration^>PT10M^</Duration^>
        echo       ^<WaitTimeout^>PT1H^</WaitTimeout^>
        echo       ^<StopOnIdleEnd^>true^</StopOnIdleEnd^>
        echo       ^<RestartOnIdle^>false^</RestartOnIdle^>
        echo     ^</IdleSettings^>
        echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
        echo     ^<Enabled^>true^</Enabled^>
        echo     ^<Hidden^>false^</Hidden^>
        echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
        echo     ^<WakeToRun^>false^</WakeToRun^>
        echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
        echo     ^<Priority^>4^</Priority^>
        echo   ^</Settings^>
        echo   ^<Actions Context="Principal1"^>
        echo     ^<Exec^>
        echo       ^<Command^>%CLASHMI_EXE_FILE%^</Command^>
        echo       ^<Arguments^>--launch_startup^</Arguments^>
        echo     ^</Exec^>
        echo   ^</Actions^>
        echo ^</Task^>
    ) > "!TASK_XML!"
    
    :: Импортируем задачу в планировщик
    schtasks /Create /TN "!TASK_NAME!" /XML "!TASK_XML!" /F >nul 2>&1
    
    if !errorlevel! equ 0 (
        :: Удаляем временный XML файл
        if exist "!TASK_XML!" del "!TASK_XML!" >nul 2>&1
        echo   [OK] Настройка автозапуска
    ) else (
        echo [ОШИБКА] Ошибка при создании задачи!
        if exist "!TASK_XML!" del "!TASK_XML!" >nul 2>&1
    )
    
    endlocal
    exit /b 0

:CLASHMI_START_AUTO
    setlocal enabledelayedexpansion
    
    :: Получаем информацию о пользователе
    for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
        for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
    )
    
    if not defined DETECTED_USER set "DETECTED_USER=%USERNAME%"
    
    :: Создаем простую задачу с немедленным запуском
    set "TASK_NAME=ClashMi_Immediate_%RANDOM%"
    
    echo   [ИНФО] Создание немедленной задачи запуска...
    
    :: Создаем задачу
    schtasks /Create /TN "!TASK_NAME!" /SC ONCE /ST 00:00 /RU "!DETECTED_USER!" /RL HIGHEST ^
        /TR "\"!CLASHMI_EXE_FILE!\" --launch_startup" /F >nul 2>&1
    
    if !errorlevel! equ 0 (
        :: Немедленно запускаем задачу
        schtasks /Run /TN "!TASK_NAME!" >nul 2>&1
        
        :: Ждем немного и удаляем задачу
        timeout /t 3 >nul
        schtasks /Delete /TN "!TASK_NAME!" /F >nul 2>&1
        
        echo   [OK] Программа запущена от имени !DETECTED_USER!
    ) else (
        echo   [FAIL] Не удалось создать задачу
    )
    
    endlocal
    exit /b 0

:CLASHMI_CLEANUP_TEMP
    echo   [ИНФО] Очистка временных файлов установки...
    
    :: Удаляем скачанный архив
    if exist "%TEMP%\clashmi_latest.zip" (
        del /q "%TEMP%\clashmi_latest.zip" >nul 2>&1
        if exist "%TEMP%\clashmi_latest.zip" (
            echo   [FAIL] Удаление архива
        ) else (
            echo   [OK] Удаление архива
        )
    )
    
    :: Удаляем временные конфигурационные файлы
    set "TEMP_FILES_DELETED=0"
    set "TEMP_FILES_TOTAL=0"
    
    for %%f in (
        "%TEMP%\setting.json"
        "%TEMP%\service_core_setting.json"
        "%TEMP%\config_tun.yaml"
        "%TEMP%\config.yaml"
        "%TEMP%\clashmi_autorun.xml"
        "%TEMP%\ClashMi_OneTime_*.xml"
        "%TEMP%\clashmi_*.xml"
    ) do (
        if exist "%%f" (
            set /a "TEMP_FILES_TOTAL+=1"
            del /q "%%f" >nul 2>&1
            if not exist "%%f" set /a "TEMP_FILES_DELETED+=1"
        )
    )
    
    :: Удаляем другие временные файлы, связанные с Clash Mi
    powershell -Command "Get-ChildItem -Path '%TEMP%' -Filter '*clashmi*' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue" >nul 2>&1
    powershell -Command "Get-ChildItem -Path '%TEMP%' -Filter '*clash*' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue" >nul 2>&1
    
    :: Проверяем результаты
    if "!TEMP_FILES_TOTAL!"=="0" (
        echo   [SKIP] Удаление временных файлов
        echo   [ИНФО] Временные файлы не найдены
    ) else if "!TEMP_FILES_DELETED!"=="!TEMP_FILES_TOTAL!" (
        echo   [OK] Удаление временных файлов
        echo   [УСПЕХ] Удалено файлов: !TEMP_FILES_DELETED! из !TEMP_FILES_TOTAL!
    ) else (
        echo   [PARTIAL] Удаление временных файлов
        echo   [ВНИМАНИЕ] Удалено файлов: !TEMP_FILES_DELETED! из !TEMP_FILES_TOTAL!
    )
    
    exit /b 0
