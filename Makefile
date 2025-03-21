.PHONY: all clean build test package package-dmg package-pkg install

APP_NAME = ferrous
BUILD_DIR = build
DIST_DIR = dist

# Get VERSION from environment variable or use v0.0.0 as fallback
VERSION ?= v0.0.0
# Strip 'v' prefix if present for app version
APP_VERSION = $(shell echo $(VERSION) | sed 's/^v//')

# When packaging, get the actual version from the built Info.plist file
BUILT_VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist)
BUILT_NUMBER = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleVersion" $(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist)

all: clean build package

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@xcodebuild clean -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release

build:
	@echo "Building $(APP_NAME) version $(APP_VERSION) from $(VERSION)..."
	@mkdir -p $(BUILD_DIR)
	@VERSION=$(VERSION) ./Scripts/build.sh
	@echo "Build completed"

test:
	@echo "Running tests..."
	@xcodebuild test -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug

package: package-dmg package-pkg

package-dmg:
	@echo "Creating DMG package for version $(BUILT_VERSION)-$(BUILT_NUMBER)..."
	@mkdir -p $(DIST_DIR)
	@./Scripts/create-dmg.sh $(BUILD_DIR)/$(APP_NAME).app $(DIST_DIR)/$(APP_NAME)-$(BUILT_VERSION)-$(BUILT_NUMBER).dmg
	@echo "DMG created at $(DIST_DIR)/$(APP_NAME)-$(BUILT_VERSION)-$(BUILT_NUMBER).dmg"

package-pkg:
	@echo "Creating PKG installer for version $(BUILT_VERSION)-$(BUILT_NUMBER)..."
	@mkdir -p $(DIST_DIR)
	@./Scripts/create-pkg.sh $(BUILD_DIR)/$(APP_NAME).app $(DIST_DIR)/$(APP_NAME)-$(BUILT_VERSION)-$(BUILT_NUMBER).pkg
	@echo "PKG created at $(DIST_DIR)/$(APP_NAME)-$(BUILT_VERSION)-$(BUILT_NUMBER).pkg"

install: build
	@echo "Installing $(APP_NAME) to Applications folder..."
	@cp -R $(BUILD_DIR)/$(APP_NAME).app /Applications/
	@echo "$(APP_NAME) installed"