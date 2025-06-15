#!/bin/bash
# Entry point for curl installation


# === Constants ===
readonly SCRIPT_NAME="GitHub Repo Add, Commit, and Push"
readonly GITHUB_USER="${NAS_MOUNT_GITHUB_USER:-jdpierce21}"
readonly GITHUB_REPO="${NAS_MOUNT_GITHUB_REPO:-nas_mount}"
readonly GITHUB_BRANCH="${NAS_MOUNT_GITHUB_BRANCH:-master}"
readonly GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
    
# === Functions ===
die() {
    echo "ERROR: $1" >&2
    [ -n "$2" ] && echo "$2" >&2
    exit 1
}

log() {
    echo "[$SCRIPT_NAME] $1"
}

# Check for git
if ! command -v git >/dev/null 2>&1; then
    die "Git is required" "Please install git first."
fi

# === Main Script ===
log "Checking for uncommitted changes..."

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    die "Not in a git repository." "Please run this script from within a git repository."
fi

# Fetch latest changes from remote
log "Fetching latest changes from remote..."
git fetch origin "$GITHUB_BRANCH" 2>/dev/null || log "Warning: Could not fetch from remote"

# Check if local branch is behind remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$GITHUB_BRANCH" 2>/dev/null || echo "")
if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
    BEHIND=$(git rev-list --count HEAD..origin/"$GITHUB_BRANCH" 2>/dev/null || echo "0")
    if [ "$BEHIND" -gt 0 ]; then
        log "Warning: Local branch is $BEHIND commit(s) behind remote"
        read -p "Pull changes first? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git pull origin "$GITHUB_BRANCH" || die "Failed to pull changes"
        fi
    fi
fi

# Check for uncommitted changes
if git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "No uncommitted changes found. Nothing to commit."
    exit 0
fi

# Show status
log "Found uncommitted changes:"
git status --short

# Add all changes
log "Adding all changes..."
git add -A

# Get commit message
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    COMMIT_MSG="Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"
fi

# Commit changes
log "Committing changes with message: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" || die "Failed to commit changes!"

# Push to remote
log "Pushing to $GITHUB_URL (branch: $GITHUB_BRANCH)..."
if ! git push origin "$GITHUB_BRANCH" 2>&1; then
    log "Push failed. Attempting to set upstream branch..."
    git push --set-upstream origin "$GITHUB_BRANCH" || die "Failed to push to remote repository!"
fi

log "Successfully pushed changes to GitHub!"

