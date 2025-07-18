#!/bin/bash -e

################################################################################
#   Copyright 2021-2025 217heidai<217heidai@gmail.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
################################################################################

################################################################################
#   Build OpenSSL for Android armeabi-v7a, arm64-v8a, x86, x86_64, riscv64
#   Supports Linux and macOS
################################################################################

WORK_PATH=$(cd "$(dirname "$0")"; pwd)

ANDROID_TARGET_API=$1
ANDROID_TARGET_ABI=$2
OPENSSL_VERSION=$3
ANDROID_NDK_VERSION=$4
ANDROID_NDK_PATH=${WORK_PATH}/android-ndk-${ANDROID_NDK_VERSION}
OPENSSL_PATH=${WORK_PATH}/openssl-${OPENSSL_VERSION}
OUTPUT_PATH=${WORK_PATH}/openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}
OPENSSL_OPTIONS="no-apps no-asm no-docs no-engine no-gost no-legacy no-tests no-zlib"

# Input validation
if [ -z "$ANDROID_TARGET_API" ] || [ -z "$ANDROID_TARGET_ABI" ] || [ -z "$OPENSSL_VERSION" ] || [ -z "$ANDROID_NDK_VERSION" ]; then
    echo "Error: Missing required parameters."
    echo "Usage: $0 <ANDROID_TARGET_API> <ANDROID_TARGET_ABI> <OPENSSL_VERSION> <ANDROID_NDK_VERSION>"
    exit 1
fi

# Check NDK and OpenSSL paths
if [ ! -d "${ANDROID_NDK_PATH}" ]; then
    echo "Error: Android NDK not found at ${ANDROID_NDK_PATH}"
    exit 1
fi
if [ ! -d "${OPENSSL_PATH}" ]; then
    echo "Error: OpenSSL source not found at ${OPENSSL_PATH}"
    exit 1
fi

# Platform detection
if [ "$(uname -s)" == "Darwin" ]; then
    echo "Build on macOS..."
    PLATFORM="darwin"
    nproc() { sysctl -n hw.logicalcpu; }
else
    echo "Build on Linux..."
    PLATFORM="linux"
    if ! command -v nproc >/dev/null 2>&1; then
        nproc() { echo 4; } # Fallback to 4 cores
    fi
fi

function build() {
    mkdir -p ${OUTPUT_PATH}
    cd ${OPENSSL_PATH}

    export ANDROID_NDK_ROOT=${ANDROID_NDK_PATH}
    export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH
    export CXXFLAGS="-fPIC -Os"
    export CPPFLAGS="-DANDROID -fPIC -Os"

    # Clean previous build
    make clean || true

    if [ "${ANDROID_TARGET_ABI}" == "armeabi-v7a" ]; then
        if ! ./Configure android-arm -D__ANDROID_API__=${ANDROID_TARGET_API} -shared ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}; then
            echo "Error: OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
            exit 1
        fi
    elif [ "${ANDROID_TARGET_ABI}" == "arm64-v8a" ]; then
        if ! ./Configure android-arm64 -D__ANDROID_API__=${ANDROID_TARGET_API} -shared ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}; then
            echo "Error: OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
            exit 1
        fi
    elif [ "${ANDROID_TARGET_ABI}" == "x86" ]; then
        if ! ./Configure android-x86 -D__ANDROID_API__=${ANDROID_TARGET_API} -shared ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}; then
            echo "Error: OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
            exit 1
        fi
    elif [ "${ANDROID_TARGET_ABI}" == "x86_64" ]; then
        if ! ./Configure android-x86_64 -D__ANDROID_API__=${ANDROID_TARGET_API} -shared ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}; then
            echo "Error: OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
            exit 1
        fi
    elif [ "${ANDROID_TARGET_ABI}" == "riscv64" ]; then
        if ! ./Configure android-riscv64 -D__ANDROID_API__=${ANDROID_TARGET_API} -shared ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}; then
            echo "Error: OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
            exit 1
        fi
    else
        echo "Unsupported target ABI: ${ANDROID_TARGET_ABI}"
        exit 1
    fi

    if ! make -j$(nproc); then
        echo "Error: OpenSSL build failed for ${ANDROID_TARGET_ABI}"
        exit 1
    fi
    if ! make install; then
        echo "Error: OpenSSL installation failed for ${ANDROID_TARGET_ABI}"
        exit 1
    fi

    echo "Build completed! Check output libraries in ${OUTPUT_PATH}/lib"
}

function clean() {
    if [ -d ${OUTPUT_PATH} ]; then
        rm -rf ${OUTPUT_PATH}/bin
        rm -rf ${OUTPUT_PATH}/share
        rm -rf ${OUTPUT_PATH}/ssl
        rm -rf ${OUTPUT_PATH}/lib/cmake
        rm -rf ${OUTPUT_PATH}/lib/engines-3
        rm -rf ${OUTPUT_PATH}/lib/ossl-modules
        rm -rf ${OUTPUT_PATH}/lib/pkgconfig
    fi
}

build
clean
