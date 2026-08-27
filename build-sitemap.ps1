# Regenerates sitemap.xml from the pages actually present on disk, taking
# each page's <lastmod> from git rather than from a hand-maintained date.
#
# The problem this solves: a hand-written sitemap drifts. You edit a page,
# forget to bump its <lastmod>, and the sitemap starts lying to crawlers.
# Here the dates are derived, so the only way to be wrong is to not run it.
#
# To run from a PowerShell prompt in this folder:
#     .\build-sitemap.ps1
# To verify the committed sitemap is current without rewriting it:
#     .\build-sitemap.ps1 -Check
# -Check exits 1 when sitemap.xml is stale, so it also works as a
# pre-commit hook or CI step.
#
# If PowerShell refuses with "running scripts is disabled on this system"
# the file was tagged with mark-of-the-web. One-time fix:
#     Unblock-File .\build-sitemap.ps1
# or run build-sitemap.bat, which passes -ExecutionPolicy Bypass.

[CmdletBinding()]
param(
    # Compare only: report whether sitemap.xml is current, write nothing.
    [switch]$Check,

    # Date staged pages as today rather than as their last commit, because
    # that is the date they will carry once the in-flight commit lands.
    # Without this a pre-commit check passes and the sitemap goes stale the
    # moment the commit completes. Also verifies sitemap.xml is itself
    # staged, since the commit takes it from the index, not the worktree.
    [switch]$PreCommit
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# Pages that exist but must never be advertised to crawlers. An error page
# in a sitemap is a direct contradiction: the sitemap says "index this",
# the page says "this isn't a page".
$excluded = @(
    '404.html'
)

# Preferred output order, roughly following site navigation. Anything not
# listed here is still included - appended after these, alphabetically -
# and called out in the summary, so a newly added page gets noticed rather
# than silently buried at the bottom of the file.
$preferredOrder = @(
    '/'
    '/products.html'
    '/products/lenshh-lt.html'
    '/products/lenshh-pro.html'
    '/download/lenshh-lt.html'
    '/buy/lenshh-lt.html'
    '/case-studies/'
    '/case-studies/gpu-merit-throughput.html'
    '/case-studies/spc-bk7-singlet.html'
    '/case-studies/vignetting-aperture-optimization.html'
    '/docs/lenshh-lt.html'
    '/docs/lenshh-lt-help.html'
    '/education.html'
    '/about.html'
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  git not found on PATH - cannot derive <lastmod> dates." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# The canonical host comes from CNAME so the sitemap can never disagree
# with what GitHub Pages actually serves. A sitemap listing a different
# host is treated as cross-domain and largely ignored.
$cnamePath = Join-Path $root 'CNAME'
if (Test-Path -LiteralPath $cnamePath) {
    $siteHost = (Get-Content -LiteralPath $cnamePath -Raw).Trim()
} else {
    $siteHost = 'synapseoptics.com'
    Write-Host "  No CNAME file; assuming $siteHost" -ForegroundColor Yellow
}
$baseUrl = "https://$siteHost"

$sep      = [IO.Path]::DirectorySeparatorChar
$rootFull = [IO.Path]::GetFullPath($root).TrimEnd($sep) + $sep

# Map a repo-relative file path to the URL crawlers should see. Directory
# index pages get the trailing-slash form (/case-studies/), which is how
# every internal link in the site already spells them - the sitemap has to
# agree with them, or it hands Google two URLs for one page.
function ConvertTo-PageUrl {
    param([string]$RelPath)

    if ($RelPath -eq 'index.html') { return '/' }
    if ($RelPath.EndsWith('/index.html')) {
        return '/' + $RelPath.Substring(0, $RelPath.Length - 'index.html'.Length)
    }
    return '/' + $RelPath
}

$untracked = @()
$dirty     = @()
$stagedNow = @()
$entries   = @()

# Pages the in-flight commit will add or modify. ACMR excludes deletions,
# which need no date because the file is already gone from disk and so is
# skipped by discovery below.
$staged = @()
if ($PreCommit) {
    $staged = @(& git -C $root diff --cached --name-only --diff-filter=ACMR 2>$null |
                Where-Object { $_ -like '*.html' })
}
$today = (Get-Date).ToString('yyyy-MM-dd')

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.html |
         Where-Object { $_.FullName -notlike "*$sep.git$sep*" }

foreach ($file in $files) {
    $rel = $file.FullName.Substring($rootFull.Length).Replace($sep, '/')

    if ($excluded -contains $rel) { continue }

    # Last commit that touched this file. Deliberately not --follow: a
    # rename changes the URL anyway, so the rename commit is the correct
    # date for the URL being emitted.
    $lastMod = & git -C $root log -1 --format=%ad --date=short -- $rel 2>$null |
               Select-Object -First 1

    if ($staged -contains $rel) {
        # Staged for the commit being made right now. git still reports the
        # previous commit's date, so use today - the date this page will
        # carry the moment the commit lands.
        $lastMod = $today
        $stagedNow += $rel
    } elseif ([string]::IsNullOrWhiteSpace($lastMod)) {
        # Never committed. Fall back to the file's own mtime so the sitemap
        # stays usable, but say so - that date is not reproducible yet.
        $lastMod = $file.LastWriteTime.ToString('yyyy-MM-dd')
        $untracked += $rel
    } elseif (& git -C $root status --porcelain -- $rel) {
        # Committed, but edited since. The git date is real yet already
        # behind the content, so flag it rather than quietly shipping it.
        $dirty += $rel
    }

    $entries += [pscustomobject]@{
        Url     = ConvertTo-PageUrl -RelPath $rel
        LastMod = $lastMod
    }
}

if ($entries.Count -eq 0) {
    Write-Host ""
    Write-Host "  No pages found under $root - refusing to write an empty sitemap." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Curated pages first, in listed order, then anything new, alphabetically.
$known   = @($entries | Where-Object { $preferredOrder -contains $_.Url } |
             Sort-Object { $preferredOrder.IndexOf($_.Url) })
$unknown = @($entries | Where-Object { $preferredOrder -notcontains $_.Url } |
             Sort-Object Url)
$ordered = $known + $unknown

# Entries in $preferredOrder whose page has since been deleted or renamed.
$liveUrls  = @($entries | ForEach-Object { $_.Url })
$staleList = @($preferredOrder | Where-Object { $liveUrls -notcontains $_ })

$sb = [Text.StringBuilder]::new()
[void]$sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>`n")
[void]$sb.Append("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">`n")
foreach ($entry in $ordered) {
    $loc = [Security.SecurityElement]::Escape($baseUrl + $entry.Url)
    [void]$sb.Append("  <url>`n")
    [void]$sb.Append("    <loc>$loc</loc>`n")
    [void]$sb.Append("    <lastmod>$($entry.LastMod)</lastmod>`n")
    [void]$sb.Append("  </url>`n")
}
[void]$sb.Append("</urlset>`n")
$xml = $sb.ToString()

$outPath = Join-Path $root 'sitemap.xml'

if (Test-Path -LiteralPath $outPath) {
    $existing = [IO.File]::ReadAllText($outPath)
} else {
    $existing = $null
}

Write-Host ""
Write-Host "  Synapse Optics - sitemap" -ForegroundColor Cyan
Write-Host "  $($ordered.Count) pages, host $baseUrl" -ForegroundColor White
Write-Host ""

foreach ($rel in $stagedNow) {
    Write-Host "  * $rel is staged - dated $today" -ForegroundColor DarkGray
}
foreach ($rel in $untracked) {
    Write-Host "  ! $rel is not committed - date taken from file mtime" -ForegroundColor Yellow
}
foreach ($rel in $dirty) {
    Write-Host "  ! $rel has uncommitted edits - date is its last commit" -ForegroundColor Yellow
}
foreach ($entry in $unknown) {
    Write-Host "  + $($entry.Url) is new - add it to the preferred order to place it" -ForegroundColor Yellow
}
foreach ($url in $staleList) {
    Write-Host "  - $url is in the preferred order but no longer exists" -ForegroundColor Yellow
}
if ($stagedNow.Count -or $untracked.Count -or $dirty.Count -or $unknown.Count -or $staleList.Count) {
    Write-Host ""
}

if ($Check) {
    if ($existing -ne $xml) {
        Write-Host "  sitemap.xml is STALE." -ForegroundColor Red
        if ($PreCommit) {
            Write-Host "  Fix:  .\build-sitemap.ps1 -PreCommit  &&  git add sitemap.xml" -ForegroundColor Yellow
        } else {
            Write-Host "  Fix:  .\build-sitemap.ps1" -ForegroundColor Yellow
        }
        Write-Host ""
        exit 1
    }

    # The commit takes sitemap.xml from the index, not the working tree, so
    # a correctly regenerated but unstaged file would still commit the old
    # bytes. Column 2 of --porcelain is the worktree-vs-index column: any
    # non-space there means what is staged is not what was just generated.
    if ($PreCommit) {
        $st = @(& git -C $root status --porcelain -- 'sitemap.xml') | Select-Object -First 1
        if ($st -and ($st.StartsWith('??') -or $st.Substring(1, 1) -ne ' ')) {
            Write-Host "  sitemap.xml is current on disk but not staged." -ForegroundColor Red
            Write-Host "  Fix:  git add sitemap.xml" -ForegroundColor Yellow
            Write-Host ""
            exit 1
        }
    }

    Write-Host "  sitemap.xml is up to date." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if ($existing -eq $xml) {
    Write-Host "  sitemap.xml already current - nothing written." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# UTF-8 without BOM, LF endings - matches the committed file and keeps
# diffs down to the lines that actually changed.
[IO.File]::WriteAllText($outPath, $xml, [Text.UTF8Encoding]::new($false))

Write-Host "  Wrote sitemap.xml" -ForegroundColor Green
Write-Host ""
