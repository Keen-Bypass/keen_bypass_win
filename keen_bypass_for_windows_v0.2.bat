@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: ###########################
:: ## ���������������� ����� ##
:: ###########################
echo -----------------------------------
echo �������� ���� ��������������...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ������ ���� ��������������...
    powershell -Command "Start-Process -Verb RunAs -FilePath \"%~f0\""
    exit /b
)
echo [�����] ���������� �������������� ������������
echo -----------------------------------
echo.

:: ############################
:: ## ��������� � ���������� ##
:: ############################
set "ARCHIVE=%TEMP%\master.zip"
set "TARGET_DIR=C:\keen_bypass_for_windows"
set "SERVICE_NAME=winws1"
set "WINDIVERT_SERVICE=WinDivert"

:: ###########################
:: ## ���� ������ �������� ##
:: ###########################
echo ===================================
echo  Keen DPI ��� Windows v0.2
echo ===================================
echo.
echo 1. ���������� ��� �������� ������
echo 2. ���������������� ������
echo.

:CHOICE_MAIN
choice /C 12 /N /M "�������� �������� [1 ��� 2]: "
if %errorlevel% equ 2 goto UNINSTALL
if %errorlevel% equ 1 goto INSTALL
goto CHOICE_MAIN

:INSTALL
:: ########################################
:: ## ��� 1: �������� ������������ ���������
:: ########################################
echo.
echo ===================================
echo  �������� ������������ ���������
echo ===================================
set "SERVICE_EXISTS=0"
set "FOLDER_EXISTS=0"
set "WINDIVERT_EXISTS=0"

sc query %SERVICE_NAME% >nul 2>&1 && (
    echo * ���������� ������ %SERVICE_NAME%
    set "SERVICE_EXISTS=1"
) || (
    echo * ������ %SERVICE_NAME% �� �������
)

sc query %WINDIVERT_SERVICE% >nul 2>&1 && (
    echo * ���������� ������ %WINDIVERT_SERVICE%
    set "WINDIVERT_EXISTS=1"
) || (
    echo * ������ %WINDIVERT_SERVICE% �� �������
)

if exist "%TARGET_DIR%" (
    echo * ���������� ����� %TARGET_DIR%
    set "FOLDER_EXISTS=1"
) else (
    echo * ����� %TARGET_DIR% �� �������
)

echo [�����] �������� ���������
echo.

:: ########################################
:: ## ��� 2: �������� ������ �����
:: ########################################
echo ===================================
echo  �������� ���������� ���������
echo ===================================
set "ERROR_FLAG=0"

if %SERVICE_EXISTS% equ 1 (
    echo ��������� ������ %SERVICE_NAME%...
    net stop %SERVICE_NAME% >nul 2>&1
    if errorlevel 1 (
        echo [������] �� ������� ���������� ������ %SERVICE_NAME%
        set "ERROR_FLAG=1"
    ) else (
        echo �������� ������ %SERVICE_NAME%...
        sc delete %SERVICE_NAME% >nul 2>&1
        if errorlevel 1 (
            echo ������� ������� ����� ������...
            reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1
            if errorlevel 1 (
                echo [������] �� ������� ������� ������ %SERVICE_NAME%
                set "ERROR_FLAG=1"
            ) else (
                echo [�����] ������ %SERVICE_NAME% �������
            )
        ) else (
            echo [�����] ������ %SERVICE_NAME% �������
        )
    )
)

if %WINDIVERT_EXISTS% equ 1 (
    echo ��������� ������ %WINDIVERT_SERVICE%...
    net stop %WINDIVERT_SERVICE% >nul 2>&1
    sc delete %WINDIVERT_SERVICE% >nul 2>&1
    if errorlevel 1 (
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1
        if errorlevel 1 (
            echo [������] �� ������� ������� ������ %WINDIVERT_SERVICE%
            set "ERROR_FLAG=1"
        ) else (
            echo [�����] ������ %WINDIVERT_SERVICE% �������
        )
    ) else (
        echo [�����] ������ %WINDIVERT_SERVICE% �������
    )
)

echo.

:: ########################################
:: ## ��� 3: �������� ����������
:: ########################################
echo ===================================
echo  ������� �������� �������
echo ===================================
if %FOLDER_EXISTS% equ 1 (
    echo ��������� ���������...
    powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
    timeout /t 2 >nul
    
    echo �������� ����� %TARGET_DIR%...
    rmdir /s /q "%TARGET_DIR%" 2>nul
    if exist "%TARGET_DIR%" (
        echo [������] �� ������� ������� ����� %TARGET_DIR%
        echo ��������, ��������� ����� ������ ������� ����������
        pause
        exit /b 1
    ) else (
        echo [�����] ����� %TARGET_DIR% �������
    )
)
echo.

