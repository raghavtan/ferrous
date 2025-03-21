#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <app-path> <pkg-output-path>"
    exit 1
fi

APP_PATH=$1
PKG_PATH=$2
TMP_DIR=$(mktemp -d)
APP_NAME=$(basename "$APP_PATH" .app)
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")

# Create a component package
pkgbuild --component "$APP_PATH" \
         --install-location /Applications \
         --version "$VERSION" \
         "$TMP_DIR/$APP_NAME.pkg"

# Create a distribution package
productbuild --package "$TMP_DIR/$APP_NAME.pkg" \
             --version "$VERSION" \
             "$PKG_PATH"

# Clean up
rm -rf "$TMP_DIR"

echo "PKG created at $PKG_PATH"