@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: ###########################
:: ## АДМИНИСТРАТИВНЫЕ ПРАВА ##
:: ###########################
echo -----------------------------------
echo Проверка прав администратора...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Запрос прав администратора...
    powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
    exit /b
)
echo [УСПЕХ] Привилегии администратора подтверждены
echo -----------------------------------
echo.

:: ############################
:: ## ПАРАМЕТРЫ И ПЕРЕМЕННЫЕ ##
:: ############################
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_win"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"

:: ###########################
:: ## МЕНЮ ВЫБОРА ДЕЙСТВИЯ ##
:: ###########################
:MAIN_MENU
cls
echo ===================================
echo  Keen Bypass для Windows v1.1
echo ===================================
echo.
echo 1. Установить или обновить проект
echo 2. Остановить и удалить службы
echo 3. Запустить службу
echo 4. Включить автоматическое обновление проекта (В разработке)
echo 5. Деинсталлировать проект
echo.

:CHOICE_MAIN
choice /C 12345 /N /M "Выберите действие [1-5]: "
if %errorlevel% equ 1 goto INSTALL
if %errorlevel% equ 2 goto STOP_AND_REMOVE_SERVICES
if %errorlevel% equ 3 goto START_SERVICE
if %errorlevel% equ 4 goto AUTO_UPDATE
if %errorlevel% equ 5 goto UNINSTALL
goto CHOICE_MAIN

:STOP_AND_REMOVE_SERVICES
echo.
echo ===================================
echo  Остановка и удаление служб
echo ===================================
net stop %SERVICE_NAME% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1

net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1

echo [УСПЕХ] Службы остановлены и удалены
echo.
pause
goto :CHOICE_MAIN

:START_SERVICE
echo.
if not exist "%TARGET_DIR%" (
    echo [ОШИБКА] Проект не установлен!
    echo Установите его через пункт 1
    pause
    goto :CHOICE_MAIN
)

:STRATEGY_MENU
echo ===================================
echo  Выбор стратегии запуска
echo ===================================
echo 1. Легкая
echo 2. Средняя
echo 3. Сложная
echo 4. Экстремальная
echo.

choice /C 1234 /N /M "Выберите стратегию [1-4]: "
set "STRATEGY=%errorlevel%"

echo Остановка служб...
net stop %SERVICE_NAME% >nul 2>&1
net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
timeout /t 2 >nul

echo Запуск стратегии %STRATEGY%...
cd /d "%TARGET_DIR%\keen_bypass_win"
powershell -Command "Start-Process -Verb RunAs -FilePath '%TARGET_DIR%\keen_bypass_win\!STRATEGY!_*.cmd' -Wait"

echo [УСПЕХ] Службы запущены
pause
goto :CHOICE_MAIN

:AUTO_UPDATE
echo.
echo ===================================
echo  Функция в разработке
echo ===================================
echo Автоматическое обновление пока недоступно
pause
goto :CHOICE_MAIN

:INSTALL
:: ########################################
:: ## ШАГ 1: ПРОВЕРКА СУЩЕСТВУЮЩЕЙ УСТАНОВКИ
:: ########################################
echo.
echo ===================================
echo  Проверка существующей установки
echo ===================================
set "SERVICE_EXISTS=0"
set "FOLDER_EXISTS=0"
set "WINDIVERT_EXISTS=0"

sc query %SERVICE_NAME% >nul 2>&1 && (
    echo * Обнаружена служба %SERVICE_NAME%
    set "SERVICE_EXISTS=1"
) || (
    echo * Служба %SERVICE_NAME% не найдена
)

sc query %WINDIVERT_SERVICE% >nul 2>&1 && (
    echo * Обнаружена служба %WINDIVERT_SERVICE%
    set "WINDIVERT_EXISTS=1"
) || (
    echo * Служба %WINDIVERT_SERVICE% не найдена
)

