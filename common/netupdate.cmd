@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Основные константы
set "PROJECT_NAME=Keen Bypass для Windows"
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_win"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"
set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
set "MAX_RETRIES=3"
set "FILE_RETRIES=3"

:: Главная точка входа
echo %PROJECT_NAME% - Автоматическое обновление
echo ===================================
echo.

:: Проверка прав администратора
call :CHECK_ADMIN_RIGHTS
if errorlevel 1 (
    exit /b 1
)

:: Получение версии проекта
call :GET_PROJECT_VERSION
if errorlevel 1 (
    echo [ОШИБКА] Не удалось получить версию.
    set "PROJECT_VERSION=unknown"
)

:: Определение текущей стратегии
call :GET_CURRENT_STRATEGY

:: Основной процесс обновления
echo [1/5] Удаление предыдущих установок...
call :CLEANUP_PREVIOUS_INSTALLATION

echo [2/5] Загрузка проекта...
call :DOWNLOAD_PROJECT
if errorlevel 1 (
    echo [ОШИБКА] Загрузка не удалась
    pause
    exit /b 1
)

echo [3/5] Распаковка...
call :EXTRACT_ARCHIVE
if errorlevel 1 (
    echo [ОШИБКА] Распаковка не удалась
    pause
    exit /b 1
)

echo [4/5] Настройка стратегии %STRATEGY%...
call :DOWNLOAD_STRATEGY_FILES
if errorlevel 1 (
    echo [ОШИБКА] Загрузка файлов стратегии не удалась
    pause
    exit /b 1
)

echo [5/5] Применение стратегии %STRATEGY%...
call :APPLY_STRATEGY

:: Финализация обновления
call :SAVE_VERSION_INFO
call :CLEANUP_TEMP_FILES

echo.
echo [УСПЕХ] Стратегия %STRATEGY% активирована.
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

:GET_CURRENT_STRATEGY
    for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do (
        set "DOCUMENTS_PATH=%%i"
    )
    set "STRATEGY_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
    set "STRATEGY=1"
    
    if exist "!STRATEGY_FOLDER!\*.txt" (
        for /f %%F in ('dir /b "!STRATEGY_FOLDER!\*.txt"') do (
            set "FILENAME=%%~nF"
            set "STRATEGY=!FILENAME:~0,1!"
        )
    )
    echo Текущая стратегия: !STRATEGY!
    exit /b 0

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
        ) else (
            echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось полностью удалить директорию
        )
    ) else (
        echo Директория не найдена, пропускаем удаление
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

:DOWNLOAD_STRATEGY_FILES
    set "GITHUB_STRATEGY=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/strategy/"
    set "GITHUB_HOSTLISTS=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/hostlists/"
    
    set "FILES[1]=1_easy.cmd"
    set "FILES[2]=2_medium.cmd"
    set "FILES[3]=3_hard.cmd"
    set "FILES[4]=4_extreme.cmd"
    set "FILES[5]=list-antifilter.txt"
    set "FILES[6]=list-rkn.txt"
    set "FILES[7]=list-exclude.txt"
    
    mkdir "%BASE_DIR%" >nul 2>&1
    mkdir "%BASE_DIR%\files" >nul 2>&1
    
    set "ERROR_FLAG=0"
    
    for /L %%i in (1,1,7) do (
        set "FILE=!FILES[%%i]!"
        if %%i leq 4 (
            set "SAVE_PATH=%BASE_DIR%\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_STRATEGY%!FILE!"
        ) else (
            set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
            set "DOWNLOAD_URL=%GITHUB_HOSTLISTS%!FILE!"
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

:APPLY_STRATEGY
    echo Применение стратегии %STRATEGY%...
    cd /d "%BASE_DIR%"
    
    call :STOP_SERVICE %SERVICE_NAME%
    call :STOP_SERVICE %WINDIVERT_SERVICE%
    timeout /t 2 >nul
    
    echo Запуск скрипта стратегии...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%BASE_DIR%\%STRATEGY%_*.cmd' -Wait"
    exit /b 0

:SAVE_VERSION_INFO
    set "VERSION_PATH=%TARGET_DIR%\keen_bypass_win\sys"
    set "VERSION_FILE=%VERSION_PATH%\version.txt"
    
    echo Сохранение версии проекта...
    mkdir "%VERSION_PATH%" >nul 2>&1
    
    powershell -Command "[System.IO.File]::WriteAllText('%VERSION_FILE%', '%PROJECT_VERSION%'.Trim())" >nul 2>&1
    
    if exist "%VERSION_FILE%" (
        echo [УСПЕХ] Версия сохранена: %PROJECT_VERSION%
    ) else (
        echo [ОШИБКА] Не удалось записать файл версии
    )
    exit /b 0

:CLEANUP_TEMP_FILES
    if exist "%ARCHIVE%" (
        echo Очистка временных файлов...
        del /q "%ARCHIVE%" >nul 2>&1
    )
    exit /b 0
