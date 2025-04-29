@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: ###########################
:: ## АДМИНИСТРАТИВНЫЕ ПРАВА ##
:: ###########################
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
    exit /b
)

:: ############################
:: ## ПАРАМЕТРЫ И ПЕРЕМЕННЫЕ ##
:: ############################
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_win"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"

:: ##############################
:: ## ОПРЕДЕЛЕНИЕ СТРАТЕГИИ ##
:: ##############################
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCUMENTS_PATH=%%i"
set "STRATEGY_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
set "STRATEGY=1"  # Значение по умолчанию

if exist "!STRATEGY_FOLDER!\*.txt" (
    for /f %%F in ('dir /b "!STRATEGY_FOLDER!\*.txt"') do (
        set "FILENAME=%%~nF"
        set "STRATEGY=!FILENAME:~0,1!"
    )
)

:: ##############################
:: ## УСТАНОВКА И НАСТРОЙКА ##
:: ##############################
echo [1/5] Удаление предыдущих установок...
net stop !SERVICE_NAME! >nul 2>&1
sc delete !SERVICE_NAME! >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\!SERVICE_NAME!" /f >nul 2>&1

net stop !WINDIVERT_SERVICE! >nul 2>&1
sc delete !WINDIVERT_SERVICE! >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\!WINDIVERT_SERVICE!" /f >nul 2>&1

if exist "!TARGET_DIR!" (
    powershell -Command "Get-Process | Where-Object { $_.Path -like '!TARGET_DIR!\*' } | Stop-Process -Force"
    timeout /t 2 >nul
    rmdir /s /q "!TARGET_DIR!" 2>nul
)

:: ##########################
:: ## ЗАГРУЗКА И РАСПАКОВКА ##
:: ##########################
echo [2/5] Загрузка проекта...
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip', '!ARCHIVE!')"

if not exist "!ARCHIVE!" (
    echo [ОШИБКА] Не удалось загрузить архив
    exit /b 1
)

echo [3/5] Распаковка...
mkdir "!TARGET_DIR!" >nul 2>&1
powershell -Command "Expand-Archive -Path '!ARCHIVE!' -DestinationPath '!TARGET_DIR!' -Force"

:: Создание папки keen_bypass_win внутри TARGET_DIR
set "BASE_DIR=!TARGET_DIR!\keen_bypass_win"
mkdir "!BASE_DIR!" >nul 2>&1
mkdir "!BASE_DIR!\files" >nul 2>&1

:: ##############################
:: ## ЗАГРУЗКА КОНФИГУРАЦИЙ ##
:: ##############################
echo [4/5] Настройка стратегии !STRATEGY!...
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

:: Загрузка всех файлов
for /L %%i in (1,1,8) do (
    set "FILE=!FILES[%%i]!"
    set "SAVE_PATH="
    set "DOWNLOAD_URL="

    if %%i leq 4 (
        set "SAVE_PATH=!BASE_DIR!\!FILE!"
        set "DOWNLOAD_URL=!GITHUB_STRATEGY!!FILE!"
    ) else (
        set "SAVE_PATH=!BASE_DIR!\files\!FILE!"
        set "DOWNLOAD_URL=!GITHUB_HOSTLISTS!!FILE!"
    )

    echo Загрузка: !FILE!
    powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('!DOWNLOAD_URL!', '!SAVE_PATH!')"

    if exist "!SAVE_PATH!" (
        echo [OK] !FILE!
    ) else (
        echo [FAIL] Не удалось загрузить !FILE!
        set "ERROR_FLAG=1"
    )
)

if defined ERROR_FLAG (
    echo [КРИТИЧЕСКАЯ ОШИБКА] Отсутствуют необходимые файлы
    exit /b 1
)

:: ##############################
:: ## АВТОМАТИЧЕСКОЕ ПРИМЕНЕНИЕ СТРАТЕГИИ ##
:: ##############################
echo [5/5] Применение стратегии !STRATEGY!...
cd /d "!BASE_DIR!"

:: Остановка и удаление старых служб
net stop !SERVICE_NAME! >nul 2>&1
net stop !WINDIVERT_SERVICE! >nul 2>&1
sc delete !SERVICE_NAME! >nul 2>&1
sc delete !WINDIVERT_SERVICE! >nul 2>&1
timeout /t 2 >nul

:: Запуск стратегии
powershell -Command "Start-Process -Verb RunAs -FilePath '!BASE_DIR!\!STRATEGY!_*.cmd' -Wait"

echo [УСПЕХ] Стратегия !STRATEGY! активирована.
exit /b 0
