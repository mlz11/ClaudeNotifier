---
name: release
description: Release a new version with semantic versioning, changelog update, and homebrew tap
---

# ClaudeNotifier Release

Automates the release process: version bump, changelog, git tag, and homebrew tap update.

## Configuration

- **Homebrew tap path**: `/Users/zraqs/dev/homebrew-tap`
- **Formula file**: `Formula/claude-notifier.rb`
- **Tarball URL pattern**: `https://github.com/mlz11/ClaudeNotifier/archive/refs/tags/v{VERSION}.tar.gz`

## Execution Steps

### 1. Analyze commits since last tag

```bash
git tag --sort=-v:refname | head -1  # Get latest tag
git log --oneline {latest_tag}..HEAD  # List commits since
```

Determine version bump based on conventional commits:
- `feat:` commits → **minor** bump (1.2.0 → 1.3.0)
- `fix:` commits only → **patch** bump (1.2.0 → 1.2.1)
- `BREAKING CHANGE:` or `!:` → **major** bump (1.2.0 → 2.0.0)

### 2. Update VERSION file

Write the new version number (without `v` prefix) to the `VERSION` file in the repo root:

```bash
echo "X.Y.Z" > VERSION
```

### 3. Update CHANGELOG.md

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features (from feat: commits)

### Changed
- Changes to existing features

### Fixed
- Bug fixes (from fix: commits)
```

Add the version link at the bottom:
```markdown
[X.Y.Z]: https://github.com/mlz11/ClaudeNotifier/releases/tag/vX.Y.Z
```

### 4. Commit version and changelog

```bash
git add VERSION CHANGELOG.md
git commit -m "chore: update changelog for vX.Y.Z"
```

### 5. Tag and push

```bash
git tag vX.Y.Z
git push
git push origin vX.Y.Z
```

### 6. Create GitHub Release

Create a GitHub Release from the tag with changelog content:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "## Added
- ...

## Fixed
- ..."
```

Use the changelog entries for the release notes.

A GitHub Actions workflow (`.github/workflows/release.yml`) will automatically build and attach `ClaudeNotifier.zip` (containing the `.app` bundle) to the release.

### 7. Get tarball sha256

Wait a moment for GitHub to generate the tarball, then:

```bash
curl -sL https://github.com/mlz11/ClaudeNotifier/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
```

### 8. Update homebrew formula

Edit `/Users/zraqs/dev/homebrew-tap/Formula/claude-notifier.rb`:
- Update `url` to new version tag
- Update `sha256` to new hash

### 9. Push homebrew tap

```bash
cd /Users/zraqs/dev/homebrew-tap
git add Formula/claude-notifier.rb
git commit -m "claude-notifier X.Y.Z"
git push
```

### 10. Report summary

Tell the user:
- New version number
- What was included (features, fixes)
- GitHub Release URL
- That homebrew tap is updated
- Upgrade command: `brew upgrade claude-notifier`
- That the `.app` zip will be attached to the release automatically by CI

## Notes

- Always read CHANGELOG.md first to understand the existing format
- Group related commits into single changelog entries
- Skip `docs:` and `chore:` commits in changelog (except for user-facing docs)
- If no `feat:` or `fix:` commits exist, ask user to confirm release is needed
