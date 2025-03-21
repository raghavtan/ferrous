#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <app-path> <dmg-output-path>"
    exit 1
fi

APP_PATH=$1
DMG_PATH=$2
TMP_DIR=$(mktemp -d)

# Copy the app to the temporary directory
cp -R "$APP_PATH" "$TMP_DIR"

# Create a symbolic link to the Applications folder
ln -s /Applications "$TMP_DIR/Applications"

# Create the DMG
hdiutil create -volname "ferrous" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_PATH"

# Clean up
rm -rf "$TMP_DIR"

echo "DMG created at $DMG_PATH"