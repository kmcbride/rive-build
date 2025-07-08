#!/bin/bash

# Verify version argument
if [[ ! $1 =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*) ]]; then
  echo "Missing version argument, eg: $0 6.9.0"
  exit 1
fi

# Move to repo
cd rive-ios

# Ensure submodules are checked out
git submodule update --init --recursive

# Checkout desired release
git reset --hard $1
git submodule foreach --recursive git reset --hard

# Reset any local changes
git clean -f -d -x
git submodule foreach --recursive git clean -f -d -x

# Patch missing code
git apply ../rive-ios-$1.patch

# Create premake dir to prevent build script from unnecessarily rebuilding it from source
mkdir -p ./submodules/rive-runtime/build/dependencies/premake-core

# Patch scripts to remove unwanted features
sed -i .bak 's/--with_rive_audio=system/--with_rive_audio=disabled/' ./scripts/build.rive.sh
sed -i .bak 's/RIVE_PREMAKE_ARGS="--with_rive_text --with_rive_layout"/RIVE_PREMAKE_ARGS="--with_rive_layout"/' ./submodules/rive-runtime/build/build_rive.sh

# Define PATH that includes runtime build scripts
PATH_INCL_RUNTIME_SCRIPTS="$PATH:./submodules/rive-runtime/build"

# Build iOS framework
PATH=$PATH_INCL_RUNTIME_SCRIPTS ./scripts/build.sh ios release
xcodebuild archive \
  -configuration Release \
  -project RiveRuntime.xcodeproj \
  -scheme RiveRuntime \
  -destination generic/platform=iOS \
  -archivePath ".build/archives/RiveRuntime_iOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  GCC_PREPROCESSOR_DEFINITIONS="WITH_RIVE_AUDIO=0 WITH_RIVE_TEXT=0"

# Build iOS simulator framework
PATH=$PATH_INCL_RUNTIME_SCRIPTS ./scripts/build.sh ios_sim release
xcodebuild archive \
  -configuration Release \
  -project RiveRuntime.xcodeproj \
  -scheme RiveRuntime \
  -destination "generic/platform=iOS Simulator" \
  -archivePath ".build/archives/RiveRuntime_iOS_Simulator" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  GCC_PREPROCESSOR_DEFINITIONS="WITH_RIVE_AUDIO=0 WITH_RIVE_TEXT=0"

# Package frameworks
xcodebuild \
  -create-xcframework \
  -archive .build/archives/RiveRuntime_iOS.xcarchive \
  -framework RiveRuntime.framework \
  -archive .build/archives/RiveRuntime_iOS_Simulator.xcarchive \
  -framework RiveRuntime.framework \
  -output archive/RiveRuntime.xcframework

# Archive package
cd archive
zip --symlinks -r RiveRuntime.xcframework.zip RiveRuntime.xcframework
