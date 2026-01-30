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
    
    :: Определяем текущего пользователя
    for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser 2^>nul') do (
        for /f "tokens=1 delims=\." %%j in ("%%i") do set "DETECTED_USER=%%j"
    )
    
    if "!DETECTED_USER!"=="" (
        set "DETECTED_USER=%USERNAME%"
    )
    
    if "!DETECTED_USER!"=="" (
        endlocal
        exit /b 1
    )
    
    :: Определяем тип учетной записи
    set "USER_TYPE=Стандартная"
    net user "!DETECTED_USER!" | findstr /r /c:"Администраторы" /c:"Administrators" >nul && set "USER_TYPE=Администратор"
    
    echo Учетная запись: !DETECTED_USER!
    echo Тип учетной записи: !USER_TYPE!
    
    endlocal & (
        set "DETECTED_USER=%DETECTED_USER%"
        set "USER_TYPE=%USER_TYPE%"
    )
    exit /b 0

:CLASHMI_CLEANUP
    echo Очистка предыдущей установки...
    
    :: Остановка процессов
    taskkill /F /IM "clashmi.exe" >nul 2>&1
    taskkill /F /IM "clashmiService.exe" >nul 2>&1
    timeout /t 2 >nul
    
    :: Сброс прокси настроек
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
    
    :: Удаление правил брандмауэра
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmi.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmiService.exe" >nul 2>&1
    
    :: Удаление файлов
    if exist "%CLASHMI_INSTALL_DIR%" (
        rmdir /s /q "%CLASHMI_INSTALL_DIR%" 2>nul
    )
    
    echo Очистка завершена.
    exit /b 0

:CLASHMI_DOWNLOAD
    echo Загрузка Clash Mi...
    
    set "CLASHMI_ZIP_FILE=%TEMP%\clashmi_latest.zip"
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%CLASHMI_DOWNLOAD_URL%', '%CLASHMI_ZIP_FILE%')" >nul 2>&1
    
    if exist "!CLASHMI_ZIP_FILE!" (
        echo Загрузка завершена.
        exit /b 0
    ) else (
        echo [ОШИБКА] Загрузка не удалась
        exit /b 1
    )

:CLASHMI_EXTRACT
    echo Распаковка архива...
    
    mkdir "%CLASHMI_INSTALL_DIR%" 2>nul
    powershell -Command "Expand-Archive -Path '%CLASHMI_ZIP_FILE%' -DestinationPath '%CLASHMI_INSTALL_DIR%' -Force" >nul 2>&1
    
    if not exist "%CLASHMI_EXE_FILE%" (
        echo [ОШИБКА] Распаковка не удалась
        exit /b 1
    )
    
    echo Распаковка завершена.
    exit /b 0

:CLASHMI_SETUP_FIREWALL
    echo Настройка брандмауэра...
    
    :: Удаляем старые правила
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmi.exe" >nul 2>&1
    netsh advfirewall firewall delete rule name="C:\Program Files\Clash Mi\clashmiService.exe" >nul 2>&1
    
    :: Создаем новые правила
    netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmi.exe" dir=in action=allow program="%CLASHMI_EXE_FILE%" enable=yes >nul 2>&1
    netsh advfirewall firewall add rule name="C:\Program Files\Clash Mi\clashmiService.exe" dir=in action=allow program="%CLASHMI_SERVICE_EXE%" enable=yes >nul 2>&1
    
    echo Настройка брандмауэра завершена.
    exit /b 0

:CLASHMI_DOWNLOAD_CONFIGS
    echo Загрузка конфигурации...
    
    if not defined DETECTED_USER (
        call :GET_USER_INFO
    )
    
    if defined DETECTED_USER (
        set "USER_APPDATA=C:\Users\%DETECTED_USER%\AppData\Roaming"
    ) else (
        set "USER_APPDATA=%APPDATA%"
    )
    
    set "USER_CLASHMI_DIR=%USER_APPDATA%\clashmi\clashmi"
    set "USER_PROFILES_DIR=%USER_CLASHMI_DIR%\profiles"
    
    mkdir "%USER_CLASHMI_DIR%" 2>nul
    mkdir "%USER_PROFILES_DIR%" 2>nul
    
    :: Загрузка конфигурационных файлов
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%CLASHMI_CONFIG_URL1%', '%USER_CLASHMI_DIR%\setting.json')" >nul 2>&1
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%CLASHMI_CONFIG_URL2%', '%USER_CLASHMI_DIR%\service_core_setting.json')" >nul 2>&1
    
    if defined USER_TYPE (
        if /i "%USER_TYPE%"=="Стандартная" (
            powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%CLASHMI_CONFIG_URL4%', '%USER_PROFILES_DIR%\config.yaml')" >nul 2>&1
        ) else (
            powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%CLASHMI_CONFIG_URL3%', '%USER_PROFILES_DIR%\config_tun.yaml')" >nul 2>&1
        )
    )
    
    echo Загрузка конфигурации завершена.
    exit /b 0

