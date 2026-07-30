# dotfiles

My Mac setup, managed with nix-darwin and home-manager.
One repo, one command, and a fresh Mac ends up configured the same way every time.

## What you get

- System settings (dark mode, key repeat, Finder, trackpad, hot corners,
  screenshot folder, menu bar clock, window manager)
- Dock contents and behaviour
- System keyboard shortcuts, including Spotlight's Cmd+Space disabled for Alfred
- Homebrew formulae and casks, declared rather than installed ad hoc
- Nix user packages (ripgrep, fd, fzf, jq, bat, eza, zoxide, lazygit, tree, htop, Neovim, Fira Code Nerd Font)
- Shell (zsh, aliases, starship prompt)
- Editor (Neovim with the rose-pine moon theme)
- Terminal (WezTerm with the rose-pine moon theme)
- Apps (VS Code, Obsidian, Claude desktop, Numi, Alfred, AltTab, Magnet, Handy, iTerm2)
- Alfred preferences, AltTab settings
- Open-at-login for Alfred, Magnet and Handy
- VS Code settings, keybindings and extension list
- Obsidian vault config for the llm-wiki vault
- Agent config (Claude and Codex share one `AGENTS.md`)

## Fresh-machine setup

```sh
git clone <this repo> ~/igote-dev/dotfiles
cd ~/igote-dev/dotfiles
./bootstrap.sh
```

`bootstrap.sh` does five things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Symlinks this repo to `~/.dotfiles`.
   This has to happen before the first build, because `home.nix` points at config
   files through `~/.dotfiles`.
3. Checks the `user` configured in `flake.nix` against your actual macOS username,
   and offers to fix it.
4. Moves conflicting hand-written config (`~/.zshrc`, `~/.gitconfig`, ...) into a
   timestamped backup dir. home-manager will not overwrite files it doesn't manage,
   so this has to happen first. Nothing is deleted. On a truly fresh Mac it's a no-op.
5. Runs the first `darwin-rebuild switch`.

Open a new terminal afterwards.

### Validate without applying

Once Nix is installed, check that the config builds without touching your system:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

## Repo tour

- `flake.nix` - the entry point. Pins nixpkgs, nix-darwin, home-manager and
  nix-homebrew to the 26.05 release, and declares the `mac` machine.
- `configuration.nix` - system-level: macOS defaults, Homebrew lists.
- `home.nix` - user-level: shell, packages, prompt, git, and the symlinks below.
- `home/` - the actual config files that get symlinked into place.
- `bootstrap.sh` - one-time setup. `rebuild.sh` - everything after that.

## How the symlinks work

The files under `home/` are the real files - editing them here is editing your
live config, no rebuild needed. `home.nix` uses `mkOutOfStoreSymlink` to point
`~/.config/nvim`, `~/.config/wezterm` and the Claude files straight at this repo,
so the two never drift.

Run `./rebuild.sh` only when you change something that isn't a symlinked file:
a package list, a shell alias, a macOS default.

Only two files under `~/.claude` are managed (`settings.json` and
`statusline-command.sh`). Everything else there - sessions, projects, history,
`settings.local.json` - is machine-local runtime state and is left alone.

## Homebrew is declarative

`configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`. Every switch
removes any formula or cask **not** listed in `brews` and `casks`.

Everything already on this machine is declared there, so the first switch is a
no-op. But if you `brew install` something later, add it to `configuration.nix`
too - otherwise the next `./rebuild.sh` takes it straight back out.

Magnet is Mac App Store only, so it's declared under `homebrew.masApps` instead
of `casks`, and needs the `mas` CLI (in `brews`). **You must be signed into the
App Store with the Apple ID that purchased Magnet**, or the switch fails there.

Things deliberately left out of the brew lists:

- `claude-code` cask - `claude` is the native installer at `~/.local/bin/claude`
  and self-updates. The cask would be a second, competing install.
- Visual Studio Code - installed by hand into `/Applications`, never via brew,
  so `zap` doesn't touch it.

## VS Code

`settings.json` and `keybindings.json` are symlinked out of `home/vscode/`, so
changing a setting in the GUI writes straight back into this repo. No rebuild.

**Settings Sync must stay off.** It syncs the same files through your Microsoft
account, and if both are active it will periodically overwrite `settings.json`
from the cloud copy and silently revert repo edits. Turn it off once:
`Cmd+Shift+P` -> `Settings Sync: Turn Off`.

Extensions are deliberately *not* managed by Nix, so the GUI can still install
them. They're tracked as a plain list instead:

