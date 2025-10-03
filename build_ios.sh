#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-Release}
BUILD_STATIC=${BUILD_STATIC:-true}
BUILD_XCFRAMEWORK=${BUILD_XCFRAMEWORK:-true}

if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found, please install it"
    exit 1
fi

if ! xcode-select -p &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Install with: xcode-select --install"
    exit 1
fi

n_cpu=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "Building Whisper for iOS..."
echo "Build type: $CMAKE_BUILD_TYPE"
echo "Using $n_cpu CPU cores"
echo "Static library: $BUILD_STATIC"
echo "XCFramework: $BUILD_XCFRAMEWORK"

function cp_headers() {
    local dest_dir="$1"
    mkdir -p "$dest_dir"
    cp "$ROOT_DIR/src/whisper.cpp/"*.h "$dest_dir/" 2>/dev/null || true
    echo "Headers copied to $dest_dir"
}

function create_ios_xcframework_info_plist() {
    cat > "$ROOT_DIR/output/ios/whisper.xcframework/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64</string>
			<key>LibraryPath</key>
			<string>whisper.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64-simulator</string>
			<key>LibraryPath</key>
			<string>whisper.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
			<key>SupportedPlatformVariant</key>
			<string>simulator</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
EOF
}

function build_static_library() {
    echo "Building static library for iOS device..."
    BUILD_DIR="$ROOT_DIR/build/static-device"
    
    IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
    if [ -z "$IOS_SDK_PATH" ] || [ ! -d "$IOS_SDK_PATH" ]; then
        echo "Error: iOS SDK not found. Make sure Xcode is installed."
        exit 1
    fi

    echo "Using iOS SDK: $IOS_SDK_PATH"

    cmake -DCMAKE_SYSTEM_NAME=iOS \
          -DCMAKE_OSX_ARCHITECTURES=arm64 \
          -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
          -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
          -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
          -DBUILD_SHARED_LIBS=OFF \
          -S "$ROOT_DIR" \
          -B "$BUILD_DIR"

    cmake --build "$BUILD_DIR" --config "$CMAKE_BUILD_TYPE" -j "$n_cpu"

    mkdir -p "$ROOT_DIR/output/ios"
    cp "$BUILD_DIR/libwhisper.a" "$ROOT_DIR/output/ios/libwhisper-device.a" || \
       { echo "Error: Could not find device libwhisper.a"; exit 1; }

    echo "Device static library built: $ROOT_DIR/output/ios/libwhisper-device.a"
    
    echo "Building static library for iOS simulator..."
    BUILD_DIR_SIM="$ROOT_DIR/build/static-simulator"
    
    IOS_SIM_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
    if [ -z "$IOS_SIM_SDK_PATH" ] || [ ! -d "$IOS_SIM_SDK_PATH" ]; then
        echo "Error: iOS Simulator SDK not found. Make sure Xcode is installed."
        exit 1
    fi

    echo "Using iOS Simulator SDK: $IOS_SIM_SDK_PATH"

    # Build for arm64 simulator (Apple Silicon Macs)
    cmake -DCMAKE_SYSTEM_NAME=iOS \
          -DCMAKE_OSX_ARCHITECTURES=arm64 \
          -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
          -DCMAKE_OSX_SYSROOT="$IOS_SIM_SDK_PATH" \
          -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
          -DBUILD_SHARED_LIBS=OFF \
          -S "$ROOT_DIR" \
          -B "$BUILD_DIR_SIM"

    cmake --build "$BUILD_DIR_SIM" --config "$CMAKE_BUILD_TYPE" -j "$n_cpu"

    cp "$BUILD_DIR_SIM/libwhisper.a" "$ROOT_DIR/output/ios/libwhisper-simulator.a" || \
       { echo "Error: Could not find simulator libwhisper.a"; exit 1; }

    echo "Simulator static library built: $ROOT_DIR/output/ios/libwhisper-simulator.a"
}

