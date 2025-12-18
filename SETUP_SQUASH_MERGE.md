# Setting Up Squash Merge for Main Branch

This repository is configured to use "Squash and Merge" as the default merge method for the main branch.

## Why Use Squash Merge?

- **Clean commit history**: Each PR becomes a single clean commit
- **Maintainable history**: Easier to read and understand the evolution of the codebase
- **Consistent commits**: PR descriptions become commit messages for better documentation

## How to Configure

### GitHub Settings (Repository Admin)

1. Go to repository settings: https://github.com/maujim/agent/settings
2. Click on "Branches" in the left sidebar
3. Under "Default branch", ensure "main" is selected
4. Under "Branch protection rules", add a rule for the main branch:
   - Check "Require status checks to pass before merging" (optional)
   - Check "Require conversation resolution before merging" (optional)
   - Keep "Allow force pushes" unchecked
   - Keep "Allow deletions" unchecked
5. In the main repository settings:
   - Go to Settings > General
   - Under "Pull request merges", uncheck "Allow merge commits"
   - Uncheck "Allow rebase merging"
   - Keep "Allow squash merge" checked
   - Set "Set auto-merge" as desired

### Merging Pull Requests

When merging PRs into main:

1. Always use the **"Squash and merge"** button
2. The PR title will become the commit title
3. The PR description will become the commit body
4. All individual commits from the PR branch will be combined

### Local Git Configuration

The repository is configured locally with:
- `git config merge.ff only` - Only fast-forward merges locally
- `git config pull.ff only` - Only fast-forward pulls
- `git config merge.renames true` - Enable rename detection

## Benefits

✅ One commit per feature in main branch
✅ Clear, descriptive commit messages from PR descriptions
✅ Easy to bisect and find the origin of changes
✅ Clean git log and history

## Commands

```bash
# Create a PR with the GitHub CLI (uses squash merge by default)
gh pr create --title "Add new feature" --body "Description of the feature" --base main

# Check current branch settings
git config --list | grep merge
git config --list | grep pull
```