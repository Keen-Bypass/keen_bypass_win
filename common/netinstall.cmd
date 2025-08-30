@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Основные константы
set "PROJECT_NAME=Keen Bypass"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "TARGET_DIR=C:\keen_bypass_win"
set "AUTOUPDATE_TASK=keen_bypass_win_autoupdate"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "BLOCKCHECK_PATH=%TARGET_DIR%\zapret-win-bundle-master\blockcheck\blockcheck.cmd"

:: Проверка прав администратора
call :CHECK_ADMIN_RIGHTS
if errorlevel 1 exit /b 1

:: Получение версии Keen Bypass
call :GET_PROJECT_VERSION
if errorlevel 1 (
    echo [ОШИБКА] Не удалось получить версию Keen Bypass
    set "PROJECT_VERSION=unknown"
)

:: Главное меню
:MENU_MAIN
cls
echo ===================================
echo  %PROJECT_NAME% v%PROJECT_VERSION%
echo ===================================
echo.
echo 1. Установить Keen Bypass.
echo 2. Обновить Keen Bypass.
echo.
echo 3. Пресеты (Выбор пресета из заранее подготовленных стратегий).
echo 4. Запустить blockcheck.
echo.
echo 5. Остановить Zapret.
echo 6. Запустить Zapret.
echo.
echo 7. Выключить автообновление.
echo 8. Включить автообновление.
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
if "%CHOICE%"=="99" goto UNINSTALL_KEEN_BYPASS
if "%CHOICE%"=="00" exit /b 0

echo.
echo [ОШИБКА] Неверный выбор: %CHOICE%
pause
goto MENU_MAIN

:: ============ ОСНОВНЫЕ ФУНКЦИИ ============

:CHECK_ADMIN_RIGHTS
    echo -----------------------------------
    echo Проверка прав администратора...
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo Запрос прав администратора...
        powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
        exit /b 1
    )
    echo [УСПЕХ] Привилегии администратора подтверждены
    echo -----------------------------------
    echo.
    exit /b 0

:GET_PROJECT_VERSION
    set "VERSION_FILE=%TEMP%\keen_version.txt"
    echo Получение актуальной версии...
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE%')" >nul 2>&1

    if exist "%VERSION_FILE%" (
        for /f "delims=" %%i in ('type "%VERSION_FILE%" ^| powershell -Command "$input.Trim()"') do set "PROJECT_VERSION=%%i"
        del /q "%VERSION_FILE%" >nul 2>&1
        exit /b 0
    ) else (
        exit /b 1
    )

:VALIDATE_PROJECT_INSTALLED
    if not exist "%TARGET_DIR%" (
        echo [ОШИБКА] Keen Bypass не установлен!
        echo Установите его через пункт 1
        pause
        goto MENU_MAIN
    )
    exit /b 0

:VALIDATE_SERVICE_EXISTS
    sc query %SERVICE_NAME% >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Служба %SERVICE_NAME% не найдена!
        echo Установите Keen Bypass через пункт 1
        pause
        goto MENU_MAIN
    )
    exit /b 0

:STOP_SERVICE
    net stop %1 >nul 2>&1
    sc delete %1 >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%1" /f >nul 2>&1
    exit /b 0

:STOP_SERVICE_ONLY
    net stop %1 >nul 2>&1
    exit /b 0

:START_SERVICE
    sc start %1 >nul 2>&1
    exit /b 0

:REMOVE_AUTOUPDATE_TASK
    schtasks /Query /TN "%AUTOUPDATE_TASK%" >nul 2>&1
    if %errorlevel% equ 0 (
        schtasks /Delete /TN "%AUTOUPDATE_TASK%" /F >nul 2>&1
        echo [УСПЕХ] Задача автообновления удалена
    ) else (
        echo [ИНФО] Задача автообновления не найдена
    )
    exit /b 0

