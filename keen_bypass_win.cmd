@echo off
chcp 1251 >nul
NET FILE >NUL 2>&1 || (PowerShell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs" & EXIT /B)
PowerShell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; $u='https://raw.githubusercontent.com/Keen-Bypass/keen_bypass_win/main/common/netinstall.cmd'; $p='%TEMP%\k.cmd'; try {[IO.File]::WriteAllText($p, (iwr $u -UseBasicParsing).Content, [Text.Encoding]::GetEncoding(1251)); & $p; ri $p} catch {echo 'Error'; pause; exit 1}"
