#!/bin/bash -e

################################################################################
#   Build OpenSSL for Android: armeabi-v7a, arm64-v8a, x86, x86_64, riscv64
#   Supports Linux and macOS for CI/CD (like GitHub Actions)
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

if [ "$(uname -s)" == "Darwin" ]; then
    echo "🧠 Building on macOS..."
    PLATFORM="darwin"
    NPROC=$(sysctl -n hw.logicalcpu)
else
    echo "🐧 Building on Linux..."
    PLATFORM="linux"
    NPROC=$(nproc)
fi

function build() {
    mkdir -p ${OUTPUT_PATH}
    cd ${OPENSSL_PATH}

    export ANDROID_NDK_ROOT=${ANDROID_NDK_PATH}
    export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH
    export CXXFLAGS="-fPIC -Os"
    export CPPFLAGS="-DANDROID -fPIC -Os"

    case "${ANDROID_TARGET_ABI}" in
        armeabi-v7a)
            TARGET="android-arm"
            ;;
        arm64-v8a)
            TARGET="android-arm64"
            ;;
        x86)
            TARGET="android-x86"
            ;;
        x86_64)
            TARGET="android-x86_64"
            ;;
        riscv64)
            TARGET="android-riscv64"
            ;;
        *)
            echo "❌ Unsupported ABI: ${ANDROID_TARGET_ABI}"
            exit 1
            ;;
    esac

    ./Configure ${TARGET} -D__ANDROID_API__=${ANDROID_TARGET_API} ${OPENSSL_OPTIONS} --prefix=${OUTPUT_PATH}

    make clean
    make -j${NPROC}
    make install_sw

    echo "✅ Build completed. Output: ${OUTPUT_PATH}/lib"
}

function clean() {
    if [ -d ${OUTPUT_PATH} ]; then
        echo "🧹 Cleaning up unused folders..."
        rm -rf ${OUTPUT_PATH}/bin \
               ${OUTPUT_PATH}/share \
               ${OUTPUT_PATH}/ssl \
               ${OUTPUT_PATH}/lib/cmake \
               ${OUTPUT_PATH}/lib/engines-3 \
               ${OUTPUT_PATH}/lib/ossl-modules \
               ${OUTPUT_PATH}/lib/pkgconfig
    fi
}

build
clean
