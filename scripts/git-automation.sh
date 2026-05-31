#!/bin/bash

################################################################################
# Git Automation Script
# A comprehensive utility to automate common Git operations
# 
# Usage: ./git-automation.sh [command] [options]
# Run with --help for detailed command information
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/git-automation.log"

################################################################################
# Utility Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log ERROR "Not a git repository. Please run this script from a git repository."
        exit 1
    fi
}

get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

get_remote_default_branch() {
    local remote=${1:-origin}
    git symbolic-ref refs/remotes/${remote}/HEAD 2>/dev/null | sed "s@^refs/remotes/${remote}/@@" || echo "main"
}

################################################################################
# Push Operations
################################################################################

push_new_branch() {
    local branch=$1
    
    if [ -z "$branch" ]; then
        branch=$(get_current_branch)
    fi
    
    log INFO "Pushing new branch: $branch"
    git push -u origin "$branch"
    log SUCCESS "Branch '$branch' pushed successfully"
}

force_push_safe() {
    local branch=${1:-$(get_current_branch)}
    
    log WARN "Force pushing branch: $branch (using --force-with-lease for safety)"
    git push --force-with-lease origin "$branch"
    log SUCCESS "Branch '$branch' force pushed successfully"
}

push_tags() {
    log INFO "Pushing all tags to origin"
    git push --tags
    log SUCCESS "Tags pushed successfully"
}

push_all_with_tags() {
    log INFO "Pushing all branches and tags"
    git push origin --all
    git push --tags
    log SUCCESS "All branches and tags pushed successfully"
}

################################################################################
# Pull Operations
################################################################################

fetch_changes() {
    local remote=${1:-origin}
    local branch=${2:-main}
    
    log INFO "Fetching changes from $remote/$branch (without modifying local branches)"
    git fetch "$remote" "$branch"
    log SUCCESS "Fetch completed successfully"
}

pull_with_rebase() {
    local branch=${1:-$(get_current_branch)}
    
    log INFO "Fetching changes and rebasing current branch: $branch"
    git pull --rebase origin "$branch"
    log SUCCESS "Pull with rebase completed successfully"
}

pull_with_merge() {
    local remote=${1:-origin}
    local branch=${2:-$(get_remote_default_branch)}
    
    log INFO "Fetching and merging: $remote/$branch"
    git pull "$remote" "$branch"
    log SUCCESS "Pull with merge completed successfully"
}

################################################################################
# Configuration Operations
################################################################################

set_config() {
    local key=$1
    local value=$2
    local global_flag=$3
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        log ERROR "Usage: set_config <key> <value> [--global]"
        return 1
    fi
    
    if [ "$global_flag" = "--global" ]; then
        log INFO "Setting global git config: $key = $value"
        git config --global "$key" "$value"
        log SUCCESS "Global config set successfully"
    else
        log INFO "Setting local git config: $key = $value"
        git config "$key" "$value"
        log SUCCESS "Local config set successfully"
    fi
}

set_user_config() {
    local name=$1
    local email=$2
    local global_flag=$3
    
    if [ -z "$name" ] || [ -z "$email" ]; then
        log ERROR "Usage: set_user_config <name> <email> [--global]"
        return 1
    fi
    
    if [ "$global_flag" = "--global" ]; then
        log INFO "Setting global user: $name <$email>"
        git config --global user.name "$name"
        git config --global user.email "$email"
    else
        log INFO "Setting local user: $name <$email>"
        git config user.name "$name"
        git config user.email "$email"
    fi
    log SUCCESS "User config set successfully"
}

add_alias() {
    local alias_name=$1
    local command=$2
    local global_flag=$3
    
    if [ -z "$alias_name" ] || [ -z "$command" ]; then
        log ERROR "Usage: add_alias <name> <command> [--global]"
        return 1
    fi
    
    if [ "$global_flag" = "--global" ]; then
        log INFO "Adding global alias: $alias_name -> $command"
        git config --global "alias.$alias_name" "$command"
    else
        log INFO "Adding local alias: $alias_name -> $command"
        git config "alias.$alias_name" "$command"
    fi
    log SUCCESS "Alias added successfully"
}

list_config() {
    local scope=$1
    
    case $scope in
        local)
            log INFO "Local git config:"
            git config --list --local
            ;;
        global)
            log INFO "Global git config:"
            git config --list --global
            ;;
        *)
            log INFO "All git config (local + global):"
            git config --list
            ;;
    esac
}

