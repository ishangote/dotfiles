# AGENTS.md - working in this repo

Read this before touching anything.
`CLAUDE.md` in this directory is a symlink to this file, so both names load the same content.

## What this repo is

A declarative macOS setup for a single machine, built on Determinate Nix, nix-darwin and home-manager, with Homebrew driven declaratively underneath it.
One command (`./bootstrap.sh`) takes a bare Mac to a fully configured one; one command (`./rebuild.sh`) applies every later change.

The repo is public.
Assume anything you add here is published.

`README.md` is the human-facing document and carries the long-form rationale for every decision.
This file is the agent-facing map: where things live, how a change reaches the machine, and what to verify.
When the two disagree, the code is the truth and both documents are wrong.

## Do not confuse the two AGENTS.md files

| Path | What it is |
| --- | --- |
| `AGENTS.md` (this file, repo root) | Instructions for working *on* this repo. Not symlinked anywhere. |
| `home/AGENTS.md` | The user's global agent policy, symlinked to `~/AGENTS.md`, `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. It is a payload file this repo ships, not guidance about this repo. |

Editing `home/AGENTS.md` changes how every agent on this machine behaves, immediately, in every project.
Treat it as a live production change and never edit it as a side effect of some other task.

## The rule that catches everyone: these files are live

Most files under `home/` are not copies.
`home.nix` uses `mkOutOfStoreSymlink`, so `~/.config/nvim`, `~/.config/wezterm`, the VS Code settings and the agent policy files point straight at this working tree.

**Editing a file under `home/` changes the running machine the moment you save it.**
There is no staging step and no rebuild in between.
An uncommitted experiment is already in effect.

Two consequences worth internalising:

- A `git checkout` or `git stash` in this repo silently reconfigures live applications.
- Breaking `home/AGENTS.md` changes how every agent on this machine behaves, immediately.

`home/.claude/settings.json` used to be the sharpest example of both and no longer is: it is copied on rebuild rather than symlinked, so a bad edit there costs a rebuild, not the running session.
That was the whole point of the change - see the note under the mechanism table.

## How a change reaches the machine

There are four distinct mechanisms. Know which one applies before you promise a change is applied.

| Mechanism | Files | How it takes effect |
| --- | --- | --- |
| Live symlink | `home/.config/**`, `home/.claude/statusline-command.sh`, `home/.pi/agent/**`, `home/vscode/{settings,keybindings}.json`, `home/vscode/profiles/**`, `home/{AGENTS,USER,OPINIONS}.md`, `home/obsidian/config/**` | Immediately on save. Some apps need a nudge, see below. |
| Nix rebuild | `flake.nix`, `flake.lock`, `configuration.nix`, `home.nix`, `etc/codex/managed_config.toml`, `home/.claude/settings.json` | `./rebuild.sh` |
| Script, run by hand | `home/vscode/extensions.txt`, `home/mas/apps.tsv`, `home/macos-prefs/*.plist` | The matching `./*.sh` command |
| Manual, no automation exists | `home/finder/favorites.tsv` | Drag into Finder's sidebar by hand |

Reload nudges for the live-symlink tier:

- WezTerm reloads on save, no action needed.
- Neovim picks it up on next launch.
- `rc.zsh` applies to the next shell you open. `exec zsh` in an existing one.
- herdr's running server does **not** reload: press `prefix+shift+r` or run `herdr server reload-config`.
- Claude Code reads `settings.json` at session start. That file is **not** in this tier - see below.
- Pi needs `/reload` inside a running session after a theme or extension edit.
- VS Code applies settings immediately. Untested for the per-profile files under `home/vscode/profiles/`, so switch profiles or restart if one does not take.
- iTerm2 loads its plist from this repo directly, but rewrites the whole file on quit.

`home/vscode/profiles/**` is the one live-symlink path home-manager does not create.
The symlinks are made by `./vscode-profiles.sh link` and the reason is in that script's header: a profile's directory name is random per creation, so it cannot be written into `home.nix`.

