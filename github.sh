#!/bin/bash
# Entry point for curl installation


# === Constants ===
readonly SCRIPT_NAME="GitHub Repo Add, Commit, and Push"
readonly SCRIPT_VERSION="2.0.0"
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
git push origin "$GITHUB_BRANCH" || die "Failed to push to remote repository!"

log "Successfully pushed changes to GitHub!"

