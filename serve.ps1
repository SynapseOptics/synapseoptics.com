# Local preview server for the Synapse Optics website. PowerShell
# equivalent of serve.bat / serve.js — uses .NET HttpListener so no
# Node.js install is required, just Windows + PowerShell (5.1 or 7+).
#
# To run from a PowerShell prompt in this folder:
#     .\serve.ps1
# To run by double-click via a .cmd wrapper or shortcut, launch with:
#     powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0serve.ps1"
#
# If PowerShell refuses with "running scripts is disabled on this
# system" the script was tagged with mark-of-the-web (typical for
# files extracted from a downloaded zip). One-time fix:
#     Unblock-File .\serve.ps1
# or run once with -ExecutionPolicy Bypass as above.

$basePort = 8765
$maxAttempts = 16
$root = $PSScriptRoot

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.ico'  = 'image/x-icon'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.pdf'  = 'application/pdf'
    '.txt'  = 'text/plain; charset=utf-8'
}

# Pick the first free port in $basePort..$basePort+$maxAttempts-1.
# Lets the user double-click serve.bat after a stale instance is still
# running without any manual cleanup — the new run quietly picks the
# next port and the browser opens at the right URL.
$listener = $null
$port = $null
for ($i = 0; $i -lt $maxAttempts; $i++) {
    $tryPort  = $basePort + $i
    $candidate = [System.Net.HttpListener]::new()
    $candidate.Prefixes.Add("http://localhost:$tryPort/")
    try {
        $candidate.Start()
        $listener = $candidate
        $port = $tryPort
        break
    } catch [System.Net.HttpListenerException] {
        $candidate.Close()
    }
}

if ($null -eq $listener) {
    Write-Host ""
    Write-Host "  Could not find a free port in $basePort..$($basePort + $maxAttempts - 1)." -ForegroundColor Red
    Write-Host "  Close other preview servers and try again." -ForegroundColor Red
    exit 1
}

try {
    $url = "http://localhost:$port"

    Write-Host ""
    Write-Host "  Synapse Optics — local preview" -ForegroundColor Cyan
    Write-Host "  $url" -ForegroundColor White
    Write-Host ""
    Write-Host "  Serving from $root" -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C in this window to stop." -ForegroundColor DarkGray
    Write-Host ""

    # Copy URL to clipboard as a backup in case browser launch fails.
    try { Set-Clipboard -Value $url } catch { }

    # Auto-open the default browser at the URL. Best-effort — if the
    # browser launch fails, the URL is still on the clipboard above and
    # printed prominently in this console.
    try { Start-Process $url } catch { }

    while ($listener.IsListening) {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        $urlPath = [System.Net.WebUtility]::UrlDecode($request.Url.AbsolutePath)
        if ($urlPath.EndsWith('/')) { $urlPath += 'index.html' }

        # Path traversal guard: resolve and reject anything escaping the root.
        $relPath  = $urlPath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
        $combined = [IO.Path]::Combine($root, $relPath)
        $fullPath = [IO.Path]::GetFullPath($combined)

        $rootFull = [IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar) +
                    [IO.Path]::DirectorySeparatorChar

        if (-not $fullPath.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $response.StatusCode = 403
            $bytes = [Text.Encoding]::UTF8.GetBytes("403 forbidden")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            Write-Host ("403  {0}" -f $urlPath)
            continue
        }

        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            $ext = [IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
            $bytes = [IO.File]::ReadAllBytes($fullPath)
            $response.ContentType = $contentType
            $response.Headers.Add('Cache-Control', 'no-cache')
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            Write-Host ("200  {0}" -f $urlPath)
        } else {
            $response.StatusCode = 404
            $bytes = [Text.Encoding]::UTF8.GetBytes("404 not found: $urlPath")
            $response.ContentType = 'text/plain; charset=utf-8'
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            Write-Host ("404  {0}" -f $urlPath)
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
