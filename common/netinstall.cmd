@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Проверка прав администратора
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

:: Получение версии с GitHub
set "VERSION_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/VERSION"
set "VERSION_FILE=%TEMP%\keen_version.txt"

echo Получение актуальной версии...
powershell -Command "$ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri '%VERSION_URL%' -OutFile '%VERSION_FILE%')" >nul 2>&1

if exist "%VERSION_FILE%" (
    for /f "delims=" %%i in ('type "%VERSION_FILE%" ^| powershell -Command "$input.Trim()"') do set "PROJECT_VERSION=%%i"
    del /q "%VERSION_FILE%" >nul 2>&1
) else (
    set "PROJECT_VERSION=v1.3"
    echo [ОШИБКА] Не удалось получить версию. Используется значение по умолчанию.
)

:: Основные переменные
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_win"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"

:: Главное меню
:MAIN_MENU
cls
echo ===================================
echo  Keen Bypass для Windows v%PROJECT_VERSION%
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
goto MENU_%errorlevel%

:MENU_1
goto INSTALL

:MENU_2
goto CHANGE_STRATEGY

:MENU_3
goto STOP_AND_REMOVE_SERVICES

:MENU_4
goto START_SERVICE

:MENU_5
goto AUTO_UPDATE

:MENU_6
goto REMOVE_AUTO_UPDATE

:MENU_7
goto UNINSTALL

:: Смена стратегии
:CHANGE_STRATEGY
echo.
echo ===================================
echo  Смена стратегии
echo ===================================
if not exist "%TARGET_DIR%" (
    echo [ОШИБКА] Проект не установлен!
    echo Установите его через пункт 1
    pause
    goto MAIN_MENU
)
sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Служба %SERVICE_NAME% не найдена!
    echo Установите проект через пункт 1
    pause
    goto MAIN_MENU
)
goto STRATEGY_MENU

:: Остановка и удаление служб
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
goto MAIN_MENU

:: Запуск службы
:START_SERVICE
echo.
if not exist "%TARGET_DIR%" (
    echo [ОШИБКА] Проект не установлен!
    echo Установите его через пункт 1
    pause
    goto MAIN_MENU
)
goto STRATEGY_MENU

:: Удаление автообновления
:REMOVE_AUTO_UPDATE
echo.
echo ===================================
echo  Удаление задачи автообновления
echo ===================================
schtasks /Query /TN "keen_bypass_win_autoupdate" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /Delete /TN "keen_bypass_win_autoupdate" /F >nul 2>&1
    echo [УСПЕХ] Задача автообновления удалена
) else (
    echo [ИНФО] Задача автообновления не найдена
)
pause
goto MAIN_MENU

:: Активация автообновления
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
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCUMENTS_PATH=%%i"
set "AUTOUPDATE_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
mkdir "!AUTOUPDATE_FOLDER!" >nul 2>&1
set "AUTOUPDATE_SCRIPT=!AUTOUPDATE_FOLDER!\autoupdate.cmd"
set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
echo Загрузка скрипта автообновления...
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%GITHUB_URL%', '!AUTOUPDATE_SCRIPT!')"
if not exist "!AUTOUPDATE_SCRIPT!" (
    echo [ОШИБКА] Скрипт автообновления не найден!
    pause
    goto MAIN_MENU
)
echo Создание задачи...
schtasks /Create /TN "keen_bypass_win_autoupdate" /SC MINUTE /MO 5 /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '!AUTOUPDATE_SCRIPT!' -ArgumentList '-silent'\"" /RU SYSTEM /RL HIGHEST /F >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Ошибка при создании задачи. Проверьте права.
    pause
    goto MAIN_MENU
)
echo [УСПЕХ] Автообновление настроено (проверка каждые 5 минут)
pause
goto MAIN_MENU

:: Установка или обновление
:INSTALL
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
if %SERVICE_EXISTS% equ 1 (
    echo Остановка службы %SERVICE_NAME%...
    net stop %SERVICE_NAME% >nul 2>&1
    sc delete %SERVICE_NAME% >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1
)
if %WINDIVERT_EXISTS% equ 1 (
    echo Остановка службы %WINDIVERT_SERVICE%...
    net stop %WINDIVERT_SERVICE% >nul 2>&1
    sc delete %WINDIVERT_SERVICE% >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1
)
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
        exit /b 1
    ) else (
        echo [УСПЕХ] Директория %TARGET_DIR% удалена
    )
)
echo.

echo ===================================
echo  Активация автообновления
echo ===================================
call :AUTO_UPDATE_SILENT
if %ERRORLEVEL% neq 0 (
    echo [ОШИБКА] Не удалось настроить автообновление
    pause
    exit /b 1
)
echo.

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

echo ===================================
echo  Распаковка
echo ===================================
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"
if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo Исправление структуры...
    for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
)
if exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo [УСПЕХ] Распаковано
) else (
    echo [ОШИБКА] Не удалось распаковать
    pause
    exit /b 1
)
echo.

echo ===================================
echo  Настройка окружения
echo ===================================
mkdir "%TARGET_DIR%\keen_bypass_win" >nul 2>&1
mkdir "%TARGET_DIR%\keen_bypass_win\files" >nul 2>&1
set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"
set "GITHUB_STRATEGY=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/strategy/"
set "GITHUB_HOSTLISTS=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/hostlists/"
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
    )
)
echo.
goto STRATEGY_MENU

:: Выбор стратегии
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
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCUMENTS_PATH=%%i"
set "STRATEGY_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
mkdir "!STRATEGY_FOLDER!" >nul 2>&1
del /Q /F "!STRATEGY_FOLDER!\*.txt" >nul 2>&1
echo. > "!STRATEGY_FOLDER!\!STRATEGY!.txt"
echo Остановка служб...
net stop %SERVICE_NAME% >nul 2>&1
net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
timeout /t 2 >nul
echo Запуск стратегии %STRATEGY%...
cd /d "%BASE_DIR%"
powershell -Command "Start-Process -Verb RunAs -FilePath '%BASE_DIR%\!STRATEGY!_*.cmd' -Wait"
goto FINAL_MENU

:: Финальное меню
:FINAL_MENU
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
if %errorlevel% equ 1 goto STRATEGY_MENU
if %errorlevel% equ 2 goto MAIN_MENU
if %errorlevel% equ 3 exit /b 0

:: Скрытая настройка автообновления
:AUTO_UPDATE_SILENT
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCUMENTS_PATH=%%i"
set "AUTOUPDATE_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
set "AUTOUPDATE_SCRIPT=!AUTOUPDATE_FOLDER!\autoupdate.cmd"
set "GITHUB_URL=https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/autoupdate.cmd"
mkdir "!AUTOUPDATE_FOLDER!" >nul 2>&1
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%GITHUB_URL%', '!AUTOUPDATE_SCRIPT!')" >nul 2>&1
if not exist "!AUTOUPDATE_SCRIPT!" exit /b 1
schtasks /Create /TN "keen_bypass_win_autoupdate" /SC MINUTE /MO 5 /TR "powershell -WindowStyle Hidden -Command \"Start-Process -Verb RunAs -FilePath '!AUTOUPDATE_SCRIPT!' -ArgumentList '-silent'\"" /RU SYSTEM /RL HIGHEST /F >nul 2>&1
if %errorlevel% neq 0 exit /b 1
exit /b 0

:: Деинсталляция
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
