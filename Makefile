APP_NAME = ClaudeNotifier
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications
BIN_DIR = $(HOME)/.local/bin
CLI_NAME = claude-notifier

.PHONY: all build install uninstall clean

all: build

build:
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@echo "Compiling $(APP_NAME)..."
	@swiftc Sources/ClaudeNotifier/main.swift \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		-framework UserNotifications
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	@echo "Copying Claude icon..."
	@cp /Applications/Claude.app/Contents/Resources/electron.icns \
		$(APP_BUNDLE)/Contents/Resources/AppIcon.icns 2>/dev/null || \
		echo "Warning: Claude.app not found, icon not copied"
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "Creating CLI symlink..."
	@mkdir -p $(BIN_DIR)
	@ln -sf $(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) $(BIN_DIR)/$(CLI_NAME)
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "CLI available as: $(CLI_NAME)"

uninstall:
	@echo "Uninstalling..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@rm -f $(BIN_DIR)/$(CLI_NAME)
	@echo "Uninstalled"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"
