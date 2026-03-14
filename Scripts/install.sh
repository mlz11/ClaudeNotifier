#!/bin/bash
set -euo pipefail

# ClaudeNotifier installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mlz11/ClaudeNotifier/main/Scripts/install.sh | bash

# -- Colors --
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

step()    { printf "\n${BLUE}${BOLD}==> %s${RESET}\n" "$1"; }
ok()      { printf "${GREEN}  [ok]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}  [warn]${RESET} %s\n" "$1"; }
fail()    { printf "${RED}  [error]${RESET} %s\n" "$1"; exit 1; }

# -- Preflight checks --
step "Checking system requirements"

if [ "$(uname -s)" != "Darwin" ]; then
    fail "ClaudeNotifier requires macOS. Detected: $(uname -s)"
fi
ok "Running on macOS"

macos_version=$(sw_vers -productVersion)
macos_major=$(echo "$macos_version" | cut -d. -f1)
if [ "$macos_major" -lt 11 ]; then
    fail "ClaudeNotifier requires macOS 11.0+. Detected: $macos_version"
fi
ok "macOS $macos_version ($(uname -m))"

# -- Install via Homebrew --
step "Installing ClaudeNotifier"

if ! command -v brew &>/dev/null; then
    printf "\n${YELLOW}Homebrew is required to install ClaudeNotifier.${RESET}\n\n"
    printf "Install Homebrew first:\n"
    printf "  ${BOLD}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${RESET}\n\n"
    printf "Then install ClaudeNotifier:\n"
    printf "  ${BOLD}brew install --cask mlz11/tap/claude-notifier${RESET}\n"
    exit 1
fi

ok "Homebrew found"
brew install --cask mlz11/tap/claude-notifier || fail "Homebrew installation failed"

ok "ClaudeNotifier installed"

# -- Run setup --
step "Running setup"

claude-notifier setup

printf "\n${GREEN}${BOLD}All done!${RESET} ClaudeNotifier is installed and configured.\n"
