---
name: file-issue
description: File a GitHub issue following repo templates and applying appropriate labels
---

# File GitHub Issue

Creates a GitHub issue on `mlz11/ClaudeNotifier` using the repo's issue templates and label taxonomy.

## Issue Templates

The repo has two templates in `.github/ISSUE_TEMPLATE/` (blank issues are disabled):

### Bug Report (`bug_report.md`)
Default labels: `type: bug`, `status: needs-triage`

Body sections:
- **Describe the bug**
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Environment** (macOS version, install method, terminal, version)
- **Doctor output**
- **Logs**
- **Additional context**

### Feature Request (`feature_request.md`)
Default labels: `type: feature`, `status: needs-triage`

Body sections:
- **Problem**
- **Proposed solution**
- **Alternatives considered**

## Available Labels

Type: `type: bug`, `type: feature`, `type: enhancement`, `type: refactor`, `type: chore`, `type: docs`
Status: `status: needs-triage`, `status: blocked`, `status: needs-investigation`, `status: wontfix`, `status: duplicate`
Priority: `priority: high`, `priority: medium`, `priority: low`
Area: `area: notifications`, `area: cli`, `area: setup`, `area: iterm`, `area: icons`, `area: build`

## Execution Steps

### 1. Determine issue type

Ask the user (via AskUserQuestion) what kind of issue they want to file:
- **Bug Report**: something is broken
- **Feature Request**: new functionality or improvement

### 2. Gather details

Ask the user to describe the issue. Use follow-up questions if needed to fill in the template sections. Don't require every section; fill in what's relevant and omit empty sections.

For bug reports, try to pre-fill **Environment** by running:
```bash
sw_vers -productVersion   # macOS version
claude-notifier --version  # app version (may not exist yet)
```

### 3. Select labels

Always include the template's default labels. Then ask the user (via AskUserQuestion with multiSelect) which additional labels to apply:
- One **area:** label (pick the most relevant)
- One **priority:** label

### 4. Create the issue

Use `gh issue create` with a HEREDOC body to preserve formatting:

```bash
gh issue create --repo mlz11/ClaudeNotifier \
  --title "The title" \
  --label "type: bug" --label "status: needs-triage" --label "area: cli" --label "priority: medium" \
  --body "$(cat <<'EOF'
**Describe the bug**
...

**Steps to reproduce**
1. ...

**Expected behavior**
...
EOF
)"
```

### 5. Report result

Show the user the issue URL returned by `gh issue create`.

## Notes

- Follow the template structure closely; the sections should match `.github/ISSUE_TEMPLATE/`
- Omit sections that have no content rather than leaving them empty
- If the user already described the issue in conversation, extract details from context rather than re-asking
- Keep titles concise and descriptive (under 70 characters)
- The `status: needs-triage` label is always included by default
