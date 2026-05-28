param(
    [switch]$Run,
    [string]$Platform = "windows"
)

Write-Host "Building BioLab LABSYNC for $Platform..." -ForegroundColor Cyan

$buildCmd = "flutter build $Platform --release"
if ($Run) {
    $buildCmd = "flutter run -d $Platform"
}

Write-Host "Running: $buildCmd" -ForegroundColor Yellow
Invoke-Expression $buildCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
} else {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}
