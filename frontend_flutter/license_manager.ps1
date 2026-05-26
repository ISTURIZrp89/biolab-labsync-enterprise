param(
  [string]$RepoPath = "$env:USERPROFILE\biolab-labsync-license"
)

$ErrorActionPreference = "Stop"

function Write-Banner {
  Clear-Host
  Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "║     LABSYNC - GESTOR DE LICENCIAS       ║" -ForegroundColor Cyan
  Write-Host "║     Genera y publica claves en segundos  ║" -ForegroundColor Cyan
  Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""
}

function Generate-Key {
  param([string]$Branch)
  $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  $random = [System.Random]::new()
  $part1 = -join (1..4 | ForEach-Object { $chars[$random.Next($chars.Length)] })
  $part2 = -join (1..4 | ForEach-Object { $chars[$random.Next($chars.Length)] })
  return "LABSYNC-$Branch-$part1-$part2"
}

function Get-Hash {
  param([string]$Key)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Key)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return [System.BitConverter]::ToString($hash).Replace("-","").ToLower()
}

function Show-LicenseFile {
  param([string]$Path)
  $json = Get-Content $Path -Raw | ConvertFrom-Json
  Write-Host "`nSucursales registradas:" -ForegroundColor Yellow
  $json.branches.PSObject.Properties | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Green
  }
}

# Main
Write-Banner

# 1. Clonar o actualizar repo
if (-not (Test-Path "$RepoPath\.git")) {
  Write-Host "[1/5] Clonando repositorio privado..." -ForegroundColor Yellow
  $repoUrl = "https://github.com/ISTURIZrp89/biolab-labsync-license.git"
  git clone $repoUrl $RepoPath 2>&1 | Out-Null
  if (-not $?) {
    Write-Host "[!] No se pudo clonar. Verifica tus credenciales de GitHub." -ForegroundColor Red
    Write-Host "    Requisitos: git config --global credential.helper manager" -ForegroundColor Gray
    exit 1
  }
  Write-Host "  [OK] Repositorio clonado en $RepoPath" -ForegroundColor Green
} else {
  Write-Host "[1/5] Actualizando repositorio..." -ForegroundColor Yellow
  Set-Location $RepoPath
  git pull origin master 2>&1 | Out-Null
  Write-Host "  [OK] Repositorio actualizado" -ForegroundColor Green
}

Set-Location $RepoPath

# 2. Mostrar sucursales existentes
Write-Host "[2/5] Cargando licencias actuales..." -ForegroundColor Yellow
$licenseFile = Join-Path $RepoPath "license.json"
if (-not (Test-Path $licenseFile)) {
  Write-Host "[!] No se encuentra license.json en el repositorio" -ForegroundColor Red
  exit 1
}

Show-LicenseFile -Path $licenseFile

# 3. Elegir sucursal o crear nueva
Write-Host "`n[3/5] Selecciona una opcion:" -ForegroundColor Yellow
Write-Host "  1) Usar sucursal existente" -ForegroundColor White
Write-Host "  2) Crear nueva sucursal" -ForegroundColor White
$opt = Read-Host "`nOpcion (1 o 2)"

$branchName = ""
if ($opt -eq "2") {
  $branchName = Read-Host "Nombre de la nueva sucursal (ej: matriz, norte, sur)"
  $branchName = $branchName.ToLower().Trim()
  if ($branchName -eq "") {
    Write-Host "[!] Nombre invalido" -ForegroundColor Red
    exit 1
  }
} else {
  $branchName = Read-Host "Nombre de la sucursal existente"
  $branchName = $branchName.ToLower().Trim()
  $json = Get-Content $licenseFile -Raw | ConvertFrom-Json
  if (-not ($json.branches.$branchName)) {
    Write-Host "[!] Sucursal '$branchName' no existe en license.json" -ForegroundColor Red
    exit 1
  }
}

# 4. Generar clave
Write-Host "[4/5] Generando nueva clave para '$branchName'..." -ForegroundColor Yellow
$newKey = Generate-Key -Branch $branchName.ToUpper()
$newHash = Get-Hash -Key $newKey

Write-Host "`n  Clave generada: " -ForegroundColor White -NoNewline
Write-Host "$newKey" -ForegroundColor Green -NoNewline
Write-Host "  (SHA256: $newHash)" -ForegroundColor Gray

Write-Host "`n  IMPORTANTE: Guarda esta clave en un lugar seguro." -ForegroundColor Yellow
Write-Host "  Una vez cerrada esta ventana, NO podras recuperarla." -ForegroundColor Yellow
Write-Host "  (Solo el hash SHA256 se guarda en el repositorio)" -ForegroundColor Yellow

# 5. Actualizar license.json
Write-Host "[5/5] Actualizando license.json..." -ForegroundColor Yellow

$jsonContent = Get-Content $licenseFile -Raw
$json = $jsonContent | ConvertFrom-Json

# Actualizar o agregar sucursal
$json.branches | Add-Member -MemberType NoteProperty -Name $branchName -Value $newHash -Force

$jsonString = $json | ConvertTo-Json
# Hacer que el JSON se vea limpio (manually format for readability)
$jsonString = "{" + "`n  `"branches`": {" + "`n"
$json.branches.PSObject.Properties | Sort-Object Name | ForEach-Object {
  $jsonString += "    `"$($_.Name)`": `"$($_.Value)`"," + "`n"
}
$jsonString = $jsonString.TrimEnd("`n").TrimEnd(",") + "`n  },"
$jsonString += "`n  `"device_commands`": " + ($json.device_commands | ConvertTo-Json) + ","
$jsonString += "`n  `"app_version`": `"$($json.app_version)`","
$jsonString += "`n  `"min_app_version`": `"$($json.min_app_version)`","
$jsonString += "`n  `"message`": `"$($json.message)`""
$jsonString += "`n}"

$jsonString | Set-Content $licenseFile -Encoding UTF8

Write-Host "  [OK] license.json actualizado" -ForegroundColor Green

# Commit y push
Write-Host "`nSubiendo cambios al repositorio privado..." -ForegroundColor Yellow
git add license.json
git commit -m "Actualizar licencia: $branchName"
git push origin master 2>&1 | Out-Null

if ($?) {
  Write-Host ""
  Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Green
  Write-Host "║           OPERACION EXITOSA              ║" -ForegroundColor Green
  Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
  Write-Host ""
  Write-Host "  Sucursal:    $branchName" -ForegroundColor White
  Write-Host "  Clave:       " -ForegroundColor White -NoNewline
  Write-Host "$newKey" -ForegroundColor Green -Bold
  Write-Host "  Hash:        $newHash" -ForegroundColor Gray
  Write-Host ""
  Write-Host "  Los dispositivos detectaran la nueva licencia" -ForegroundColor Cyan
  Write-Host "  en los proximos 10 minutos (validacion automatica)." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "[ENTER para salir]" -ForegroundColor Gray
  Read-Host | Out-Null
} else {
  Write-Host "[!] Error al hacer push. Revisa tus credenciales de GitHub." -ForegroundColor Red
  Read-Host | Out-Null
}