```sh
./vscode-extensions.sh install   # install everything in the list
./vscode-extensions.sh save      # capture what's installed back into the list
./vscode-extensions.sh diff      # show drift, change nothing
```

Install something from the GUI, then run `save` and commit the diff.

## Obsidian

Obsidian has **no global settings layer**. Every setting - theme, plugins,
hotkeys, graph - lives in `<vault>/.obsidian`.
(`~/Library/Application Support/obsidian/obsidian.json` is only a registry of
vault paths and IDs, not settings.)

So "global" is built by hand: one shared config at `home/obsidian/config`, and
every vault's `.obsidian` symlinked at it. Change the theme in one vault and
every vault has it.

Point a new vault at the shared config:

```sh
./obsidian-vault.sh ~/igote-dev/some-vault
```

For vaults you intend to keep, also add a line to `home.nix` (there's a
commented template) so a fresh Mac wires them up without running the script.

Notes:

- Vault *notes* stay in their own repo. Only `.obsidian` lives here.
- A vault repo should gitignore `.obsidian`, or git will track the symlink itself.
- Cloning a vault repo on a machine without these dotfiles gives you default settings.
- `workspace.json` is per-session pane layout, not a setting. It's gitignored -
  with a shared config, tracking it would make every vault open with the last
  vault's layout.
- The whole directory is symlinked, not the individual files. Obsidian writes
  settings atomically (temp file + rename), which would replace a per-file
  symlink with a regular file and break the link.

## Alfred

Alfred has its own sync mechanism, which is better than symlinking the
preferences bundle by hand - it manages the file layout itself. Point it at this
repo once, in the GUI:

`Alfred Preferences` -> `Advanced` -> `Syncing` -> `Set preferences folder...`
-> choose `~/.dotfiles/home/alfred`

Alfred moves `Alfred.alfredpreferences` (~7 MB: workflows, themes, hotkeys,
snippets) into the repo and reads from there afterwards. Nothing to rebuild.

The Powerpack license is a separate file that Alfred's sync does **not** cover.
A copy lives in `home/alfred/license/`. On a fresh Mac, either re-enter the
license or copy it back:

```sh
cp home/alfred/license/powerpack.*.dat ~/Library/Application\ Support/Alfred/
```

This repo is private, which is the only reason that file is committed. **Do not
make this repo public without removing it from git history first** - deleting the
file in a later commit does not remove it from history.

## Dock

`dock.persistent-apps` in `configuration.nix` is the dock, in order, left to
right. `persistent-others` is empty, so no folders or files.

**This replaces the dock on every switch.** Anything dragged in by hand vanishes
on the next `./rebuild.sh` - add it to the list instead. Same deal as
`cleanup = "zap"` for Homebrew: declared or gone.

Safari is referenced by its full Cryptexes path
(`/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app`) rather
than `/Applications/Safari.app`. The latter is only a symlink into that volume,
and the Dock doesn't follow it to read the bundle's display name - the tile ends up
labelled "Safari.app". Ugly path, correct label.

Plain paths are fine; nix-darwin turns them into the dock's internal tile format.
The option also accepts tagged entries if you want folders or spacers:

```nix
persistent-apps = [
  "/Applications/WezTerm.app"
  { spacer = { small = false; }; }
  { folder = "/Users/ishangote/Screenshots"; }
];
```

Running apps not in the list still appear in the dock while they're open - that's
macOS, not this config. Only the pinned set is managed.

## Finder

Behaviour is declared in `configuration.nix`:

| Setting | Effect |
| --- | --- |
| `_FXSortFoldersFirst` + `…OnDesktop` | Folders never mix in with files |
| `FXDefaultSearchScope = "SCcf"` | Search the current folder, not the whole Mac |
| `ShowPathbar` | Folder chain at the bottom, also a drop target |
| `ShowStatusBar` | Item count and free space |
| `ShowPreviewPane` | Preview sidebar. Via `CustomUserPreferences` - no typed option |
| `FXPreferredViewStyle = "Nlsv"` | List view |
| `CreateDesktop = false` | No icons on the desktop |

`ShowPreviewPane` is also tracked per view style by Finder, so a window opened
before it was set may keep the old state until you toggle it once by hand.

### Favorites - manual

`home/finder/favorites.tsv` records the intended sidebar, but **applying it is a
manual step**. Drag these into Finder's sidebar, in order:

| Name | Path |
| --- | --- |
| Recents | (Finder sidebar built-in - enable in Settings > Sidebar) |
| Desktop | `~/Desktop` |
| Documents | `~/Documents` |
| Downloads | `~/Downloads` |
| Screenshots | `~/Screenshots` |
| igote-dev | `~/igote-dev` |

