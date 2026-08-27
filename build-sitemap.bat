@echo off
REM ============================================================
REM  Regenerates sitemap.xml for the Synapse Optics website.
REM
REM  Every page's <lastmod> is read from git — the date of the
REM  last commit that touched that file — so the sitemap cannot
REM  drift out of step with the site the way a hand-edited one
REM  does. Pages are discovered from disk, so adding a new .html
REM  file is enough to get it listed.
REM
REM  Usage: double-click this file, then commit sitemap.xml if
REM  it changed. Run it after committing page edits, not before:
REM  the dates come from commits, and the script warns about any
REM  page with uncommitted changes.
REM
REM  To check without rewriting (exits 1 if stale), run from a
REM  prompt: build-sitemap.bat -Check
REM ============================================================

REM Switch console to UTF-8 so em dashes and accents render.
chcp 65001 >nul

setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-sitemap.ps1" %*

echo.
echo Press any key to close.
pause >nul

endlocal
