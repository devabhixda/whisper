# Clean Whisper Build

This directory contains the extracted C++ source for `whisper.cpp` and scripts to build it for Android and iOS.

## Directory Structure

- `src/`: Contains the C++ source code for whisper.
- `output/`: The destination for the compiled libraries.
  - `android/`: Contains `.a` and `.so` files for different Android ABIs.
  - `ios/`: Contains the `whisper.xcframework` for iOS.
- `build/`: Temporary directory for build artifacts.
- `CMakeLists.txt`: The main CMake build configuration.
- `build_android.sh`: Script to build the Android libraries.
- `build_ios.sh`: Script to build the iOS XCFramework.

## Prerequisites

### For Android

- The Android NDK must be installed.
- The `ANDROID_NDK_HOME` environment variable must be set to the path of your NDK installation.

### For iOS

- Xcode and its Command Line Tools must be installed.

## How to Build

1. **Navigate to this directory:**
   ```bash
   cd whisper
   ```

2. **Make the scripts executable:**
   ```bash
   chmod +x build_android.sh
   chmod +x build_ios.sh
   ```

3. **Run the desired build script:**

   - **For Android:**
     ```bash
     ./build_android.sh
     ```

   - **For iOS:**
     ```bash
     ./build_ios.sh
     ```

## Outputs

The compiled libraries will be placed in the `output` directory. You can then take these artifacts and integrate them directly into your mobile applications.
