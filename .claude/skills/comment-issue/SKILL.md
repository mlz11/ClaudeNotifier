---
name: comment-issue
description: Respond to a GitHub issue with a factual comment, optionally close and relabel
---

# Comment on GitHub Issue

Responds to an open GitHub issue on `mlz11/ClaudeNotifier` with a factual, concise comment.

## Writing Style

- Be factual and direct, not overly polite. No "Thanks for the report!" fluff.
- Use "ClaudeNotifier" or "the app" as the subject, never "I" or "we".
- If making an assumption about the user's setup (terminal vs IDE, macOS version, etc.), ask them to confirm before closing.
- Reference relevant README sections by linking to the heading anchor when the issue touches a documented limitation. Check the README first.

## Execution Steps

### 1. Read the issue

```bash
gh issue view <number>
```

Understand what the user is reporting or requesting.

### 2. Check the README for relevant documentation

Search the README for any sections that already cover the topic (known limitations, supported terminals, FAQ entries, etc.):

```bash
grep -i "<keywords>" README.md
```

If a relevant section exists, include a link to it in the response:
```
https://github.com/mlz11/ClaudeNotifier#<heading-anchor>
```

### 3. Draft the comment

Present the draft to the user for review before posting. The comment should:
- Directly address the issue
- State what ClaudeNotifier can or cannot do about it, and why
- Link to README sections if applicable
- Ask the reporter to confirm any assumptions about their setup

### 4. Post after user approval

```bash
gh issue comment <number> --body "$(cat <<'EOF'
...
EOF
)"
```

### 5. Close and relabel (if applicable)

Only close if the user explicitly asks. When closing:

1. Add a short closing comment explaining the resolution.
2. Update labels to reflect the outcome:
   - Remove action labels (e.g., `type: enhancement`, `type: feature`) if the issue won't be addressed
   - Add the appropriate status label (`status: wontfix`, `status: duplicate`, etc.)
3. Close with the right reason:
   - `--reason "not planned"` for wontfix/out-of-scope
   - `--reason "completed"` for resolved issues

```bash
gh issue comment <number> --body "Closing reason here."
gh issue close <number> --reason "not planned"
gh issue edit <number> --remove-label "type: enhancement" --add-label "status: wontfix"
```

## Available Labels

Type: `type: bug`, `type: feature`, `type: enhancement`, `type: refactor`, `type: chore`, `type: docs`
Status: `status: needs-triage`, `status: blocked`, `status: needs-investigation`, `status: wontfix`, `status: duplicate`
Priority: `priority: high`, `priority: medium`, `priority: low`
Area: `area: notifications`, `area: cli`, `area: setup`, `area: iterm`, `area: icons`, `area: build`

## Notes

- Always read the issue and README before drafting a response
- Always show the draft to the user before posting
- Never close an issue without the user asking for it
- When an issue touches a documented limitation, the README link is mandatory
