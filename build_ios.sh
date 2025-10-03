#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/build/ios"
OUTPUT_DIR="$PROJECT_ROOT/output/ios"
XCFRAMEWORK_PATH="$OUTPUT_DIR/whisper.xcframework"

# Clean up previous builds
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR" # Clean the whole output dir for a fresh run
mkdir -p "$OUTPUT_DIR"

# --- Build and Install for iOS (arm64) ---
echo "Building and installing for iOS (arm64)"
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_BUILD_DIR="$BUILD_DIR/ios-arm64"
IOS_INSTALL_DIR="$OUTPUT_DIR/ios-arm64"

cmake -S "$PROJECT_ROOT" -B "$IOS_BUILD_DIR" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_XCODE_ATTRIBUTE_SDKROOT="$IOS_SDK_PATH" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="$IOS_INSTALL_DIR"

cmake --build "$IOS_BUILD_DIR" --target install --config Release

# --- Build and Install for iOS Simulator (x86_64) ---
echo "Building and installing for iOS Simulator (x86_64)"
SIM_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIM_BUILD_DIR="$BUILD_DIR/ios-x86_64"
SIM_INSTALL_DIR="$OUTPUT_DIR/ios-x86_64"

cmake -S "$PROJECT_ROOT" -B "$SIM_BUILD_DIR" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_XCODE_ATTRIBUTE_SDKROOT="$SIM_SDK_PATH" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="$SIM_INSTALL_DIR"

cmake --build "$SIM_BUILD_DIR" --target install --config Release

# --- Create XCFramework ---
echo "Creating whisper.xcframework"

# The headers are installed by cmake, so we point xcodebuild to the installed location
HEADERS_PATH="$IOS_INSTALL_DIR/include"

xcodebuild -create-xcframework \
    -library "$IOS_INSTALL_DIR/lib/libwhisper.a" \
    -headers "$HEADERS_PATH" \
    -library "$SIM_INSTALL_DIR/lib/libwhisper.a" \
    -headers "$HEADERS_PATH" \
    -output "$XCFRAMEWORK_PATH"

echo "iOS build complete."
echo "XCFramework is at $XCFRAMEWORK_PATH"
echo "Static libraries and headers are in $IOS_INSTALL_DIR and $SIM_INSTALL_DIR"
