---
name: release-process-guardrails
description: Guardrails for protected-branch release flow (PR-only, merge-then-tag, CI gates). Use this skill for any release/tag/publish/merge workflow in this repo.
---

# Release Process Guardrails

## When to use
- User asks to release, tag, publish, merge, or push to `main`
- User wants to create GitHub releases or tags
- User asks to clean up release branches or align local and remote `main`

## Must follow
- Protected `main` requires PR flow; direct pushes to `main` are blocked
- Merge PR first, then create tag and GitHub release
- Verify CI and code scanning are green before merge
- If local `main` diverges from `origin/main`, prefer reset to `origin/main` over creating a merge commit
- Use required closeout checklist artifacts before declaring release complete:
  - `docs/VERIFY-RELEASE.md`
  - `.github/skills/release-verification-checklist/SKILL.md`

## Checklist
1) Ensure PR exists for release changes
2) Wait for CI (PSScriptAnalyzer, Pester) to finish successfully
3) Pull and triage GitHub Copilot PR review comments before merge
4) Merge via squash (unless policy says otherwise)
5) Sync local `main` to `origin/main`
6) Tag release on the merge commit
7) Create/verify GitHub release notes
8) Verify published release metadata with `gh release list`

## Common pitfalls
- Tagging or publishing before PR merge (tags point to local-only commits)
- `git pull` creating merge commits on protected branches
- Assuming bot reviews satisfy human approval rules

## Useful commands
- PR status: `gh pr view <id> --json mergeStateStatus,statusCheckRollup,reviewDecision`
- Merge (squash): `gh pr merge <id> --squash --delete-branch`
- Tag release: `git tag vX.Y.Z; git push --tags`
- Release notes: `gh release create vX.Y.Z -t "vX.Y.Z" -n "..."`
- Align local main: `git fetch origin; git reset --hard origin/main`
- Verify release publication: `gh release list --limit 10`
