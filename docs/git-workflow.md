# Git workflow

This document describes how we use branches, pull requests, and merges in the JobHunter repository. It matches the summary in the root [README](../README.md) and adds day-to-day conventions.

## Branches

| Branch | Role |
|--------|------|
| `main` | Production-ready code. Only updated from `develop` via controlled releases (or hotfixes when needed). |
| `develop` | Integration branch for ongoing work. All feature branches merge here first. |
| `feature/<short-name>` | New functionality or non-trivial refactors. Examples: `feature/auth-login`, `feature/resume-parser`. |
| `bugfix/<short-name>` | Fixes for defects found on `develop` (or pre-release work that is not urgent production repair). |
| `hotfix/<short-name>` | Urgent production fixes branched from `main`, merged back to both `main` and `develop` so branches stay aligned. |

Use lowercase, hyphens, and short descriptive slugs in branch names. Prefer one logical change per branch.

## Starting work

1. Fetch latest remote state: `git fetch origin`.
2. Ensure `develop` is up to date: `git checkout develop` then `git pull origin develop`.
3. Create a branch: `git checkout -b feature/your-topic`.

Avoid long-lived branches that drift far from `develop`. Rebase or merge `develop` into your branch regularly if the work spans several days.

## Pull requests

- Open pull requests **into `develop`** for normal feature and bugfix work.
- Keep PRs focused: one concern per PR when possible, so review stays fast and history stays clear.
- In the PR description, briefly state **what** changed and **why**, and link any issue or task tracker item if you use one.
- Request review when the change is ready for others; mark draft if it is still experimental.

Resolve review feedback with additional commits or a clean history update (see below), whichever fits the team norm for that PR.

## Merging

- Prefer **squash merge** or **merge commit** consistently per team agreement; pick one default for `develop` so history stays predictable.
- **Do not** force-push to `main` or `develop` except in rare coordinated maintenance (and never rewrite shared history without team agreement).

## Releases to production

When `develop` is stable and you want a production cut:

1. Tag or release from `main` as your process requires (version tags, changelog, etc.).
2. Merge `develop` into `main` (or open a release PR from `develop` to `main`) after final checks.

Hotfixes on `main` should be merged or cherry-picked into `develop` immediately afterward so the next release does not drop the fix.

## Commits

Use a **type prefix**, a colon, a space, then a short summary in the imperative mood (same idea as [Conventional Commits](https://www.conventionalcommits.org/)):

```text
<type>: <short summary in imperative mood>
```

Examples:

- `feat: add JWT refresh endpoint`
- `fix: handle empty resume upload`
- `docs: describe git workflow`
- `chore: bump Go toolchain in CI`
- `refactor: extract resume parser interface`
- `test: cover gateway auth middleware`
- `ci: run backend tests on PR`

Common types (use the closest fit; add a new type only when it stays clear to the team):

| Type | Typical use |
|------|-------------|
| `feat` | New user-visible behavior or API |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance, deps, tooling with no product behavior change |
| `refactor` | Code change that is not a fix or feature |
| `test` | Tests only |
| `ci` | CI or pipeline configuration |

Rules:

- Keep the **first line** short (about 50–72 characters including the prefix). Add a blank line and a **body** when reviewers need more context.
- Write the summary in the imperative mood (`feat: add login`, not `feat: added login` or `feat: adds login`).

## Conflicts and rebasing

- If your branch conflicts with `develop`, update your branch: merge `develop` into your branch, or rebase your branch onto `develop` if your team prefers a linear history on PRs.
- After a rebase that was already pushed, you must force-push your **feature** branch only (`git push --force-with-lease`), never shared protected branches unless explicitly agreed.

## Quick reference

```text
main     ───●────────────●──  (releases, hotfixes)
            \          /
develop  ───●──●──●──●──●──  (integration)
                \  /
feature/foo  ───●──●──       (your work)
```

For questions not covered here, default to keeping `develop` green, keeping PRs small, and aligning `main` with what actually runs in production.
