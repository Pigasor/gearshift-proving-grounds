@echo off
title GearShift Proving Grounds
echo ========================================================
echo        GEARSHIFT PROVING GROUNDS - OYUN BASLANIYOR
echo ========================================================
echo.

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if exist "%SCRIPT_DIR%Godot_v4.3-stable_win64.exe" (
    echo [OK] Yerel Godot 4.3 bulundu! Oyun aciliyor...
    start "" "%SCRIPT_DIR%Godot_v4.3-stable_win64.exe" --path "%SCRIPT_DIR%."
    exit /b 0
)

for /r "%SCRIPT_DIR%" %%F in (*godot*.exe) do (
    if exist "%%F" (
        echo [OK] Godot bulundu: %%F
        start "" "%%F" --path "%SCRIPT_DIR%."
        exit /b 0
    )
)

where godot >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Sistem Godot bulundu!
    start "" godot --path "%SCRIPT_DIR%."
    exit /b 0
)

echo [HATA] Godot bulunamadi.
pause
