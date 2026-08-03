# Claude Code Documentation Mirror

**English** | [한국어](README.ko.md)

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

Local mirror of the Claude Code documentation from https://code.claude.com/docs/en/, synced every 3 hours — plus hooks that point Claude at it automatically, so documentation questions keep working on networks where Anthropic's docs are blocked.

## What this project does

Claude Code's documentation lives on the web, and Claude reaches for the web whenever it answers a question about it. This project removes that dependency: the docs live on your disk, keep themselves current, and Claude uses them automatically.

Three goals drive the design:

- **Documentation that is always readable.** The full documentation set is mirrored locally and synced every 3 hours — the same pages, available and identical, on a fast connection, behind a corporate proxy, or fully offline.
- **Claude answers from local files without being asked.** A mirror alone is not enough, because nothing tells Claude the copy exists. Two hooks close that gap: a `PreToolUse` hook on `WebFetch` turns every `code.claude.com` fetch into a read of the mirrored file, and a `SubagentStart` hook tells `claude-code-guide` — the subagent Claude delegates documentation questions to — where the mirror is before it takes its first action.
- **Staying current without getting in the way.** Updates run in the background at most once every 3 hours, matching the mirror's own cadence, and every network call has a hard time cap — the sync machinery can never stall a read, even on a network that silently drops packets.

The result: documentation questions are answered from the mirror — faster than a fetch on a good network, and working at all on a blocked one.

