#!/bin/bash

# Configuration
VERSION="1.4.1"
YEAR=$(date +%Y)
WEEK=$(date +%V) # ISO week number
DEFAULT_BRANCH="release/Y${YEAR}W${WEEK}"
UPDATE_URL="https://raw.githubusercontent.com/Danushka96/release-script/main/release.sh"

# Function to check and install dependencies
check_dependencies() {
    if ! command -v gum &> /dev/null; then
        echo -e "\033[1;33mGum is not installed.\033[0m Gum is required for this rich TUI experience."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            read -p "Would you like to install it via Homebrew? (y/n): " INSTALL_GUM
            if [[ "$INSTALL_GUM" =~ ^[Yy]$ ]]; then
                brew install gum
            else
                echo "Gum is required. Exiting."
                exit 1
            fi
        else
            echo "Please install gum: https://github.com/charmbracelet/gum"
            exit 1
        fi
    fi
}

# Function to show usage
usage() {
    echo "Usage: release [command]"
    echo ""
    echo "Commands:"
    echo "  install   Install the script globally as 'release'"
    echo "  version   Show the current version"
    echo "  update    Update the script to the latest version"
    echo "  help      Show this help message"
    echo ""
    echo "If no command is provided, starts the interactive release process."
}

# Function to get last 2 tags
show_last_tags() {
    local pattern="$1"
    echo -e "\n\033[1;34mLast 2 tags matching '$pattern':\033[0m"
    git tag --sort=-v:refname -l "$pattern*" | head -n 2
}

# Handle CLI arguments
case "$1" in
    install)
        SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
        LOCAL_BIN="$HOME/.local/bin"
        mkdir -p "$LOCAL_BIN"
        
        echo "Select installation directory:"
        INSTALL_CHOICE=$(gum choose "System global (/usr/local/bin/release) - Requires sudo" "User local ($LOCAL_BIN/release) - No sudo required")
        
        if [[ "$INSTALL_CHOICE" == "System"* ]]; then
            sudo ln -sf "$SCRIPT_PATH" /usr/local/bin/release
        else
            ln -sf "$SCRIPT_PATH" "$LOCAL_BIN/release"
            echo -e "\n\033[1;33mIMPORTANT:\033[0m Make sure $LOCAL_BIN is in your PATH."
            echo "Add this to your ~/.zshrc if needed:"
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        fi
        exit 0
        ;;
    version)
        echo "Release Automation Script v$VERSION"
        exit 0
        ;;
    update)
        SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
        echo "Checking for updates from $UPDATE_URL..."
        if curl -s -f "$UPDATE_URL" -o "${SCRIPT_PATH}.tmp"; then
            mv "${SCRIPT_PATH}.tmp" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            echo "Successfully updated to the latest version."
        else
            echo "Failed to download update. Please check your connection or the URL."
            rm -f "${SCRIPT_PATH}.tmp"
            exit 1
        fi
        exit 0
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    "")
        # Check dependencies only for interactive mode
        check_dependencies
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

# Start Interactive Release
# Circles Life Brand Colors (24-bit ANSI)
VIOLET="\033[38;2;100;0;255m"
SAFFRON="\033[38;2;241;195;65m"
RESET="\033[0m"

echo -e "${VIOLET}"
echo "   ______ _____ _____   _____ _      ______  _____   _      _____ ______ ______ "
echo "  / ____|_   _|  __ \ / ____| |    |  ____|/ ____| | |    |_   _|  ____|  ____|"
echo " | |      | | | |__) | |    | |    | |__  | (___   | |      | | | |__  | |__   "
echo " | |      | | |  _  /| |    | |    |  __|  \___ \  | |      | | |  __| |  __|  "
echo " | |____ _| |_| | \ \| |____| |____| |____ ____) | | |____ _| |_| |    | |____ "
echo "  \____|_____|_|  \_ \\______|______|______|_____/  |______|_____|_|    |______|"
echo -e "${RESET}"
echo -e "                          ${SAFFRON}--- CIRCLES LIFE SRI LANKA ---${RESET}"
echo "                     --- Release Automation Script v$VERSION ---"

