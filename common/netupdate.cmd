@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
    exit /b
)

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
set "BASE_DIR=%TARGET_DIR%\keen_bypass_win"

:: Определение стратегии
for /f "usebackq" %%i in (`powershell -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCUMENTS_PATH=%%i"
set "STRATEGY_FOLDER=!DOCUMENTS_PATH!\keen_bypass_win"
set "STRATEGY=1"
if exist "!STRATEGY_FOLDER!\*.txt" (
    for /f %%F in ('dir /b "!STRATEGY_FOLDER!\*.txt"') do (
        set "FILENAME=%%~nF"
        set "STRATEGY=!FILENAME:~0,1!"
    )
)

:: Удаление предыдущих установок
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

:: Загрузка проекта
echo [2/5] Загрузка проекта...
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/nikrays/zapret-win-bundle/archive/refs/heads/master.zip', '!ARCHIVE!')"
if not exist "!ARCHIVE!" (
    echo [ОШИБКА] Не удалось загрузить архив
    exit /b 1
)

:: Распаковка
echo [3/5] Распаковка...
mkdir "!TARGET_DIR!" >nul 2>&1
powershell -Command "Expand-Archive -Path '!ARCHIVE!' -DestinationPath '!TARGET_DIR!' -Force"
mkdir "!BASE_DIR!" >nul 2>&1
mkdir "!BASE_DIR!\files" >nul 2>&1

:: Настройка стратегии
echo [4/5] Настройка стратегии !STRATEGY!...
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

:: Применение стратегии
echo [5/5] Применение стратегии !STRATEGY!...
cd /d "!BASE_DIR!"
net stop !SERVICE_NAME! >nul 2>&1
net stop !WINDIVERT_SERVICE! >nul 2>&1
sc delete !SERVICE_NAME! >nul 2>&1
sc delete !WINDIVERT_SERVICE! >nul 2>&1
timeout /t 2 >nul
powershell -Command "Start-Process -Verb RunAs -FilePath '!BASE_DIR!\!STRATEGY!_*.cmd' -Wait"

:: Сохранение версии
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

echo [УСПЕХ] Стратегия !STRATEGY! активирована.
exit /b 0
