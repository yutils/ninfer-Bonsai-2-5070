#!/usr/bin/env bash
# Build CraneBW/ninfer-ternary-bonsai-ada on Windows/MSVC for RTX 5070 (sm_120a).
# Replicates vcvars64.bat manually because this agent session cannot invoke cmd.exe.
set -uo pipefail

MSVCROOT_W='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207'
SDKROOT_W='C:\Program Files (x86)\Windows Kits\10'
SDKVER='10.0.26100.0'
CMAKE_BIN='/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin'
NINJA_BIN='/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'
CUDA_W='C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3'
CUDA_BIN='/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.3/bin'

REPO_W='E:\ninfer-Bonsai\repo'
REPO='/e/ninfer-Bonsai/repo'
BUILD_W='E:\ninfer-Bonsai\build'
BUILD='/e/ninfer-Bonsai/build'

MSVCROOT='/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/14.44.35207'
SDKROOT='/c/Program Files (x86)/Windows Kits/10'

export PATH="$MSVCROOT/bin/Hostx64/x64:$SDKROOT/bin/$SDKVER/x64:$CMAKE_BIN:$NINJA_BIN:$CUDA_BIN:$PATH"
export INCLUDE="$MSVCROOT_W\\include;$SDKROOT_W\\Include\\$SDKVER\\ucrt;$SDKROOT_W\\Include\\$SDKVER\\um;$SDKROOT_W\\Include\\$SDKVER\\shared;$SDKROOT_W\\Include\\$SDKVER\\winrt;$SDKROOT_W\\Include\\$SDKVER\\cppwinrt"
export LIB="$MSVCROOT_W\\lib\\x64;$SDKROOT_W\\Lib\\$SDKVER\\ucrt\\x64;$SDKROOT_W\\Lib\\$SDKVER\\um\\x64"
export VSLANG=1033

echo "=== configure ==="
cmake.exe -S "$REPO_W" -B "$BUILD_W" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_ARCHITECTURES=120a \
  -DCMAKE_CUDA_COMPILER="$CUDA_W\\bin\\nvcc.exe" \
  -DNINFER_DISABLE_MEDIA=ON \
  2>&1 | tail -25
CFG=${PIPESTATUS[0]}
echo "CONFIGURE_RC=$CFG"
[ "$CFG" -ne 0 ] && exit 1

echo "=== build ==="
cmake.exe --build "$BUILD_W" --config Release 2>&1 | tail -40
BUILD_RC=${PIPESTATUS[0]}
echo "BUILD_RC=$BUILD_RC"
exit $BUILD_RC