Three approaches were tried and rejected:

- **Copying the store file.** Favorites live in
  `~/Library/Application Support/com.apple.sharedfilelist/*.sfl3`, which is
  TCC-protected - without Full Disk Access the directory silently *appears empty*
  rather than erroring. The files also hold opaque bookmark blobs with volume
  UUIDs and inode numbers baked in, so they don't reliably resolve on another Mac.
- **The `mysides` CLI.** Unmaintained since ~2017 and broken on macOS 15: `add`
  reports success, but `list` returns nothing and `remove` fails outright, because
  both enumerate through the long-deprecated `LSSharedFileList` API. Automating
  with it would silently accumulate duplicates.
- **`sfltool`.** Modern macOS only exposes `dumpbtm`, for background items.

If this becomes worth solving, granting Full Disk Access and versioning the
`.sfl3` would at least give same-machine backup/restore.

```sh
./finder-favorites.sh save    # current favorites -> repo
./finder-favorites.sh apply   # repo -> Finder, then: killall Finder
./finder-favorites.sh list    # what Finder has right now
```

Two reasons this doesn't just copy the store file:

- Favorites live in
  `~/Library/Application Support/com.apple.sharedfilelist/*.sfl3`, which is
  TCC-protected. Without Full Disk Access the directory simply *appears empty* -
  it doesn't error, which makes this easy to misdiagnose.
- Those files hold opaque bookmark blobs with volume UUIDs and inode numbers
  baked in, so they don't reliably resolve on a different Mac.

`mysides` goes through the `LSSharedFileList` API and deals in plain paths, so it
needs no special permission and the output actually ports.

`apply` only ever *adds*. Favorites not listed in the file are left alone - it
will never silently remove something it doesn't know about.

## Terminals

Both terminals are set up the same way:

| | |
| --- | --- |
| `Option` + `←` / `→` | Move by word |
| `Cmd` + `←` / `→` | Move to start / end of line |
| Select text | Does **not** copy |
| `Cmd` + `C` | Copies the selection |

### WezTerm

All of it lives in `home/.config/wezterm/wezterm.lua`, so it's fully declarative
and edits apply to new windows immediately.

Option+arrow sends `ESC-b` / `ESC-f` and Cmd+arrow sends `Ctrl-A` / `Ctrl-E`,
which is what zsh's line editor expects.

On copy-on-select: WezTerm's defaults for single, double and triple click are all
`CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection")` - the
`Clipboard` half is what makes a plain drag clobber your clipboard. They're
overridden to `PrimarySelection`, which still *completes* the selection (so it
stays highlighted for Cmd+C) but on macOS the primary selection isn't the system
clipboard, so Cmd+V is unaffected. Single click keeps
`CompleteSelectionOrOpenLinkAtMouseCursor` rather than `Nop` so click-to-open-link
still works.

### iTerm2

iTerm2 is fully version controlled. Its entire preferences file lives at
`home/iterm2/com.googlecode.iterm2.plist`, and iTerm2 loads from there via its own
"custom folder" mechanism.

`configuration.nix` sets only the two bootstrap keys, because they're what tell
iTerm2 where to look and so can't live inside the file being loaded:

```nix
"com.googlecode.iterm2" = {
  LoadPrefsFromCustomFolder = true;
  PrefsCustomFolder = "/Users/<user>/.dotfiles/home/iterm2";
};
```

Everything else - profile, colours, font, key mappings, `CopySelection` - is in
the plist. It's stored as **XML** rather than binary so diffs are readable.

The key mappings are iTerm2's own "Natural Text Editing" preset, read straight out
of `/Applications/iTerm.app/Contents/Resources/PresetKeyMappings.plist` and merged
into the profile's `Keyboard Map`. Merged, not replaced - any mapping already
present wins, so this is safe to re-run.

**Changing settings from here on:** edit them in the iTerm2 GUI as normal, then
when prompted on quit, let it save changes back to the folder. Then commit the
diff. If you edit the plist by hand instead, quit iTerm2 first - it writes its
in-memory copy on exit and will overwrite you.

Why the plist and not `defaults`: key mappings are a nested dictionary inside the
`New Bookmarks` profile array. Writing that through `defaults` replaces the whole
array, which would destroy the profile, theme and font along with it.

## Not managed here

A few things macOS only exposes through a GUI session, which `darwin-rebuild`
activation doesn't have. They're listed so it's clear they were considered:

- **Wallpaper** (solid black). Setting it needs AppleScript to drive Finder, and
  activation can't. Set it by hand:
  `System Settings > Wallpaper > Solid Colors > Black`.
