#!/bin/bash
#
# Backup Repository Cleanup Tool
# Identifies and removes files matching .gitignore patterns with user confirmation
#
# Usage: ./cleanup.sh [--dry-run] [--tracked-only] [--untracked-only] [--auto-commit]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command-line flags
DRY_RUN=false
TRACKED_ONLY=false
UNTRACKED_ONLY=false
AUTO_COMMIT=false

# Arrays to store files
declare -a tracked_files
declare -a untracked_files
declare -A file_sizes

# ===== Logging Functions =====

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo -e "${BLUE}$*${NC}"
}

# ===== Help Function =====

show_help() {
    cat << 'EOF'
Backup Repository Cleanup Tool

Identifies and removes files matching .gitignore patterns with user confirmation.
Handles both git-tracked and untracked files safely.

Usage: ./cleanup.sh [OPTIONS]

Options:
  --dry-run           Show what would be deleted without deleting
  --tracked-only      Only remove git-tracked files (from git)
  --untracked-only    Only delete untracked files (from filesystem)
  --auto-commit       Automatically commit removed git-tracked files
  -h, --help          Show this help message

Examples:
  ./cleanup.sh --dry-run              # Preview changes
  ./cleanup.sh                        # Interactive cleanup with confirmation
  ./cleanup.sh --tracked-only         # Only remove tracked files from git
  ./cleanup.sh --untracked-only       # Only delete untracked files

Safety:
  - Essential files are never deleted (.git, .gitignore, scripts)
  - Shows full list before deletion
  - Requires explicit confirmation
  - Dry-run mode available for preview
EOF
}

# ===== Validation Functions =====

check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository. Please run this script from a git repository."
        exit 1
    fi
}

should_exclude() {
    local file="$1"

    # Never delete essential files
    if [[ "$file" == ".git" ]] || \
       [[ "$file" == ".gitignore" ]] || \
       [[ "$file" == "cleanup.sh" ]] || \
       [[ "$file" == "backup.sh" ]] || \
       [[ "$file" == "restore.sh" ]] || \
       [[ "$file" == "MACHINES.md" ]] || \
       [[ "$file" == "README.md" ]] || \
       [[ "$file" == .claude* ]]; then
        return 0  # Should exclude (true)
    fi

    return 1  # Should not exclude (false)
}

# ===== File Discovery Functions =====