:CREATE_AUTOUPDATE_TASK
    set "INTERVAL=%1"
    if "!INTERVAL!"=="" set "INTERVAL=5"
    
    schtasks /Create /TN "%AUTOUPDATE_TASK%" /SC MINUTE /MO %INTERVAL% ^
        /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '!AUTOUPDATE_SCRIPT!' -ArgumentList '-silent'\"" ^
        /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    
    if %errorlevel% neq 0 exit /b 1
    exit /b 0

:DOWNLOAD_FILE
    set "URL=%~1"
    set "DEST=%~2"
    
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    if exist "!DEST!" exit /b 0
    exit /b 1

:GET_DOCUMENTS_FOLDER
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    exit /b 0

:: ============ НОВЫЕ ОПЕРАЦИИ МЕНЮ ============

:INSTALL_KEEN_BYPASS
    echo.
    echo ===================================
    echo  Установка Keen Bypass
    echo ===================================
    
    if exist "%TARGET_DIR%" (
        echo [ИНФО] Keen Bypass уже установлен
        echo Используйте пункт 2 для обновления
        pause
        goto MENU_MAIN
    )
    
    call :FULL_INSTALLATION
    goto MENU_MAIN

:UPDATE_KEEN_BYPASS
    echo.
    echo ===================================
    echo  Обновление Keen Bypass
    echo ===================================
    
    call :FULL_INSTALLATION
    goto MENU_MAIN

:RUN_BLOCKCHECK
    echo.
    echo ===================================
    echo  Запуск Blockcheck
    echo ===================================
    
    call :VALIDATE_PROJECT_INSTALLED
    if not exist "%BLOCKCHECK_PATH%" (
        echo [ОШИБКА] Файл blockcheck.cmd не найден
        pause
        goto MENU_MAIN
    )
    
    echo Запуск blockcheck...
    cd /d "%TARGET_DIR%\zapret-win-bundle-master\blockcheck"
    call "%BLOCKCHECK_PATH%"
    pause
    goto MENU_MAIN

:STOP_ZAPRET
    echo.
    echo ===================================
    echo  Остановка Zapret
    echo ===================================
    
    echo Остановка службы %SERVICE_NAME%...
    call :STOP_SERVICE_ONLY %SERVICE_NAME%
    echo Остановка службы %WINDIVERT_SERVICE%...
    call :STOP_SERVICE_ONLY %WINDIVERT_SERVICE%
    echo [УСПЕХ] Службы остановлены
    pause
    goto MENU_MAIN

:START_ZAPRET
    echo.
    echo ===================================
    echo  Запуск Zapret
    echo ===================================
    
    echo Запуск службы %SERVICE_NAME%...
    call :START_SERVICE %SERVICE_NAME%
    echo Запуск службы %WINDIVERT_SERVICE%...
    call :START_SERVICE %WINDIVERT_SERVICE%
    echo [УСПЕХ] Службы запущены
    pause
    goto MENU_MAIN

:PRESETS_MENU
    echo.
    echo ===================================
    echo  Пресеты стратегий
    echo ===================================
    
    call :VALIDATE_PROJECT_INSTALLED
    call :VALIDATE_SERVICE_EXISTS
    
    goto PRESET_SELECTION

:DISABLE_AUTO_UPDATE
    echo.
    echo ===================================
    echo  Выключение автообновления
    echo ===================================
    
    call :REMOVE_AUTOUPDATE_TASK
    pause
    goto MENU_MAIN

:ENABLE_AUTO_UPDATE
    echo.
    echo ===================================
    echo  Включение автообновления
    echo ===================================
    
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        echo [ОШИБКА] Ошибка при создании задачи. Проверьте права.
    ) else (
        echo [УСПЕХ] Автообновление настроено (проверка каждые 10 минут)
    )
    pause
    goto MENU_MAIN

