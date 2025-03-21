#!/bin/bash
set -e
    # Build using Xcode
    xcodebuild -project ferrous.xcodeproj -scheme ferrous -configuration Release -derivedDataPath ./DerivedData
    
    # Copy the app to the build directory
    mkdir -p build
    cp -R ./DerivedData/Build/Products/Release/ferrous.app ./build/

echo "Build completed successfully"