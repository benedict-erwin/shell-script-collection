#!/bin/bash

# Script Name: rewrite-author.sh
# Description: Rewrites all commits in a git repository to change author and committer information.
#              This script can clone a bare repository first (with --clone flag) or work on existing repository,
#              rewrites the entire commit history using git filter-branch, and prepares it for pushing.
#
# Usage: ./rewrite-author.sh [--clone] "repo_url_or_path" "New Author Name" "new@email.com"
#
# Parameters:
# - --clone (optional): Clone repository first before rewriting
# - repo_url_or_path: URL to clone (with --clone) or path to existing repository
# - new_name: New author name (use quotes if contains spaces)
# - new_email: New author email address
#
# Dependencies:
# - git (for repository operations and filter-branch)
#
# Warning: This operation rewrites git history and is irreversible.
#          Always backup your repository before running this script.
#
# Author: Benedict E. Pranata
# Version: 1.0

# Parse command line arguments
CLONE_FLAG=false
if [ "$1" = "--clone" ]; then
    CLONE_FLAG=true
    shift
fi

# Check if all required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 [--clone] <repo_url_or_path> <new_name> <new_email>"
    echo ""
    echo "Examples:"
    echo "  Clone and rewrite: $0 --clone https://github.com/AccountA/repo-name.git 'Benedict Erwin' benedict@example.com"
    echo "  Rewrite existing:  $0 /path/to/existing/repo.git 'Benedict Erwin' benedict@example.com"
    echo ""
    echo "Arguments:"
    echo "  --clone (optional)   Clone repository first before rewriting"
    echo "  repo_url_or_path     URL to clone (with --clone) or path to existing repository"
    echo "  new_name            New author name (use quotes if contains spaces)"
    echo "  new_email           New author email address"
    exit 1
fi

REPO_URL_OR_PATH="$1"
NEW_NAME="$2"
NEW_EMAIL="$3"

# Handle cloning or use existing repository
if [ "$CLONE_FLAG" = true ]; then
    echo "[INFO] Cloning bare repository from $REPO_URL_OR_PATH ..."
    git clone --bare "$REPO_URL_OR_PATH" temp-repo.git
    REPO_DIR="temp-repo.git"
    cd "$REPO_DIR" || { echo "Failed to enter repo directory"; exit 1; }
else
    echo "[INFO] Using existing repository at $REPO_URL_OR_PATH ..."
    REPO_DIR="$REPO_URL_OR_PATH"
    cd "$REPO_DIR" || { echo "Failed to enter repo directory: $REPO_DIR"; exit 1; }
fi

# Rewrite author information
echo "[INFO] Rewriting all commit authors and committers ..."
git filter-branch --env-filter "
export GIT_AUTHOR_NAME='$NEW_NAME'
export GIT_AUTHOR_EMAIL='$NEW_EMAIL'
export GIT_COMMITTER_NAME='$NEW_NAME'
export GIT_COMMITTER_EMAIL='$NEW_EMAIL'
" --tag-name-filter cat -- --branches --tags

echo "[INFO] Rewrite completed."

# Next steps information
echo
if [ "$CLONE_FLAG" = true ]; then
    echo "[INFO] Now create an empty repository in new account."
    echo "[INFO] Then push the rewritten results to the new repo with:"
    echo
    echo "    cd $REPO_DIR"
    echo "    git push --force --mirror <new_github_repo_url>"
    echo
    echo "[INFO] Example:"
    echo "    git push --force --mirror https://github.com/AccountB/repo-name.git"
else
    echo "[INFO] Repository history has been rewritten in-place."
    echo "[INFO] If you want to push to a new repository, use:"
    echo
    echo "    git push --force --mirror <new_github_repo_url>"
fi
echo
echo "[INFO] Done. All commits are now under $NEW_NAME <$NEW_EMAIL>."
