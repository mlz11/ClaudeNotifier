#!/bin/bash
set -euo pipefail

# ClaudeNotifier uninstaller
# Removes hooks, config, app bundle, and CLI symlink.

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
info()    { printf "  %s\n" "$1"; }

confirm() {
    if [ -t 0 ]; then
        printf "%s [y/N] " "$1"
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    else
        # Non-interactive: proceed
        return 0
    fi
}

# -- Remove hooks from settings.json --
step "Removing Claude Code hooks"

settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
    # Only remove hooks whose command references claude-notifier's notify script
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
path = '$settings_file'
with open(path) as f:
    data = json.load(f)
hooks = data.get('hooks', {})
removed = []
for key in list(hooks.keys()):
    entries = hooks[key]
    if not isinstance(entries, list):
        continue
    is_ours = False
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            if 'claude-notifier' in cmd or 'ClaudeNotifier' in cmd:
                is_ours = True
                break
        if is_ours:
            break
    if is_ours:
        del hooks[key]
        removed.append(key)
if not hooks:
    data.pop('hooks', None)
else:
    data['hooks'] = hooks
with open(path, 'w') as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write('\n')
for k in removed:
    print(f'  Removed {k} hook')
if not removed:
    print('  No ClaudeNotifier hooks found')
"
    else
        warn "python3 not found, could not clean hooks from $settings_file"
        info "Manually remove ClaudeNotifier hooks from $settings_file"
    fi
else
    info "No settings file found at $settings_file"
fi

# -- Remove app support directory --
step "Removing application data"

app_support_dir="$HOME/Library/Application Support/ClaudeNotifier"
if [ -d "$app_support_dir" ]; then
    rm -rf "$app_support_dir"
    ok "Removed $app_support_dir"
else
    info "No application data found"
fi

# -- Uninstall app --
step "Uninstalling ClaudeNotifier"

if command -v brew &>/dev/null && brew list --cask mlz11/tap/claude-notifier &>/dev/null 2>&1; then
    brew uninstall --cask claude-notifier
    ok "Uninstalled via Homebrew"
else
    # Manual removal fallback
    removed_something=false

    if [ -d "/Applications/ClaudeNotifier.app" ]; then
        if confirm "  Remove /Applications/ClaudeNotifier.app?"; then
            rm -rf "/Applications/ClaudeNotifier.app"
            ok "Removed /Applications/ClaudeNotifier.app"
            removed_something=true
        else
            info "Skipped /Applications/ClaudeNotifier.app"
        fi
    fi

    cli_path="$HOME/.local/bin/claude-notifier"
    if [ -L "$cli_path" ] || [ -f "$cli_path" ]; then
        rm -f "$cli_path"
        ok "Removed $cli_path"
        removed_something=true
    fi

    if [ "$removed_something" = false ]; then
        info "No ClaudeNotifier installation found"
    fi
fi

printf "\n${GREEN}${BOLD}ClaudeNotifier has been uninstalled.${RESET}\n"