`etc/codex/managed_config.toml` is the odd one out in the nix tier: `configuration.nix` reads it with `builtins.readFile` and embeds the text into an `/etc` derivation, so a rebuild is required even though the file looks like plain config.
It cannot be a symlink, and that is deliberate.

`home/.claude/settings.json` is the other one, and the only file here that is **copied** rather than linked.
A `home.activation` hook in `home.nix` installs it over `~/.claude/settings.json` on every rebuild.
The reason is that Claude Code writes `/model` and `/config` changes back to that path, so while it was an out-of-store symlink every session toggle landed in this repo's working tree - `effortLevel` churned through four commits, and one of them reverted a deliberate setting as a side effect of an unrelated change.
Copying separates the two jobs the file was doing at once: the repo holds the declared default, the live copy is Claude Code's to write, and a rebuild re-asserts the default.

Two consequences.
Editing `home/.claude/settings.json` no longer does anything until `./rebuild.sh` runs, and then only in a new session.
And a rebuild discards whatever model or effort you had toggled to, by design - change the default in the repo, not in the running app.

## The shell is split in two

There is no `home/.zshrc`, and there cannot be one.
`~/.zshrc` is a symlink into `/nix/store`, generated by home-manager from the `programs.zsh` block in `home.nix`, and home-manager owns it completely.

So the shell straddles two tiers, and which half you are editing decides whether a rebuild is needed:

| Half | File | Holds | Tier |
| --- | --- | --- | --- |
| Declarative | `home.nix`, `programs.zsh` and friends | aliases, history, plugin enables, prompt, PATH, session variables, `dirHashes` | nix rebuild |
| Hand-written | `home/.config/zsh/rc.zsh` | key bindings, functions, completion styles - plain zsh no option covers | live symlink |

`rc.zsh` is sourced from the tail of the generated `~/.zshrc`, behind an `[[ -r ]]` guard that prints to stderr if the file is missing.
The guard exists because an unguarded `source` of a missing file aborts the rest of `~/.zshrc` on every shell, and a shell that cannot start takes the agents with it.

Put a new setting in the declarative half whenever home-manager has an option for it.
Reaching for `initContent` or a raw `setopt` when an option exists hides the setting from `nix eval` and from anyone reading `home.nix`, and it needs a rebuild either way.

Four files feed the running shell and only two are in this repo:

| File | Source | Yours |
| --- | --- | --- |
| `/etc/zshenv` | nix-darwin, generated | no |
| `/etc/zshrc` | nix-darwin, generated, and deliberately stripped - see below | no |
| `~/.zprofile` | home-manager, from `programs.zsh.profileExtra` | yes |
| `~/.zshrc` | home-manager, from `programs.zsh.*` plus `rc.zsh` | yes |

`configuration.nix` sets `programs.zsh.enableCompletion`, `enableBashCompletion` and `promptInit` off at the **system** tier.
Do not restore them.
Their defaults make nix-darwin's `/etc/zshrc` run `compinit` a second time, disagreeing with home-manager's run about `~/.zcompdump` and rebuilding the dump on every interactive shell - measured at 0.77s per shell versus 0.06s without.
The comment in `configuration.nix` carries the full measurement and how to reproduce it.

## Repo map

### Entry points

| File | Purpose |
| --- | --- |
| `flake.nix` | Pins nixpkgs, nix-darwin, home-manager and nix-homebrew to the 26.05 release. Declares the `mac` host and the single `user = "ishangote"` line. |
| `flake.lock` | Exact input revisions. Generated. Update with `nix flake update`, never by hand. |
| `configuration.nix` | System tier: macOS defaults, dock, Finder, trackpad, `CustomUserPreferences` escape hatch, Homebrew `brews`/`casks`, the `/etc/codex` policy. |
| `home.nix` | User tier: Nix packages, zsh, starship, git, fzf/zoxide, every `mkOutOfStoreSymlink`, launchd login agents, the screenshots-dir activation hook. |

