@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Основные константы
set "PROJECT_NAME=Keen Bypass для Windows"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "TARGET_DIR=C:\keen_bypass_win"
set "AUTOUPDATE_TASK=keen_bypass_win_autoupdate"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"

:: Проверка прав администратора
call :CHECK_ADMIN_RIGHTS
if errorlevel 1 exit /b 1

:: Получение версии проекта
call :GET_PROJECT_VERSION
if errorlevel 1 (
    echo [ОШИБКА] Не удалось получить версию проекта
    set "PROJECT_VERSION=unknown"
)

:: Главное меню
:MENU_MAIN
cls
echo ===================================
echo  %PROJECT_NAME% v%PROJECT_VERSION%
echo ===================================
echo.
echo 1. Установить или обновить проект
echo 2. Сменить стратегию
echo 3. Остановить и удалить службы
echo 4. Запустить службу
echo 5. Активация автообновления
echo 6. Удалить автообновление
echo 7. Деинсталлировать проект
echo.
choice /C 1234567 /N /M "Выберите действие [1-7]: "
goto MENU_OPTION_%errorlevel%

:MENU_OPTION_1
    goto INSTALL_PROJECT

:MENU_OPTION_2
    goto CHANGE_STRATEGY

:MENU_OPTION_3
    goto STOP_REMOVE_SERVICES

:MENU_OPTION_4
    goto START_SERVICE

:MENU_OPTION_5
    goto ENABLE_AUTO_UPDATE

:MENU_OPTION_6
    goto DISABLE_AUTO_UPDATE

:MENU_OPTION_7
    goto UNINSTALL_PROJECT

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
    
    :: Используем оригинальную логику из вашего кода
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
        echo [ОШИБКА] Проект не установлен!
        echo Установите его через пункт 1
        pause
        goto MENU_MAIN
    )
    exit /b 0

:VALIDATE_SERVICE_EXISTS
    sc query %SERVICE_NAME% >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Служба %SERVICE_NAME% не найдена!
        echo Установите проект через пункт 1
        pause
        goto MENU_MAIN
    )
    exit /b 0

:STOP_SERVICE
    net stop %1 >nul 2>&1
    sc delete %1 >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%1" /f >nul 2>&1
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

:: ============ ОСНОВНЫЕ ОПЕРАЦИИ ============

:INSTALL_PROJECT
    echo.
    echo ===================================
    echo  Проверка существующей установки
    echo ===================================
    
    set "SERVICE_EXISTS=0"
    set "FOLDER_EXISTS=0"
    set "WINDIVERT_EXISTS=0"
    
    sc query %SERVICE_NAME% >nul 2>&1 && set "SERVICE_EXISTS=1"
    sc query %WINDIVERT_SERVICE% >nul 2>&1 && set "WINDIVERT_EXISTS=1"
    if exist "%TARGET_DIR%" set "FOLDER_EXISTS=1"
    
    echo [УСПЕХ] Проверка завершена
    echo.

    echo ===================================
    echo  Удаление предыдущих установок
    echo ===================================
    
    if %SERVICE_EXISTS% equ 1 call :STOP_SERVICE %SERVICE_NAME%
    if %WINDIVERT_EXISTS% equ 1 call :STOP_SERVICE %WINDIVERT_SERVICE%
    echo.

    echo ===================================
    echo  Очистка файловой системы
    echo ===================================
    
    if %FOLDER_EXISTS% equ 1 (
        powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
        timeout /t 2 >nul
        rmdir /s /q "%TARGET_DIR%" 2>nul
        
        if exist "%TARGET_DIR%" (
            echo [ОШИБКА] Не удалось удалить директорию %TARGET_DIR%
            pause
            goto MENU_MAIN
        ) else (
            echo [УСПЕХ] Директория %TARGET_DIR% удалена
        )
    )
    echo.

    echo ===================================
    echo  Настройка автообновления
    echo ===================================
    
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось настроить автообновление
        pause
        goto MENU_MAIN
    )
    echo.

    echo ===================================
    echo  Загрузка и установка
    echo ===================================
    
    call :DOWNLOAD_AND_EXTRACT
    if errorlevel 1 (
        pause
        goto MENU_MAIN
    )
    
    call :DOWNLOAD_STRATEGY_FILES
    if errorlevel 1 (
        echo [ПРЕДУПРЕЖДЕНИЕ] Не все файлы стратегий загружены
    )
    echo.

    goto STRATEGY_SELECTION

:CHANGE_STRATEGY
    echo.
    echo ===================================
    echo  Смена стратегии
    echo ===================================
    
    call :VALIDATE_PROJECT_INSTALLED
    call :VALIDATE_SERVICE_EXISTS
    
    goto STRATEGY_SELECTION

:STOP_REMOVE_SERVICES
    echo.
    echo ===================================
    echo  Остановка и удаление службы
    echo ===================================
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    
    echo [УСПЕХ] Службы остановлены и удалены
    echo.
    pause
    goto MENU_MAIN

:START_SERVICE
    echo.
    call :VALIDATE_PROJECT_INSTALLED
    goto STRATEGY_SELECTION

