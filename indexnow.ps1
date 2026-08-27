# Submits this site's URLs to IndexNow, which notifies Bing, Yandex,
# Seznam and Naver that pages have changed. Google does not participate.
# It affects how soon crawlers revisit, not how pages rank.
#
# The URL list is read from sitemap.xml, so the sitemap is the single
# source of truth: regenerate it with build-sitemap.ps1 first, and
# whatever it lists is what gets submitted.
#
# To run from a PowerShell prompt in this folder:
#     .\indexnow.ps1
# To see exactly what would be sent without sending it:
#     .\indexnow.ps1 -DryRun
#
# Ordering matters. The key file must already be live on the public site
# before submitting: search engines fetch it to confirm you control the
# domain. Commit and push it first, give GitHub Pages a minute, then run
# this. The check below fails loudly rather than letting a submission be
# silently rejected, which is the one mistake that looks like success.

[CmdletBinding()]
param(
    # Submit only these URLs instead of everything in the sitemap. Use it
    # after editing one page: resubmitting all 14 for a one-page change is
    # the repeated no-op traffic that gets a domain deprioritised.
    [string[]]$Urls,

    # Print the payload and exit without contacting IndexNow.
    [switch]$DryRun,

    # Submit anyway if the key file cannot be fetched. Only useful when
    # the site is briefly unreachable but you know the key is published.
    [switch]$SkipKeyCheck
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$endpoint = 'https://api.indexnow.org/indexnow'

# PowerShell 5.1 can still default to TLS 1.0, which these endpoints refuse.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

function Fail($message) {
    Write-Host ""
    Write-Host "  $message" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# --- host -------------------------------------------------------------
$cnamePath = Join-Path $root 'CNAME'
if (-not (Test-Path -LiteralPath $cnamePath)) { Fail "No CNAME file - cannot determine the site host." }
$siteHost = (Get-Content -LiteralPath $cnamePath -Raw).Trim()
$baseUrl  = "https://$siteHost"

# --- key --------------------------------------------------------------
# The key file is identified by the protocol's own rule: it is named
# <key>.txt and contains exactly <key>. Deriving it that way means a key
# rotation needs no edit here, and robots.txt is excluded automatically
# because its contents are not its filename.
$keyFile = Get-ChildItem -LiteralPath $root -File -Filter *.txt | Where-Object {
    $name = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $body = [IO.File]::ReadAllText($_.FullName).Trim()
    $name -eq $body
} | Select-Object -First 1

if (-not $keyFile) {
    Fail "No IndexNow key file found in $root (expected <key>.txt containing <key>)."
}

$key         = [IO.Path]::GetFileNameWithoutExtension($keyFile.Name)
$keyLocation = "$baseUrl/$($keyFile.Name)"

# --- urls -------------------------------------------------------------
if ($Urls) {
    $urls = @($Urls)
    $source = 'command line'
} else {
    $sitemapPath = Join-Path $root 'sitemap.xml'
    if (-not (Test-Path -LiteralPath $sitemapPath)) { Fail "sitemap.xml not found - run build-sitemap.ps1 first." }

    [xml]$sitemap = Get-Content -LiteralPath $sitemapPath -Raw
    $urls = @($sitemap.urlset.url | ForEach-Object { $_.loc })
    $source = 'sitemap.xml'
}

if ($urls.Count -eq 0) { Fail "No URLs to submit." }

# IndexNow rejects the whole batch if any URL is off-host, so catch it here
# where the message can say which one.
$offHost = @($urls | Where-Object { $_ -notlike "$baseUrl/*" -and $_ -ne $baseUrl })
if ($offHost.Count -gt 0) {
    Fail "These URLs are not on $siteHost and would be rejected:`n    $($offHost -join "`n    ")"
}

Write-Host ""
Write-Host "  Synapse Optics - IndexNow" -ForegroundColor Cyan
Write-Host "  $($urls.Count) URLs from $source, host $siteHost" -ForegroundColor White
Write-Host "  key $key" -ForegroundColor DarkGray
Write-Host ""

# --- verify the key file is actually published ------------------------
if (-not $SkipKeyCheck) {
    try {
        $probe = Invoke-WebRequest -Uri $keyLocation -UseBasicParsing -TimeoutSec 20
        $served = $probe.Content.Trim()
        if ($served -ne $key) {
            Fail "$keyLocation served '$served' but the key is '$key'."
        }
        Write-Host "  Key file is live and correct." -ForegroundColor Green
    } catch {
        Fail ("Cannot fetch $keyLocation - $($_.Exception.Message)`n" +
              "  Commit and push the key file, wait for Pages to rebuild, then retry.")
    }
}

$payload = [ordered]@{
    host        = $siteHost
    key         = $key
    keyLocation = $keyLocation
    urlList     = $urls
}
$json = $payload | ConvertTo-Json -Depth 3

if ($DryRun) {
    Write-Host ""
    Write-Host "  Dry run - nothing sent. Payload:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $json
    Write-Host ""
    exit 0
}

# --- submit -----------------------------------------------------------
Write-Host "  Submitting to $endpoint ..." -ForegroundColor DarkGray

try {
    # Send explicit UTF-8 bytes rather than a string: it removes any doubt
    # about how Windows PowerShell encodes the body before transmission.
    $response = Invoke-WebRequest -Uri $endpoint -Method Post `
                    -Body ([Text.Encoding]::UTF8.GetBytes($json)) `
                    -ContentType 'application/json; charset=utf-8' `
                    -UseBasicParsing -TimeoutSec 30
    $code = [int]$response.StatusCode
    $body = $response.Content
} catch {
    # PowerShell 5.1 throws on any non-2xx, so recover the real status
    # rather than reporting a generic failure.
    $webResponse = $_.Exception.Response
    if ($webResponse) {
        $code = [int]$webResponse.StatusCode
        try {
            $reader = [IO.StreamReader]::new($webResponse.GetResponseStream())
            $body = $reader.ReadToEnd()
            $reader.Close()
        } catch { $body = '' }
    } else {
        Fail "Request failed - $($_.Exception.Message)"
    }
}

Write-Host ""
if ($code -eq 200 -or $code -eq 202) {
    # 202 means accepted with the key still being validated - success.
    Write-Host "  HTTP $code - accepted. $($urls.Count) URLs submitted." -ForegroundColor Green
    if ($code -eq 202) {
        Write-Host "  (202: key validation still pending, which is normal on a first run.)" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

Write-Host "  HTTP $code - NOT accepted." -ForegroundColor Red
switch ($code) {
    400 { Write-Host "  400 Bad Request - malformed payload." -ForegroundColor Yellow }
    403 { Write-Host "  403 Forbidden - key not valid or not reachable at $keyLocation." -ForegroundColor Yellow }
    422 { Write-Host "  422 Unprocessable - URLs do not match the host, or the key does not match." -ForegroundColor Yellow }
    429 { Write-Host "  429 Too Many Requests - slow down; try again later." -ForegroundColor Yellow }
}
if ($body) { Write-Host "  Response: $body" -ForegroundColor DarkGray }
Write-Host ""
exit 1
