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
set "TARGET_DIR=C:\keen_bypass_for_windows"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"

:: ###########################
:: ## МЕНЮ ВЫБОРА ДЕЙСТВИЯ ##
:: ###########################
echo ===================================
echo  Keen DPI для Windows v0.2
echo ===================================
echo.
echo 1. Установить или обновить проект
echo 2. Деинсталлировать проект
echo.

:CHOICE_MAIN
choice /C 12 /N /M "Выберите действие [1 или 2]: "
if %errorlevel% equ 2 goto UNINSTALL
if %errorlevel% equ 1 goto INSTALL
goto CHOICE_MAIN

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
    echo * Обнаружена папка %TARGET_DIR%
    set "FOLDER_EXISTS=1"
) else (
    echo * Папка %TARGET_DIR% не найдена
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
    echo Остановка процессов...
    powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
    timeout /t 2 >nul
    
    echo Удаление папки %TARGET_DIR%...
    rmdir /s /q "%TARGET_DIR%" 2>nul
    if exist "%TARGET_DIR%" (
        echo [ОШИБКА] Не удалось удалить папку %TARGET_DIR%
        echo Возможно, некоторые файлы заняты другими процессами
        pause
        exit /b 1
    ) else (
        echo [УСПЕХ] Папка %TARGET_DIR% удалена
    )
)
echo.

:: ##########################
:: ## ШАГ 4: ЗАГРУЗКА
:: ##########################
echo ===================================
echo  Загрузка архива
echo ===================================
echo Скачивание master.zip...
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip', '%ARCHIVE%')"

if not exist "%ARCHIVE%" (
    echo [ОШИБКА] Не удалось загрузить архив
    pause
    exit /b 1
) else (
    echo [УСПЕХ] Архив успешно загружен
)
echo.

:: ############################
:: ## ШАГ 5: РАСПАКОВКА
:: ############################
echo ===================================
echo  Распаковка архива
echo ===================================
if not exist "%TARGET_DIR%" (
    echo Создание целевой директории...
    mkdir "%TARGET_DIR%"
)

echo Распаковка master.zip...
powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"

if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo Исправление структуры папок...
    for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
        ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
    )
)

if exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo [УСПЕХ] Архив распакован
) else (
    echo [ОШИБКА] Не удалось распаковать архив
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
echo Создание структуры папок...
mkdir "%TARGET_DIR%\keen-dpi-for-windows" >nul 2>&1
mkdir "%TARGET_DIR%\keen-dpi-for-windows\files" >nul 2>&1

set "BASE_DIR=%TARGET_DIR%\keen-dpi-for-windows"
set "FILES[1]=https://disk.yandex.ru/d/leyAyl9ivQn1Hw 1_easy.cmd"
set "FILES[2]=https://disk.yandex.ru/d/uOtp5TOoiKfeYQ 2_medium.cmd"
set "FILES[3]=https://disk.yandex.ru/d/PDvcosHtgJvvYA 3_hard.cmd"
set "FILES[4]=https://disk.yandex.ru/d/JoGt-zD16JggMg 4_extreme.cmd"
set "FILES[5]=https://disk.yandex.ru/d/Uab16z68JqaeEA list-antifilter.txt"
set "FILES[6]=https://disk.yandex.ru/d/Q430zUQrVxsq1Q list-googlevideo.txt"
set "FILES[7]=https://disk.yandex.ru/d/h10ubXuxbb7XlQ list-rkn.txt"
set "FILES[8]=https://disk.yandex.ru/d/YQcgJF_fLPQWqQ list-exclude.txt"

for /L %%i in (1,1,8) do (
    for /f "tokens=1,2" %%A in ("!FILES[%%i]!") do (
        set "SAVE_PATH="
        if %%i leq 4 (
            set "SAVE_PATH=%BASE_DIR%\%%B"
        ) else (
            set "SAVE_PATH=%BASE_DIR%\files\%%B"
        )

        powershell -Command "$url='https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=%%A'; $dl=(Invoke-RestMethod -Uri $url).href; (New-Object System.Net.WebClient).DownloadFile($dl, '!SAVE_PATH!')"

        if exist "!SAVE_PATH!" (
            echo [УСПЕХ] Файл %%B загружен
        ) else (
            echo [ОШИБКА] Не удалось загрузить %%B
            set "ERROR_FLAG=1"
        )
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
echo Если все работает - закройте скрипт
echo Если есть проблемы, нажмите 1:
echo 1. Сменить стратегию
echo 2. Выход
echo ====================================
echo.

:CHOICE_FINAL
choice /C 12 /N /M "Выберите действие [1 или 2]: "
if %errorlevel% equ 2 (
    echo.
    echo ====================================
    echo Завершение работы через 5 секунд...
    echo ====================================
    timeout /t 5 >nul
    exit /b 0
)

if %errorlevel% equ 1 (
    cls
    goto STRATEGY_MENU
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
timeout /t 5
exit /b 0