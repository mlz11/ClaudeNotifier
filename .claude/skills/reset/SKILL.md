---
name: reset
description: Completely reset ClaudeNotifier installation, removing all components and permissions
---

# ClaudeNotifier Reset

Use the `reset.sh` script in this skill's directory to perform the reset.

## Execution Steps

1. **Check current state**: Run `./reset.sh check` from the skill's base directory to get JSON showing what's installed

2. **Show summary**: Parse the JSON and tell the user what will be removed:
   - Hooks in settings.json (if `hooks_exist` is true)
   - Notify script at ~/Library/Application Support/ClaudeNotifier/notify.sh (if `script_exists` is true)
   - Config file at ~/Library/Application Support/ClaudeNotifier/config.json (if `config_exists` is true)
   - CLI symlink at ~/.local/bin/claude-notifier (if `cli_exists` is true)
   - App bundle (show `app_path` if `app_exists` is true)
   - Notification permissions (if `notif_exists` is true)
   - Automation permissions (always reset)

3. **Single confirmation**: Use AskUserQuestion to confirm the reset with Yes/No options. Show what will be removed in the description.

4. **Execute reset**: If confirmed, run `./reset.sh all` to perform all steps at once

5. **Report results**: Show the script output as a summary

## Notes

- The script automatically skips steps where targets don't exist
- A backup of settings.json is created at ~/.claude/settings.json.backup before any changes
- The base directory path is provided at the top of this skill prompt
