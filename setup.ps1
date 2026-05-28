param(
    [switch]$Init
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  BioLab LABSYNC Enterprise - Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Flutter no instalado. Instalalo desde: https://flutter.dev" -ForegroundColor Red
    exit 1
}

# Check Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Python 3.11+ no instalado." -ForegroundColor Red
    exit 1
}

# Setup Frontend
Write-Host "[1/3] Configurando Frontend (Flutter)..." -ForegroundColor Yellow
Set-Location packages/frontend
flutter pub get
Set-Location ../..

# Setup Backend
Write-Host "[2/3] Configurando Backend (Python)..." -ForegroundColor Yellow
Set-Location packages/backend
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
Set-Location ../..

# Drift codegen
Write-Host "[3/3] Generando codigo (drift, riverpod)..." -ForegroundColor Yellow
Set-Location packages/frontend
dart run build_runner build --delete-conflicting-outputs
Set-Location ../..

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup completado!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para iniciar:" -ForegroundColor White
Write-Host "  Frontend: cd packages/frontend && flutter run -d windows" -ForegroundColor Gray
Write-Host "  Backend:  cd packages/backend && .\.venv\Scripts\uvicorn app.main:app --reload" -ForegroundColor Gray
Write-Host "  Infra:    docker compose up -d" -ForegroundColor Gray
