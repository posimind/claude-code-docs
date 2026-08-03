# Claude Code Documentation Mirror

**English** | [한국어](README.ko.md)

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

Local mirror of the Claude Code documentation from https://code.claude.com/docs/en/, synced every 3 hours — plus hooks that point Claude at it automatically, so documentation questions keep working on networks where Anthropic's docs are blocked.

## What this project does

Ask Claude Code "how do I configure a PreToolUse hook?" and it delegates the question to the `claude-code-guide` subagent, which answers by fetching `code.claude.com`. The docs live on the web, so that is the right default — until you are on a network that blocks `*.claude.*`. Then the failure is not clean; Claude degrades in three ways:

| Failure mode | What you get |
| :----------- | :----------- |
| Answers from training-time knowledge | Option names and paths that have since changed, presented confidently |
| Hallucination | Plausible-looking hook events or CLI flags that do not exist |
| Workaround searching | Failed fetch → retries → search engines → blog posts — tokens and minutes spent, accuracy not gained |

This project removes the web dependency: the docs live on your disk, keep themselves current, and Claude uses them automatically.

Three goals drive the design:

- **Documentation that is always readable.** The full documentation set (174 pages at the time of writing) is mirrored locally and synced every 3 hours — the same pages, available and identical, on a fast connection, behind a corporate proxy, or fully offline.
- **Claude answers from local files without being asked.** A mirror alone is not enough, because nothing tells Claude the copy exists. Two hooks close that gap: a `PreToolUse` hook on `WebFetch` turns every `code.claude.com` fetch into a read of the mirrored file, and a `SubagentStart` hook tells `claude-code-guide` — the subagent Claude delegates documentation questions to — where the mirror is before it takes its first action.
- **Staying current without getting in the way.** Updates run in the background at most once every 3 hours, matching the mirror's own cadence, and every network call has a hard time cap — the sync machinery can never stall a read, even on a network that silently drops packets.

The result: documentation questions are answered from the mirror — faster than a fetch on a good network, and working at all on a blocked one.

