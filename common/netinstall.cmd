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
echo  Keen Bypass для Windows v1.3
echo ===================================
echo.
echo 1. Установить или обновить проект
echo 2. Сменить стратегию
echo 3. Остановить и удалить службы
echo 4. Запустить службу
echo 5. Включить автоматическое обновление проекта (В разработке)
echo 6. Деинсталлировать проект
echo.

:CHOICE_MAIN
choice /C 123456 /N /M "Выберите действие [1-6]: "
if %errorlevel% equ 1 goto INSTALL
if %errorlevel% equ 2 goto CHANGE_STRATEGY
if %errorlevel% equ 3 goto STOP_AND_REMOVE_SERVICES
if %errorlevel% equ 4 goto START_SERVICE
if %errorlevel% equ 5 goto AUTO_UPDATE
if %errorlevel% equ 6 goto UNINSTALL
goto CHOICE_MAIN

:: ##############################
:: ## СМЕНА СТРАТЕГИИ ##
:: ##############################
:CHANGE_STRATEGY
echo.
echo ===================================
echo  Смена стратегии
echo ===================================
if not exist "%TARGET_DIR%" (
    echo [ОШИБКА] Проект не установлен!
    echo Установите его через пункт 1
    pause
    goto :CHOICE_MAIN
)

sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Служба %SERVICE_NAME% не найдена!
    echo Установите проект через пункт 1
    pause
    goto :CHOICE_MAIN
)

goto STRATEGY_MENU

:: #################################
:: ## ОСТАНОВКА И УДАЛЕНИЕ СЛУЖБ ##
:: #################################
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

:: ##############################
:: ## ЗАПУСК СЛУЖБЫ ##
:: ##############################
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
echo 1. Легкая (Подходит для большинства провайдеров).
echo 2. Средняя (Подходит к провайдерам где стоят несколько ТСПУ).
echo 3. Сложная (Подходит к провайдерам где заблокирован tls1.2).
echo 4. Экстремальная (Подходит к провайдерам где заблокирован tls1.2).
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

:: ################################
:: ## АВТОМАТИЧЕСКОЕ ОБНОВЛЕНИЕ ##
:: ################################
:AUTO_UPDATE
echo.
echo ===================================
echo  Настройка автоматического обновления
echo ===================================
echo Проверка существующей задачи...
schtasks /Query /TN "keen_bypass_win_autoupdate" >nul 2>&1
if %errorlevel% equ 0 (
    echo Удаление существующей задачи...
    schtasks /Delete /TN "keen_bypass_win_autoupdate" /F >nul 2>&1
)

echo Проверка директории...
if not exist "%TARGET_DIR%\keen_bypass_win" (
    mkdir "%TARGET_DIR%\keen_bypass_win"
)

echo Загрузка скрипта...
set "AUTOUPDATE_SCRIPT=%TARGET_DIR%\keen_bypass_win\autoupdate.cmd"
set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; try { $response = Invoke-WebRequest -Uri '%GITHUB_URL%' -OutFile '%AUTOUPDATE_SCRIPT%' -ErrorAction Stop; Write-Host '[УСПЕХ] Скрипт загружен' } catch { Write-Host '[ОШИБКА] Причина: ' + $_.Exception.Message; exit 1 }"

if not exist "%AUTOUPDATE_SCRIPT%" (
    echo [ОШИБКА] Скрипт автообновления не найден после загрузки!
    pause
    goto :CHOICE_MAIN
)

echo Создание задачи...
schtasks /Create /TN "keen_bypass_win_autoupdate" /SC MINUTE /MO 5 /TR "powershell -Command \"Start-Process -Verb RunAs -FilePath '%AUTOUPDATE_SCRIPT%'\"" /RU SYSTEM /RL HIGHEST /F >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Ошибка при создании задачи. Проверьте права.
    pause
    goto :CHOICE_MAIN
)

echo [УСПЕХ] Автообновление настроено (проверка каждые 5 минут)
pause
goto :CHOICE_MAIN

:: ##############################
:: ## УСТАНОВКА/ОБНОВЛЕНИЕ ##
:: ##############################
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
set "GITHUB_STRATEGY=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/strategy/"
set "GITHUB_HOSTLISTS=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/hostlists/"

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
    set "DOWNLOAD_URL="
    
    if %%i leq 4 (
        set "SAVE_PATH=%BASE_DIR%\!FILE!"
        set "DOWNLOAD_URL=%GITHUB_STRATEGY%!FILE!"
    ) else (
        set "SAVE_PATH=%BASE_DIR%\files\!FILE!"
        set "DOWNLOAD_URL=%GITHUB_HOSTLISTS%!FILE!"
    )

    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('!DOWNLOAD_URL!', '!SAVE_PATH!')"

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
echo 1. Легкая (Подходит для большинства провайдеров).
echo 2. Средняя (Подходит к провайдерам где стоят несколько ТСПУ).
echo 3. Сложная (Подходит к провайдерам где заблокирован tls1.2).
echo 4. Экстремальная (Подходит к провайдерам где заблокирован tls1.2).
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
    cls
    goto MAIN_MENU
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

:: ##########################
:: ## ДЕИНСТАЛЛЯЦИЯ ##
:: ##########################
:UNINSTALL
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

echo Удаление автообновления...
schtasks /Delete /TN "keen_bypass_win_autoupdate" /F >nul 2>&1

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