get_file_size() {
    local file="$1"
    if [ -e "$file" ]; then
        du -sh "$file" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

is_git_tracked() {
    local file="$1"
    git ls-files --error-unmatch "$file" &>/dev/null
}

find_gitignored_files() {
    log_info "Scanning for files matching .gitignore patterns..."

    # Find all files that match .gitignore patterns
    local count=0
    while IFS= read -r file; do
        # Skip if file doesn't exist
        [ -e "$file" ] || continue

        # Skip excluded files and directories
        if should_exclude "$file"; then
            continue
        fi

        # Categorize as tracked or untracked
        if is_git_tracked "$file"; then
            tracked_files+=("$file")
            file_sizes["$file"]=$(get_file_size "$file")
        else
            untracked_files+=("$file")
            file_sizes["$file"]=$(get_file_size "$file")
        fi

        count=$((count + 1))
    done < <(find . -type f -not -path './.git/*' 2>/dev/null | while read -r file; do
        if git check-ignore "$file" 2>/dev/null; then
            echo "$file"
        fi
    done)

    if [ $count -eq 0 ]; then
        log_warn "No files matching .gitignore patterns found."
        return 1
    fi

    return 0
}

# ===== Size Calculation =====

calculate_total_size() {
    local files=("$@")
    local total=0

    for file in "${files[@]}"; do
        if [ -e "$file" ]; then
            local size=$(du -sb "$file" 2>/dev/null | awk '{print $1}')
            total=$((total + size))
        fi
    done

    # Convert to human-readable format
    if [ $total -eq 0 ]; then
        echo "0B"
    elif [ $total -lt 1024 ]; then
        echo "${total}B"
    elif [ $total -lt 1048576 ]; then
        echo "$((total / 1024))KB"
    elif [ $total -lt 1073741824 ]; then
        echo "$((total / 1048576))MB"
    else
        echo "$((total / 1073741824))GB"
    fi
}

# ===== Display Functions =====

show_summary() {
    local tracked_count=${#tracked_files[@]}
    local untracked_count=${#untracked_files[@]}
    local total_count=$((tracked_count + untracked_count))

    if [ $total_count -eq 0 ]; then
        log_warn "No files to clean up."
        return 1
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              CLEANUP ANALYSIS REPORT                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "FOUND FILES MATCHING .GITIGNORE PATTERNS:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Show tracked files
    if [ $tracked_count -gt 0 ]; then
        echo "GIT-TRACKED FILES (will be removed from repository):"
        local tracked_total=0
        local shown=0
        for file in "${tracked_files[@]}"; do
            shown=$((shown + 1))
            local size="${file_sizes[$file]}"
            if [ $shown -le 10 ]; then
                printf "  ✗ %-55s (%s)\n" "$file" "$size"
            fi
        done
        if [ $tracked_count -gt 10 ]; then
            echo "  ... and $((tracked_count - 10)) more files"
        fi
        echo ""
        tracked_total=$(calculate_total_size "${tracked_files[@]}")
        echo "  Subtotal: $tracked_count files, $tracked_total"
        echo ""
    fi

    # Show untracked files
    if [ $untracked_count -gt 0 ]; then
        echo "UNTRACKED FILES (will be deleted from filesystem):"
        local untracked_total=0
        local shown=0
        for file in "${untracked_files[@]}"; do
            shown=$((shown + 1))
            local size="${file_sizes[$file]}"
            if [ $shown -le 10 ]; then
                printf "  ✗ %-55s (%s)\n" "$file" "$size"
            fi
        done
        if [ $untracked_count -gt 10 ]; then
            echo "  ... and $((untracked_count - 10)) more files"
        fi
        echo ""
        untracked_total=$(calculate_total_size "${untracked_files[@]}")
        echo "  Subtotal: $untracked_count files, $untracked_total"
        echo ""
    fi

    # Show total impact
    echo "TOTAL IMPACT:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Files to process: $total_count"

    local all_files=("${tracked_files[@]}" "${untracked_files[@]}")
    local total_size=$(calculate_total_size "${all_files[@]}")
    echo "  Space to free: $total_size"

    if [ $tracked_count -gt 0 ]; then
        echo "  Git-tracked files: $tracked_count (will be staged for commit)"
    fi
    if [ $untracked_count -gt 0 ]; then
        echo "  Untracked files: $untracked_count (will be permanently deleted)"
    fi
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "MODE: DRY-RUN (no files will be deleted)"
        echo ""
    fi

    return 0
}

# ===== Confirmation =====

confirm_cleanup() {
    if [ "$DRY_RUN" = true ]; then
        return 0  # Auto-approve in dry-run mode
    fi

    read -p "Proceed with cleanup? (y/N): " -r confirm
    echo ""

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        log_warn "Cleanup cancelled by user"
        return 1
    fi
}

# ===== Execution =====

execute_cleanup() {
    local total_removed=0
    local total_deleted=0

    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              EXECUTING CLEANUP                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Process tracked files
    if [ ${#tracked_files[@]} -gt 0 ] && [ "$UNTRACKED_ONLY" != true ]; then
        echo "Removing git-tracked files from repository..."
        for file in "${tracked_files[@]}"; do
            local size="${file_sizes[$file]}"
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Would remove: $file ($size)"
            else
                git rm -r --cached "$file" &>/dev/null || true
                log_info "Removed from git: $file ($size)"
                total_removed=$((total_removed + 1))
            fi
        done
        echo ""
    fi

    # Process untracked files
    if [ ${#untracked_files[@]} -gt 0 ] && [ "$TRACKED_ONLY" != true ]; then
        echo "Deleting untracked files..."
        for file in "${untracked_files[@]}"; do
            local size="${file_sizes[$file]}"
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Would delete: $file ($size)"
            else
                rm -rf "$file" 2>/dev/null || log_warn "Could not delete: $file"
                log_info "Deleted: $file ($size)"
                total_deleted=$((total_deleted + 1))
            fi
        done
        echo ""
    fi

    # Summary
    echo "╔════════════════════════════════════════════════════════════════╗"
    if [ "$DRY_RUN" = true ]; then
        echo "║              DRY-RUN COMPLETE (no changes made)             ║"
    else
        echo "║              CLEANUP COMPLETED                             ║"
    fi
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" != true ]; then
        if [ $total_removed -gt 0 ]; then
            log_info "Removed from git tracking: $total_removed files"
        fi
        if [ $total_deleted -gt 0 ]; then
            log_info "Deleted from filesystem: $total_deleted files"
        fi

        local all_files=("${tracked_files[@]}" "${untracked_files[@]}")
        local total_size=$(calculate_total_size "${all_files[@]}")
        log_info "Total space freed: $total_size"
        echo ""

        # Check git status
        if [ $total_removed -gt 0 ]; then
            echo "Git status: $total_removed files staged for removal"
            echo ""
            echo "Next steps:"
            echo "  1. Review changes: git status"
            echo "  2. Commit changes: git commit -m 'Remove gitignored files from tracking'"
            echo ""

            if [ "$AUTO_COMMIT" = true ]; then
                echo "Auto-committing changes..."
                git commit -m "Remove gitignored files from tracking

Cleaned up files matching .gitignore patterns:
- Tracked files: $total_removed
- Freed space: $total_size"
                log_info "Auto-commit completed"
            fi
        fi
    fi
}

# ===== Main =====

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;
            --tracked-only)
                TRACKED_ONLY=true
                ;;
            --untracked-only)
                UNTRACKED_ONLY=true
                ;;
            --auto-commit)
                AUTO_COMMIT=true
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # Validate argument combinations
    if [ "$TRACKED_ONLY" = true ] && [ "$UNTRACKED_ONLY" = true ]; then
        log_error "Cannot use both --tracked-only and --untracked-only"
        exit 1
    fi
}

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           Backup Repository Cleanup Tool                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    parse_arguments "$@"

    check_git_repo

    if ! find_gitignored_files; then
        echo ""
        exit 0
    fi

    if ! show_summary; then
        exit 0
    fi

    if ! confirm_cleanup; then
        exit 1
    fi

    execute_cleanup

    echo "✓ Cleanup process complete."
    echo ""
}

main "$@"