> ⚠️ **Early beta.** If anything misbehaves, please [open an issue](https://github.com/posimind/claude-code-docs/issues).

## Installation

Supported on macOS and Linux (Windows: [contributions welcome](#contributing-and-known-issues)). Requires `git`, `jq` and `curl` — on Linux, `jq` may need installing first (`apt install jq` / `yum install jq`).

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

The same command updates or repairs an existing install of any version.

What it does:

1. Installs to `~/.claude-code-docs` (migrating an older install if found)
2. Creates the `/claude-docs` slash command (listed as `/claude-docs (user)` in Claude Code)
3. Registers three hooks in `~/.claude/settings.json`, all running the same helper script — hooks you added yourself are left untouched:

| Hook | Purpose |
| :--- | :------ |
| `PreToolUse` on `Read` | syncs the mirror when Claude reads from it, at most once every 3 hours |
| `PreToolUse` on `WebFetch` | redirects `code.claude.com` fetches to the mirrored file |
| `SubagentStart` on `claude-code-guide` | tells that subagent where the mirror is |

**Restart Claude Code after installing** — hooks are loaded when a session starts.

### Customize command name

Set `CLAUDE_DOCS_COMMAND_NAME` when installing to rename `/claude-docs` (letters, digits, hyphens and underscores):

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh   # → /cdocs hooks
```

The chosen name is recorded in `~/.claude-code-docs/.command_name`, so the uninstaller removes the right command file. Renaming does not affect the hooks — they are keyed to the helper script's path, not the command name.

## Usage

### Just ask — no command needed

Ask about Claude Code in plain language and the hooks route the lookup to the mirror:

```
How do I configure a PreToolUse hook?
What's the difference between hooks and MCP?
```

The `claude-code-guide` subagent starts out knowing where the mirror is, and any attempt to fetch `code.claude.com` — by the subagent or the main conversation — is turned into a local read. One caveat: if Claude answers from memory without looking anything up, no hook fires. To force the lookup, use the command.

### The `/claude-docs` command

```bash
/claude-docs               # list all documentation topics
/claude-docs hooks         # read a specific page in full
/claude-docs -t            # sync with GitHub now and show status
/claude-docs -t hooks      # force a sync, then read a page
/claude-docs what's new    # recent documentation changes
/claude-docs changelog     # official Claude Code release notes
/claude-docs uninstall     # print removal instructions
```

Reading a page prints a freshness line first, e.g. `✅ You have the latest docs (v0.4.1, main)`. `what's new` lists recent doc commits with links and which pages changed. `changelog` reads the official `CHANGELOG.md`, which the sync workflow mirrors from the Claude Code repository — like every other page, it works offline.

The command also takes natural language, useful when you want the lookup forced rather than left to Claude's judgment:

```bash
/claude-docs what environment variables exist and how do I use them?
/claude-docs find all mentions of authentication
```

| You want | Do this |
| :------- | :------ |
| An answer to a Claude Code question | Just ask — the hooks route it to the mirror |
| A specific page, in full | `/claude-docs hooks` |
| To be sure the docs were actually consulted | `/claude-docs <topic or question>` |
| To know how current the mirror is | `/claude-docs -t` |
| Recent documentation changes | `/claude-docs what's new` |
| Release notes | `/claude-docs changelog` |

## How it works — two separate layers

The pipeline has two halves with very different characters: a **scheduled publisher** that runs in the cloud, and an **event-driven consumer** that runs on your machine only when Claude is actually used.

```
code.claude.com                          (official docs)
      │
      │  ① GitHub Actions — every 3 hours, on GitHub's infrastructure
      ▼
github.com/posimind/claude-code-docs     (remote mirror)
      │
      │  ② git pull — when Claude reads, at most once per 3 hours
      ▼
~/.claude-code-docs                      (local mirror)
      │
      │  ③ hooks — on every question, instant, no network
      ▼
Claude
```

### ① The remote mirror — a scheduled publisher

A GitHub Actions workflow in this repository fetches every page from `code.claude.com` on a fixed 3-hour cron and commits whatever changed. It runs on GitHub's infrastructure:

- It happens whether or not anyone is using Claude Code — your machine plays no part in it
- It is the **only** point in the whole system that ever contacts `code.claude.com`
- Its 3-hour cadence is what defines "current" for everything downstream

### ②③ The local install — an event-driven consumer

Your copy at `~/.claude-code-docs` never contacts the official site. It does two jobs, both triggered by use, never by a schedule — nothing runs on your machine while Claude is idle.

**③ Routing Claude to the local files** — every question, instantly, no network involved:

- A question delegated to `claude-code-guide` starts with the mirror's location already injected
- Any `code.claude.com` fetch is denied and pointed at the mirrored file instead
- This works identically whether the last sync was a minute ago or the network has been down for a week (mechanics in [Offline and restricted networks](#offline-and-restricted-networks))

**② Keeping itself current** — reactively, throttled:

- When Claude reads from the mirror (or you run `/claude-docs`), the helper pulls new commits from the GitHub mirror — at most once every 3 hours, since checking more often than ① publishes could not find anything new
- Every network call is time-capped (fetch 15s, pull 30s) and fails silently: offline, you simply keep reading the cached copy
- `/claude-docs -t` bypasses the throttle and forces a sync now

### Side by side

| | ① Remote mirror sync | ②③ Local install |
| :- | :------------------ | :--------------- |
| Runs on | GitHub's infrastructure | your machine |
| Triggered by | 3-hour cron schedule | Claude reading / fetching / asking |
| Talks to | `code.claude.com` | `github.com` only |
| While idle | keeps publishing every 3 hours | does nothing at all |
| On failure | next cron retries | keeps serving the cached docs; reads are never blocked |

## Offline and restricted networks

### Redirecting fetches

The `WebFetch` hook resolves `code.claude.com` URLs against `docs_manifest.json` and denies the fetch with the matching local path as the reason Claude sees:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

Nested pages flatten their path with a double underscore (`/docs/en/agent-sdk/python` → `agent-sdk__python.md`); anchors, query strings and a trailing `.md` are stripped before the lookup. URLs on other hosts pass through untouched. If a page is not mirrored, the hook still denies the fetch, but points at `ls` and `grep` over the mirror instead of a specific file.

### Steering the `claude-code-guide` subagent

The `SubagentStart` hook injects the mirror into that agent's context before its first action: where the mirror lives and how many pages it has, that it must answer from local files because the network is blocked, how to find a page (`Read <topic>.md`, or `grep -ril '<keyword>'`), the double-underscore convention, and that `docs_manifest.json` maps every file back to its official URL — which it should cite without fetching.

To cover another agent, extend the `SubagentStart` matcher in `~/.claude/settings.json` — it is a regex, so `claude-code-guide|my-docs-agent` works.

### Checking that it works

```bash
# Should print a deny decision naming the local file
echo '{"tool_input":{"url":"https://code.claude.com/docs/en/hooks"}}' \
  | ~/.claude-code-docs/claude-docs-helper.sh webfetch-guard

# Should print the context injected into the subagent
echo '{"agent_type":"claude-code-guide"}' \
  | ~/.claude-code-docs/claude-docs-helper.sh subagent-context
```

## Troubleshooting

**`/claude-docs` not found** — check `ls ~/.claude/commands/claude-docs.md`, restart Claude Code, or re-run the installer.

**Claude still tries to fetch the official docs** — restart Claude Code (hooks load at session start), then check the hooks are registered:

```bash
jq '.hooks | to_entries[] | .key as $e | .value[]
    | select((.hooks[0].command // "") | contains("claude-code-docs"))
    | "\($e) [\(.matcher)]"' ~/.claude/settings.json
```

You should see `PreToolUse [Read]`, `PreToolUse [WebFetch]` and `SubagentStart [claude-code-guide]`. If Claude answered from memory without looking anything up, no hook fires by design — ask again with `/claude-docs` to force the lookup.

**Documentation not updating** — `/claude-docs -t` forces a sync; or `cd ~/.claude-code-docs && git pull`; check that [GitHub Actions](https://github.com/posimind/claude-code-docs/actions) is running.

## Uninstalling

```bash
~/.claude-code-docs/uninstall.sh    # or: /claude-docs uninstall for instructions
```

Removes the command, the hooks and the installation directory. See [UNINSTALL.md](UNINSTALL.md) for manual removal.

## Security notes

- The installer modifies `~/.claude/settings.json` to add the three hooks above; all of them run the same helper script in `~/.claude-code-docs`
- Hooks from previous installs are removed on install and on uninstall, matched by `claude-code-docs` appearing in the command — hooks you added yourself are left alone
- All operations are limited to the documentation directory; nothing is sent externally
- **Repository trust**: the installer clones from GitHub over HTTPS. For more control, fork the repository and install from your own fork, or clone manually and review the code before running the installer

## What's new

### v0.4.1 (latest)

- The auto-update hook now works: it had been a no-op since v0.3, so installed mirrors went stale until a slash command happened to run
- Updates are throttled to once every 3 hours — the mirror's own cadence — and `/claude-docs -t` still forces a sync
- Network git calls are time-capped (fetch 15s, pull 30s), so a blocked network cannot stall Claude's reads
- The installer re-runs only when an update actually changed it, and never from inside the hook
- Offline fixes: `-t` and the topic list no longer exit before printing when GitHub is unreachable
- README rewritten to match actual behavior (dropped a nonexistent output message, the "diffs" claim, and the wrong description of `changelog`)

### v0.3.3 (upstream)

- Claude Code changelog integration (`/claude-docs changelog`), macOS shell compatibility fixes, platform badges

## Contributing and known issues

Contributions are welcome — Windows support, bug reports, feature ideas, documentation: [open an issue](https://github.com/posimind/claude-code-docs/issues) or a PR. Known issues: auto-updates can fail on unusual network setups, and some documentation links may not resolve.

## License

Documentation content belongs to Anthropic. The mirror tooling is open source — contributions welcome.

## Fork notice

This repository is a fork of **[ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs)**, the original Claude Code documentation mirror. All credit for the mirror, the sync workflow and the `/docs` helper goes to that project and its contributors. Upstream remains the place for the mirror itself; issues specific to this fork belong [here](https://github.com/posimind/claude-code-docs/issues).

Everything changed since the fork:

- **Offline hooks** — the `WebFetch` redirect and the `claude-code-guide` context injection described above; the project's defining feature
- **Working auto-update** (v0.4.1) — the `Read` hook actually syncs the mirror now, throttled to every 3 hours, with time-capped network calls and a conditional, hook-safe installer re-run
- **Retargeted to this fork** — installer, uninstaller, helper script and docs clone and pull from `posimind/claude-code-docs`, so an installed copy tracks this repository rather than upstream
- **Refreshed documentation URLs** — for Anthropic's move from `docs.anthropic.com/en/docs/claude-code` to `code.claude.com/docs/en`, including the sitemap-failure fallback in `fetch_claude_docs.py` that had been pairing the old base URL with new-style page paths
- **Renamed slash command** — `/docs` became `/claude-docs` to avoid colliding with other tooling, configurable via `CLAUDE_DOCS_COMMAND_NAME`
- **Installer and uninstaller fixes** — the uninstaller could never remove `~/.claude-code-docs` (its pattern missed dot-directories); the installer deleted the directory it was launched from; templates now render via `mv`, so re-rendering the running helper script is safe
- **Sync workflow fix** — no more empty commits when nothing changed
- **Korean README** — [README.ko.md](README.ko.md)
