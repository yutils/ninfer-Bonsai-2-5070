@echo off
setlocal
chcp 936 >nul 2>&1
rem ============================================================
rem  NInfer - Ternary Bonsai 2 27B  (RTX 5070 / sm_120a)
rem  repo: CraneBW/ninfer-ternary-bonsai-ada
rem
rem  knobs (edit then double-click):
rem    CTX      上下文上限 token。32K 稳；64K 可；96K 装不下
rem    MODELID  对外模型名，客户端的 model 必须和它一致
rem    KVTYPE   KV 缓存: bf16 | fp8 | int8 | nvfp4 | k8v4
rem    PORT     监听端口
rem    DRAFT    MTP 投机解码草稿 token 数 (0 = 关闭)
rem ============================================================
set "CTX=50000"
set "MODELID=bonsai2-27b"
set "KVTYPE=fp8"
set "PORT=8080"
set "DRAFT=3"

cd /d "%~dp0"

set "ARTIFACT=artifacts\ternary-bonsai2-27b.ninfer"
set "EXE=build\apps\ninfer-serve.exe"

if not exist "%ARTIFACT%" (
  echo [ERROR] artifact not found: %ARTIFACT%
  pause & exit /b 1
)
if not exist "%EXE%" (
  echo [ERROR] ninfer-serve.exe not found, run build.bat first
  pause & exit /b 1
)

echo loading model, first run takes 10-20s ...
echo endpoint: http://127.0.0.1:%PORT%/v1/models   (OpenAI compatible)
echo press Ctrl+C in this window to stop
echo.

"%EXE%" %ARTIFACT% ^
  --host 127.0.0.1 --port %PORT% ^
  --model-id %MODELID% ^
  --max-context %CTX% --kv-capacity auto --kv-dtype %KVTYPE% ^
  --max-concurrency 2 ^
  --spec mtp --draft-tokens %DRAFT% ^
  --cors

echo.
echo server exited.
pause
