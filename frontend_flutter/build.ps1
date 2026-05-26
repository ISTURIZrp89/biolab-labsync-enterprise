param(
  [string]$Platform = "windows",
  [switch]$Run
)

$token = $env:LICENSE_GITHUB_TOKEN
if (-not $token) {
  $token = Read-Host "Ingresa el token de GitHub (LICENSE_GITHUB_TOKEN)"
  if (-not $token) {
    Write-Error "Token requerido. Configura la variable de entorno LICENSE_GITHUB_TOKEN"
    exit 1
  }
}

$cmd = if ($Run) { "run" } else { "build" }
$platformFlag = switch ($Platform) {
  "windows" { "-d windows" }
  "macos"   { "-d macos" }
  "linux"   { "-d linux" }
  "android" { "-d android" }
  "ios"     { "-d ios" }
  "web"     { "-d web" }
  default   { "-d windows" }
}

Write-Host "Compilando con LICENSE_GITHUB_TOKEN..." -ForegroundColor Cyan
flutter $cmd $platformFlag --dart-define=LICENSE_GITHUB_TOKEN=$token
