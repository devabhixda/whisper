#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check for ANDROID_NDK_HOME
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME is not set. Please set it to your Android NDK location."
    exit 1
fi

# Determine number of cores for parallel build
if [[ "$(uname)" == "Darwin" ]]; then
    NUM_CORES=$(sysctl -n hw.ncpu)
else
    NUM_CORES=$(nproc)
fi

# Project root is the directory where the script is located
PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/build/android"
OUTPUT_DIR="$PROJECT_ROOT/output/android"

# Architectures to build
declare -a ANDROID_ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

for ABI in "${ANDROID_ABIS[@]}"; do
    echo "Building for ABI: $ABI"
    
    ABI_BUILD_DIR="$BUILD_DIR/$ABI"
    ABI_OUTPUT_DIR="$OUTPUT_DIR/$ABI"
    
    # Clean previous build files for a fresh start
    rm -rf "$ABI_BUILD_DIR"
    mkdir -p "$ABI_BUILD_DIR"
    
    # --- Build Shared Library (.so) ---
    echo "Building shared library for $ABI..."
    cmake -S "$PROJECT_ROOT" -B "$ABI_BUILD_DIR/shared" \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$ABI \
        -DANDROID_NATIVE_API_LEVEL=21 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384" \
        -DCMAKE_INSTALL_PREFIX="$ABI_OUTPUT_DIR"
    
    cmake --build "$ABI_BUILD_DIR/shared" --target install -j$NUM_CORES

    # --- Build Static Library (.a) ---
    echo "Building static library for $ABI..."
    cmake -S "$PROJECT_ROOT" -B "$ABI_BUILD_DIR/static" \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$ABI \
        -DANDROID_NATIVE_API_LEVEL=21 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_INSTALL_PREFIX="$ABI_OUTPUT_DIR"

    cmake --build "$ABI_BUILD_DIR/static" --target install -j$NUM_CORES

done

echo "Android build complete. Artifacts are in $OUTPUT_DIR"