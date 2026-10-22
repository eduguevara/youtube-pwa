# Servidor estático mínimo (sin dependencias ni permisos de administrador) para instalar la PWA.
# Usa TcpListener en lugar de HttpListener para poder escuchar en la IP de la LAN sin "netsh urlacl".
param(
    [int]$Port = 8787,
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.json' = 'application/manifest+json; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
}

$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -ExpandProperty IPAddress

Write-Host ''
Write-Host '  ============================================' -ForegroundColor DarkGray
Write-Host '   Instalador PWA YouTube Mobile' -ForegroundColor White
Write-Host '  ============================================' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Abre una de estas direcciones en el navegador del movil' -ForegroundColor Gray
Write-Host '  (conectado a la misma red WiFi que este PC):' -ForegroundColor Gray
Write-Host ''
foreach ($ip in $ips) { Write-Host "     http://${ip}:$Port/" -ForegroundColor Green }
Write-Host ''
Write-Host '  Cuando la app este en la pantalla de inicio, cierra esta ventana.' -ForegroundColor Yellow
Write-Host '  Si Windows pregunta por el Firewall, permite el acceso en "Redes privadas".' -ForegroundColor DarkYellow
Write-Host ''

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
try {
    $listener.Start()
} catch {
    Write-Host "  ERROR: no se pudo abrir el puerto $Port. Esta en uso? Prueba: start-installer.bat 8788" -ForegroundColor Red
    exit 1
}

function Send-Response($stream, [int]$code, [string]$status, [string]$type, [byte[]]$body, [bool]$headOnly) {
    $headers = "HTTP/1.1 $code $status`r`n" +
               "Content-Type: $type`r`n" +
               "Content-Length: $($body.Length)`r`n" +
               "Cache-Control: no-cache`r`n" +
               "Connection: close`r`n`r`n"
    $h = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $stream.Write($h, 0, $h.Length)
    if (-not $headOnly -and $body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 5000
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
            $requestLine = $reader.ReadLine()
            while ($true) { $line = $reader.ReadLine(); if ([string]::IsNullOrEmpty($line)) { break } }
            if (-not $requestLine) { continue }

            $parts = $requestLine.Split(' ')
            $method = $parts[0]
            $rawPath = ($parts[1] -split '\?')[0]
            $relPath = [System.Uri]::UnescapeDataString($rawPath).TrimStart('/')
            if ($relPath -eq '') { $relPath = 'index.html' }

            $full = [System.IO.Path]::GetFullPath((Join-Path $Root $relPath))
            $remote = $client.Client.RemoteEndPoint.Address
            Write-Host ("  {0:HH:mm:ss}  {1,-15} {2} /{3}" -f (Get-Date), $remote, $method, $relPath) -ForegroundColor DarkGray

            if ($method -notin 'GET', 'HEAD') {
                Send-Response $stream 405 'Method Not Allowed' 'text/plain' ([byte[]]@()) $false
            } elseif (-not $full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase) -or
                      -not (Test-Path -LiteralPath $full -PathType Leaf) -or
                      $relPath -match '\.(ps1|bat)$') {
                $b = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                Send-Response $stream 404 'Not Found' 'text/plain' $b ($method -eq 'HEAD')
            } else {
                $ext = [System.IO.Path]::GetExtension($full).ToLower()
                $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
                $bytes = [System.IO.File]::ReadAllBytes($full)
                Send-Response $stream 200 'OK' $type $bytes ($method -eq 'HEAD')
            }
            $stream.Flush()
        } catch {
            # Cliente desconectado o petición malformada: se ignora y se atiende la siguiente.
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
