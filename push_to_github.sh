#!/bin/bash

###############################################################################
# File: push_to_github.sh
# Date: 2025-06-13
# Version: 1.0.0
# Description: Initialize and push NAS mount scripts to GitHub repository
###############################################################################

set -e  # Exit on error

# === Colors for output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Helper functions ===
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# === Configuration ===
REPO_URL="git@github.com:jdpierce21/nas_mount.git"  # Using SSH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === Main logic ===
print_header "GitHub Repository Setup"

cd "$SCRIPT_DIR"

# === Check git config ===
print_header "Checking Git Configuration"

if [[ -z "$(git config user.email)" ]]; then
    print_warning "Git email not configured"
    read -p "Enter your email for git commits: " git_email
    git config user.email "$git_email"
    print_success "Git email configured"
else
    print_success "Git email: $(git config user.email)"
fi

if [[ -z "$(git config user.name)" ]]; then
    print_warning "Git name not configured"
    read -p "Enter your name for git commits: " git_name
    git config user.name "$git_name"
    print_success "Git name configured"
else
    print_success "Git name: $(git config user.name)"
fi

# Check if already a git repository
if [[ -d .git ]]; then
    print_info "Git repository already initialized"
    
    # Check if remote exists
    if git remote get-url origin &>/dev/null; then
        CURRENT_REMOTE=$(git remote get-url origin)
        if [[ "$CURRENT_REMOTE" != "$REPO_URL" ]]; then
            print_warning "Remote 'origin' points to: $CURRENT_REMOTE"
            read -p "Update to $REPO_URL? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git remote set-url origin "$REPO_URL"
                print_success "Remote updated"
            fi
        else
            print_success "Remote already set correctly"
        fi
    else
        git remote add origin "$REPO_URL"
        print_success "Remote 'origin' added"
    fi
else
    # Initialize new repository
    print_info "Initializing git repository..."
    git init
    print_success "Git repository initialized"
    
    # Add remote
    git remote add origin "$REPO_URL"
    print_success "Remote 'origin' added"
fi

# === Check for uncommitted changes ===
print_header "Checking Repository Status"

# Add all files
git add .

# Check if there are changes to commit
if ! git diff-index --quiet HEAD 2>/dev/null; then
    print_info "Uncommitted changes found"
    git status --short
    echo
    read -p "Commit these changes? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        read -p "Enter commit message: " commit_msg
        git commit -m "${commit_msg:-Update NAS mount scripts}"
        print_success "Changes committed"
    fi
else
    print_success "No uncommitted changes"
fi

# === Push to GitHub ===
print_header "Pushing to GitHub"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    # No branch yet (new repo)
    git branch -M main
    CURRENT_BRANCH="main"
    print_info "Created branch: main"
fi

# Push
print_info "Pushing to origin/$CURRENT_BRANCH..."
if git push -u origin "$CURRENT_BRANCH"; then
    print_success "Successfully pushed to GitHub!"
else
    print_error "Push failed. Please check your GitHub credentials and repository permissions."
    exit 1
fi

# === Create initial tag if this is the first push ===
if ! git tag | grep -q .; then
    print_header "Creating Initial Release"
    read -p "Create v1.0.0 release tag? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git tag -a v1.0.0 -m "Initial release - Cross-platform NAS mount manager"
        git push origin v1.0.0
        print_success "Release v1.0.0 created!"
        print_info "GitHub Actions will create a release automatically"
    fi
fi

# === Summary ===
print_header "Summary"

echo "Repository URL: https://github.com/jdpierce21/nas_mount"
echo
echo "One-line installation:"
echo "  curl -fsSL https://raw.githubusercontent.com/jdpierce21/nas_mount/main/install.sh | bash"
echo
echo "Clone URL:"
echo "  git clone $REPO_URL"
echo
echo "To create a new release:"
echo "  git tag vX.Y.Z"
echo "  git push origin vX.Y.Z"
echo
print_success "All done! Your NAS mount scripts are now on GitHub."