# Claude Code Documentation Mirror

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

Local mirror of Claude Code documentation files from https://code.claude.com/docs/en/, updated every 3 hours.

## ⚠️ Early Beta Notice

**This is an early beta release**. There may be errors or unexpected behavior. If you encounter any issues, please [open an issue](https://github.com/posimind/claude-code-docs/issues) - your feedback helps improve the tool!

## 🆕 Version 0.3.3 - Changelog Integration

**New in this version:**
- 📋 **Claude Code Changelog**: Access the official Claude Code release notes with `/claude-docs changelog`
- 🍎 **Full macOS compatibility**: Fixed shell compatibility issues for Mac users
- 🐧 **Linux support**: Tested on Ubuntu, Debian, and other distributions
- 🔧 **Improved installer**: Better handling of updates and edge cases

To update:
```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

## Why This Exists

- **Faster access** - Reads from local files instead of fetching from web
- **Automatic updates** - Attempts to stay current with the latest documentation
- **Track changes** - See what changed in docs over time
- **Claude Code changelog** - Quick access to official release notes and version history
- **Better Claude Code integration** - Allows Claude to explore documentation more effectively

## Platform Compatibility

- ✅ **macOS**: Fully supported (tested on macOS 12+)
- ✅ **Linux**: Fully supported (Ubuntu, Debian, Fedora, etc.)
- ⏳ **Windows**: Not yet supported - [contributions welcome](#contributing)!

### Prerequisites

This tool requires the following to be installed:
- **git** - For cloning and updating the repository (usually pre-installed)
- **jq** - For JSON processing in the auto-update hook (pre-installed on macOS; Linux users may need `apt install jq` or `yum install jq`)
- **curl** - For downloading the installation script (usually pre-installed)
- **Claude Code** - Obviously :)

## Installation

Run this single command:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

This will:
1. Install to `~/.claude-code-docs` (or migrate existing installation)
2. Create the `/claude-docs` slash command to pass arguments to the tool and tell it where to find the docs (rename it with `CLAUDE_DOCS_COMMAND_NAME` - see [Customize command name](#customize-command-name))
3. Set up a 'PreToolUse' 'Read' hook to enable automatic git pull when reading docs from the ~/.claude-code-docs`
4. Set up hooks that keep Claude on the local mirror when `code.claude.com` is unreachable (see [Offline and Restricted Networks](#offline-and-restricted-networks))

**Note**: The command is `/claude-docs (user)` - it will show in your command list with "(user)" after it to indicate it's a user-created command.

## Usage

The `/claude-docs` command provides instant access to documentation with optional freshness checking.

### Default: Lightning-fast access (no checks)
```bash
/claude-docs hooks        # Instantly read hooks documentation
/claude-docs mcp          # Instantly read MCP documentation
/claude-docs memory       # Instantly read memory documentation
```

You'll see: `📚 Reading from local docs (run /claude-docs -t to check freshness)`

### Check documentation sync status with -t flag
```bash
/claude-docs -t           # Show sync status with GitHub
/claude-docs -t hooks     # Check sync status, then read hooks docs
/claude-docs -t mcp       # Check sync status, then read MCP docs
```

### See what's new
```bash
/claude-docs what's new   # Show recent documentation changes with diffs
```

### Read Claude Code changelog
```bash
/claude-docs changelog    # Read official Claude Code release notes and version history
```

The changelog feature fetches the latest release notes directly from the official Claude Code repository, showing you what's new in each version.

### Uninstall
```bash
/claude-docs uninstall    # Get commnd to remove claude-code-docs completely
```

### Customize command name

The default command is `/claude-docs`. To use a different name, set `CLAUDE_DOCS_COMMAND_NAME` when running the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh

# Now use /cdocs
/cdocs hooks
/cdocs mcp
```

You can use any name made of letters, digits, hyphens and underscores: `cdocs`, `claude-code-docs`, etc. The name is used for the command file (`~/.claude/commands/<name>.md`) and inside the help text the helper script prints.

The installer records the chosen name in `~/.claude-code-docs/.command_name`, so the uninstaller removes the right command file without you having to set the variable again.

### Creative usage examples
```bash
# Natural language queries work great
/claude-docs what environment variables exist and how do I use them?
/claude-docs explain the differences between hooks and MCP

# Check for recent changes
/claude-docs -t what's new in the latest documentation?
/claude-docs changelog    # Check Claude Code release notes

# Search across all docs
/claude-docs find all mentions of authentication
/claude-docs how do I customize Claude Code's behavior?
```

## How Updates Work

The documentation attempts to stay current:
- GitHub Actions runs periodically to fetch new documentation
- When you use `/claude-docs`, it checks for updates
- Updates are pulled when available
- You may see "🔄 Updating documentation..." when this happens

Note: If automatic updates fail, you can always run the installer again to get the latest version.

## Offline and Restricted Networks

On a network that cannot reach `code.claude.com`, Claude would normally try to fetch the official docs and fail. Two hooks send it to the mirror instead:

**Fetches are redirected.** A `PreToolUse` hook on `WebFetch` intercepts any `code.claude.com` URL, resolves it against `docs_manifest.json`, and denies the fetch with the matching local path in the reason:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "Read ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

Nested pages flatten their path with a double underscore, and anchors, query strings and a trailing `.md` are all handled. URLs on other hosts pass through untouched. If a page is not mirrored, the hook still denies the fetch but points at `ls` and `grep` over the mirror.

**Subagents are told up front.** A `SubagentStart` hook fires for the built-in `claude-code-guide` agent - the one Claude delegates Claude Code questions to - and injects the mirror's location, page count and naming convention into its context, so it reads local files instead of reaching for `WebFetch` at all.

To cover another agent, add its name to the `SubagentStart` matcher in `~/.claude/settings.json`; the matcher is a regex, so `claude-code-guide|my-docs-agent` works. Both hooks are also useful with the network up, since a local read beats a fetch.

You can exercise either hook by hand:

```bash
echo '{"tool_input":{"url":"https://code.claude.com/docs/en/hooks"}}' \
  | ~/.claude-code-docs/claude-docs-helper.sh webfetch-guard
```

## Updating from Previous Versions

Regardless of which version you have installed, simply run:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

The installer will handle migration and updates automatically.

## Troubleshooting

### Command not found
If `/claude-docs` returns "command not found":
1. Check if the command file exists: `ls ~/.claude/commands/claude-docs.md`
2. Restart Claude Code to reload commands
3. Re-run the installation script

### Documentation not updating
If documentation seems outdated:
1. Run `/claude-docs -t` to check sync status and force an update
2. Manually update: `cd ~/.claude-code-docs && git pull`
3. Check if GitHub Actions are running: [View Actions](https://github.com/posimind/claude-code-docs/actions)

### Installation errors
- **"git/jq/curl not found"**: Install the missing tool first
- **"Failed to clone repository"**: Check your internet connection
- **"Failed to update settings.json"**: Check file permissions on `~/.claude/settings.json`

## Uninstalling

To completely remove the docs integration:

```bash
/claude-docs uninstall
```

Or run:
```bash
~/.claude-code-docs/uninstall.sh
```

See [UNINSTALL.md](UNINSTALL.md) for manual uninstall instructions.

## Security Notes

- The installer modifies `~/.claude/settings.json` to add three hooks, all of which run the same helper script in `~/.claude-code-docs`:
  - `PreToolUse` on `Read` - runs `git pull` when reading documentation files
  - `PreToolUse` on `WebFetch` - denies `code.claude.com` fetches and names the local file instead; other hosts are ignored
  - `SubagentStart` on `claude-code-guide` - injects the mirror's location into that subagent's context
- Hooks from previous installs are removed on install and on uninstall, matched by `claude-code-docs` appearing in the command; hooks you added yourself are left alone
- All operations are limited to the documentation directory
- No data is sent externally - everything is local
- **Repository Trust**: The installer clones from GitHub over HTTPS. For additional security, you can:
  - Fork the repository and install from your own fork
  - Clone manually and run the installer from the local directory
  - Review all code before installation

## What's New

### v0.3.3 (Latest)
- Added Claude Code changelog integration (`/claude-docs changelog`)
- Fixed shell compatibility for macOS users (zsh/bash)
- Improved documentation and error messages
- Added platform compatibility badges

### v0.3.2
- Fixed automatic update functionality  
- Improved handling of local repository changes
- Better error recovery during updates

## Contributing

**Contributions are welcome!** This is a community project and we'd love your help:

- 🪟 **Windows Support**: Want to help add Windows compatibility? [Fork the repository](https://github.com/posimind/claude-code-docs/fork) and submit a PR!
- 🐛 **Bug Reports**: Found something not working? [Open an issue](https://github.com/posimind/claude-code-docs/issues)
- 💡 **Feature Requests**: Have an idea? [Start a discussion](https://github.com/posimind/claude-code-docs/issues)
- 📝 **Documentation**: Help improve docs or add examples

You can also use Claude Code itself to help build features - just fork the repo and let Claude assist you!

## Known Issues

As this is an early beta, you might encounter some issues:
- Auto-updates may occasionally fail on some network configurations
- Some documentation links might not resolve correctly

If you find any issues not listed here, please [report them](https://github.com/posimind/claude-code-docs/issues)!

## License

Documentation content belongs to Anthropic.
This mirror tool is open source - contributions welcome!