# 1. Environment Selection
MODE=$(gum choose "Pre-Prod (RC Release)" "Prod (Version Release)")

if [[ "$MODE" == "Pre-Prod"* ]]; then
    ENV_MODE="PREPROD"
else
    ENV_MODE="PROD"
fi

# 2. Branch Management
TARGET_BRANCH=$(gum input --placeholder "Enter release branch name" --value "$DEFAULT_BRANCH")

# Derive Year and Week from the selected branch
if [[ "$TARGET_BRANCH" =~ release/Y([0-9]{4})W([0-9]{2}) ]]; then
    YEAR_DERIVED="${BASH_REMATCH[1]}"
    WEEK_DERIVED="${BASH_REMATCH[2]}"
    TAG_PREFIX="Y${YEAR_DERIVED}W${WEEK_DERIVED}"
    echo -e "\n\033[1;34mINFO:\033[0m Derived tag prefix '$TAG_PREFIX' from branch '$TARGET_BRANCH'"
else
    TAG_PREFIX="Y${YEAR}W${WEEK}" 
fi

# Check if branch exists
if git branch -a | grep -q "remotes/origin/$TARGET_BRANCH"; then
    echo -e "\nBranch 'origin/$TARGET_BRANCH' exists."
    gum confirm "Checkout and pull master into $TARGET_BRANCH?" && \
    gum spin --title "Updating branch..." -- bash -c "git checkout $TARGET_BRANCH && git pull origin master"
else
    echo -e "\nBranch '$TARGET_BRANCH' does not exist."
    gum confirm "Create branch $TARGET_BRANCH from master?" && \
    gum spin --title "Creating branch..." -- bash -c "git checkout master && git pull origin master && git checkout -b $TARGET_BRANCH && git push -u origin $TARGET_BRANCH"
fi

# 3. Pull and Log
gum confirm "Pull Master into current branch?" && \
gum spin --title "Pulling from master..." -- git pull origin master

# Show changes since last tag
if [[ "$ENV_MODE" == "PREPROD" ]]; then
    LAST_TAG=$(git tag -l "${TAG_PREFIX}-RC*" --sort=-v:refname | head -n 1)
else
    LAST_TAG=$(git tag -l "[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n 1)
fi

if [[ -n "$LAST_TAG" ]]; then
    echo -e "\n\033[1;34mChanges since last relevant tag ($LAST_TAG):\033[0m"
    git log "$LAST_TAG"..HEAD --oneline
else
    echo -e "\n\033[1;34mNo previous relevant tags found. Showing last 10 commits:\033[0m"
    git log -n 10 --oneline
fi

gum confirm "Push changes to $TARGET_BRANCH?" && \
gum spin --title "Pushing changes..." -- git push

# 4. Tag Management
if [[ "$ENV_MODE" == "PREPROD" ]]; then
    show_last_tags "$TAG_PREFIX"
    
    LATEST_TAG=$(git tag -l "${TAG_PREFIX}-RC*" --sort=-v:refname | head -n 1)
    if [[ -z "$LATEST_TAG" ]]; then
        NEXT_TAG="${TAG_PREFIX}-RC1"
    else
        RC_NUM=$(echo "$LATEST_TAG" | grep -o 'RC[0-9]*' | sed 's/RC//')
        NEXT_RC=$((RC_NUM + 1))
        NEXT_TAG="${TAG_PREFIX}-RC${NEXT_RC}"
    fi
    
    gum confirm "Create and push tag $NEXT_TAG?" && \
    gum spin --title "Tagging..." -- bash -c "git tag $NEXT_TAG && git push origin tag $NEXT_TAG"

else
    show_last_tags ""
    PROD_TAG=$(gum input --placeholder "Enter new version tag (e.g., 1.5.2)")
    if [[ -z "$PROD_TAG" ]]; then echo "Aborted."; exit 1; fi
    
    gum confirm "Create and push tag $PROD_TAG?" && \
    gum spin --title "Tagging..." -- bash -c "git tag $PROD_TAG && git push origin tag $PROD_TAG"
fi

echo -e "\n\033[1;32mRelease Complete!\033[0m"