> ⚠️ **Early beta.** If anything misbehaves, please [open an issue](https://github.com/posimind/claude-code-docs/issues).

## Installation

Supported on macOS and Linux (Windows: [experimental Git Bash workaround](#windows-git-bash-experimental), [contributions welcome](#contributing-and-known-issues)). Requires `git`, `jq` and `curl` — on Linux, `jq` may need installing first (`apt install jq` / `yum install jq`).

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

### Verify the installation

```bash
# 1) The command file exists
ls ~/.claude/commands/claude-docs.md

# 2) All three hooks are registered
jq '.hooks | to_entries[] | .key as $e | .value[]
    | select((.hooks[0].command // "") | contains("claude-code-docs"))
    | "\($e) [\(.matcher)]"' ~/.claude/settings.json
```

The second command should print exactly:

```
"PreToolUse [Read]"
"PreToolUse [WebFetch]"
"SubagentStart [claude-code-guide]"
```

### Customize command name

Set `CLAUDE_DOCS_COMMAND_NAME` when installing to rename `/claude-docs` (letters, digits, hyphens and underscores):

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh   # → /cdocs hooks
```

The chosen name is recorded in `~/.claude-code-docs/.command_name`, so the uninstaller removes the right command file. Renaming does not affect the hooks — they are keyed to the helper script's path, not the command name.

### Windows (Git Bash, experimental)

> ⚠️ **Not a supported platform.** The installer accepts macOS and Linux only; what follows is a workaround, not a configuration this repository tests. Verify it yourself before rolling it out more widely — and note that re-running the installer can undo steps 5 and 6.

The workaround rests on how Claude Code itself runs hooks: shell-form hook commands go to `sh -c` on macOS/Linux but to **Git Bash on Windows**, with PowerShell only as a fallback when Git Bash is missing. So with Git for Windows installed, `~/.claude-code-docs/claude-docs-helper.sh` works as a hook command unchanged.

Four things break on the way there, handled in order below: Git Bash ships without `jq`; CRLF line endings break the scripts; `column` is missing and Windows' own `timeout.exe` shadows GNU `timeout`; and the installer's OS check rejects `msys`.

**Step 0 — Git for Windows and jq.** Git for Windows brings `git`, `bash` and `curl`; `jq` is not included:

```powershell
winget install jqlang.jq
```

Then check from a **new** Git Bash window (dropping a `jq.exe` into `C:\Program Files\Git\usr\bin` works too):

```bash
git --version && curl --version | head -1 && jq --version
```

**Step 1 — `$HOME` must equal `%USERPROFILE%`.** If Git Bash's `$HOME` differs from what Claude Code sees as `%USERPROFILE%`, the install succeeds but lands where Claude Code never looks.

```bash
echo "$HOME"                        # expect /c/Users/<you>
cmd.exe /c "echo %USERPROFILE%"     # expect C:\Users\<you>
```

If they differ, set the Windows environment variable `HOME` to `%USERPROFILE%` and reopen Git Bash.

**Step 2 — prevent CRLF line endings (the most common failure).** The repository has no `.gitattributes` and Git for Windows defaults to `core.autocrlf=true`, so a clone checks the shell scripts out with CRLF endings and bash fails with `$'\r': command not found`. Before installing:

```bash
git config --global core.autocrlf input
```

Already cloned with CRLF? Re-checkout in place:

```bash
cd ~/.claude-code-docs
git config core.autocrlf input
git rm --cached -r . > /dev/null
git reset --hard

# Verify: any \r in the output means CRLF is still there
head -1 install.sh | od -c | head -2
```

**Step 3 — shim `column`.** Git Bash has no `column`, and under `set -e` the topic listing (installer output, `/claude-docs` with no argument, the search fallback) dies at that point. `column` only formats, so `cat` is a lossless stand-in — one topic per line instead of columns. From an elevated Git Bash (`/usr/bin` is `C:\Program Files\Git\usr\bin`):

```bash
printf '#!/bin/sh\nexec cat\n' > /usr/bin/column
chmod +x /usr/bin/column
column < /dev/null && echo "column shim OK"
```

**Step 4 — check which `timeout` wins.** When a `timeout` command exists, the helper uses it to cap network git calls (`timeout 15 git fetch …`). On Git Bash the PATH may resolve to Windows' `C:\Windows\System32\timeout.exe` — a wait utility, entirely unrelated — which makes every capped git call fail with a syntax error. The helper reads that as "GitHub unreachable" and quietly keeps serving stale docs forever.

```bash
type -a timeout
timeout 1 true; echo "exit=$?"      # exit=0 → GNU timeout, all good
```

If it is not GNU, the clean fix is a GNU coreutils `timeout.exe` in `/usr/bin`. A pass-through shim works as a stopgap, at the price of the time cap — git may hang on a dead network:

```bash
printf '#!/bin/sh\nshift\nexec "$@"\n' > /usr/bin/timeout
chmod +x /usr/bin/timeout
```

**Step 5 — patch the OS gate and install.** `install.sh` exits unless `$OSTYPE` is `darwin*` or `linux-gnu*`, and Git Bash reports `msys`. Download it and widen that one branch:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o install.sh

# In the OS-detection block near the top:
#   before: elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#   after:  elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
sed -i 's|elif \[\[ "$OSTYPE" == "linux-gnu"\* \]\]; then|elif [[ "$OSTYPE" == "linux-gnu"* \|\| "$OSTYPE" == msys* \|\| "$OSTYPE" == cygwin* ]]; then|' install.sh

grep -n 'OSTYPE' install.sh   # confirm the patch
bash -n install.sh            # syntax check
bash install.sh               # install
```

The gate only labels the OS; nothing else in the installer branches on it.

**Step 6 — pin the hook shell to bash (recommended).** Git Bash is already the default, but pinning `"shell": "bash"` rules out the PowerShell fallback. This touches only the `claude-code-docs` hooks — hooks of your own are left alone:

```bash
jq '
def fix(list): [ (list // [])[]
  | if ((((.hooks // [])[0].command) // "") | contains("claude-code-docs"))
    then .hooks[0].shell = "bash" else . end ];
.hooks.PreToolUse = fix(.hooks.PreToolUse)
| .hooks.SubagentStart = fix(.hooks.SubagentStart)
' ~/.claude/settings.json > ~/.claude/settings.json.tmp \
  && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

> Re-running the installer rewrites the hooks and drops the `shell` field — repeat this step after updates.

**Step 7 — verify.** Run the checks from [Verify the installation](#verify-the-installation), then run the helper directly — leftover CRLF or jq problems surface here:

```bash
~/.claude-code-docs/claude-docs-helper.sh -t
```

Restart Claude Code and confirm `/claude-docs -t` prints `✅ You have the latest documentation`. From here, usage is identical to macOS/Linux.

Two footnotes: if a hook fails on execute permissions, change its command to `bash ~/.claude-code-docs/claude-docs-helper.sh <subcommand>`; and `uninstall.sh` has no OS gate and runs as-is, though the shims from steps 3–4 are yours to remove.

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

Reading a page prints a freshness line first, e.g. `✅ You have the latest docs (v0.4.1, main)`. `what's new` lists recent doc commits with links and which pages changed. `changelog` reads the official `CHANGELOG.md`, which the sync workflow mirrors from the Claude Code repository — like every other page, it works offline. A topic that does not exist is not an error: the helper extracts keywords from what you typed and suggests matching topics instead.

`-t` answers with the sync verdict, branch and version:

```
✅ You have the latest documentation    # or: ⚠️ behind by N commit(s) / ⚠️ Could not sync with GitHub
📍 Branch: main
📦 Version: 0.4.1
```

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

In one line: ① publishes the docs to GitHub, ② pulls them down lazily, and ③ turns Claude's gaze from the web to the disk.

### ① The remote mirror — a scheduled publisher

A GitHub Actions workflow in this repository (`.github/workflows/update-docs.yml`) fetches every page from `code.claude.com` on a fixed 3-hour cron and commits whatever changed. It runs on GitHub's infrastructure:

- It happens whether or not anyone is using Claude Code — your machine plays no part in it
- It is the **only** point in the whole system that ever contacts `code.claude.com`
- Its 3-hour cadence is what defines "current" for everything downstream — the maximum lag is 3 hours

Each run works through the same pipeline (`scripts/fetch_claude_docs.py`):

1. Discover the page list from `https://code.claude.com/docs/sitemap.xml` (legacy sitemaps as fallback)
2. Fetch every page **as raw markdown, not HTML** — it requests `<page URL>.md` directly, so there is no parsing or rewriting step
3. Validate what came back (no HTML mixed in, minimum length, markdown structure) — a page that fails validation is not saved
4. Retry failed pages three times with exponential backoff; a page that still fails keeps its previous copy
5. Flatten nested paths with `__` (`/docs/en/agent-sdk/python` → `agent-sdk__python.md`)
6. Record each file's SHA-256 hash, source URL and fetch time in `docs/docs_manifest.json`
7. Commit only when something actually changed — no empty commits

The one page not sourced from the docs site is `changelog.md`, mirrored from `CHANGELOG.md` in the `anthropics/claude-code` repository.

When a run fails partway, the workflow **commits nothing** — a half-updated mirror inconsistent with its own manifest is never published — and automatically opens an issue on the repository.

### ②③ The local install — an event-driven consumer

Your copy at `~/.claude-code-docs` never contacts the official site. It does two jobs, both triggered by use, never by a schedule — nothing runs on your machine while Claude is idle.

**③ Routing Claude to the local files** — every question, instantly, no network involved:

- A question delegated to `claude-code-guide` starts with the mirror's location already injected
- Any `code.claude.com` fetch is denied and pointed at the mirrored file instead
- This works identically whether the last sync was a minute ago or the network has been down for a week (mechanics in [Offline and restricted networks](#offline-and-restricted-networks))

**② Keeping itself current** — reactively, throttled:

```
Claude reads a file
  → PreToolUse[Read] fires → claude-docs-helper.sh hook-check
  → file outside ~/.claude-code-docs?  → exit immediately (nothing happens)
  → inside the mirror → check the .last_check stamp
       · throttle window (3h) not expired → exit
       · expired → git fetch (15s cap) → pull only if behind (30s cap)
  → always exit 0, success or failure
```

- **Reads outside the mirror pass through instantly.** Reading your project's source never waits on a git fetch.
- **The hook always exits 0.** Exit 2 from a `PreToolUse` hook blocks the tool call itself, so an unreachable GitHub is never allowed to stop Claude from reading a file.
- **The 3-hour throttle** matches ①'s cadence — checking more often could not find anything new. The stamp is written at install time (no pointless re-fetch seconds after installing) and **before** each fetch rather than after, so a dead network costs one timeout per window, not one per read.
- **Time caps (fetch 15s / pull 30s)** hold even on a network that silently drops packets. They rely on `timeout(1)`; stock macOS lacks it, and the helper falls back to curl's low-speed abort — which cuts stalled transfers but not a hung connect, so best effort there.
- **It only pulls when behind.** When local is equal to or ahead of origin, nothing happens — local modifications are never clobbered.
- `/claude-docs -t` bypasses the throttle and forces a sync now.

One more wrinkle: an update that changes `install.sh` or the helper-script template needs the installer re-run, and the hook cannot do that — it would re-render the very script it is running inside. So the hook leaves a `.needs_reinstall` marker and the **next user-facing command** picks it up. Updates that only touch docs — nearly all of them — never enter this path.

### Side by side

| | ① Remote mirror sync | ②③ Local install |
| :- | :------------------ | :--------------- |
| Runs on | GitHub's infrastructure | your machine |
| Triggered by | 3-hour cron schedule | Claude reading / fetching / asking |
| Talks to | `code.claude.com` | `github.com` only |
| While idle | keeps publishing every 3 hours | does nothing at all |
| On failure | commits nothing, opens an issue; next cron retries | keeps serving the cached docs; reads are never blocked |

## Offline and restricted networks

### Redirecting fetches

The `WebFetch` hook resolves `code.claude.com` URLs against `docs_manifest.json` and denies the fetch with the matching local path as the reason Claude sees:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

A URL is resolved in two steps. First the query string, fragment, a trailing `.md` and a trailing slash are stripped; then:

1. **Manifest exact match** — the URL is looked up against the `original_url` entries in `docs_manifest.json` (the authoritative path)
2. **Naming-convention fallback** — failing that, the path after `/docs/en/` is flattened with `__` and checked on disk, which covers pages published since the last sync

| URL | Result |
| :-- | :----- |
| `/docs/en/hooks` | `docs/hooks.md` |
| `/docs/en/agent-sdk/python` | `docs/agent-sdk__python.md` |
| `/docs/en/hooks#pretooluse` | `docs/hooks.md` (fragment stripped first) |
| a page that is not mirrored | fetch still denied, but Claude is pointed at `ls` and `grep` over the mirror |
| `https://example.com/…` | untouched — other hosts pass through |

### Steering the `claude-code-guide` subagent

The `SubagentStart` hook injects the mirror into that agent's context before its first action: where the mirror lives and how many pages it has (counted at run time), that it must answer from local files because the network is blocked, how to find a page (`Read <topic>.md`, or `grep -ril '<keyword>'`), the double-underscore convention, and that `docs_manifest.json` maps every file back to its official URL — which it should cite without fetching.

Together the two hooks close both paths: the `SubagentStart` context keeps the trip to the web from starting, and the `WebFetch` guard catches whatever tries anyway. That is what reduces user-side effort to zero.

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

**`-t` prints "Could not sync with GitHub"** — GitHub itself is unreachable from your network. Reads of the cached docs keep working regardless. On Windows, suspect the `timeout` conflict first ([Windows section](#windows-git-bash-experimental), step 4).

**(Windows) `$'\r': command not found`** — the clone has CRLF line endings; re-checkout as in step 2 of the Windows section.

**(Windows) topic list cuts off midway** — `column` is missing; create the shim from step 3 of the Windows section.

**(Windows) `Unsupported OS type: msys`** — the OS gate is unpatched; see step 5 of the Windows section.

## Uninstalling

```bash
~/.claude-code-docs/uninstall.sh    # or: /claude-docs uninstall for instructions
```

Removes the command, the hooks and the installation directory. See [UNINSTALL.md](UNINSTALL.md) for manual removal.

## Trust and security

Installing a third-party script that hooks into Claude Code deserves scrutiny. Point by point:

**Integrity — how you know the content is genuine.** The collection pipeline is fully automated with no human editing step, and both the fetch script (`scripts/fetch_claude_docs.py`) and the workflow definition are in this repository to read. Pages are stored as the raw markdown the official site serves — there is no summarizing or rewriting. Every file's SHA-256 hash, source URL and fetch time are recorded in `docs/docs_manifest.json`, so tampering is machine-checkable:

```bash
# Compare the recorded hash of a file with its actual hash
cd ~/.claude-code-docs
jq -r '.files["hooks.md"]' docs/docs_manifest.json
sha256sum docs/hooks.md
```

Every change lands as a commit, so the full history doubles as an audit log — any sentence can be traced to the commit that changed it. And answers always carry the official URL (`📖 Official page: …`), so cross-checking against the source is one click away.

**Network boundary.** The local install never contacts `code.claude.com` — this is not a proxy or tunnel around a blocked domain, but a static copy of already-public content. The only external host it talks to is `github.com` over HTTPS, and only for `git fetch` / `git pull`. (At install time only, `raw.githubusercontent.com` additionally serves the install script and, as a recovery path, the helper template.)

**Nothing leaves your machine.** The hooks read local files and map URL strings — questions, code and prompts have no path out. There is no telemetry or analytics, and all file access stays inside `~/.claude-code-docs`. The `WebFetch` and `SubagentStart` hooks emit JSON decisions and context only and never touch the network; the only network calls anywhere are the GitHub-bound git commands in the sync path. Command arguments are stripped of shell metacharacters and control characters before use.

**Footprint and rollback.** Exactly three things are touched: `~/.claude/settings.json` (three hooks), `~/.claude/commands/<name>.md` (the command), and `~/.claude-code-docs/` (the install). Hooks are matched for removal by `claude-code-docs` appearing in their command string — hooks you added yourself are never touched. `uninstall.sh` removes all of it, backs up `settings.json` first, and preserves the install directory if it has uncommitted changes.

**If you need tighter control.** Download the installer and read it before running, or fork the repository and install from your fork. If GitHub itself is blocked, mirror the repository to an internal git server and swap the remote:

```bash
cd ~/.claude-code-docs
git remote set-url origin https://git.internal.example.com/mirror/claude-code-docs.git
git pull
```

The hooks work regardless of where `origin` points, and updates keep pulling from it, so the swap survives. But if the directory is ever deleted and the installer takes its fresh-clone path, it clones from `posimind` again — an unsupported scenario, so validate before relying on it.

## Limitations

- **A community mirror, not an Anthropic product** — the helper prints `COMMUNITY MIRROR - NOT AFFILIATED WITH ANTHROPIC` to keep that visible
- **Up to 3 hours behind** the official docs — a page updated minutes ago may not be reflected yet
- **Early beta** — auto-updates can fail on unusual network setups, and some in-document links may not resolve
- **Windows is not officially supported** — the [Git Bash workaround](#windows-git-bash-experimental) works but is not a configuration this repository validates, and installer updates can revert its patches
- **One path no hook covers**: Claude answering purely from memory, without looking anything up. By design nothing fires then — when accuracy matters, force the lookup with `/claude-docs`

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
