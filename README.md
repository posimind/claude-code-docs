# Claude Code Documentation Mirror

**English** | [한국어](README.ko.md)

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

Local mirror of Claude Code documentation files from https://code.claude.com/docs/en/, updated every 3 hours.

## Built for Networks That Block Anthropic's Docs

**This fork exists to make Claude Code usable where `code.claude.com` and other Anthropic documentation hosts are unreachable** - corporate proxies, air-gapped networks, and egress-filtered CI environments.

Without it, asking Claude a question about Claude Code fails in a specific way: the built-in `claude-code-guide` subagent, which Claude delegates those questions to, tries to `WebFetch` the official docs, gets a network error, and answers from memory or not at all. A local copy of the docs does not fix this on its own, because nothing tells the agent the copy exists.

So this fork mirrors the documentation **and** wires Claude to it:

- **Fetches are redirected.** A `PreToolUse` hook on `WebFetch` intercepts every `code.claude.com` URL, resolves it to the mirrored file, and denies the fetch while naming that file - so Claude reads it instead of failing.
- **Subagents are told the mirror exists.** A `SubagentStart` hook injects the mirror's location, page count and file-naming convention into `claude-code-guide` before it runs, so it searches local paths and never reaches for the network.

Both are installed automatically. See [Offline and Restricted Networks](#offline-and-restricted-networks) for the details, and [Security Notes](#security-notes) for exactly what gets written to your settings.

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

- **Works without access to Anthropic** - The docs stay available when `code.claude.com` is blocked, and Claude is pointed at them automatically
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
3. Set up three hooks in `~/.claude/settings.json`, all calling the same helper script:
   - `PreToolUse` on `Read` - pulls the latest docs when Claude reads from `~/.claude-code-docs`, at most once every 3 hours
   - `PreToolUse` on `WebFetch` - redirects `code.claude.com` fetches to the mirrored file
   - `SubagentStart` on `claude-code-guide` - tells that subagent where the mirror is

   Hooks you added yourself are left untouched. See [Offline and Restricted Networks](#offline-and-restricted-networks).

**Note**: Hooks are loaded when a session starts, so restart Claude Code after installing.

**Note**: The command is `/claude-docs (user)` - it will show in your command list with "(user)" after it to indicate it's a user-created command.

## Usage

There are two ways to reach the docs, and since the hooks were added the first one covers most cases.

### Just ask - no command needed

The hooks work on ordinary questions. Ask about Claude Code in plain language and the mirror is used automatically:

```
How do I configure a PreToolUse hook?
What's the difference between hooks and MCP?
Can a subagent run in the background?
```

When Claude hands the question to the `claude-code-guide` subagent, that agent starts out knowing where the mirror is and reads local files. If anything tries to fetch `code.claude.com` - the subagent or the main conversation - the fetch is turned into a local read. You don't have to remember a command, and it works on a blocked network.

One caveat: if Claude decides it already knows the answer and never looks anything up, no hook fires, because there is no fetch and no subagent to steer. When you want the documentation consulted for certain, use the command below.

### `/claude-docs` - read a page directly

The command is still the way to pull up a specific page verbatim, check how fresh the mirror is, or see what changed:

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

### Which one to use

| You want | Do this |
| :------- | :------ |
| An answer to a Claude Code question | Just ask - the hooks route it to the mirror |
| A specific page, in full | `/claude-docs hooks` |
| To be sure the docs were actually consulted | `/claude-docs <topic>` or `/claude-docs <question>` |
| To know how current the mirror is | `/claude-docs -t` |
| Recent documentation changes | `/claude-docs what's new` |
| Release notes | `/claude-docs changelog` |

The command also takes natural language, which is useful when you want the lookup forced rather than left to Claude's judgment:

```bash
/claude-docs what environment variables exist and how do I use them?
/claude-docs explain the differences between hooks and MCP
/claude-docs find all mentions of authentication
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

Renaming the command does not affect the hooks - they are keyed to the helper script's path, not to the command name.

## How Updates Work

The documentation attempts to stay current:
- GitHub Actions runs periodically to fetch new documentation
- Reading from the mirror (via the hook or `/claude-docs`) checks GitHub for updates, at most once every 3 hours - the same cadence the mirror itself updates at, so checking more often could not find anything new
- Updates are pulled when available
- You may see "🔄 Updating documentation..." when this happens
- `/claude-docs -t` always contacts GitHub, so use it to force a sync

Note: If automatic updates fail, you can always run the installer again to get the latest version.

## Offline and Restricted Networks

Two hooks keep Claude on the mirror when the official docs are unreachable. Both run the installed helper script and are registered by the installer.

### Redirecting fetches

A `PreToolUse` hook on `WebFetch` intercepts any `code.claude.com` URL, resolves it against `docs_manifest.json`, and denies the fetch with the matching local path as the reason Claude sees:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

Nested pages flatten their path with a double underscore (`/docs/en/agent-sdk/python` becomes `agent-sdk__python.md`), and anchors, query strings and a trailing `.md` are all stripped before the lookup. URLs on other hosts pass through untouched. If a page is not mirrored, the hook still denies the fetch, but points at `ls` and `grep` over the mirror instead of a specific file.

### Steering the `claude-code-guide` subagent

`claude-code-guide` is the built-in subagent Claude delegates Claude Code questions to. Left alone it reaches for `WebFetch` first, which fails on a restricted network.

A `SubagentStart` hook matched to that agent injects the mirror into its context before it takes its first action, telling it:

- where the mirror lives and how many pages it has
- to answer from local files, because `code.claude.com` is not reachable
- how to find a page - `Read <topic>.md`, or `grep -ril '<keyword>'` across the mirror
- that nested pages flatten their path with a double underscore
- that `docs_manifest.json` maps every file back to its original URL, which it should cite without fetching

The result is that the agent searches local paths from the start rather than discovering the network is blocked and working around it.

To cover another agent, add its name to the `SubagentStart` matcher in `~/.claude/settings.json` - the matcher is a regex, so `claude-code-guide|my-docs-agent` works.

### Checking that it works

Hooks load when a session starts, so restart Claude Code after installing. You can run either hook by hand without restarting:

```bash
# Should print a deny decision naming the local file
echo '{"tool_input":{"url":"https://code.claude.com/docs/en/hooks"}}' \
  | ~/.claude-code-docs/claude-docs-helper.sh webfetch-guard

# Should print the context injected into the subagent
echo '{"agent_type":"claude-code-guide"}' \
  | ~/.claude-code-docs/claude-docs-helper.sh subagent-context
```

Both hooks are worth keeping even with the network up, since a local read beats a fetch.

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

### Claude still tries to fetch the official docs
If a question about Claude Code still results in a failed `WebFetch`:
1. Restart Claude Code - hooks are loaded when a session starts
2. Check the hooks are registered:
   ```bash
   jq '.hooks | to_entries[] | .key as $e | .value[]
       | select((.hooks[0].command // "") | contains("claude-code-docs"))
       | "\($e) [\(.matcher)]"' ~/.claude/settings.json
   ```
   You should see `PreToolUse [Read]`, `PreToolUse [WebFetch]` and `SubagentStart [claude-code-guide]`
3. Run the hook by hand to confirm the helper works - see [Checking that it works](#checking-that-it-works)
4. If Claude answered without looking anything up, no hook fires by design. Ask again with `/claude-docs` to force the lookup

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
  - `PreToolUse` on `Read` - runs `git pull` when reading documentation files, at most once every 3 hours
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

## Fork Notice

This repository is a fork of **[ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs)**, the original Claude Code documentation mirror. All credit for the mirror, the sync workflow and the `/docs` helper goes to that project and its contributors.

The fork was created to serve networks where Anthropic's documentation hosts are blocked. What changed here:

- **Offline hooks** - a `PreToolUse` hook on `WebFetch` that redirects `code.claude.com` fetches to the mirrored file, and a `SubagentStart` hook that tells the `claude-code-guide` subagent to search the mirror instead of the network. This is the reason the fork exists.
- **Retargeted to this fork** - the installer, uninstaller, helper script and docs now clone and pull from `posimind/claude-code-docs`, so an installed copy tracks this repository rather than upstream.
- **Refreshed documentation URLs** - updated for Anthropic's move from `docs.anthropic.com/en/docs/claude-code` to `code.claude.com/docs/en`, including a sitemap-failure fallback in `fetch_claude_docs.py` that had been pairing the old base URL with new-style page paths.
- **Renamed slash command** - `/docs` became `/claude-docs` to avoid colliding with other tooling, and the name is now configurable through `CLAUDE_DOCS_COMMAND_NAME`.
- **Installer and uninstaller fixes** - the uninstaller could never remove `~/.claude-code-docs`, because its path pattern did not match a directory whose name starts with a dot; and the installer treated the directory it was launched from as an old installation and deleted it, which destroyed a clean clone of the repo when you ran the installer from inside one.

Upstream continues to be the place for the mirror itself. Issues specific to the offline hooks or to this fork's packaging belong [here](https://github.com/posimind/claude-code-docs/issues).