The host label `mac` appears in `flake.nix`, `rebuild.sh` and `bootstrap.sh`.
All three have to match.

### Scripts

| Script | What it does |
| --- | --- |
| `bootstrap.sh` | One-time fresh-Mac setup: install Nix, symlink the repo to `~/.dotfiles`, reconcile the username, back up conflicting hand-written config, run the first switch. |
| `rebuild.sh` | Everything after that. `sudo darwin-rebuild switch --flake ~/.dotfiles#mac`. |
| `vscode-extensions.sh` | `install` / `save` / `diff` against `home/vscode/extensions.txt`. |
| `vscode-profiles.sh` | `save` / `link` / `status` for named VS Code profiles, whose settings `home.nix` cannot declare. Resolves the profile's directory from VS Code's `storage.json` at run time, because the name is random per creation. |
| `mas-apps.sh` | `install` / `status` / `save` against `home/mas/apps.tsv`. Exists because `homebrew.masApps` cannot reach the App Store daemon from nix-darwin's activation namespace. |
| `macos-prefs.sh` | `export` / `import` / `diff` for plist-backed app preferences. Add a `domain:App Name` line to `DOMAINS` to cover another app. |
| `obsidian-vault.sh` | Point one vault's `.obsidian` at the shared config. One-off counterpart to the declarations in `home.nix`. |
| `scrub-iterm2-plist.sh` | Strips the two machine-fingerprint keys iTerm2 writes back on every quit. `--check` exits non-zero, suitable for a pre-commit hook. |

All scripts resolve their own directory and are safe to run from anywhere.
All use `set -euo pipefail`.
All print usage from their own header comment when called with no argument.

### Payload under `home/`

| Path | Configures | Applied by |
| --- | --- | --- |
| `home/.config/wezterm/wezterm.lua` | WezTerm: rose-pine-moon, FiraCode Nerd Font 15, opacity 0.8, key and mouse bindings, unfocused-window dimming | symlink (dir) |
| `home/.config/nvim/` | Neovim: `init.lua`, `lua/vim_config.lua`, `lua/keys.lua`, `lua/plugin.lua` (lazy.nvim bootstrap), `lua/plugins/*.lua`, `lazy-lock.json` | symlink (dir) |
| `home/.config/zsh/rc.zsh` | The hand-written half of the shell: key bindings and anything else plain zsh. Sourced from the generated `~/.zshrc`. See "The shell is split in two" below. | symlink (file only) |
| `home/.config/herdr/config.toml` | herdr agent multiplexer: theme overrides, tmux-style prefix map, mouse and copy behaviour, update policy | symlink (file only) |
| `home/.claude/settings.json` | Claude Code: `bypassPermissions`, model `opus`, `effortLevel` `xhigh`, status line, plugin toggles. The declared default only - Claude Code owns the live copy. | copied by `home.nix` activation, on rebuild |
| `home/.claude/statusline-command.sh` | Status line renderer: model, effort, cwd, context usage | symlink |
| `home/.pi/agent/settings.json` | Pi: theme, thinking and startup behaviour, default provider and model, pinned extension packages. Pi also writes `lastChangelogVersion` here itself, so that key churns on every update. | symlink (file only) |
| `home/.pi/agent/models.json` | Pi: context-window overrides for the `openai-codex` provider | symlink (file only) |
| `home/.pi/agent/themes/` | Pi: the `rose-pine-moon` theme Pi does not ship itself | symlink (dir) |
| `home/.pi/agent/extensions/` | Pi: local extensions. `terminal-status-title.js` only. | symlink (dir) |
| `home/AGENTS.md` | The global agent policy, shared by Claude Code and Codex | symlink (three targets) |
| `home/USER.md` | Who the user is. Loaded on demand by `AGENTS.md`. | symlink |
| `home/OPINIONS.md` | Durable engineering opinions. Loaded on demand by `AGENTS.md`. | symlink |
| `home/vscode/settings.json`, `keybindings.json` | VS Code's **default profile**. JSONC: comments and trailing commas, so plain `jq` will not parse them. | symlink |
| `home/vscode/profiles/<name>/{settings,keybindings}.json` | The named VS Code profiles, `igote-dev-cpp` and `igote-dev-python`. Also JSONC. One directory per profile, named after the profile rather than after VS Code's own random directory. | `./vscode-profiles.sh link` |
| `home/vscode/extensions.txt` | Extension list, one id per line | `./vscode-extensions.sh install` |
| `home/obsidian/config/` | Shared `.obsidian` for every vault: `appearance.json`, `core-plugins.json`, `community-plugins.json`, `graph.json`, `plugins/*/data.json` | symlink (dir) |
| `home/iterm2/com.googlecode.iterm2.plist` | Entire iTerm2 preferences, stored as XML for readable diffs | iTerm2's own custom-prefs-folder mechanism |
| `home/macos-prefs/*.plist` | AltTab settings, `com.apple.symbolichotkeys` (19 of 23 system hotkeys disabled, including Cmd+Space so Alfred can own it and hotkey 30 so Xnip can own Cmd+Shift+4) and Xnip's capture shortcut | `./macos-prefs.sh import` |
| `home/mas/apps.tsv` | Mac App Store apps, `id<TAB>name` | `./mas-apps.sh install` |
| `home/finder/favorites.tsv` | Intended Finder sidebar. Record only. | manual |

