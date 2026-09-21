@echo off
setlocal
chcp 936 >nul 2>&1
cd /d "%~dp0"

rem ============================================================
rem  NInfer 控制台聊天客户端
rem  依赖: 先双击 start-server.bat 把服务跑起来
rem ============================================================
set "PORT=8080"
set "MODEL=bonsai2-27b"

rem 优先用 WorkBuddy 自带的 Python，没有就退回系统 python
set "PY=C:\Users\yujing\.workbuddy\binaries\python\versions\3.13.12\python.exe"
if not exist "%PY%" set "PY=python"

if not exist "chat.py" (
  echo [ERROR] chat.py not found in %~dp0
  pause & exit /b 1
)

echo connecting to http://127.0.0.1:%PORT% ...
"%PY%" chat.py --base http://127.0.0.1:%PORT% --model %MODEL%
if errorlevel 1 (
  echo.
  echo [ERROR] failed. start-server.bat first, then run this again.
)
pause
