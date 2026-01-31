APP_NAME = ClaudeNotifier
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications
BIN_DIR = $(HOME)/.local/bin
CLI_NAME = claude-notifier

.PHONY: all build install uninstall clean lint format setup

all: build

build:
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@echo "Compiling $(APP_NAME)..."
	@swiftc Sources/ClaudeNotifier/main.swift \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		-framework UserNotifications
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	@cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
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
	@if ! echo "$$PATH" | grep -q "$(BIN_DIR)"; then \
		echo ""; \
		echo "NOTE: $(BIN_DIR) is not in your PATH."; \
		echo "Add it with:"; \
		echo "  echo 'export PATH=\"\$$HOME/.local/bin:\$$PATH\"' >> ~/.zshrc && source ~/.zshrc"; \
	fi

uninstall:
	@echo "Uninstalling..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@rm -f $(BIN_DIR)/$(CLI_NAME)
	@echo "Uninstalled"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

lint:
	@swiftlint lint Sources/

format:
	@swiftformat Sources/

setup:
	@echo "Installing pre-commit hooks..."
	@pre-commit install
	@echo "Done! Hooks will run on each commit."
