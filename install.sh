#!/bin/bash
set -euo pipefail

# Claude Code Docs Installer v0.3.3 - Changelog integration and compatibility improvements
# This script installs/migrates claude-code-docs to ~/.claude-code-docs

echo "Claude Code Docs Installer v0.3.3"
echo "==============================="

# Fixed installation location
INSTALL_DIR="$HOME/.claude-code-docs"

# Where the installer was started from - never deleted as an "old installation",
# so running this script from a clone of the repo does not wipe that clone
ORIGINAL_PWD="$(pwd)"

# Branch to use for installation
INSTALL_BRANCH="main"

# Slash command name - override with: CLAUDE_DOCS_COMMAND_NAME=mydocs ./install.sh
COMMAND_NAME="${CLAUDE_DOCS_COMMAND_NAME:-claude-docs}"

if [[ ! "$COMMAND_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "❌ Error: invalid command name: $COMMAND_NAME"
    echo "Only letters, digits, hyphens and underscores are allowed"
    exit 1
fi

COMMAND_FILE="$HOME/.claude/commands/${COMMAND_NAME}.md"

# Command file used by installs before the command was renamed
LEGACY_COMMAND_FILE="$HOME/.claude/commands/docs.md"

# Detect OS type
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    echo "✓ Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    echo "✓ Detected Linux"
else
    echo "❌ Error: Unsupported OS type: $OSTYPE"
    echo "This installer supports macOS and Linux only"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
for cmd in git jq curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: $cmd is required but not installed"
        echo "Please install $cmd and try again"
        exit 1
    fi
done
echo "✓ All dependencies satisfied"


# Function to find existing installations from configs
find_existing_installations() {
    local paths=()
    
    # Check command files (current name and the legacy /docs one) for paths
    local cmd_file
    for cmd_file in "$COMMAND_FILE" "$LEGACY_COMMAND_FILE"; do
        [[ -f "$cmd_file" ]] || continue
        # Look for paths in the command file
        # v0.1 format: LOCAL DOCS AT: /path/to/claude-code-docs/docs/
        # v0.2+ format: Execute: /path/to/claude-code-docs/helper.sh
        while IFS= read -r line; do
            # v0.1 format
            if [[ "$line" =~ LOCAL\ DOCS\ AT:\ ([^[:space:]]+)/docs/ ]]; then
                local path="${BASH_REMATCH[1]}"
                path="${path/#\~/$HOME}"
                [[ -d "$path" ]] && paths+=("$path")
            fi
            # v0.2+ format
            if [[ "$line" =~ Execute:.*claude-code-docs ]]; then
                # Extract path from various formats
                local path=$(echo "$line" | grep -o '[^ "]*claude-code-docs[^ "]*' | head -1)
                path="${path/#\~/$HOME}"
                
                # Get directory part
                if [[ -d "$path" ]]; then
                    paths+=("$path")
                elif [[ -d "$(dirname "$path")" ]] && [[ "$(basename "$(dirname "$path")")" == "claude-code-docs" ]]; then
                    paths+=("$(dirname "$path")")
                fi
            fi
        done < "$cmd_file"
    done

    # Check settings.json hooks for paths
    if [[ -f ~/.claude/settings.json ]]; then
        local hooks=$(jq -r '.hooks.PreToolUse[]?.hooks[]?.command // empty' ~/.claude/settings.json 2>/dev/null)
        while IFS= read -r cmd; do
            if [[ "$cmd" =~ claude-code-docs ]]; then
                # Extract paths from v0.1 complex hook format
                # Look for patterns like: "/path/to/claude-code-docs/.last_check"
                local v01_paths=$(echo "$cmd" | grep -o '"[^"]*claude-code-docs[^"]*"' | sed 's/"//g' || true)
                while IFS= read -r path; do
                    [[ -z "$path" ]] && continue
                    # Extract just the directory part
                    if [[ "$path" =~ (.*/claude-code-docs)(/.*)?$ ]]; then
                        path="${BASH_REMATCH[1]}"
                        path="${path/#\~/$HOME}"
                        [[ -d "$path" ]] && paths+=("$path")
                    fi
                done <<< "$v01_paths"
                
                # Also try v0.2+ simpler format
                local found=$(echo "$cmd" | grep -o '[^ "]*claude-code-docs[^ "]*' || true)
                while IFS= read -r path; do
                    [[ -z "$path" ]] && continue
                    path="${path/#\~/$HOME}"
                    # Clean up path to get the claude-code-docs directory
                    if [[ "$path" =~ (.*/claude-code-docs)(/.*)?$ ]]; then
                        path="${BASH_REMATCH[1]}"
                    fi
                    [[ -d "$path" ]] && paths+=("$path")
                done <<< "$found"
            fi
        done <<< "$hooks"
    fi
    
    # Also check current directory if running from an installation
    if [[ -f "$ORIGINAL_PWD/docs/docs_manifest.json" && "$ORIGINAL_PWD" != "$INSTALL_DIR" ]]; then
        paths+=("$ORIGINAL_PWD")
    fi
    
    # Deduplicate and exclude new location
    if [[ ${#paths[@]} -gt 0 ]]; then
        printf '%s\n' "${paths[@]}" | grep -v "^$INSTALL_DIR$" | sort -u
    fi
}

# Function to migrate from old location
migrate_installation() {
    local old_dir="$1"
    
    echo "📦 Found existing installation at: $old_dir"
    echo "   Migrating to: $INSTALL_DIR"
    echo ""
    
    # Check if old dir has uncommitted changes
    local should_preserve=false
    if [[ -d "$old_dir/.git" ]]; then
        cd "$old_dir"
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            should_preserve=true
            echo "⚠️  Uncommitted changes detected in old installation"
        fi
        cd - >/dev/null
    fi
    
    # Fresh install at new location
    echo "Installing fresh at ~/.claude-code-docs..."
    git clone -b "$INSTALL_BRANCH" https://github.com/posimind/claude-code-docs.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Remove old directory if safe
    if [[ "$old_dir" == "$ORIGINAL_PWD" ]]; then
        echo ""
        echo "ℹ️  Old installation preserved at: $old_dir"
        echo "   (you are running the installer from here)"
    elif [[ "$should_preserve" == "false" ]]; then
        echo "Removing old installation..."
        rm -rf "$old_dir"
        echo "✓ Old installation removed"
    else
        echo ""
        echo "ℹ️  Old installation preserved at: $old_dir"
        echo "   (has uncommitted changes)"
    fi
    
    echo ""
    echo "✅ Migration complete!"
}

# Function to safely update git repository
safe_git_update() {
    local repo_dir="$1"
    cd "$repo_dir"
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Determine which branch to use - always use installer's target branch
    local target_branch="$INSTALL_BRANCH"
    
    # Note: Simplified branch switching - no longer need v0.3.1 upgrade detection
    
    # If we're on a different branch or have conflicts, we need to switch
    if [[ "$current_branch" != "$target_branch" ]]; then
        echo "  Switching from $current_branch to $target_branch branch..."
    else
        echo "  Updating $target_branch branch..."
    fi
    
    # Set git config for pull strategy if not set
    if ! git config pull.rebase >/dev/null 2>&1; then
        git config pull.rebase false
    fi
    
    echo "Updating to latest version..."
    
    # Note: Old v0.3.1 upgrade logic removed - new branch switching logic handles all cases
    
    # Try regular pull first (use target branch)
    if git pull --quiet origin "$target_branch" 2>/dev/null; then
        return 0
    fi
    
    # If pull failed, try more aggressive approach
    echo "  Standard update failed, trying harder..."
    
    # Fetch latest
    if ! git fetch origin "$target_branch" 2>/dev/null; then
        echo "  ⚠️  Could not fetch from GitHub (offline?)"
        return 1
    fi
    
    # If we're switching branches, skip the change detection - just force clean
    if [[ "$current_branch" != "$target_branch" ]]; then
        echo "  Branch switch detected, forcing clean state..."
        local needs_user_confirmation=false
    else
        # Check what kind of changes we have (only when staying on same branch)
        local has_conflicts=false
        local has_local_changes=false
        local has_untracked=false
        local needs_user_confirmation=false
        
        # Check for merge conflicts (but ignore conflicts on docs_manifest.json - that's expected)
        local non_manifest_conflicts=$(git status --porcelain | grep "^UU\|^AA\|^DD" | grep -v "docs/docs_manifest.json" 2>/dev/null)
        if [[ -n "$non_manifest_conflicts" ]]; then
            has_conflicts=true
            needs_user_confirmation=true
        fi
        
        # Check for uncommitted changes (but ignore docs_manifest.json - that's expected)
        local non_manifest_changes=$(git status --porcelain | grep -v "docs/docs_manifest.json" 2>/dev/null)
        if [[ -n "$non_manifest_changes" ]]; then
            has_local_changes=true
            needs_user_confirmation=true
        fi
        
        # Check for untracked files (but ignore common temp files)
        if git status --porcelain | grep "^??" | grep -v -E "\.(tmp|log|swp)$" | grep -q . 2>/dev/null; then
            has_untracked=true
            needs_user_confirmation=true
        fi
    fi
    
    # If we have significant changes, ask user for confirmation
    if [[ "$needs_user_confirmation" == "true" ]]; then
        echo ""
        echo "⚠️  WARNING: Local changes detected in your installation:"
        if [[ "$has_conflicts" == "true" ]]; then
            echo "  • Merge conflicts need resolution"
        fi
        if [[ "$has_local_changes" == "true" ]]; then
            echo "  • Modified files (other than docs_manifest.json)"
        fi
        if [[ "$has_untracked" == "true" ]]; then
            echo "  • Untracked files"
        fi
        echo ""
        echo "The installer will reset to a clean state, discarding these changes."
        echo "Note: Changes to docs_manifest.json are handled automatically."
        echo ""
        read -p "Continue and discard local changes? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled. Your local changes are preserved."
            echo "To proceed later, either:"
            echo "  1. Manually resolve the issues, or"
            echo "  2. Run the installer again and choose 'y' to discard changes"
            return 1
        fi
        echo "  Proceeding with clean installation..."
    else
        # If only manifest changes/conflicts (or no changes), proceed silently
        local manifest_only_changes=$(git status --porcelain | grep "docs/docs_manifest.json" 2>/dev/null)
        if [[ -n "$manifest_only_changes" ]]; then
            local conflict_type=$(echo "$manifest_only_changes" | grep "^UU")
            if [[ -n "$conflict_type" ]]; then
                echo "  Resolving manifest file conflicts automatically..."
            else
                echo "  Handling manifest file updates automatically..."
            fi
        fi
    fi
    
    # Force clean state - handle any conflicts, merges, or messy states
    if [[ "$needs_user_confirmation" == "true" ]]; then
        echo "  Forcing clean update (discarding local changes)..."
    else
        echo "  Updating to clean state..."
    fi
    
    # Abort any in-progress merge/rebase
    git merge --abort >/dev/null 2>&1 || true
    git rebase --abort >/dev/null 2>&1 || true
    
    # Clear any stale index
    git reset >/dev/null 2>&1 || true
    
    # Force checkout target branch (handles detached HEAD, wrong branch, etc.)
    git checkout -B "$target_branch" "origin/$target_branch" >/dev/null 2>&1
    
    # Reset to clean state (discards all local changes - user confirmed if needed)
    git reset --hard "origin/$target_branch" >/dev/null 2>&1
    
    # Clean any untracked files that might interfere
    git clean -fd >/dev/null 2>&1 || true
    
    echo "  ✓ Updated successfully to clean state"
    
    return 0
}

# Function to cleanup old installations
cleanup_old_installations() {
    # Use the global OLD_INSTALLATIONS array that was populated before config updates
    if [[ ${#OLD_INSTALLATIONS[@]} -eq 0 ]]; then
        return
    fi
    
    echo ""
    echo "Cleaning up old installations..."
    echo "Found ${#OLD_INSTALLATIONS[@]} old installation(s) to remove:"
    
    for old_dir in "${OLD_INSTALLATIONS[@]}"; do
        # Skip empty paths
        if [[ -z "$old_dir" ]]; then
            continue
        fi
        
        echo "  - $old_dir"

        # Never remove the directory the installer was launched from
        if [[ "$old_dir" == "$ORIGINAL_PWD" ]]; then
            echo "    ⚠️  Preserved (you are running the installer from here)"
            continue
        fi

        # Check if it has uncommitted changes
        if [[ -d "$old_dir/.git" ]]; then
            cd "$old_dir"
            if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
                cd - >/dev/null
                rm -rf "$old_dir"
                echo "    ✓ Removed (clean)"
            else
                cd - >/dev/null
                echo "    ⚠️  Preserved (has uncommitted changes)"
            fi
        else
            echo "    ⚠️  Preserved (not a git repo)"
        fi
    done
}

# Main installation logic
echo ""

# Always find old installations first (before any config changes)
echo "Checking for existing installations..."
existing_installs=()
while IFS= read -r line; do
    [[ -n "$line" ]] && existing_installs+=("$line")
done < <(find_existing_installations)
if [[ ${#existing_installs[@]} -gt 0 ]]; then
    OLD_INSTALLATIONS=("${existing_installs[@]}")  # Save for later cleanup
else
    OLD_INSTALLATIONS=()  # Initialize empty array
fi

if [[ ${#existing_installs[@]} -gt 0 ]]; then
    echo "Found ${#existing_installs[@]} existing installation(s):"
    for install in "${existing_installs[@]}"; do
        echo "  - $install"
    done
    echo ""
fi

# Check if already installed at new location
if [[ -d "$INSTALL_DIR" && -f "$INSTALL_DIR/docs/docs_manifest.json" ]]; then
    echo "✓ Found installation at ~/.claude-code-docs"
    echo "  Updating to latest version..."
    
    # Update it safely
    safe_git_update "$INSTALL_DIR"
    cd "$INSTALL_DIR"
else
    # Need to install at new location
    if [[ ${#existing_installs[@]} -gt 0 ]]; then
        # Migrate from old location
        old_install="${existing_installs[0]}"
        migrate_installation "$old_install"
    else
        # Fresh installation
        echo "No existing installation found"
        echo "Installing fresh to ~/.claude-code-docs..."
        
        git clone -b "$INSTALL_BRANCH" https://github.com/posimind/claude-code-docs.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
fi

# Now we're in $INSTALL_DIR, set up the new script-based system
echo ""
echo "Setting up Claude Code Docs v0.3.3..."

# Replace {{COMMAND_NAME}} placeholders with the configured command name
# (portable across GNU and BSD sed - no in-place flag)
render_command_name() {
    local file="$1"
    sed "s/{{COMMAND_NAME}}/$COMMAND_NAME/g" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Copy helper script from template
echo "Installing helper script..."
if [[ -f "$INSTALL_DIR/scripts/claude-docs-helper.sh.template" ]]; then
    cp "$INSTALL_DIR/scripts/claude-docs-helper.sh.template" "$INSTALL_DIR/claude-docs-helper.sh"
    render_command_name "$INSTALL_DIR/claude-docs-helper.sh"
    chmod +x "$INSTALL_DIR/claude-docs-helper.sh"
    echo "✓ Helper script installed"
else
    echo "  ⚠️  Template file missing, attempting recovery..."
    # Try to fetch just the template file
    if curl -fsSL "https://raw.githubusercontent.com/posimind/claude-code-docs/$INSTALL_BRANCH/scripts/claude-docs-helper.sh.template" -o "$INSTALL_DIR/claude-docs-helper.sh" 2>/dev/null; then
        render_command_name "$INSTALL_DIR/claude-docs-helper.sh"
        chmod +x "$INSTALL_DIR/claude-docs-helper.sh"
        echo "  ✓ Helper script downloaded directly"
    else
        echo "  ❌ Failed to install helper script"
        echo "  Please check your installation and try again"
        exit 1
    fi
fi

# Always update command (in case it points to old location)
echo "Setting up /$COMMAND_NAME command..."
mkdir -p ~/.claude/commands

# Remove old command if it exists
if [[ -f "$COMMAND_FILE" ]]; then
    echo "  Updating existing command..."
fi

# Create simplified docs command
cat > "$COMMAND_FILE" << EOF
Execute the Claude Code Docs helper script at ~/.claude-code-docs/claude-docs-helper.sh

Usage:
- /$COMMAND_NAME - List all available documentation topics
- /$COMMAND_NAME <topic> - Read specific documentation with link to official docs
- /$COMMAND_NAME -t - Check sync status without reading a doc
- /$COMMAND_NAME -t <topic> - Check freshness then read documentation
- /$COMMAND_NAME whats new - Show recent documentation changes (or "what's new")

Examples of expected output:

When reading a doc:
📚 COMMUNITY MIRROR: https://github.com/posimind/claude-code-docs
📖 OFFICIAL DOCS: https://code.claude.com/docs/en

[Doc content here...]

📖 Official page: https://code.claude.com/docs/en/hooks

When showing what's new:
📚 Recent documentation updates:

• 5 hours ago:
  📎 https://github.com/posimind/claude-code-docs/commit/eacd8e1
  📄 data-usage: https://code.claude.com/docs/en/data-usage
     ➕ Added: Privacy safeguards
  📄 security: https://code.claude.com/docs/en/security
     ✨ Data flow and dependencies section moved here

📎 Full changelog: https://github.com/posimind/claude-code-docs/commits/main/docs
📚 COMMUNITY MIRROR - NOT AFFILIATED WITH ANTHROPIC

Every request checks for the latest documentation from GitHub (takes ~0.4s).
The helper script handles all functionality including auto-updates.

Execute: ~/.claude-code-docs/claude-docs-helper.sh "\$ARGUMENTS"
EOF

echo "✓ Created /$COMMAND_NAME command"

# Record the command name so the uninstaller removes the right file
echo "$COMMAND_NAME" > "$INSTALL_DIR/.command_name"

# Warn about a leftover /docs command from an older install
if [[ "$COMMAND_NAME" != "docs" && -f "$LEGACY_COMMAND_FILE" ]] && grep -q "claude-code-docs" "$LEGACY_COMMAND_FILE" 2>/dev/null; then
    echo ""
    echo "ℹ️  An older /docs command still exists at: $LEGACY_COMMAND_FILE"
    echo "   It was left untouched. Remove it if you no longer want /docs:"
    echo "   rm -f $LEGACY_COMMAND_FILE"
fi

# Always update hooks (remove old ones pointing to wrong location)
echo "Setting up hooks..."

# Keeps the mirror fresh when Claude reads from it
HOOK_COMMAND="~/.claude-code-docs/claude-docs-helper.sh hook-check"
# Redirects fetches of code.claude.com to the local mirror
WEBFETCH_HOOK_COMMAND="~/.claude-code-docs/claude-docs-helper.sh webfetch-guard"
# Tells doc-answering subagents about the mirror before they reach for WebFetch
SUBAGENT_HOOK_COMMAND="~/.claude-code-docs/claude-docs-helper.sh subagent-context"
SUBAGENT_MATCHER="claude-code-guide"

# One program for both branches: with null input (-n) the assignments build the
# object from scratch, so a missing settings.json needs no separate template.
# strip_ours drops hooks from any previous install, at any path.
HOOK_JQ_PROGRAM='
def strip_ours(list): [ (list // [])[]
    | select((((.hooks // [])[0].command) // "") | contains("claude-code-docs") | not) ];

.hooks.PreToolUse = strip_ours(.hooks.PreToolUse) + [
    { matcher: "Read",     hooks: [{ type: "command", command: $read_cmd }] },
    { matcher: "WebFetch", hooks: [{ type: "command", command: $web_cmd }] }
]
| .hooks.SubagentStart = strip_ours(.hooks.SubagentStart) + [
    { matcher: $agent_matcher, hooks: [{ type: "command", command: $sub_cmd }] }
]'

if [ -f ~/.claude/settings.json ]; then
    echo "  Updating Claude settings..."
    jq --arg read_cmd "$HOOK_COMMAND" \
       --arg web_cmd "$WEBFETCH_HOOK_COMMAND" \
       --arg sub_cmd "$SUBAGENT_HOOK_COMMAND" \
       --arg agent_matcher "$SUBAGENT_MATCHER" \
       "$HOOK_JQ_PROGRAM" ~/.claude/settings.json > ~/.claude/settings.json.tmp
    mv ~/.claude/settings.json.tmp ~/.claude/settings.json
    echo "✓ Updated Claude settings"
else
    echo "  Creating Claude settings..."
    jq -n --arg read_cmd "$HOOK_COMMAND" \
          --arg web_cmd "$WEBFETCH_HOOK_COMMAND" \
          --arg sub_cmd "$SUBAGENT_HOOK_COMMAND" \
          --arg agent_matcher "$SUBAGENT_MATCHER" \
          "$HOOK_JQ_PROGRAM" > ~/.claude/settings.json
    echo "✓ Created Claude settings"
fi

# Note: Do NOT modify docs_manifest.json - it's tracked by git and would break updates

# Clean up old installations now that v0.3 is set up
cleanup_old_installations

# Success message
echo ""
echo "✅ Claude Code Docs v0.3.3 installed successfully!"
echo ""
echo "📚 Command: /$COMMAND_NAME (user)"
echo "📂 Location: ~/.claude-code-docs"
echo ""
echo "Usage examples:"
echo "  /$COMMAND_NAME hooks         # Read hooks documentation"
echo "  /$COMMAND_NAME -t           # Check when docs were last updated"
echo "  /$COMMAND_NAME what's new  # See recent documentation changes"
echo ""
echo "🔄 Auto-updates: Enabled - syncs automatically when GitHub has newer content"
echo "🌐 Offline mode: Fetches of code.claude.com are redirected to the local mirror,"
echo "   and doc-answering subagents are told where the mirror lives"
echo ""
echo "Available topics:"
ls "$INSTALL_DIR/docs" | grep '\.md$' | sed 's/\.md$//' | sort | column -c 60
echo ""
echo "⚠️  Note: Restart Claude Code for auto-updates to take effect"