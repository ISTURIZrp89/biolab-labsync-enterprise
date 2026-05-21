param([switch]$DevMode)

$rootDir = $PSScriptRoot
$backendDir = Join-Path $rootDir "backend"
$python = Join-Path $backendDir "venv\Scripts\python.exe"
$portApi = 8000
$portWeb = 8765

if (-not (Test-Path $python)) {
    Write-Host "Virtualenv no encontrado. Ejecuta primero: .\setup_dev.ps1" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  LABSYNC ENTERPRISE v7.0" -ForegroundColor Cyan
Write-Host "  Iniciando servidores..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Matar instancias anteriores
Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "uvicorn|main:app" } | Stop-Process -Force 2>$null
Start-Sleep -Seconds 1

# Iniciar Backend FastAPI (nueva ventana)
$apiArgs = "-ExecutionPolicy Bypatch -NoExit -Command " + `
    "cd '$backendDir'; " + `
    "& '$python' -m uvicorn main:app --host 0.0.0.0 --port $portApi"
if ($DevMode) { $apiArgs += " --reload" }

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command", "cd '$backendDir'; & '$python' -m uvicorn main:app --host 0.0.0.0 --port $portApi"
) -WindowStyle Normal

Start-Sleep -Seconds 4

# Iniciar Servidor Web PowerShell (nueva ventana)
Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command", "cd '$rootDir'; & powershell -ExecutionPolicy Bypass -File '$rootDir\server.ps1' -Port $portWeb"
) -WindowStyle Normal

Start-Sleep -Seconds 2

# Abrir navegadores
Start-Process "http://localhost:$portApi/docs"
Start-Process "http://localhost:$portWeb"

Write-Host ""
Write-Host "  API Backend:  http://localhost:$portApi" -ForegroundColor Green
Write-Host "  Documentacion: http://localhost:$portApi/docs" -ForegroundColor Green
Write-Host "  Web App:      http://localhost:$portWeb" -ForegroundColor Green
Write-Host ""
Write-Host "  Cierra las ventanas PowerShell para detener los servidores." -ForegroundColor Gray
Write-Host ""
