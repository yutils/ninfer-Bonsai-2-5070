@echo off
setlocal
chcp 936 >nul 2>&1
rem ============================================================
rem  rebuild NInfer (RTX 5070 / sm_120a, no FFmpeg)
rem  only needed after changing C++ sources
rem  requires: VS2022 BuildTools + CUDA 13.3 + Ninja
rem ============================================================
cd /d "%~dp0"

set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set "CMAKE=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "NINJA=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"

if not exist "%VCVARS%" ( echo [ERROR] vcvars64.bat not found & pause & exit /b 1 )
if not exist "%CMAKE%"  ( echo [ERROR] cmake.exe not found   & pause & exit /b 1 )

call "%VCVARS%"
set "PATH=%NINJA%;%PATH%"

echo === configure ===
"%CMAKE%" -S "%~dp0repo" -B "%~dp0build" -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_CUDA_ARCHITECTURES=120a ^
  -DNINFER_DISABLE_MEDIA=ON
if errorlevel 1 ( echo CONFIGURE FAILED & pause & exit /b 1 )

echo === build ===
"%CMAKE%" --build "%~dp0build" --config Release
if errorlevel 1 ( echo BUILD FAILED & pause & exit /b 1 )

echo.
echo BUILD OK  -^>  build\apps\ninfer-serve.exe
pause