show_config_file() {
    local scope=${1:-local}
    
    case $scope in
        local)
            log INFO "Local git config file (.git/config):"
            cat .git/config
            ;;
        global)
            log INFO "Global git config file (~/.gitconfig):"
            cat ~/.gitconfig 2>/dev/null || log WARN "Global config file not found"
            ;;
        gitignore)
            if [ -f .gitignore ]; then
                log INFO ".gitignore contents:"
                cat .gitignore
            else
                log WARN ".gitignore file not found"
            fi
            ;;
    esac
}

################################################################################
# Help and Information
################################################################################

show_help() {
    cat <<'EOF'
Git Automation Script - Comprehensive Git Operations Manager

USAGE:
    ./git-automation.sh [command] [options]

PUSH COMMANDS:
    push-new-branch [branch-name]
        Push a new branch upstream with tracking. If no branch name provided, 
        pushes current branch.
        
    force-push [branch-name]
        Safely force push using --force-with-lease. If no branch name provided,
        force pushes current branch.
        
    push-tags
        Push all local tags to origin.
        
    push-all
        Push all branches and tags to origin.

PULL COMMANDS:
    fetch [remote] [branch]
        Fetch changes without modifying local branches.
        Default: origin main
        
    pull-rebase [branch]
        Fetch and rebase current branch. Creates cleaner history.
        Default: current branch
        
    pull-merge [remote] [branch]
        Fetch and merge changes into current branch.
        Default: origin main

CONFIG COMMANDS:
    set-config <key> <value> [--global]
        Set a git config option. Add --global for system-wide config.
        
    set-user <name> <email> [--global]
        Configure user name and email.
        
    add-alias <name> <command> [--global]
        Add a git alias (e.g., "st" for "status").
        
    list-config [local|global]
        List all config options.
        
    show-config [local|global|gitignore]
        Display config file contents.

UTILITY COMMANDS:
    status
        Show repository status and current branch.
        
    branch
        List all branches.
        
    logs [count]
        Show recent commits (default: 5).
        
    help
        Display this help message.

EXAMPLES:
    # Push new feature branch
    ./git-automation.sh push-new-branch feature/my-feature
    
    # Force push current branch safely
    ./git-automation.sh force-push
    
    # Fetch updates from main without changing your branch
    ./git-automation.sh fetch origin main
    
    # Pull with rebase to maintain clean history
    ./git-automation.sh pull-rebase
    
    # Configure global user
    ./git-automation.sh set-user "John Doe" "john@example.com" --global
    
    # Add an alias
    ./git-automation.sh add-alias st status

For more git config options, run: man git-config

EOF
}

################################################################################
# Information Commands
################################################################################

show_status() {
    log INFO "Repository Status"
    echo "Current branch: $(get_current_branch)"
    echo "Default remote branch: $(get_remote_default_branch)"
    echo ""
    git status
}

show_branches() {
    log INFO "Local Branches:"
    git branch -v
    echo ""
    log INFO "Remote Branches:"
    git branch -r
}

show_logs() {
    local count=${1:-5}
    log INFO "Recent commits (last $count):"
    git log --oneline -n "$count"
}

################################################################################
# Main Command Router
################################################################################

main() {
    local command=$1
    shift || true
    
    # Initialize log file
    touch "$LOG_FILE"
    
    # Check if in git repo for most commands
    if [ "$command" != "help" ] && [ -n "$command" ]; then
        check_git_repo
    fi
    
    case $command in
        # Push operations
        push-new-branch)
            push_new_branch "$@"
            ;;
        force-push)
            force_push_safe "$@"
            ;;
        push-tags)
            push_tags
            ;;
        push-all)
            push_all_with_tags
            ;;
        
        # Pull operations
        fetch)
            fetch_changes "$@"
            ;;
        pull-rebase)
            pull_with_rebase "$@"
            ;;
        pull-merge)
            pull_with_merge "$@"
            ;;
        
        # Config operations
        set-config)
            set_config "$@"
            ;;
        set-user)
            set_user_config "$@"
            ;;
        add-alias)
            add_alias "$@"
            ;;
        list-config)
            list_config "$@"
            ;;
        show-config)
            show_config_file "$@"
            ;;
        
        # Information commands
        status)
            show_status
            ;;
        branch)
            show_branches
            ;;
        logs)
            show_logs "$@"
            ;;
        
        help|--help|-h|"")
            show_help
            ;;
        
        *)
            log ERROR "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
