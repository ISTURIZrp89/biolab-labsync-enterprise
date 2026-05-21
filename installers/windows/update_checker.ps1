# BioLab LABSYNC - Background Update Checker
# Runs on Windows startup, checks for updates every 30 minutes
# Auto-downloads and installs if update is available

$SERVER_URL = "http://localhost:8000"
$CHECK_INTERVAL = 1800  # 30 minutes in seconds
$INSTALL_DIR = "$env:LOCALAPPDATA\BioLab"
$EXE_PATH = "$INSTALL_DIR\biolab_labsync.exe"

Write-Host "========================================"
Write-Host "BioLab LABSYNC - Update Checker"
Write-Host "========================================"
Write-Host ""
Write-Host "[INFO] Server: $SERVER_URL"
Write-Host "[INFO] Check interval: $($CHECK_INTERVAL / 60) minutes"
Write-Host "[INFO] Install dir: $INSTALL_DIR"
Write-Host ""

# Create install directory if not exists
if (!(Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}

function Check-And-Update {
    try {
        # Get current version
        $currentVersion = "7.1.0"
        if (Test-Path "$INSTALL_DIR\version.txt") {
            $currentVersion = Get-Content "$INSTALL_DIR\version.txt"
        }

        # Check for updates
        $response = Invoke-RestMethod -Uri "$SERVER_URL/api/updates/check?current_version=$currentVersion&platform=windows" -TimeoutSec 10

        if ($response.has_update) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Nueva version disponible: $($response.latest_version)"

            # Download update info
            $downloadInfo = $response.download
            if ($downloadInfo) {
                $filename = $downloadInfo.filename
                $url = $downloadInfo.url

                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Descargando: $filename"

                # Download installer
                $tempFile = "$env:TEMP\$filename"
                Invoke-WebRequest -Uri $url -OutFile $tempFile -TimeoutSec 300

                if (Test-Path $tempFile) {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Descarga completada. Instalando..."

                    # Kill running instance
                    $process = Get-Process -Name "biolab_labsync" -ErrorAction SilentlyContinue
                    if ($process) {
                        $process | Stop-Process -Force
                        Start-Sleep -Seconds 2
                    }

                    # Silent install
                    Start-Process -FilePath $tempFile -ArgumentList "/SILENT", "/NORESTART", "/DIR=`"$INSTALL_DIR`"", "/SUPPRESSMSGBOXES" -Wait -NoNewWindow

                    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
                        # Save new version
                        $response.latest_version | Out-File -FilePath "$INSTALL_DIR\version.txt" -Force

                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Actualizacion instalada: $($response.latest_version)"

                        # Restart app
                        if (Test-Path $EXE_PATH) {
                            Start-Process -FilePath $EXE_PATH
                        }
                    } else {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error en instalacion (codigo: $LASTEXITCODE)"
                    }

                    # Cleanup
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] La aplicacion esta actualizada (v$currentVersion)"
        }
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error: $_"
    }
}

# Main loop
while ($true) {
    Check-And-Update
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Proxima verificacion en $($CHECK_INTERVAL / 60) minutos..."
    Write-Host ""
    Start-Sleep -Seconds $CHECK_INTERVAL
}