:ENABLE_AUTO_UPDATE
    echo.
    echo ===================================
    echo  Настройка автоматического обновления
    echo ===================================
    
    call :SETUP_AUTO_UPDATE
    if errorlevel 1 (
        echo [ОШИБКА] Ошибка при создании задачи. Проверьте права.
    ) else (
        echo [УСПЕХ] Автообновление настроено (проверка каждые 10 минут)
    )
    pause
    goto MENU_MAIN

:DISABLE_AUTO_UPDATE
    echo.
    echo ===================================
    echo  Удаление задачи автообновления
    echo ===================================
    
    call :REMOVE_AUTOUPDATE_TASK
    pause
    goto MENU_MAIN

:UNINSTALL_PROJECT
    echo.
    echo ===================================
    echo  Деинсталляция
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
    timeout /t 3
    exit /b 0

:: ============ ВСПОМОГАТЕЛЬНЫЕ ПРОЦЕДУРЫ ============

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
    
    echo Загрузка проекта...
    call :DOWNLOAD_FILE "https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip" "%ARCHIVE%"
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось загрузить
        exit /b 1
    )
    echo [УСПЕХ] Загружено
    echo.

    echo ===================================
    echo  Распаковка
    echo ===================================
    
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"
    
    if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
        echo Исправление структуры...
        for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
            ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
        )
    )
    
    if exist "%TARGET_DIR%\zapret-win-bundle-master" (
        echo [УСПЕХ] Распаковано
        exit /b 0
    ) else (
        echo [ОШИБКА] Не удалось распаковать
        exit /b 1
    )

:DOWNLOAD_STRATEGY_FILES
    set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
    set "GITHUB_STRATEGY=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/strategy/"
    set "GITHUB_HOSTLISTS=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/hostlists/"
    
    mkdir "%BASE_DIR%" >nul 2>&1
    mkdir "%BASE_DIR%\files" >nul 2>&1
    
    set "FILES[1]=1_easy.cmd"
    set "FILES[2]=2_medium.cmd"
    set "FILES[3]=3_hard.cmd"
    set "FILES[4]=4_extreme.cmd"
    set "FILES[5]=list-antifilter.txt"
    set "FILES[6]=list-rkn.txt"
    set "FILES[7]=list-exclude.txt"
    
    for /L %%i in (1,1,7) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 4 (
            set "SAVE_PATH=%BASE_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_STRATEGY%!FILE!"
        ) else (
            set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_HOSTLISTS%!FILE!"
        )
        
        call :DOWNLOAD_FILE "!DOWNLOAD_URL!" "!SAVE_PATH!"
        if errorlevel 1 (
            echo [ОШИБКА] Не удалось загрузить !FILE!
        ) else (
            echo [УСПЕХ] Загружен !FILE!
        )
    )
    exit /b 0

:STRATEGY_SELECTION
    echo.
    echo Выберите стратегию:
    echo 1. Легкая (Подходит для большинства провайдеров).
    echo 2. Средняя (Подходит к провайдерам где стоят несколько ТСПУ).
    echo 3. Сложная (Подходит к провайдерам где заблокирован tls1.2).
    echo 4. Экстремальная (Подходит к провайдерам где заблокирован tls1.2).
    echo.
    choice /C 1234 /N /M "Ваш выбор [1-4]: "
    set "STRATEGY=%errorlevel%"
    
    call :GET_DOCUMENTS_FOLDER
    set "STRATEGY_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    mkdir "!STRATEGY_FOLDER!" >nul 2>&1
    del /Q /F "!STRATEGY_FOLDER!\*.txt" >nul 2>&1
    echo. > "!STRATEGY_FOLDER!\!STRATEGY!.txt"
    
    set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
    echo Остановка служб...
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    
    echo Запуск стратегии %STRATEGY%...
    set "STRATEGY_FILE=%BASE_DIR%\%STRATEGY%_*.cmd"
    cd /d "%BASE_DIR%"
    
    powershell -Command "Start-Process -Verb RunAs -FilePath '%STRATEGY_FILE%' -Wait"
    goto FINAL_SETUP

:FINAL_SETUP
    echo.
    echo ====================================
    echo  УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!
    echo ====================================
    
    set "VERSION_PATH=%TARGET_DIR%\keen_bypass_win\sys"
    set "VERSION_FILE=%VERSION_PATH%\version.txt"
    
    echo Сохранение версии проекта...
    mkdir "%VERSION_PATH%" >nul 2>&1
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        echo [УСПЕХ] Отпечаток версии сохранен: %PROJECT_VERSION%
    ) else (
        echo [ОШИБКА] Не удалось записать файл версии
    )
    
    echo.
    echo ====================================
    echo Проверьте необходимые ресурсы
    echo Если все работает, нажмите "3" или закройте скрипт
    echo Если есть проблемы, нажмите "1", чтобы сменить стратегию:
    echo 1. Сменить стратегию
    echo 2. Вернуться в главное меню
    echo 3. Выход
    echo ====================================
    echo.
    
    choice /C 123 /N /M "Выберите действие [1-3]: "
    if %errorlevel% equ 1 goto STRATEGY_SELECTION
    if %errorlevel% equ 2 goto MENU_MAIN
    if %errorlevel% equ 3 exit /b 0

:: Точка входа
if "%~1"=="" goto MENU_MAIN
exit /b 0
