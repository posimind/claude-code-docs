#!/bin/bash
set -euo pipefail

# Claude Code Documentation Mirror - Smart Uninstaller
# Dynamically finds and removes all installations

echo "Claude Code Documentation Mirror - Uninstaller"
echo "=============================================="
echo ""

INSTALL_DIR="$HOME/.claude-code-docs"

# Slash command name: env override > name recorded at install time > default
if [[ -n "${CLAUDE_DOCS_COMMAND_NAME:-}" ]]; then
    COMMAND_NAME="$CLAUDE_DOCS_COMMAND_NAME"
elif [[ -f "$INSTALL_DIR/.command_name" ]]; then
    COMMAND_NAME="$(tr -d '[:space:]' < "$INSTALL_DIR/.command_name")"
else
    COMMAND_NAME="claude-docs"
fi

# Fall back to the default if the recorded name is unusable as a filename
if [[ ! "$COMMAND_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
    COMMAND_NAME="claude-docs"
fi

COMMAND_FILE="$HOME/.claude/commands/${COMMAND_NAME}.md"

# Command file used by installs before the command was renamed
LEGACY_COMMAND_FILE="$HOME/.claude/commands/docs.md"

# Find all installations from configs
find_all_installations() {
    local paths=()

    # From command files (current name and the legacy /docs one)
    local cmd_file
    for cmd_file in "$COMMAND_FILE" "$LEGACY_COMMAND_FILE"; do
        [[ -f "$cmd_file" ]] || continue
        while IFS= read -r line; do
            if [[ "$line" =~ Execute:.*claude-code-docs ]]; then
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

    # From hooks
    if [[ -f ~/.claude/settings.json ]]; then
        local hooks=$(jq -r '.hooks.PreToolUse[]?.hooks[]?.command // empty' ~/.claude/settings.json 2>/dev/null)
        while IFS= read -r cmd; do
            if [[ "$cmd" =~ claude-code-docs ]]; then
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
    
    # Deduplicate - handle empty array case
    if [[ ${#paths[@]} -gt 0 ]]; then
        printf '%s\n' "${paths[@]}" | sort -u
    fi
}

# Main uninstall logic
installations=()
while IFS= read -r line; do
    installations+=("$line")
done < <(find_all_installations)

if [[ ${#installations[@]} -gt 0 ]]; then
    echo "Found installations at:"
    for path in "${installations[@]}"; do
        echo "  📁 $path"
    done
    echo ""
fi

echo "This will remove:"
echo "  • The /$COMMAND_NAME command from $COMMAND_FILE"
echo "  • All claude-code-docs hooks from ~/.claude/settings.json"
if [[ ${#installations[@]} -gt 0 ]]; then
    echo "  • Installation directories (if safe to remove)"
fi
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove command file
if [[ -f "$COMMAND_FILE" ]]; then
    rm -f "$COMMAND_FILE"
    echo "✓ Removed /$COMMAND_NAME command"
fi

# Point out a leftover /docs command from an older install (left untouched)
if [[ "$COMMAND_NAME" != "docs" && -f "$LEGACY_COMMAND_FILE" ]] && grep -q "claude-code-docs" "$LEGACY_COMMAND_FILE" 2>/dev/null; then
    echo "ℹ️  An older /docs command still exists at: $LEGACY_COMMAND_FILE"
    echo "   Remove it with: rm -f $LEGACY_COMMAND_FILE"
fi

# Remove hooks
if [[ -f ~/.claude/settings.json ]]; then
    cp ~/.claude/settings.json ~/.claude/settings.json.backup
    
    # Remove ALL hooks containing claude-code-docs
    jq '.hooks.PreToolUse = [(.hooks.PreToolUse // [])[] | select(.hooks[0].command | contains("claude-code-docs") | not)]' ~/.claude/settings.json > ~/.claude/settings.json.tmp
    
    # Clean up empty structures
    jq 'if .hooks.PreToolUse == [] then .hooks |= if . == {PreToolUse: []} then {} else del(.PreToolUse) end else . end | if .hooks == {} then del(.hooks) else . end' ~/.claude/settings.json.tmp > ~/.claude/settings.json.tmp2
    
    mv ~/.claude/settings.json.tmp2 ~/.claude/settings.json
    rm -f ~/.claude/settings.json.tmp
    echo "✓ Removed hooks (backup: ~/.claude/settings.json.backup)"
fi

# Remove directories
if [[ ${#installations[@]} -gt 0 ]]; then
    echo ""
    for path in "${installations[@]}"; do
        if [[ ! -d "$path" ]]; then
            continue
        fi
        
        if [[ -d "$path/.git" ]]; then
            # Save current directory ('local' is only valid inside a function)
            current_dir=$(pwd)
            cd "$path"
            
            if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
                cd "$current_dir"
                rm -rf "$path"
                echo "✓ Removed $path (clean git repo)"
            else
                cd "$current_dir"
                echo "⚠️  Preserved $path (has uncommitted changes)"
            fi
        else
            echo "⚠️  Preserved $path (not a git repo)"
        fi
    done
fi

echo ""
echo "✅ Uninstall complete!"
echo ""
echo "To reinstall:"
echo "curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash"