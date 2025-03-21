.PHONY: all clean build test package package-dmg package-pkg install

APP_NAME = ferrous
BUILD_DIR = build
DIST_DIR = dist
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ferrous/Info.plist)
BUILD_NUMBER = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleVersion" ferrous/Info.plist)

all: clean build package

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@xcodebuild clean -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release

build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@./Scripts/build.sh
	@echo "Build completed"

test:
	@echo "Running tests..."
	@xcodebuild test -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug

package: package-dmg package-pkg

package-dmg:
	@echo "Creating DMG package..."
	@mkdir -p $(DIST_DIR)
	@./Scripts/create-dmg.sh $(BUILD_DIR)/$(APP_NAME).app $(DIST_DIR)/$(APP_NAME)-$(VERSION)-$(BUILD_NUMBER).dmg
	@echo "DMG created at $(DIST_DIR)/$(APP_NAME)-$(VERSION)-$(BUILD_NUMBER).dmg"

package-pkg:
	@echo "Creating PKG installer..."
	@mkdir -p $(DIST_DIR)
	@./Scripts/create-pkg.sh $(BUILD_DIR)/$(APP_NAME).app $(DIST_DIR)/$(APP_NAME)-$(VERSION)-$(BUILD_NUMBER).pkg
	@echo "PKG created at $(DIST_DIR)/$(APP_NAME)-$(VERSION)-$(BUILD_NUMBER).pkg"

install: build
	@echo "Installing $(APP_NAME) to Applications folder..."
	@cp -R $(BUILD_DIR)/$(APP_NAME).app /Applications/
	@echo "$(APP_NAME) installed"