- **Safari's own settings.** TCC-protected container, see below.
- **iTerm2 / Alfred key mappings and prefs** - handled through each app's own
  preferences-folder mechanism instead, see above.

## App Store apps

Declared in `home/mas/apps.tsv`, installed by `./mas-apps.sh`:

```sh
./mas-apps.sh install   # install anything missing
./mas-apps.sh status    # declared vs installed, plus undeclared strays
./mas-apps.sh save      # rewrite the list from what's installed
```

**This is deliberately not `homebrew.masApps`.** nix-darwin runs the Homebrew
bundle as:

```
sudo --user=<user> --set-home env brew bundle ...
```

`sudo -u` lands in a different bootstrap namespace than the user's GUI session.
`mas list` still works there (receipts are just files on disk), but `mas install`
and `mas upgrade` need the App Store daemon, which that namespace can't reach.
Every entry fails, and because the bundle runs near the end of activation it takes
the **home-manager user activation** down with it - so launchd agents and the
wallpaper silently don't get applied either. Running `mas` from a normal shell
works fine, hence the script.

Requirements: signed into the App Store with the Apple ID that owns the apps.

`cleanup = "zap"` does **not** apply to App Store apps - Homebrew only removes what
Homebrew installed. Removing something from `apps.tsv` leaves it on disk; delete it
by hand. `./mas-apps.sh status` lists those strays.

Most of this list is really Safari configuration:

| App | Purpose |
| --- | --- |
| AdBlock for Safari | Content blocking |
| Noir | Dark mode for Safari (paid) |
| Vimlike | Vim keys in Safari |
| Magnet | Window snapping |

## Safari

Safari's own settings are **not** versioned here, and can't easily be.

Its preferences live in a sandboxed container
(`~/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist`)
that macOS TCC blocks from being read or written - "Operation not permitted" even
as the owning user, even though the file is user-owned. Getting at it needs Full
Disk Access granted to the terminal, and writes additionally need Safari closed.

What *is* reproducible is the part that matters: the extensions, via `masApps`
above. Bookmarks, history, passwords and Reading List already sync through iCloud.

## Open at login

Alfred, Magnet and Handy are launched at login by launchd agents declared in
`home.nix`, one plist each in `~/Library/LaunchAgents`.

An app's own "launch at login" checkbox writes a macOS Login Item, which doesn't
reproduce on a new Mac - hence doing it here instead. **Turn those checkboxes off
in the apps**, or you have two mechanisms doing the same job.

To check what's registered:

```sh
launchctl list | grep dev.igote.login
```

AltTab manages its own LaunchAgent (`com.lwouis.alt-tab-macos.plist`) when you
enable start-at-login in its settings. That one is left alone - home-manager only
touches agents it declares.

## Mac app preferences

Apps that keep settings in a plist are versioned in `home/macos-prefs/`, as XML
so diffs are readable, filtered down to real settings (AppCenter telemetry IDs,
Sparkle updater state and saved window positions are stripped out).

```sh
./macos-prefs.sh export   # live prefs -> repo
./macos-prefs.sh import   # repo -> live, quits and restarts the app
./macos-prefs.sh diff     # show drift, change nothing
```

Add a `domain:App Name` line to `DOMAINS` in the script to cover another app.
Leave the app name empty for domains no running app owns.

`import` quits the owning app first on purpose: macOS caches preferences in
`cfprefsd`, and a running app will write its in-memory copy straight back over
the import.

Covered today:

- **AltTab** - appearance, hold shortcut, menu bar icon.
- **`com.apple.symbolichotkeys`** - system keyboard shortcuts. 18 of the 22
  hotkeys are disabled here, including Spotlight's Cmd+Space so Alfred can own
  it, plus Mission Control and Spaces navigation. Captured as a whole domain
  because writing a partial `AppleSymbolicHotKeys` dict replaces all of it.
  **Takes effect on next login, not immediately.**

Magnet is not here - it stores nothing at the usual preferences path.

On a fresh Mac, `./macos-prefs.sh import` is a required step. Without it Spotlight
still owns Cmd+Space and fights Alfred.

## Notes

The first time you launch `nvim`, it bootstraps
[lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub.
That needs network access once; after that it's offline.

Neovim keymaps worth knowing: space is the leader, `<Esc>` saves, `<leader>f`
finds files, `<leader>s` greps, `<leader>e` opens the file browser, `<leader>g`
opens Neogit. The mouse is off on purpose.

Git's editor is still `code --wait`. Change `programs.git.settings.core.editor`
in `home.nix` to `"nvim"` once Neovim feels like home.
