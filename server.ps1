# BioLab HTTP Server v6.4 - PowerShell puro (sin dependencias)
param([int]$Port = 8765)

$dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".jsx"  = "application/javascript; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".ico"  = "image/x-icon"
    ".txt"  = "text/plain; charset=utf-8"
    ".webp" = "image/webp"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host ""
Write-Host "  ========================================"
Write-Host "   BIOLAB v6.4 - Servidor corriendo"
Write-Host "   http://localhost:$Port"
Write-Host "   Cierra esta ventana para detenerlo."
Write-Host "  ========================================"
Write-Host ""

function Send-Json($resp, $obj, $code = 200) {
    $json = $obj | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $resp.StatusCode = $code
    $resp.ContentType = "application/json; charset=utf-8"
    $resp.ContentLength64 = $bytes.Length
    $resp.OutputStream.Write($bytes, 0, $bytes.Length)
    $resp.OutputStream.Close()
}

while ($listener.IsListening) {
    try {
        $ctx  = $listener.GetContext()
        $req  = $ctx.Request
        $resp = $ctx.Response
        $resp.Headers.Add("Access-Control-Allow-Origin", "*")
        $resp.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $resp.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        $rawPath = $req.Url.LocalPath

        # Handle CORS preflight
        if ($req.HttpMethod -eq "OPTIONS") {
            $resp.StatusCode = 200
            $resp.OutputStream.Close()
            continue
        }

        # POST /api/save-file  { path, filename, contentBase64, encoding }
        if ($req.HttpMethod -eq "POST" -and $rawPath -eq "/api/save-file") {
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()
                $data = $body | ConvertFrom-Json
                $savePath = $data.path
                $filename = $data.filename
                $fullPath = Join-Path $savePath $filename
                # Ensure directory exists
                if (-not (Test-Path $savePath)) { New-Item -ItemType Directory -Path $savePath -Force | Out-Null }
                # Decode base64 and save
                $bytes = [Convert]::FromBase64String($data.contentBase64)
                [System.IO.File]::WriteAllBytes($fullPath, $bytes)
                Send-Json $resp @{ success = $true; savedTo = $fullPath }
            } catch {
                Send-Json $resp @{ success = $false; error = $_.Exception.Message } 500
            }
            continue
        }

        # POST /api/list-dir  { path }
        if ($req.HttpMethod -eq "POST" -and $rawPath -eq "/api/list-dir") {
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()
                $data = $body | ConvertFrom-Json
                $items = Get-ChildItem -Path $data.path -ErrorAction Stop | Select-Object Name, LastWriteTime, Length
                Send-Json $resp @{ success = $true; items = $items }
            } catch {
                Send-Json $resp @{ success = $false; error = $_.Exception.Message } 500
            }
            continue
        }

        # Serve static files
        if ($rawPath -eq "/" -or $rawPath -eq "") { $rawPath = "/index.html" }
        $filePath = Join-Path $dir ($rawPath.TrimStart("/").Replace("/", "\"))

        if (Test-Path $filePath -PathType Leaf) {
            $ext     = [System.IO.Path]::GetExtension($filePath).ToLower()
            $ct      = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
            $bytes   = [System.IO.File]::ReadAllBytes($filePath)
            $resp.ContentType   = $ct
            $resp.ContentLength64 = $bytes.Length
            $resp.StatusCode    = 200
            $resp.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $resp.StatusCode = 404
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $rawPath")
            $resp.OutputStream.Write($body, 0, $body.Length)
        }
        $resp.OutputStream.Close()
    } catch {
        # Ignorar errores de conexion cerrada
    }
}