function build_framework() {
    local system_name="$1"
    local architecture="$2"
    local sdk="$3"
    local identifier="$4"
    local build_dir="$5"
    
    echo "Building framework for $identifier..."
    
    SDK_PATH=$(xcrun --sdk "$sdk" --show-sdk-path)
    if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
        echo "Error: $sdk SDK not found. Make sure Xcode is installed."
        exit 1
    fi

    echo "Using SDK: $SDK_PATH"
    
    # Build dynamic library for framework
    cmake -DCMAKE_SYSTEM_NAME="$system_name" \
          -DCMAKE_OSX_ARCHITECTURES="$architecture" \
          -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
          -DCMAKE_OSX_SYSROOT="$SDK_PATH" \
          -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
          -DBUILD_SHARED_LIBS=ON \
          -S "$ROOT_DIR" \
          -B "$build_dir"

    cmake --build "$build_dir" --config "$CMAKE_BUILD_TYPE" -j "$n_cpu"

    # Create framework structure manually
    DEST_DIR="$ROOT_DIR/output/ios/whisper.xcframework/$identifier"
    FRAMEWORK_DEST="$DEST_DIR/whisper.framework"

    rm -rf "$DEST_DIR"
    mkdir -p "$FRAMEWORK_DEST"
    
    # Copy the dynamic library as the framework binary
    cp "$build_dir/libwhisper.dylib" "$FRAMEWORK_DEST/whisper"
    
    echo "Framework binary copied to $FRAMEWORK_DEST/whisper"
    
    # Copy headers
    cp_headers "$FRAMEWORK_DEST/Headers"
    
    # Create Info.plist for the framework
    cat > "$FRAMEWORK_DEST/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>whisper</string>
    <key>CFBundleIdentifier</key>
    <string>com.whisper.framework</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>whisper</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF
}

function build_ios_xcframework() {
    echo "Building iOS XCFramework..."
    
    rm -rf "$ROOT_DIR/output/ios/whisper.xcframework"
    rm -rf "$ROOT_DIR/build/ios" "$ROOT_DIR/build/ios-simulator"
    
    mkdir -p "$ROOT_DIR/build/ios" "$ROOT_DIR/build/ios-simulator"

    build_framework "iOS" "arm64" "iphoneos" "ios-arm64" "$ROOT_DIR/build/ios"
    build_framework "iOS" "arm64" "iphonesimulator" "ios-arm64-simulator" "$ROOT_DIR/build/ios-simulator"

    create_ios_xcframework_info_plist

    rm -rf "$ROOT_DIR/build/ios" "$ROOT_DIR/build/ios-simulator"
    
    echo "iOS XCFramework built: $ROOT_DIR/output/ios/whisper.xcframework"
}

t0=$(date +%s)

# Clean up previous builds
rm -rf "$ROOT_DIR/build"
rm -rf "$ROOT_DIR/output/ios"
mkdir -p "$ROOT_DIR/output/ios"

if [ "$BUILD_STATIC" = "true" ]; then
    build_static_library
fi

if [ "$BUILD_XCFRAMEWORK" = "true" ]; then
    build_ios_xcframework
fi

t1=$(date +%s)
echo ""
echo "Build complete!"
echo "Total time: $((t1 - t0)) seconds"

if [ "$BUILD_STATIC" = "true" ]; then
    rm -rf "$ROOT_DIR/build/static-device" "$ROOT_DIR/build/static-simulator"
    echo "Static libraries:"
    echo "  Device: $ROOT_DIR/output/ios/libwhisper-device.a"
    echo "  Simulator: $ROOT_DIR/output/ios/libwhisper-simulator.a"
fi

if [ "$BUILD_XCFRAMEWORK" = "true" ]; then
    echo "XCFramework:"
    echo "  iOS: $ROOT_DIR/output/ios/whisper.xcframework"
fi
