@echo off
REM BioLab LABSYNC - Silent Installer for Windows
REM Usage: install_silent.exe [SERVER_URL]

setlocal enabledelayedexpansion

set SERVER_URL=%1
if "%SERVER_URL%"=="" set SERVER_URL=http://localhost:8000

echo ========================================
echo BioLab LABSYNC - Instalador Silencioso
echo ========================================
echo.

REM Check if already installed
set INSTALL_DIR=%LOCALAPPDATA%\BioLab
set EXE_PATH=%INSTALL_DIR%\biolab_labsync.exe

if exist "%EXE_PATH%" (
    echo [INFO] BioLab ya instalado en %INSTALL_DIR%
    echo [INFO] Verificando actualizaciones...
) else (
    echo [INFO] Instalando BioLab LABSYNC...
    mkdir "%INSTALL_DIR%" 2>nul
)

REM Download version info
echo [1/3] Verificando version...
powershell -Command "(New-Object Net.WebClient).DownloadFile('%SERVER_URL%/api/updates/version.json', '%TEMP%\labsync_version.json')" 2>nul

if not exist "%TEMP%\labsync_version.json" (
    echo [ERROR] No se pudo conectar al servidor: %SERVER_URL%
    echo [ERROR] Verifica que el backend este corriendo
    pause
    exit /b 1
)

REM Parse version
for /f "tokens=*" %%i in ('powershell -Command "(Get-Content '%TEMP%\labsync_version.json' | ConvertFrom-Json).version"') do set NEW_VERSION=%%i

echo [INFO] Version disponible: %NEW_VERSION%

REM Download installer
echo [2/3] Descargando actualizacion...
powershell -Command "(New-Object Net.WebClient).DownloadFile('%SERVER_URL%/api/updates/file/BioLab-LABSYNC-%NEW_VERSION%-windows.exe', '%TEMP%\biolab_update.exe')" 2>nul

if not exist "%TEMP%\biolab_update.exe" (
    echo [ERROR] No se pudo descargar el instalador
    pause
    exit /b 1
)

REM Silent install
echo [3/3] Instalando silenciosamente...
start /wait "" "%TEMP%\biolab_update.exe" /SILENT /NORESTART /DIR="%INSTALL_DIR%" /SUPPRESSMSGBOXES

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Instalacion completada exitosamente
    echo [OK] BioLab LABSYNC v%NEW_VERSION% instalado en %INSTALL_DIR%
    echo.
    echo Iniciando aplicacion...
    start "" "%INSTALL_DIR%\biolab_labsync.exe"
) else (
    echo.
    echo [ERROR] Error en la instalacion (codigo: %ERRORLEVEL%)
    pause
    exit /b %ERRORLEVEL%
)

REM Cleanup
del "%TEMP%\biolab_update.exe" 2>nul
del "%TEMP%\labsync_version.json" 2>nul

echo.
echo ========================================
echo Instalacion completada
echo ========================================
