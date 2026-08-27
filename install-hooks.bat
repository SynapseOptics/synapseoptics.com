@echo off
REM ============================================================
REM  Enables this repository's git hooks. Run once per clone.
REM
REM  Git never enables hooks automatically on clone, and it does
REM  not version .git/hooks. Rather than copy files into that
REM  folder — where they immediately start drifting from the
REM  versioned original — this points git at the tracked hooks/
REM  directory, so the committed hook IS the hook that runs.
REM
REM  It wraps a single command, which you can also just run:
REM      git config core.hooksPath hooks
REM
REM  To undo:  git config --unset core.hooksPath
REM  To skip the hook for one commit:  git commit --no-verify
REM ============================================================

chcp 65001 >nul

setlocal
cd /d "%~dp0"

git config core.hooksPath hooks
if errorlevel 1 (
    echo.
    echo   Failed - is this a git repository, and is git on PATH?
    echo.
    pause >nul
    exit /b 1
)

echo.
echo   Hooks enabled: core.hooksPath = hooks
echo   pre-commit will now check sitemap.xml is current.
echo.
echo Press any key to close.
pause >nul

endlocal
