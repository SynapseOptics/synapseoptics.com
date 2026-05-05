@echo off
REM ============================================================
REM  Local preview server for the Synapse Optics website.
REM
REM  The site uses absolute paths like /css/style.css that only
REM  resolve over HTTP. Double-clicking index.html opens a
REM  file:// URL where /css/style.css points at the filesystem
REM  root and 404s, so the site looks broken.
REM
REM  This launcher starts a tiny static-file server on port 8765
REM  (via PowerShell + .NET HttpListener — no Node.js install
REM  needed, just built-in Windows PowerShell) and auto-opens
REM  the browser at http://localhost:8765.
REM
REM  Usage: double-click this file. The console window stays
REM  open serving the site; close it (or press Ctrl+C) to stop.
REM ============================================================

REM Switch console to UTF-8 so em dashes and accents render.
chcp 65001 >nul

setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"

echo.
echo Server stopped. Press any key to close.
pause >nul

endlocal
