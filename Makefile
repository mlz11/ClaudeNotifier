APP_NAME = ClaudeNotifier
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications
BIN_DIR = $(HOME)/.local/bin
CLI_NAME = claude-notifier

GENERATED_SCRIPT = Sources/ClaudeNotifier/NotifyScript.generated.swift

.PHONY: all build install uninstall clean lint format setup icons

all: build

SOURCES = $(wildcard Sources/ClaudeNotifier/*.swift)

$(GENERATED_SCRIPT): Scripts/notify.sh
	@echo "Generating NotifyScript.generated.swift..."
	@echo '// Auto-generated from Scripts/notify.sh - do not edit directly' > $@
	@echo '' >> $@
	@echo 'let notifyScript = """' >> $@
	@cat $< >> $@
	@echo '"""' >> $@

build: $(GENERATED_SCRIPT)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@echo "Compiling $(APP_NAME)..."
	@swiftc $(SOURCES) \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		-framework UserNotifications
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	@cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	@for icns in Resources/AppIcon-*.icns; do \
		if [ -f "$$icns" ]; then \
			cp "$$icns" $(APP_BUNDLE)/Contents/Resources/; \
		fi; \
	done
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

icons:
	@echo "Generating icon variants..."
	@./Scripts/generate-icon.sh --all
	@echo "Icon variants generated in Resources/"

install: build
	@read -p "Install directory [$(INSTALL_DIR)]: " input_dir; \
	dir=$${input_dir:-$(INSTALL_DIR)}; \
	case "$$dir" in ~/*) dir="$$HOME$${dir#\~}";; ~) dir="$$HOME";; esac; \
	printf "\n\033[1;36mInstalling to $$dir...\033[0m\n"; \
	rm -rf "$$dir/$(APP_NAME).app"; \
	mkdir -p "$$dir"; \
	cp -r $(APP_BUNDLE) "$$dir/"; \
	printf "\033[32mInstalled $$dir/$(APP_NAME).app\033[0m\n"; \
	printf "\033[1;36mCreating CLI symlink...\033[0m\n"; \
	mkdir -p $(BIN_DIR); \
	ln -sf "$$dir/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" $(BIN_DIR)/$(CLI_NAME); \
	printf "\033[32mLinked $(BIN_DIR)/$(CLI_NAME)\033[0m\n"; \
	printf "\n\033[1;32mInstall complete!\033[0m CLI available as: \033[1;36m$(CLI_NAME)\033[0m\n"; \
	if ! echo "$$PATH" | grep -q "$(BIN_DIR)"; then \
		echo ""; \
		printf "\033[33mNOTE: $(BIN_DIR) is not in your PATH.\033[0m\n"; \
		printf "\033[33mAdd it with:\033[0m\n"; \
		printf "  \033[2mecho 'export PATH=\"\$$HOME/.local/bin:\$$PATH\"' >> ~/.zshrc && source ~/.zshrc\033[0m\n"; \
	fi

uninstall:
	@if [ -L "$(BIN_DIR)/$(CLI_NAME)" ]; then \
		target=$$(readlink "$(BIN_DIR)/$(CLI_NAME)"); \
		dir=$$(dirname "$$(dirname "$$(dirname "$$(dirname "$$target")")")"); \
		echo "Detected install at $$dir"; \
		rm -rf "$$dir/$(APP_NAME).app"; \
		rm -f "$(BIN_DIR)/$(CLI_NAME)"; \
		echo "Uninstalled"; \
	else \
		echo "No installation found (symlink $(BIN_DIR)/$(CLI_NAME) does not exist)"; \
	fi

clean:
	@rm -rf $(BUILD_DIR)
	@rm -f $(GENERATED_SCRIPT)
	@echo "Cleaned build directory"

lint:
	@swiftlint lint Sources/

format:
	@swiftformat Sources/

setup:
	@echo "Installing pre-commit hooks..."
	@pre-commit install
	@echo "Done! Hooks will run on each commit."