`etc/codex/managed_config.toml` is the Codex agent policy (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`).
It lives in `/etc` rather than `~/.codex/config.toml` because Codex rewrites that file from scratch on every settings change and drops keys it does not recognise.
`/etc/codex/managed_config.toml` is the mdm layer, which outranks the user config and which Codex never writes to.

### Docs

- `README.md` - the full human-facing guide, with the reasoning behind every decision. Section anchors are stable, link to them.
- `docs/wezterm-keys.md` - the complete WezTerm key reference, read off the machine with `wezterm show-keys` rather than from the docs.
- `LICENSE` - MIT.

## Declared or gone

Two mechanisms here delete things that are not declared.
Removing a line is a destructive operation, not a cleanup.

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix`. Every switch **uninstalls** any formula or cask not listed in `brews`/`casks`. Dropping a line uninstalls software on the next rebuild.
- `dock.persistent-apps` is the entire dock. Every switch replaces it. `persistent-others = [ ]` is declared precisely so a stray drag gets reverted.

`cleanup = "zap"` does **not** reach App Store apps; Homebrew only removes what Homebrew installed.
Removing a line from `apps.tsv` leaves the app on disk.

Never remove an entry from either list as incidental tidying.
If an entry looks wrong, say so and leave it.

## Verify before you claim done

Every one of these was run in this repo and works.
Match the check to what you touched.

```sh
# Nix layer - evaluates the whole config without touching the system (~3s)
nix build .#darwinConfigurations.mac.system --dry-run
nix flake check --no-build

# Shell scripts
bash -n <script>.sh

# The hand-written half of the shell. `zsh -n` parses without executing, so it
# catches a syntax error before it reaches a live shell.
zsh -n home/.config/zsh/rc.zsh

# Read the zshrc home-manager WOULD generate, without switching to it. Useful
# for checking ordering: initContent lands before the generated aliases, and
# history-substring-search binds the arrows after zsh-syntax-highlighting.
nix eval --raw --impure --expr \
  '(builtins.getFlake "git+file://'"$PWD"'?dirty=1").darwinConfigurations.mac.config.home-manager.users.ishangote.home.file."./.zshrc".text'

# Shell startup time. Anything approaching a second means compinit is running
# twice again - see the comment in configuration.nix. Should be ~0.06s.
/usr/bin/time zsh -ic exit

# Proof the completion dump is NOT being rebuilt every shell: the mtime must
# not move between the two stats.
stat -f %Sm ~/.zcompdump; zsh -ic exit; stat -f %Sm ~/.zcompdump

# JSON (strict): Claude settings, Obsidian config, lazy-lock
jq -e . home/.claude/settings.json

# JSONC (VS Code, both the default profile and everything under
# home/vscode/profiles/): has comments and trailing commas, plain jq FAILS by
# design. Validate by loading it in VS Code, not with jq.

# VS Code profile symlinks. Must print "linked" for every file; anything else
# means the repo copy and the live copy have parted ways.
./vscode-profiles.sh status

# Plists
plutil -lint home/iterm2/com.googlecode.iterm2.plist home/macos-prefs/*.plist

# herdr
herdr config check

# WezTerm - non-zero exit on a config error, and the grep verifies the
# copy-on-select bindings specifically
wezterm --config-file home/.config/wezterm/wezterm.lua show-keys
wezterm show-keys | grep 'Up {'      # nothing may say Complete*

# Codex - --strict-config turns an unrecognised key into a hard error
codex --strict-config doctor

# iTerm2 plist, mandatory before committing any change to it
./scrub-iterm2-plist.sh --check

# Drift checks that change nothing
./vscode-extensions.sh diff
./macos-prefs.sh diff
./mas-apps.sh status
```

A nix `--dry-run` emits a `builtins.derivation ... without a proper context` warning about `options.json`.
That is upstream nix-darwin noise, not a problem with this repo.

`./rebuild.sh` needs sudo and reconfigures the machine.
Do not run it without an explicit go-ahead.

## Conventions this repo holds itself to

- **Comments carry the why, at length.** Nearly every non-obvious line here has a comment explaining what was tried, what broke, and what was verified. Match that density. A change with no explanation is out of place in this repo.
- **Record what was verified, not what was assumed.** The existing comments say things like "verified with `codex doctor`" or "read off this machine with `wezterm show-keys`". Hold to that standard, and say plainly when something is untested.
- **Only deviations are configured.** herdr's config carries settings that match upstream defaults only where the default was tested and deliberately pinned, and says so. Do not add settings just to be explicit.
- **Markdown:** one sentence per physical line, so diffs stay clean. Never an em dash; use a plain dash.
- **Upstream attribution:** when adapting someone else's repo or config, call it "the reference" or "upstream". Never their name or handle, in code, comments, commits or docs.
- **Commits:** imperative mood, one concern per commit, explaining the why. See `git log` for the register. Never add an agent as co-author.
- **Nix style:** two-space indent, one attribute per line, comments above the line they explain.

## Secrets and the public-repo rules

This repo is public and deliberately holds no credentials.
Before adding any file, check it against these:

- `.gitignore` covers the Alfred preferences bundle (workflows routinely embed API keys), the Alfred Powerpack license, Obsidian plugin and theme code, Obsidian's `workspace.json`, and `.claude/settings.local.json`.
- Obsidian **settings** are tracked; plugin **code** (`main.js`, `manifest.json`, `styles.css`) and the Minimal theme are not. That is a licensing decision, explained in the README. Do not vendor them.
- `~/.codex/auth.json` holds live ChatGPT tokens and is neither symlinked nor committed.
- `~/.pi/agent/auth.json` is the same for Pi. Only four repo-authored paths under `~/.pi/agent` are symlinked; the directory itself deliberately is not, because Pi keeps credentials, sessions, trust decisions and downloaded package trees there.
- `~/.claude.json` holds oauth tokens and per-project history and is deliberately not managed.
- `home/iterm2/com.googlecode.iterm2.plist` regrows two machine fingerprints (`NSOSPLastRootDirectory`, a bookmark blob embedding the boot volume UUID, and `NoSyncInstallationId`) every time iTerm2 quits. Run `./scrub-iterm2-plist.sh` before committing any change to it.
- The git email is deliberately GitHub's noreply address, so pushes do not publish a scrapeable inbox. Leave it alone.

One posture is intentionally permissive and is not a bug to fix: both agents are configured to never prompt and never sandbox.
The README's Agents section carries the full argument and the warning that goes with it.
If a change would touch that posture, raise it rather than adjusting it.

## Manual steps no rebuild can perform

macOS exposes these only through a GUI session, which `darwin-rebuild` activation does not have.
They are listed so their absence reads as a decision, not an omission.

- Wallpaper: `System Settings > Wallpaper > Solid Colors > Black`.
- Finder sidebar favorites: drag them in, per `home/finder/favorites.tsv`.
- Obsidian community plugins: install once from the community browser on a fresh Mac; the tracked `data.json` files then apply.
- Alfred: point its sync folder at `~/.dotfiles/home/alfred` once, in Alfred Preferences.
- VS Code Settings Sync must stay **off**, or it periodically overwrites `settings.json` from the cloud and silently reverts repo edits.
- VS Code profiles: create `igote-dev-cpp` and `igote-dev-python` once from the GUI, then run `./vscode-profiles.sh link`. Only the GUI can register a profile, and VS Code assigns its directory a fresh random name each time, which is why the link step cannot happen during a rebuild.
- `codex login` once; `codex doctor` confirms it.
- Pi is installed from npm, not Nix or Homebrew: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`, then authenticate with `pi auth`.
- Docker Desktop's first launch needs an admin password for its privileged helper.
- `./macos-prefs.sh import` after a fresh setup, or Spotlight keeps Cmd+Space and fights Alfred.
- Launch Xnip once before that import. It is sandboxed, its app-group container does not exist until first launch, and `import` will not create it - the Xnip entry skips with a message until it does. `mas install` also needs an interactive sudo password for a first-time install, so `./mas-apps.sh install` cannot be run unattended.
- Turn off each app's own "launch at login" checkbox; login agents are declared in `home.nix` instead. Two deliberate exceptions, both explained in the README: AltTab and Xnip manage their own, and are tracked rather than declared as agents.

## Keeping the docs true

**Any change to a config in this repo must update the docs in the same commit.**
Documentation drift is the main failure mode here, because most of this repo's value is in the recorded reasoning rather than the settings themselves.

When you change something, update every row that mentions it:

| You changed | Also update |
| --- | --- |
| Added, removed or renamed a tracked file | The repo map in this file, and `README.md` |
| A `brews`/`casks` entry, or a Nix package | `README.md` (What you get, Homebrew is declarative) |
| A `mkOutOfStoreSymlink` in `home.nix` | The apply-mechanism table and the repo map here, and the README's symlink section |
| A WezTerm key or mouse binding | `docs/wezterm-keys.md`, plus the README's Terminals section if copy behaviour is involved |
| A herdr key or setting | The inline comment in `config.toml`, and the README's herdr section |
| A zsh alias, binding, history or plugin setting | The README's Shell section, and the split table above if it changes which half owns something |
| An agent setting or the permission posture | `README.md` Agents section, and the tables above |
| A verification command | The "Verify before you claim done" block above, after actually running it |
| A new script | The scripts table here, and `README.md` |
| A new manual step | The manual-steps list here, and `README.md` |

If a change makes an existing comment or README paragraph wrong, fix the prose in the same commit.
A stale explanation is worse than none, because the next reader trusts it.

## Known drift

None currently tracked.

The four entries that lived here - a stale Codex policy path, a claim that
`~/.codex/config.toml` was symlinked, a block documenting a `./finder-favorites.sh`
that never existed, and the wrong Obsidian vault name - were all fixed, along with
a fifth the list had missed in `configuration.nix`.

Keep this section honest rather than empty.
When you find a claim in `README.md` or this file that the tree contradicts and you
are not fixing it in the change you are making, record it here with the file, the
line, and what the code actually does.
The cost of drift here is high: most of this repo's value is in the recorded
reasoning, so a confident wrong sentence is worse than a missing one.
