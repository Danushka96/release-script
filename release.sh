#!/bin/bash

# Configuration
VERSION="1.6.0"
YEAR=$(date +%Y)
WEEK=$(date +%V) # ISO week number
DEFAULT_BRANCH="release/Y${YEAR}W${WEEK}"
UPDATE_URL="https://raw.githubusercontent.com/Danushka96/release-script/main/release.sh"
LOG_FILE="./release.log"
BANNER_WIDTH=80

# Handle Interrupts
trap_exit() {
    echo -e "\n\033[1;31mInterrupted by user. Exiting...\033[0m"
    log "Script interrupted by user."
    # Kill the current process group to ensure subshells/tools also exit
    trap - SIGINT SIGTERM # Prevent recursion
    kill -SIGINT -$$ 2>/dev/null
    exit 1
}
trap trap_exit SIGINT SIGTERM

# Logging Function
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Centering Function (ANSI Aware)
center_text() {
    local text="$1"
    local width=$BANNER_WIDTH
    # Use perl to strip ANSI escape codes reliably across platforms
    local plain_text=$(echo -e "$text" | perl -pe 's/\x1b\[[0-9;]*[mK]//g')
    local text_len=${#plain_text}
    local padding=$(( (width - text_len) / 2 ))
    if [ $padding -lt 0 ]; then padding=0; fi
    # Print leading padding
    printf "%${padding}s" ""
    echo -e "$text"
}

# Resolve Running User
GIT_USER_NAME=$(git config user.name || echo "Unknown User")
GIT_USER_EMAIL=$(git config user.email || echo "unknown@email.com")

# Initialize Log File
echo "--- Release Started ---" > "$LOG_FILE"
log "Script Source: $0"
log "Working Directory: $(pwd)"
log "User: $GIT_USER_NAME <$GIT_USER_EMAIL>"
log "Version: $VERSION"

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
    echo "  logs      View the release execution logs"
    echo "  help      Show this help message"
    echo ""
    echo "If no command is provided, starts the interactive release process."
}

# Function to show banner
show_banner() {
    local VIOLET="\033[38;2;160;70;255m"  # Brighter Neon Violet
    local SAFFRON="\033[38;2;255;220;60m" # Brighter Electric Saffron
    local RESET="\033[0m"

    echo -e "${VIOLET}"
    echo "   ______ _____ _____   _____ _      ______  _____   _      _____ ______ ______ "
    echo "  / ____|_   _|  __ \ / ____| |    |  ____|/ ____| | |    |_   _|  ____|  ____|"
    echo " | |      | | | |__) | |    | |    | |__  | (___   | |      | | | |__  | |__   "
    echo " | |      | | |  _  /| |    | |    |  __|  \___ \  | |      | | |  __| |  __|  "
    echo " | |____ _| |_| | \ \| |____| |____| |____ ____) | | |____ _| |_| |    | |____ "
    echo "  \____|_____|_|  \_ \______|______|______|_____/  |______|_____|_|    |______|"
    echo -e "${RESET}"
    center_text "${SAFFRON}--- CIRCLES LIFE SRI LANKA ---${RESET}"
    center_text "--- Release Automation Script v$VERSION ---"
    center_text "\033[1mRunning as: $GIT_USER_NAME <$GIT_USER_EMAIL>\033[0m"
    echo ""
}

# Function to get last 2 tags
show_last_tags() {
    local pattern="$1"
    echo -e "\n\033[1;34mLast 2 tags matching '$pattern':\033[0m"
    git tag --sort=-v:refname -l "$pattern*" | head -n 2
}

# 0. Git Repository Check
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "\033[1;31mERROR:\033[0m Not a git repository (or any of the parent directories)."
    exit 1
fi

# Detect Primary Branch (main or master)
PRIMARY_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [[ -z "$PRIMARY_BRANCH" ]]; then
    if git branch -r | grep -q "origin/main"; then
        PRIMARY_BRANCH="main"
    else
        PRIMARY_BRANCH="master"
    fi
fi
log "Detected Primary Branch: $PRIMARY_BRANCH"

