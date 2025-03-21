#!/bin/bash
set -e

# Get VERSION from environment variable or use v0.0.0 as fallback
VERSION=${VERSION:-"v0.0.0"}
# Strip 'v' prefix if present for CFBundleShortVersionString
APP_VERSION=${VERSION#v}

echo "Building ferrous app version: $APP_VERSION (from $VERSION)"

# Calculate build number - using timestamp for simplicity
BUILD_NUMBER=$(date +%Y%m%d%H%M)

# Update Info.plist with version information
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" ferrous/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" ferrous/Info.plist

echo "Updated Info.plist with version $APP_VERSION and build $BUILD_NUMBER"

# Build using Xcode with explicit version parameters to override APPLICATION_VERSION
echo "Building app using Xcode..."
xcodebuild -project ferrous.xcodeproj -scheme ferrous -configuration Release \
  MARKETING_VERSION="$APP_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -derivedDataPath ./DerivedData

# Copy the app to the build directory
echo "Copying app to build directory..."
mkdir -p build
cp -R ./DerivedData/Build/Products/Release/ferrous.app ./build/

# Verify version was set correctly in the final app
FINAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/ferrous.app/Contents/Info.plist)
echo "Build completed successfully with version $FINAL_VERSION"