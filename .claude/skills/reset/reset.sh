#!/bin/bash
# ClaudeNotifier Reset Script
# Called by the reset skill to perform uninstallation steps

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
NOTIFY_SCRIPT="$HOME/.claude/notify.sh"
CLI_SYMLINK="$HOME/.local/bin/claude-notifier"
APP_BUNDLE="/Applications/ClaudeNotifier.app"
NOTIF_PLIST="$HOME/Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted.plist"
BUNDLE_ID="com.claude.notifier"

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  check           Check what's installed and print JSON status
  backup          Backup settings.json
  remove-hooks    Remove ClaudeNotifier hooks from settings.json
  remove-script   Remove notify.sh
  remove-cli      Remove CLI symlink
  remove-app      Remove app bundle
  reset-notif     Reset notification permissions
  reset-auto      Reset automation permissions
  all             Run all removal steps (no confirmation)
EOF
    exit 1
}

# Output JSON status of what's installed
cmd_check() {
    local settings_exists="false"
    local hooks_exist="false"
    local script_exists="false"
    local cli_exists="false"
    local cli_target=""
    local app_exists="false"
    local app_path=""
    local notif_exists="false"

    [[ -f "$SETTINGS_FILE" ]] && settings_exists="true"

    if [[ -f "$SETTINGS_FILE" ]]; then
        if grep -q '"Notification"' "$SETTINGS_FILE" 2>/dev/null && \
           grep -q 'notify.sh' "$SETTINGS_FILE" 2>/dev/null; then
            hooks_exist="true"
        fi
    fi

    [[ -f "$NOTIFY_SCRIPT" ]] && script_exists="true"

    if [[ -L "$CLI_SYMLINK" ]]; then
        cli_exists="true"
        cli_target=$(readlink "$CLI_SYMLINK" 2>/dev/null || echo "")
        # Extract app path from symlink target
        if [[ "$cli_target" == *"/ClaudeNotifier.app/"* ]]; then
            app_path="${cli_target%/Contents/MacOS/ClaudeNotifier}"
        fi
    fi

    # Check app at detected path or fallback
    if [[ -n "$app_path" && -d "$app_path" ]]; then
        app_exists="true"
    elif [[ -d "$APP_BUNDLE" ]]; then
        app_exists="true"
        app_path="$APP_BUNDLE"
    fi

    # Check notification permissions
    if [[ -f "$NOTIF_PLIST" ]]; then
        if /usr/libexec/PlistBuddy -c "Print :apps" "$NOTIF_PLIST" 2>/dev/null | grep -q "$BUNDLE_ID"; then
            notif_exists="true"
        fi
    fi

    cat <<EOF
{
  "settings_exists": $settings_exists,
  "hooks_exist": $hooks_exist,
  "script_exists": $script_exists,
  "cli_exists": $cli_exists,
  "cli_target": "$cli_target",
  "app_exists": $app_exists,
  "app_path": "$app_path",
  "notif_exists": $notif_exists
}
EOF
}

cmd_backup() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
        echo "Backed up to $SETTINGS_FILE.backup"
    else
        echo "No settings.json to backup"
    fi
}

cmd_remove_hooks() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo "No settings.json found"
        return 0
    fi

    # Use Python for reliable JSON manipulation
    python3 <<EOF
import json
import sys

with open("$SETTINGS_FILE", "r") as f:
    settings = json.load(f)

modified = False
if "hooks" in settings:
    if "Notification" in settings["hooks"]:
        del settings["hooks"]["Notification"]
        modified = True
    if "Stop" in settings["hooks"]:
        del settings["hooks"]["Stop"]
        modified = True
    # Remove empty hooks object
    if not settings["hooks"]:
        del settings["hooks"]

if modified:
    with open("$SETTINGS_FILE", "w") as f:
        json.dump(settings, f, indent=2)
    print("Removed hooks from settings.json")
else:
    print("No ClaudeNotifier hooks found")
EOF
}

cmd_remove_script() {
    if [[ -f "$NOTIFY_SCRIPT" ]]; then
        rm "$NOTIFY_SCRIPT"
        echo "Removed $NOTIFY_SCRIPT"
    else
        echo "No notify.sh found"
    fi
}

cmd_remove_cli() {
    if [[ -L "$CLI_SYMLINK" ]]; then
        rm "$CLI_SYMLINK"
        echo "Removed $CLI_SYMLINK"
    else
        echo "No CLI symlink found"
    fi
}

cmd_remove_app() {
    local target_app=""

    # Try to detect from symlink first
    if [[ -L "$CLI_SYMLINK" ]]; then
        local cli_target
        cli_target=$(readlink "$CLI_SYMLINK" 2>/dev/null || echo "")
        if [[ "$cli_target" == *"/ClaudeNotifier.app/"* ]]; then
            target_app="${cli_target%/Contents/MacOS/ClaudeNotifier}"
        fi
    fi

    # Fallback to default location
    [[ -z "$target_app" ]] && target_app="$APP_BUNDLE"

    if [[ -d "$target_app" ]]; then
        rm -rf "$target_app"
        echo "Removed $target_app"
    else
        echo "No app bundle found"
    fi
}

cmd_reset_notif() {
    if [[ ! -f "$NOTIF_PLIST" ]]; then
        echo "Notification plist not found"
        return 0
    fi

    # Find and remove the entry for our bundle ID
    local index=0
    while true; do
        local bundle_id
        bundle_id=$(/usr/libexec/PlistBuddy -c "Print :apps:$index:bundle-id" "$NOTIF_PLIST" 2>/dev/null) || break

        if [[ "$bundle_id" == "$BUNDLE_ID" ]]; then
            /usr/libexec/PlistBuddy -c "Delete :apps:$index" "$NOTIF_PLIST"
            killall usernoted cfprefsd NotificationCenter "System Settings" 2>/dev/null || true
            echo "Removed notification permissions"
            return 0
        fi
        ((index++))
    done

    echo "No notification permissions found"
}

cmd_reset_auto() {
    tccutil reset AppleEvents "$BUNDLE_ID" 2>&1 | head -1
}

cmd_all() {
    echo "=== Backup ==="
    cmd_backup
    echo ""
    echo "=== Remove Hooks ==="
    cmd_remove_hooks
    echo ""
    echo "=== Remove Script ==="
    cmd_remove_script
    echo ""
    echo "=== Remove CLI ==="
    cmd_remove_cli
    echo ""
    echo "=== Remove App ==="
    cmd_remove_app
    echo ""
    echo "=== Reset Notifications ==="
    cmd_reset_notif
    echo ""
    echo "=== Reset Automation ==="
    cmd_reset_auto
    echo ""
    echo "=== Done ==="
}

[[ $# -lt 1 ]] && usage

case "$1" in
    check)        cmd_check ;;
    backup)       cmd_backup ;;
    remove-hooks) cmd_remove_hooks ;;
    remove-script) cmd_remove_script ;;
    remove-cli)   cmd_remove_cli ;;
    remove-app)   cmd_remove_app ;;
    reset-notif)  cmd_reset_notif ;;
    reset-auto)   cmd_reset_auto ;;
    all)          cmd_all ;;
    *)            usage ;;
esac