# Handle CLI arguments
case "$1" in
    install)
        SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
        LOCAL_BIN="$HOME/.local/bin"
        mkdir -p "$LOCAL_BIN"
        
        echo "Select installation directory:"
        INSTALL_CHOICE=$(gum choose "System global (/usr/local/bin/release) - Requires sudo" "User local ($LOCAL_BIN/release) - No sudo required") || exit 1
        
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
    logs)
        if [[ -f "$LOG_FILE" ]]; then
            cat "$LOG_FILE"
        else
            echo "No log file found at $LOG_FILE"
        fi
        exit 0
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    "")
        # Start interactive process
        check_dependencies
        show_banner
        
        # NEW: Fetch all remote status first
        gum spin --title "Fetching from remote..." -- bash -c "git fetch --all >> '$LOG_FILE' 2>&1"
        
        # NEW: Dirty Repo Check
        if [[ -n $(git status --porcelain) ]]; then
            echo -e "\033[1;33mWARNING:\033[0m You have uncommitted or untracked changes."
            log "Warning: Dirty repository detected."
            if ! gum confirm --default=yes "Uncommitted changes might cause checkout/pull failures. Proceed anyway?"; then
                log "Release aborted by user due to dirty repository."
                exit 1
            fi
        fi
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

# 1. Environment Selection
MODE=$(gum choose --header "Select Environment" "Pre-Prod (RC Release)" "Prod (Version Release)") || exit 1

if [[ "$MODE" == "Pre-Prod"* ]]; then
    ENV_MODE="PREPROD"
else
    ENV_MODE="PROD"
fi
log "Environment: $ENV_MODE"

# 2. Branch Management
TARGET_BRANCH=$(gum input --placeholder "Enter release branch name" --value "$DEFAULT_BRANCH") || exit 1
log "Target Branch: $TARGET_BRANCH"

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
    if gum confirm --default=yes "Checkout and pull $PRIMARY_BRANCH into $TARGET_BRANCH?"; then
        log "Action: Update existing branch $TARGET_BRANCH from $PRIMARY_BRANCH"
        gum spin --title "Updating branch..." -- bash -c "(git checkout $TARGET_BRANCH && git pull origin $PRIMARY_BRANCH) >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
    fi
else
    echo -e "\nBranch '$TARGET_BRANCH' does not exist."
    if gum confirm --default=yes "Create branch $TARGET_BRANCH from $PRIMARY_BRANCH?"; then
        log "Action: Create new branch $TARGET_BRANCH from $PRIMARY_BRANCH"
        gum spin --title "Creating branch..." -- bash -c "(git checkout $PRIMARY_BRANCH && git pull origin $PRIMARY_BRANCH && git checkout -b $TARGET_BRANCH && git push -u origin $TARGET_BRANCH) >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
    fi
fi

# 3. Pull and Log
if gum confirm --default=yes "Pull $PRIMARY_BRANCH into current branch?"; then
    log "Action: Pull $PRIMARY_BRANCH"
    gum spin --title "Pulling from $PRIMARY_BRANCH..." -- bash -c "git pull origin $PRIMARY_BRANCH >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
fi

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

if gum confirm --default=yes "Push changes to $TARGET_BRANCH?"; then
    log "Action: Push changes to $TARGET_BRANCH"
    gum spin --title "Pushing changes..." -- bash -c "git push origin $TARGET_BRANCH >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
fi

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
    
    if gum confirm --default=yes "Create and push tag $NEXT_TAG?"; then
        log "Action: Create tag $NEXT_TAG"
        gum spin --title "Tagging..." -- bash -c "(git tag $NEXT_TAG && git push origin $NEXT_TAG) >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
    fi

else
    show_last_tags ""
    PROD_TAG=$(gum input --placeholder "Enter new version tag (e.g., 1.5.2)") || exit 1
    if [[ -z "$PROD_TAG" ]]; then log "Tagging aborted"; exit 1; fi
    
    if gum confirm --default=yes "Create and push tag $PROD_TAG?"; then
        log "Action: Create version tag $PROD_TAG"
        gum spin --title "Tagging..." -- bash -c "(git tag $PROD_TAG && git push origin $PROD_TAG) >> $LOG_FILE 2>&1" || { echo "Git operation failed. Check $LOG_FILE"; exit 1; }
    fi
fi

echo -e "\n\033[1;32mRelease Complete!\033[0m"
log "--- Release Complete ---"