:UNINSTALL_KEEN_BYPASS
    echo.
    echo ===================================
    echo  Деинсталляция Keen Bypass
    echo ===================================
    
    echo Остановка служб...
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    echo Удаление автообновления...
    call :REMOVE_AUTOUPDATE_TASK
    echo Удаление файлов...
    powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
    timeout /t 2 >nul
    rmdir /s /q "%TARGET_DIR%" 2>nul
    
    if exist "%TARGET_DIR%" (
        echo [ОШИБКА] Не удалось удалить папку %TARGET_DIR%
        pause
        goto MENU_MAIN
    ) else (
        echo [УСПЕХ] Все компоненты удалены
    )
    
    echo.
    echo ===================================
    echo  УДАЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО!
    echo ===================================
    echo.
    pause
    exit /b 0

:: ============ ВСПОМОГАТЕЛЬНЫЕ ПРОЦЕДУРЫ ============

:FULL_INSTALLATION
    echo Проверка существующей установки...
    set "SERVICE_EXISTS=0"
    set "FOLDER_EXISTS=0"
    set "WINDIVERT_EXISTS=0"
    
    sc query %SERVICE_NAME% >nul 2>&1 && set "SERVICE_EXISTS=1"
    sc query %WINDIVERT_SERVICE% >nul 2>&1 && set "WINDIVERT_EXISTS=1"
    if exist "%TARGET_DIR%" set "FOLDER_EXISTS=1"
    
    echo Удаление предыдущих установок...
    if %SERVICE_EXISTS% equ 1 call :STOP_SERVICE %SERVICE_NAME%
    if %WINDIVERT_EXISTS% equ 1 call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    if %FOLDER_EXISTS% equ 1 (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%TARGET_DIR%" 2>nul
        
        if exist "%TARGET_DIR%" (
            echo [ОШИБКА] Не удалось удалить директорию %TARGET_DIR%
            pause
            exit /b 1
        )
    )

    echo Настройка автообновления...
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось настроить автообновление
        pause
        exit /b 1
    )

    echo Загрузка и установка...
    call :DOWNLOAD_AND_EXTRACT
    if errorlevel 1 (
        pause
        exit /b 1
    )
    
    call :DOWNLOAD_PRESET_FILES
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Не все файлы пресетов загружены
    )

    :: Автоматически применяем пресет 1
    set "PRESET=1"
    call :APPLY_PRESET
    goto MENU_MAIN

:SETUP_AUTO_UPDATE
    call :GET_DOCUMENTS_FOLDER
    set "AUTOUPDATE_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    set "AUTOUPDATE_SCRIPT=!AUTOUPDATE_FOLDER!\autoupdate.cmd"
    set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
    
    echo Проверка существующей задачи...
    call :REMOVE_AUTOUPDATE_TASK >nul
    
    mkdir "!AUTOUPDATE_FOLDER!" >nul 2>&1
    
    echo Загрузка скрипта автообновления...
    call :DOWNLOAD_FILE "!GITHUB_URL!" "!AUTOUPDATE_SCRIPT!"
    if errorlevel 1 exit /b 1
    
    echo Создание задачи...
    call :CREATE_AUTOUPDATE_TASK 10
    exit /b %errorlevel%

:DOWNLOAD_AND_EXTRACT
    set "ARCHIVE=%TEMP%\master.zip"
    
    echo Загрузка Zapret...
    call :DOWNLOAD_FILE "https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip" "%ARCHIVE%"
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось загрузить
        exit /b 1
    )

    echo Распаковка...
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"
    
    if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
        )
    )
    
    if exist "%TARGET_DIR%\zapret-win-bundle-master" (
        echo [УСПЕХ] Установка завершена
        exit /b 0
    ) else (
        echo [ОШИБКА] Не удалось распаковать
        exit /b 1
    )

