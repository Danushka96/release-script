#!/bin/bash

# Configuration
VERSION="1.1.0"
YEAR=$(date +%Y)
WEEK=$(date +%V) # ISO week number
DEFAULT_BRANCH="release/Y${YEAR}W${WEEK}"

# Function to show usage
usage() {
    echo "Usage: release [command]"
    echo ""
    echo "Commands:"
    echo "  install   Install the script globally as 'release'"
    echo "  version   Show the current version"
    echo "  update    Update the script (placeholder)"
    echo "  help      Show this help message"
    echo ""
    echo "If no command is provided, starts the interactive release process."
}

# Function to confirm action
confirm() {
    local message="$1"
    local command="$2"
    echo -e "\n\033[1;33mPROPOSAL:\033[0m $message"
    echo -e "\033[1;32mCOMMAND:\033[0m $command"
    read -p "Press ENTER to execute or Ctrl+C to abort..."
    eval "$command"
}

# Handle CLI arguments
case "$1" in
    install)
        SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
        confirm "Install script to /usr/local/bin/release?" "sudo ln -sf \"$SCRIPT_PATH\" /usr/local/bin/release"
        exit 0
        ;;
    version)
        echo "Release Automation Script v$VERSION"
        exit 0
        ;;
    update)
        echo "Update command will be available in future versions (via GitHub)."
        exit 0
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    "")
        # No arguments, continue to interactive mode
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

echo "--- Release Automation Script v$VERSION ---"

# Function to get last 2 tags
show_last_tags() {
    local pattern="$1"
    echo -e "\n\033[1;34mLast 2 tags matching '$pattern':\033[0m"
    git tag --sort=-v:refname -l "$pattern*" | head -n 2
}

# 1. Environment Selection
echo "Select Environment:"
echo "1) Pre-Prod (RC Release)"
echo "2) Prod (Version Release)"
read -p "Selection (1/2): " ENV_CHOICE

if [[ "$ENV_CHOICE" == "1" ]]; then
    MODE="PREPROD"
    TAG_PREFIX="Y${YEAR}W${WEEK}"
elif [[ "$ENV_CHOICE" == "2" ]]; then
    MODE="PROD"
else
    echo "Invalid selection. Exiting."
    exit 1
fi

# 2. Branch Management
read -p "Enter release branch name [default: $DEFAULT_BRANCH]: " TARGET_BRANCH
TARGET_BRANCH=${TARGET_BRANCH:-$DEFAULT_BRANCH}

# Check if branch exists locally or remotely
if git branch -a | grep -q "remotes/origin/$TARGET_BRANCH"; then
    echo "Branch 'origin/$TARGET_BRANCH' exists."
    confirm "Checkout and pull master into $TARGET_BRANCH" "git checkout $TARGET_BRANCH && git pull origin master"
else
    echo "Branch '$TARGET_BRANCH' does not exist."
    confirm "Create branch $TARGET_BRANCH from master" "git checkout master && git pull origin master && git checkout -b $TARGET_BRANCH && git push -u origin $TARGET_BRANCH"
fi

# 3. Pull and Log
confirm "Pull Master into current branch" "git pull origin master"
confirm "Show logs" "git log -n 5 --oneline"
confirm "Push changes" "git push"

# 4. Tag Management
if [[ "$MODE" == "PREPROD" ]]; then
    show_last_tags "$TAG_PREFIX"
    
    # Simple increment logic
    LATEST_TAG=$(git tag -l "${TAG_PREFIX}-RC*" --sort=-v:refname | head -n 1)
    if [[ -z "$LATEST_TAG" ]]; then
        NEXT_TAG="${TAG_PREFIX}-RC1"
    else
        RC_NUM=$(echo "$LATEST_TAG" | grep -o 'RC[0-9]*' | sed 's/RC//')
        NEXT_RC=$((RC_NUM + 1))
        NEXT_TAG="${TAG_PREFIX}-RC${NEXT_RC}"
    fi
    
    confirm "Create tag $NEXT_TAG" "git tag $NEXT_TAG"
    confirm "Push tag $NEXT_TAG" "git push origin tag $NEXT_TAG"

else
    # Prod Mode
    show_last_tags ""
    read -p "Enter new version tag (e.g., 1.5.2): " PROD_TAG
    if [[ -z "$PROD_TAG" ]]; then
        echo "Tag cannot be empty. Exiting."
        exit 1
    fi
    
    confirm "Create tag $PROD_TAG" "git tag $PROD_TAG"
    confirm "Push tag $PROD_TAG" "git push origin tag $PROD_TAG"
fi

echo -e "\n\033[1;32mRelease Complete!\033[0m"
