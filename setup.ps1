param(
    [switch]$Init
)

$ErrorActionPreference = 'Stop'

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

# Check Python version
$pythonVersion = python --version 2>&1
if ($pythonVersion -notmatch "3\.1[1-9]") {
    Write-Host "[ERROR] Se requiere Python 3.11+. Version actual: $pythonVersion" -ForegroundColor Red
    exit 1
}

# Check Docker (optional)
$hasDocker = Get-Command docker -ErrorAction SilentlyContinue

# Setup Frontend
Write-Host "[1/4] Configurando Frontend (Flutter)..." -ForegroundColor Yellow
Push-Location packages/frontend
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
} finally {
    Pop-Location
}

# Setup Backend
Write-Host "[2/4] Configurando Backend (Python)..." -ForegroundColor Yellow
Push-Location packages/backend
try {
    if (-not (Test-Path .venv)) {
        python -m venv .venv
    }
    .\.venv\Scripts\pip install -e ".[dev]"
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
} finally {
    Pop-Location
}

# Setup .env if not exists
Write-Host "[3/4] Verificando configuracion..." -ForegroundColor Yellow
$envFile = "packages/backend\.env"
$envExample = "packages/backend\.env.example"
if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile
    Write-Host "  Creado .env desde .env.example - Editar con valores reales" -ForegroundColor Yellow
}

# Drift codegen
Write-Host "[4/4] Generando codigo (drift, riverpod)..." -ForegroundColor Yellow
Push-Location packages/frontend
try {
    dart run build_runner build --delete-conflicting-outputs
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup completado!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para iniciar:" -ForegroundColor White
Write-Host "  Frontend: cd packages/frontend && flutter run -d windows" -ForegroundColor Gray
Write-Host "  Backend:  cd packages/backend && .\.venv\Scripts\uvicorn app.main:app --reload" -ForegroundColor Gray
if ($hasDocker) {
    Write-Host "  Infra:    docker compose up -d" -ForegroundColor Gray
} else {
    Write-Host "  Infra:    Docker no disponible - instalar Docker Desktop" -ForegroundColor DarkYellow
}
