@echo off
REM ============================================================
REM  Local preview server for the Synapse Optics website.
REM
REM  The site uses absolute paths like /css/style.css. Those only
REM  resolve when the pages are served over HTTP. Double-clicking
REM  index.html opens a file:// URL where /css/style.css points
REM  at the filesystem root and 404s.
REM
REM  Usage: double-click this file. A console window stays open
REM  serving the site at http://localhost:8765. Open the URL in
REM  any browser. Close the console window to stop the server.
REM ============================================================

REM Switch console to UTF-8 so em dashes and accents render.
chcp 65001 >nul

setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js is not on PATH.
  echo Install it from https://nodejs.org and re-run this file.
  echo.
  pause
  exit /b 1
)

node serve.js
echo.
echo Server stopped. Press any key to close.
pause >nul

endlocal
