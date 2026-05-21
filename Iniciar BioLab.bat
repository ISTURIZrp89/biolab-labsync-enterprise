@echo off
title LABSYNC Enterprise v7.0
cd /d "%~dp0"

echo ==========================================
echo   LABSYNC ENTERPRISE v7.0
echo   Iniciando servidores...
echo ==========================================
echo.

:: Matar procesos anteriores
taskkill /F /IM python.exe /FI "WINDOWTITLE eq uvicorn*" >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq BioLab_Server" >nul 2>&1

:: Iniciar Backend FastAPI
echo [API] Iniciando backend en puerto 8000...
start "uvicorn-backend" /MIN cmd /c "cd /d backend && venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000"

:: Esperar a que arranque
timeout /t 4 /nobreak >nul

:: Iniciar Servidor Web PowerShell
echo [WEB] Iniciando servidor web en puerto 8765...
start "BioLab_Server" /MIN powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0server.ps1"

:: Esperar un momento
timeout /t 2 /nobreak >nul

:: Abrir navegadores
echo [OK] Abriendo aplicaciones...
start "" "http://localhost:8000/docs"
start "" "http://localhost:8765"

echo.
echo ==========================================
echo   LABSYNC ENTERPRICE ACTIVO
echo   API:  http://localhost:8000
echo   Docs: http://localhost:8000/docs
echo   Web:  http://localhost:8765
echo ==========================================
echo.
echo   Presiona cualquier tecla para cerrar...
echo   (Los servidores seguiran corriendo en segundo plano)
pause >nul
exit
