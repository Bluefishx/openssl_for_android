#!/bin/bash -e

################################################################################
#   Build OpenSSL for Android: armeabi-v7a, arm64-v8a, x86, x86_64
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
    mkdir -p "${OUTPUT_PATH}"
    cd "${OPENSSL_PATH}"

    export ANDROID_NDK_ROOT="${ANDROID_NDK_PATH}"
    export PATH="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH"
    export CXXFLAGS="-fPIC -Os"
    export CPPFLAGS="-DANDROID -fPIC -Os"

    # 🔑 Apply 16KB alignment ONLY for arm64-v8a
    if [ "${ANDROID_TARGET_ABI}" == "arm64-v8a" ]; then
        export LDFLAGS="-Wl,-z,max-page-size=16384"
        echo "Applying 16KB alignment flags for arm64-v8a..."
    else
        unset LDFLAGS
    fi

    # Clean previous build
    make clean || true

    # ABI → Configure target mapping
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
        *)
            echo "❌ Unsupported target ABI: ${ANDROID_TARGET_ABI}"
            exit 1
            ;;
    esac

    echo "⚙️ Configuring OpenSSL for ${ANDROID_TARGET_ABI}..."
    if ! ./Configure "${TARGET}" -D__ANDROID_API__="${ANDROID_TARGET_API}" -shared \
        ${OPENSSL_OPTIONS} --prefix="${OUTPUT_PATH}" \
        ${LDFLAGS:+LDFLAGS="$LDFLAGS"}; then
        echo "❌ OpenSSL configuration failed for ${ANDROID_TARGET_ABI}"
        exit 1
    fi

    echo "🔨 Building OpenSSL for ${ANDROID_TARGET_ABI}..."
    if ! make -j"$(nproc)"; then
        echo "❌ OpenSSL build failed for ${ANDROID_TARGET_ABI}"
        exit 1
    fi
    if ! make install_sw; then
        echo "❌ OpenSSL installation failed for ${ANDROID_TARGET_ABI}"
        exit 1
    fi

    echo "✅ Build completed for ${ANDROID_TARGET_ABI}! Output in ${OUTPUT_PATH}/lib"

    # Alignment verification for arm64-v8a
    if [ "${ANDROID_TARGET_ABI}" == "arm64-v8a" ]; then
        echo "🔎 Verifying 16KB alignment..."
        for so in "${OUTPUT_PATH}"/lib/*.so; do
            if readelf -l "$so" | awk '/LOAD/{print $0}' | grep -q '0x4000'; then
                echo "✅ $so aligned to 16KB"
            else
                echo "❌ $so alignment NOT 16KB"
                exit 1
            fi
        done
    fi
}

function clean() {
    if [ -d "${OUTPUT_PATH}" ]; then
        rm -rf "${OUTPUT_PATH}/bin"
        rm -rf "${OUTPUT_PATH}/share"
        rm -rf "${OUTPUT_PATH}/ssl"
        rm -rf "${OUTPUT_PATH}/lib/cmake"
        rm -rf "${OUTPUT_PATH}/lib/engines-3"
        rm -rf "${OUTPUT_PATH}/lib/ossl-modules"
        rm -rf "${OUTPUT_PATH}/lib/pkgconfig"
    fi
}

build
clean
