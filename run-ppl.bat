@echo off
setlocal
chcp 936 >nul 2>&1
rem ============================================================
rem  correctness check: perplexity
rem  verdict: single digit ~ low teens = OK ; hundreds = broken
rem ============================================================
cd /d "%~dp0"

if not exist "build\apps\ninfer-perplexity.exe" (
  echo [ERROR] ninfer-perplexity.exe not found, run build.bat first
  pause & exit /b 1
)

build\apps\ninfer-perplexity.exe artifacts\ternary-bonsai2-27b.ninfer ^
  --text eval\ppl_sample.txt --context 512 --stride 256 --kv-dtype fp8

echo.
pause
