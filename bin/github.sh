#!/bin/bash
# Entry point for curl installation


# === Constants ===
SCRIPT_NAME="Git Manager"

# Auto-detect from git config
readonly REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
readonly CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "master")

# Extract user and repo from remote URL
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    readonly GITHUB_USER="${BASH_REMATCH[1]}"
    readonly GITHUB_REPO="${BASH_REMATCH[2]}"
else
    readonly GITHUB_USER=""
    readonly GITHUB_REPO=""
fi

readonly GITHUB_BRANCH="${NAS_MOUNT_GITHUB_BRANCH:-$CURRENT_BRANCH}"
readonly GITHUB_URL="${REMOTE_URL:-https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git}"
    
# === Functions ===
die() {
    echo "ERROR: $1" >&2
    [ -n "$2" ] && echo "$2" >&2
    exit 1
}

log() {
    echo "[$SCRIPT_NAME] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Check for git
if ! command -v git >/dev/null 2>&1; then
    die "Git is required" "Please install git first."
fi

# Check if remote origin is configured
if [ -z "$REMOTE_URL" ]; then
    echo ""
    echo "No git remote origin found. Let's set it up with SSH."
    echo ""
    read -p "Enter your GitHub username (default: jdpierce21): " github_username
    github_username=${github_username:-jdpierce21}
    
    # Get repository name from current directory
    repo_name=$(basename "$PWD")
    
    echo "Setting up SSH remote: git@github.com:${github_username}/${repo_name}.git"
    git remote add origin "git@github.com:${github_username}/${repo_name}.git" || die "Failed to add remote"
    
    # Re-read the remote URL after adding it
    REMOTE_URL=$(git config --get remote.origin.url)
    
    # Re-extract user and repo
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        GITHUB_USER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]}"
    fi
    
    echo "Remote origin added successfully!"
    echo ""
fi

# === Main Script ===
echo ""
echo "===[Starting]==="
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
    log "No uncommitted changes found."
    
    # Check if there are unpushed commits
    UNPUSHED=$(git rev-list HEAD --not --remotes 2>/dev/null | wc -l)
    if [ "$UNPUSHED" -gt 0 ]; then
        log "Found $UNPUSHED unpushed commit(s). Attempting to push..."
        # Skip directly to push
        SKIP_COMMIT=true
    else
        log "Nothing to commit or push."
        exit 0
    fi
else
    SKIP_COMMIT=false
fi

# Show status and commit if needed
if [ "$SKIP_COMMIT" = "false" ]; then
    log "Found uncommitted changes:"
    git status --short

    # Add all changes
    log "Adding all changes..."
    echo ""
    echo "===[Remote Response]==="
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
fi

# Push to remote
log "Pushing to $GITHUB_URL (branch: $GITHUB_BRANCH)..."
if ! git push origin "$GITHUB_BRANCH" 2>&1; then
    # Check if the error is due to non-fast-forward
    if git push --dry-run origin "$GITHUB_BRANCH" 2>&1 | grep -q "non-fast-forward"; then
        echo ""
        echo "WARNING: Your local and remote branches have diverged!"
        echo "This usually happens when changes were made to the remote that you don't have locally."
        echo ""
        echo "You have two options:"
        echo "1) Force push your LOCAL changes to remote (this will OVERWRITE the remote)"
        echo "2) Pull the REMOTE changes to local (this will OVERWRITE your local commits)"
        echo ""
        read -p "Choose an option (1=force push local, 2=pull remote, c=cancel): " -n 1 -r
        echo
        
        case "$REPLY" in
            1|2)
                # Create a full backup before any destructive operation
                log "Creating safety backup before force operation..."
                BACKUP_DESC="github-safety-backup-before-force-$(date +%Y%m%d-%H%M%S)"
                
                # Check for project-specific backup tools
                if [ -x "./pynoc-cli" ]; then
                    # PyNOC project - use pynoc-cli
                    ./pynoc-cli backup full "$BACKUP_DESC" || log "Warning: pynoc-cli backup failed, continuing anyway"
                elif [ -x "./backup.sh" ]; then
                    # Generic backup script
                    ./backup.sh "$BACKUP_DESC" || log "Warning: backup.sh failed, continuing anyway"
                else
                    # Fallback to git stash if no backup tool available
                    log "Using git stash for backup (no project-specific backup tool found)"
                    git stash push -m "$BACKUP_DESC" || log "Warning: git stash failed"
                fi
                
                if [ "$REPLY" = "1" ]; then
                    log "Force pushing local changes to remote..."
                    git push --force origin "$GITHUB_BRANCH" || die "Failed to force push to remote repository!"
                    log "Successfully force pushed local changes to remote!"
                else
                    log "Pulling remote changes to local..."
                    # First, backup current state in a branch
                    BACKUP_BRANCH="backup-$(date +%Y%m%d-%H%M%S)"
                    git branch "$BACKUP_BRANCH" || die "Failed to create backup branch"
                    log "Created backup branch: $BACKUP_BRANCH"
                    
                    # Reset to remote
                    git fetch origin "$GITHUB_BRANCH" || die "Failed to fetch from remote"
                    git reset --hard "origin/$GITHUB_BRANCH" || die "Failed to reset to remote"
                    log "Successfully pulled remote changes to local!"
                    log "Your previous local state is saved in branch: $BACKUP_BRANCH"
                fi
                ;;
            *)
                die "Operation cancelled by user"
                ;;
        esac
    else
        log "Attempting to set upstream branch..."
        git push --set-upstream origin "$GITHUB_BRANCH" || die "Failed to push to remote repository!"
    fi
fi

echo ""
echo "===[Complete]==="
log "Successfully pushed changes to GitHub!"
