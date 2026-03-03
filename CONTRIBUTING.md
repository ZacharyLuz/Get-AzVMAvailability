# Contributing to Get-AzVMAvailability

> **This is a personal open-source project, not an official Microsoft product.** Contributing here does not create any relationship with, or obligation for, Microsoft.
> Please do not include confidential or internal information in issues, PRs, or discussions.

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Use a clear, descriptive title
- Include PowerShell version, Az module versions, and OS
- Provide steps to reproduce the issue
- Include relevant error messages or screenshots

### Suggesting Enhancements

- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Explain why this would be useful to other users

### Pull Requests

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Make your changes
4. Test thoroughly with different scenarios
5. Commit with clear messages (git commit -m Add amazing feature)
6. Push to your branch (git push origin feature/amazing-feature)
7. Open a Pull Request

### PR Description Formatting (Required)

- PR descriptions must render as valid Markdown in GitHub.
- Do not submit PR bodies with literal escaped newline sequences like `\n`.
- Use one of these safe patterns when creating/editing PRs from CLI:

```powershell
# Preferred: body file
gh pr create --title "..." --body-file pr-body.md

# Or: here-string variable (real newlines)
$body = @'
## Summary
...
'@
gh pr edit <pr-number> --body $body
```

- Verify formatting before merge:

```powershell
gh pr view <pr-number> --json body --jq .body
```

## Development Setup

    # Clone your fork
    git clone https://github.com/zacharyluz/Get-AzVMAvailability.git
    cd Get-AzVMAvailability

    # Install dependencies
    Install-Module -Name Az.Compute -Scope CurrentUser
    Install-Module -Name Az.Resources -Scope CurrentUser
    Install-Module -Name ImportExcel -Scope CurrentUser

## Code Style

- Use consistent indentation (4 spaces)
- Follow PowerShell best practices
- Add comments for complex logic
- Use meaningful variable names
- Include help documentation for new parameters

## Testing

Before submitting a PR, test with:
- Multiple subscriptions
- Various regions
- Both interactive and automated modes
- CSV and XLSX exports
- Unicode and ASCII terminal modes

## Keeping Tools Current

Three tooling components require active maintenance as the script evolves:

| Tool | What goes stale | How to prevent |
|------|-----------------|----------------|
| `tests/` | New functions without Pester coverage | Check the **New functions have Pester test coverage** box in every PR that adds functions |
| `PSScriptAnalyzerSettings.psd1` | New PSScriptAnalyzer rules not evaluated | Review periodically — `Get-ScriptAnalyzerRule` lists all available rules |
| `tools/Validate-Script.ps1` | New `.ps1` files not included in lint targets | Update `$lintTargets` when new scripts are added to `tools/` |

A scheduled CI workflow (`.github/workflows/scheduled-health-check.yml`) runs `tools/Validate-Script.ps1` weekly on `main` and opens a GitHub issue automatically if any check fails.

## Release Process Standard (Required)

For any change that updates `$ScriptVersion`, use this order every time:

1. Merge PR into `main`
2. Sync local `main` to `origin/main`
3. Create tag `vX.Y.Z` on the merge commit
4. Create GitHub Release from `CHANGELOG.md` section `## [X.Y.Z]`
5. Verify release metadata with `gh release list`

### Required closeout artifacts

- `docs/VERIFY-RELEASE.md`
- `.github/skills/release-verification-checklist/SKILL.md`

These are the required checklist references before release closeout.

## Questions?

Feel free to [open an issue](https://github.com/ZacharyLuz/Get-AzVMAvailability/issues) on GitHub.