:DOWNLOAD_PRESET_FILES
    set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
    set "GITHUB_PRESET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/presets/"
    set "GITHUB_IPSET=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/ipset/"
    
    mkdir "%BASE_DIR%" >nul 2>&1
    mkdir "%BASE_DIR%\files" >nul 2>&1
    
    set "FILES[1]=strategy1.cmd"
    set "FILES[2]=strategy2.cmd"
    set "FILES[3]=strategy3.cmd"
    set "FILES[4]=strategy4.cmd"
    set "FILES[5]=hosts-antifilter.txt"
    set "FILES[6]=hosts-rkn.txt"
    set "FILES[7]=hosts-exclude.txt"
    
    for /L %%i in (1,1,7) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 4 (
            set "SAVE_PATH=%BASE_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_PRESET%!FILE!"
        ) else (
            set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_IPSET%!FILE!"
        )
        
        call :DOWNLOAD_FILE "!DOWNLOAD_URL!" "!SAVE_PATH!"
        if errorlevel 1 (
            echo [ОШИБКА] Не удалось загрузить !FILE!
        ) else (
            echo [УСПЕХ] Загружен !FILE!
        )
    )
    exit /b 0

:PRESET_SELECTION
    echo.
    echo ====================================
    echo  Выберите пресет
    echo ====================================
    echo.
    echo 1. Пресет 1 (Обычный, листы HOSTLIST+AUTOHOSTLIST+HOSTLIST-EXCLUDE).
    echo 2. Пресет 2 (Альтернативный, листы HOSTLIST+AUTOHOSTLIST+HOSTLIST-EXCLUDE).
    echo 3. Пресет 3 (Сложный, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
    echo 4. Пресет 4 (Сложный2, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
    echo.
    echo 0. Вернуться в главное меню.
    echo 00. Выход.
    echo.
    set /p PRESET_CHOICE="Выберите пресет: "

    if "%PRESET_CHOICE%"=="1" set "PRESET=1" & goto APPLY_PRESET
    if "%PRESET_CHOICE%"=="2" set "PRESET=2" & goto APPLY_PRESET
    if "%PRESET_CHOICE%"=="3" set "PRESET=3" & goto APPLY_PRESET
    if "%PRESET_CHOICE%"=="4" set "PRESET=4" & goto APPLY_PRESET
    if "%PRESET_CHOICE%"=="0" goto MENU_MAIN
    if "%PRESET_CHOICE%"=="00" exit /b 0

    echo.
    echo [ОШИБКА] Неверный выбор: %PRESET_CHOICE%
    pause
    goto PRESET_SELECTION

:APPLY_PRESET
    echo.
    echo ====================================
    echo  Применение пресета %PRESET%
    echo ====================================
    
    call :GET_DOCUMENTS_FOLDER
    set "PRESET_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    mkdir "!PRESET_FOLDER!" >nul 2>&1
    del /Q /F "!PRESET_FOLDER!\*.txt" >nul 2>&1
    echo. > "!PRESET_FOLDER!\!PRESET!.txt"
    
    set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
    echo Остановка служб...
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    
    echo Запуск пресета %PRESET%...
    set "PRESET_FILE=%BASE_DIR%\strategy%PRESET%.cmd"
    cd /d "%BASE_DIR%"
    
    powershell -Command "Start-Process -Verb RunAs -FilePath '%PRESET_FILE%' -Wait"
    goto FINAL_SETUP

:FINAL_SETUP
    echo.
    echo ====================================
    echo  УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!
    echo ====================================
    
    set "VERSION_PATH=%TARGET_DIR%\keen_bypass_win\sys"
    set "VERSION_FILE=%VERSION_PATH%\version.txt"
    
    echo Сохранение версии Keen Bypass...
    mkdir "%VERSION_PATH%" >nul 2>&1
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        echo [УСПЕХ] Отпечаток версии сохранен: %PROJECT_VERSION%
    ) else (
        echo [ОШИБКА] Не удалось записать файл версии
    )
    
    echo.
    echo Автоматический возврат в главное меню...
    timeout /t 2 >nul
    goto MENU_MAIN

:: Точка входа
if "%~1"=="" goto MENU_MAIN
exit /b 0