:: ##########################
:: ## ��� 4: ��������
:: ##########################
echo ===================================
echo  �������� ������
echo ===================================
echo ���������� master.zip...
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip', '%ARCHIVE%')"

if not exist "%ARCHIVE%" (
    echo [������] �� ������� ��������� �����
    pause
    exit /b 1
) else (
    echo [�����] ����� ������� ��������
)
echo.

:: ############################
:: ## ��� 5: ����������
:: ############################
echo ===================================
echo  ���������� ������
echo ===================================
if not exist "%TARGET_DIR%" (
    echo �������� ������� ����������...
    mkdir "%TARGET_DIR%"
)

echo ���������� master.zip...
powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TARGET_DIR%' -Force"

if not exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo ����������� ��������� �����...
    for /f "delims=" %%i in ('dir /b "%TARGET_DIR%"') do (
        ren "%TARGET_DIR%\%%i" "zapret-win-bundle-master"
    )
)

if exist "%TARGET_DIR%\zapret-win-bundle-master" (
    echo [�����] ����� ����������
) else (
    echo [������] �� ������� ����������� �����
    pause
    exit /b 1
)
echo.

:: ##############################
:: ## ��� 6: ���������
:: ##############################
echo ===================================
echo  ��������� ���������
echo ===================================
echo �������� ��������� �����...
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
            echo [�����] ���� %%B ��������
        ) else (
            echo [������] �� ������� ��������� %%B
            set "ERROR_FLAG=1"
        )
    )
)
echo.

:: ##############################
:: ## ��� 7: ����� ���������
:: ##############################
:STRATEGY_MENU
echo.
echo �������� ���������:
echo 1. ������ (�������� ��� ����������� �����������, ���������� 3/3 � keen bypass)
echo 2. ������� (�������� � ����������� ��� ����� ��������� ����, ���������� 4/4 � keen bypass)
echo 3. ������� (�������� � ����������� ��� ������������ tls1.2, ���������� 7/7 � keen bypass)
echo 4. ������������� (�������� � ����������� ��� ������������ tls1.2, ���������� 8/8 � keen bypass)
echo.

choice /C 1234 /N /M "��� ����� [1-4]: "
set "STRATEGY=%errorlevel%"

:: ��������� ����� ����� �����������
echo ��������� �����...
net stop %SERVICE_NAME% >nul 2>&1
net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
timeout /t 2 >nul

:: ������ ��������� ���������
echo ������ ��������� %STRATEGY%...
cd /d "%BASE_DIR%"
powershell -Command "Start-Process -Verb RunAs -FilePath '%BASE_DIR%\!STRATEGY!_*.cmd' -Wait"

:: ##############################
:: ## ��� 8: ����� � ���������
:: ##############################
:FINAL_MENU
echo.
echo ====================================
echo  ��������� ������� ���������!
echo ====================================
echo.
echo ====================================
echo ��������� ����������� �������
echo ���� ��� �������� - �������� ������
echo ���� ���� ��������, ������� 1:
echo 1. ������� ���������
echo 2. �����
echo ====================================
echo.

:CHOICE_FINAL
choice /C 12 /N /M "�������� �������� [1 ��� 2]: "
if %errorlevel% equ 2 (
    echo.
    echo ====================================
    echo ���������� ������ ����� 5 ������...
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
:: ## ��������� �������� ##
:: ##########################
echo.
echo ===================================
echo  �������������
echo ===================================
echo ��������� �����...
net stop %SERVICE_NAME% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%SERVICE_NAME%" /f >nul 2>&1

net stop %WINDIVERT_SERVICE% >nul 2>&1
sc delete %WINDIVERT_SERVICE% >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%WINDIVERT_SERVICE%" /f >nul 2>&1

echo �������� ������...
powershell -Command "Get-Process | Where-Object { $_.Path -like '%TARGET_DIR%\*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
timeout /t 2 >nul
rmdir /s /q "%TARGET_DIR%" 2>nul

if exist "%TARGET_DIR%" (
    echo [������] �� ������� ������� ����� %TARGET_DIR%
    pause
    exit /b 1
) else (
    echo [�����] ��� ���������� �������
)

echo.
echo ===================================
echo  �������� ������� ���������!
echo ===================================
timeout /t 5
exit /b 0