:CLASHMI_CREATE_SHORTCUTS
    echo Создание ярлыков...
    
    if not defined DETECTED_USER (
        call :GET_USER_INFO
    )
    
    if not defined DETECTED_USER (
        echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось создать ярлыки - пользователь не определен
        exit /b 1
    )
    
    set "USER_HOME=C:\Users\%DETECTED_USER%"
    set "START_MENU=%USER_HOME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    
    mkdir "!START_MENU!" 2>nul
    
    :: Создание ярлыка в меню Пуск
    powershell -Command "$ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut('!START_MENU!\%CLASHMI_SHORTCUT_NAME%.lnk'); $sc.TargetPath='%CLASHMI_EXE_FILE%'; $sc.WorkingDirectory='%CLASHMI_INSTALL_DIR%'; $sc.Save()" >nul 2>&1
    
    if exist "!START_MENU!\%CLASHMI_SHORTCUT_NAME%.lnk" (
        echo Ярлыки созданы.
        exit /b 0
    ) else (
        echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось создать ярлыки
        exit /b 1
    )

:CLASHMI_AUTORUN
    echo Настройка автозапуска...
    
    if not defined DETECTED_USER (
        call :GET_USER_INFO
    )
    
    if not defined DETECTED_USER (
        echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось настроить автозапуск - пользователь не определен
        exit /b 1
    )
    
    :: Удаляем старую задачу
    schtasks /Delete /TN "Clash Mi Autorun" /F >nul 2>&1
    
    :: Создаем XML для задачи
    set "TASK_XML=%TEMP%\clashmi_autorun.xml"
    
    (
        echo ^<?xml version="1.0" encoding="UTF-16"?^>
        echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
        echo   ^<RegistrationInfo^>
        echo     ^<Author^>System^</Author^>
        echo   ^</RegistrationInfo^>
        echo   ^<Triggers^>
        echo     ^<LogonTrigger^>
        echo       ^<Enabled^>true^</Enabled^>
        echo       ^<Delay^>PT30S^</Delay^>
        echo     ^</LogonTrigger^>
        echo   ^</Triggers^>
        echo   ^<Principals^>
        echo     ^<Principal id="Author"^>
        echo       ^<UserId^>%USERDOMAIN%\%DETECTED_USER%^</UserId^>
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
        echo       ^<StopOnIdleEnd^>true^</StopOnIdleEnd^>
        echo       ^<RestartOnIdle^>false^</RestartOnIdle^>
        echo     ^</IdleSettings^>
        echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
        echo     ^<Enabled^>true^</Enabled^>
        echo     ^<Hidden^>false^</Hidden^>
        echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
        echo     ^<WakeToRun^>false^</WakeToRun^>
        echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
        echo     ^<Priority^>7^</Priority^>
        echo   ^</Settings^>
        echo   ^<Actions Context="Author"^>
        echo     ^<Exec^>
        echo       ^<Command^>%CLASHMI_EXE_FILE%^</Command^>
        echo       ^<Arguments^>--launch_startup^</Arguments^>
        echo     ^</Exec^>
        echo   ^</Actions^>
        echo ^</Task^>
    ) > "!TASK_XML!"
    
    :: Импортируем задачу
    schtasks /Create /TN "Clash Mi Autorun" /XML "!TASK_XML!" /F >nul 2>&1
    
    del "!TASK_XML!" 2>nul
    
    echo Настройка автозапуска завершена.
    exit /b 0

:CLASHMI_START_AUTO
    echo Запуск Clash Mi...
    
    if not exist "%CLASHMI_EXE_FILE%" (
        echo [ОШИБКА] Clash Mi не найден
        exit /b 1
    )
    
    :: Запуск приложения
    powershell -Command "Start-Process -FilePath '%CLASHMI_EXE_FILE%' -ArgumentList '--launch_startup' -WindowStyle Hidden" >nul 2>&1
    
    :: Ждем запуска
    timeout /t 5 >nul
    
    :: Проверяем запуск
    tasklist | find /i "clashmi.exe" >nul 2>&1
    if errorlevel 0 (
        echo Clash Mi запущен.
        exit /b 0
    ) else (
        echo [ПРЕДУПРЕЖДЕНИЕ] Clash Mi не запустился автоматически
        exit /b 1
    )

:CLASHMI_CLEANUP_TEMP
    echo Очистка временных файлов...
    
    if exist "%TEMP%\clashmi_latest.zip" (
        del /q "%TEMP%\clashmi_latest.zip" >nul 2>&1
    )
    
    echo Очистка завершена.
    exit /b 0