if exist "%TARGET_DIR%" (
    echo * Обнаружена директория %TARGET_DIR%
    set "FOLDER_EXISTS=1"
) else (
    echo * Директория %TARGET_DIR% не найдена
)

echo [УСПЕХ] Проверка завершена
echo.

:: ########################################
:: ## ШАГ 2: УДАЛЕНИЕ СТАРЫХ СЛУЖБ
:: ########################################
echo ===================================
echo  Удаление предыдущих установок
echo ===================================
set "ERROR_FLAG=0"

if %SERVICE_EXISTS% equ 1 (
    echo Остановка службы %SERVICE_NAME%...
    net stop %SERVICE_NAME% >nul 2>&1
    if errorlevel 1 (
        echo [ОШИБКА] Не удалось остановить службу %SERVICE_NAME%
        set "ERROR_FLAG=1"
    ) else (
        echo Удаление службы %SERVICE_NAME%...
        sc delete %SERVICE_NAME% >nul 2>&1
        if errorlevel 1 (
            echo Попытка удалить через реестр...
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1
            if errorlevel 1 (
                echo [ОШИБКА] Не удалось удалить службу %SERVICE_NAME%
                set "ERROR_FLAG=1"
            ) else (
                echo [УСПЕХ] Служба %SERVICE_NAME% удалена
            )
        ) else (
            echo [УСПЕХ] Служба %SERVICE_NAME% удалена
        )
    )
)

if %WINDIVERT_EXISTS% equ 1 (
    echo Остановка службы %WINDIVERT_SERVICE%...
    net stop %WINDIVERT_SERVICE% >nul 2>&1
    sc delete %WINDIVERT_SERVICE% >nul 2>&1
    if errorlevel 1 (
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1
        if errorlevel 1 (
            echo [ОШИБКА] Не удалось удалить службу %WINDIVERT_SERVICE%
            set "ERROR_FLAG=1"
        ) else (
            echo [УСПЕХ] Служба %WINDIVERT_SERVICE% удалена
        )
    ) else (
        echo [УСПЕХ] Служба %WINDIVERT_SERVICE% удалена
    )
)

echo.

:: ########################################
:: ## ШАГ 3: УДАЛЕНИЕ ДИРЕКТОРИИ
:: ########################################
echo ===================================
echo  Очистка файловой системы
echo ===================================
if %FOLDER_EXISTS% equ 1 (
    powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
    timeout /t 2 >nul
    
    rmdir /s /q "%TARGET_DIR%" 2>nul
    if exist "%TARGET_DIR%" (
        echo [ОШИБКА] Не удалось удалить Директория %TARGET_DIR%
        echo Возможно, некоторые файлы заняты другими процессами
        pause
        exit /b 1
    ) else (
        echo [УСПЕХ] Директория %TARGET_DIR% удалена
    )
)
echo.

:: ##########################
:: ## ШАГ 4: ЗАГРУЗКА
:: ##########################
echo ===================================
echo  Загрузка
echo ===================================
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip', '%ARCHIVE%')"

if not exist "%ARCHIVE%" (
    echo [ОШИБКА] Не удалось загрузить
    pause
    exit /b 1
) else (
    echo [УСПЕХ] Загружено
)
echo.

:: ############################
:: ## ШАГ 5: РАСПАКОВКА
:: ############################
echo ===================================
echo  Распаковка
echo ===================================
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
)

powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"

if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo Исправление структуры...
    for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
        ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
    )
)

if exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo [УСПЕХ] Распаковано
) else (
    echo [ОШИБКА] Не удалось распаковать
    pause
    exit /b 1
)
echo.

:: ##############################
:: ## ШАГ 6: НАСТРОЙКА
:: ##############################
echo ===================================
echo  Настройка окружения
echo ===================================
mkdir "%TARGET_DIR%\keen_bypass_win" >nul 2>&1
mkdir "%TARGET_DIR%\keen_bypass_win\files" >nul 2>&1

set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
set "GITHUB_RAW=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/"

