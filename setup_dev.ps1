param([switch]$Reset)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  LABSYNC ENTERPRISE - Configuracion Dev" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$backendDir = Join-Path $PSScriptRoot "backend"

# 1. Verificar Python
try {
    $py = Get-Command "python" -ErrorAction Stop
    $ver = & $py --version
    Write-Host "[OK] Python: $ver" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Python no encontrado. Instala Python 3.11+ desde python.org" -ForegroundColor Red
    exit 1
}

# 2. Crear virtualenv
$venvDir = Join-Path $backendDir "venv"
if (-not (Test-Path $venvDir) -or $Reset) {
    Write-Host "[...] Creando virtualenv..." -ForegroundColor Yellow
    & $py -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Error creando virtualenv" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Virtualenv creado" -ForegroundColor Green
} else {
    Write-Host "[OK] Virtualenv existe" -ForegroundColor Green
}

# 3. Instalar dependencias
$pip = Join-Path $venvDir "Scripts\pip.exe"
Write-Host "[...] Instalando dependencias..." -ForegroundColor Yellow
& $pip install -r (Join-Path $backendDir "requirements.txt") 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Error instalando dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencias instaladas" -ForegroundColor Green

# 4. Verificar .env
$envFile = Join-Path $backendDir ".env"
if (-not (Test-Path $envFile)) {
    @"
SECRET_KEY=LABSYNC_SUPER_SECRET_KEY_ENTERPRISE_7.0
DATABASE_URL=sqlite:///./labsync.db
ACCESS_TOKEN_EXPIRE_MINUTES=480
CORS_ORIGINS=*
SYNC_SERVER_PORT=8000
"@ | Set-Content -Path $envFile -Encoding UTF8
    Write-Host "[OK] .env creado" -ForegroundColor Green
} else {
    Write-Host "[OK] .env existe" -ForegroundColor Green
}

# 5. Crear acceso directo en escritorio (opcional)
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "LABSYNC Enterprise.lnk"
if (-not (Test-Path $shortcutPath)) {
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$PSScriptRoot\dev_start.ps1`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = "LABSYNC Enterprise v7.0 - Iniciar servidores"
    $shortcut.Save()
    Write-Host "[OK] Acceso directo creado en Escritorio" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CONFIGURACION COMPLETADA" -ForegroundColor Green
Write-Host "  Ejecuta: .\dev_start.ps1" -ForegroundColor White
Write-Host "  O usa el acceso directo en el Escritorio" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