:: Список файлов для загрузки
set "FILES[1]=1_easy.cmd"
set "FILES[2]=2_medium.cmd"
set "FILES[3]=3_hard.cmd"
set "FILES[4]=4_extreme.cmd"
set "FILES[5]=list-antifilter.txt"
set "FILES[6]=list-googlevideo.txt"
set "FILES[7]=list-rkn.txt"
set "FILES[8]=list-exclude.txt"

for /L %%i in (1,1,8) do (
    set "FILE=!FILES[%%i]!"
    set "SAVE_PATH="
    
    if %%i leq 4 (
        set "SAVE_PATH=%BASE_DIR%\!FILE!"
    ) else (
        set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
    )

    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%GITHUB_RAW%!FILE!', '!SAVE_PATH!')"

    if exist "!SAVE_PATH!" (
        echo [УСПЕХ] Загружен !FILE!
    ) else (
        echo [ОШИБКА] Не удалось загрузить !FILE!
        set "ERROR_FLAG=1"
    )
)
echo.

:: ##############################
:: ## ШАГ 7: ВЫБОР СТРАТЕГИИ
:: ##############################
:STRATEGY_MENU
echo.
echo Выберите стратегию:
echo 1. Легкая (Подходит для большинства провайдеров, аналогична 3/3 в keen bypass)
echo 2. Средняя (Подходит к провайдерам где стоят несколько ТСПУ, аналогична 4/4 в keen bypass)
echo 3. Сложная (Подходит к провайдерам где заблокирован tls1.2, аналогична 7/7 в keen bypass)
echo 4. Экстремальная (Подходит к провайдерам где заблокирован tls1.2, аналогична 8/8 в keen bypass)
echo.

choice /C 1234 /N /M "Ваш выбор [1-4]: "
set "STRATEGY=%errorlevel%"

:: Остановка служб перед применением
echo Остановка служб...
net stop %SERVICE_NAME% >nul 2>&1
net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
timeout /t 2 >nul

:: Запуск выбранной стратегии
echo Запуск стратегии %STRATEGY%...
cd /d "%BASE_DIR%"
powershell -Command "Start-Process -Verb RunAs -FilePath '%BASE_DIR%\!STRATEGY!_*.cmd' -Wait"

:: ##############################
:: ## ШАГ 8: ФИНАЛ И ПЕРЕВЫБОР
:: ##############################
:FINAL_MENU
echo.
echo ====================================
echo  УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!
echo ====================================
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

:CHOICE_FINAL
choice /C 123 /N /M "Выберите действие [1-3]: "
if %errorlevel% equ 1 (
    cls
    goto STRATEGY_MENU
)
if %errorlevel% equ 2 (
    cls  ; Добавлена очистка экрана
    goto MAIN_MENU  ; Исправлено: переход к метке MAIN_MENU без двоеточия
)
if %errorlevel% equ 3 (
    echo.
    echo ====================================
    echo Завершение работы через 3 секунды...
    echo ====================================
    timeout /t 3
    exit /b 0
)

goto CHOICE_FINAL

:UNINSTALL
:: ##########################
:: ## ПРОЦЕДУРА УДАЛЕНИЯ ##
:: ##########################
echo.
echo ===================================
echo  Деинсталляция
echo ===================================
echo Остановка служб...
net stop %SERVICE_NAME% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1

net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1

echo Удаление файлов...
powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
timeout /t 2 >nul
rmdir /s /q "%TARGET_DIR%" 2>nul

if exist "%TARGET_DIR%" (
    echo [ОШИБКА] Не удалось удалить папку %TARGET_DIR%
    pause
    exit /b 1
) else (
    echo [УСПЕХ] Все компоненты удалены
)

echo.
echo ===================================
echo  УДАЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО!
echo ===================================
echo.
echo ====================================
echo Завершение работы через 3 секунды...
echo ====================================
timeout /t 3
exit /b 0
