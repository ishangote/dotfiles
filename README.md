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
- Agent multiplexer (herdr, themed to match)
- Apps (VS Code, Obsidian, Claude desktop, Docker Desktop, Numi, Alfred, AltTab, Magnet, Handy, iTerm2)
- Alfred preferences, AltTab settings
- Open-at-login for Alfred, Magnet and Handy
- VS Code settings, keybindings and extension list
- Obsidian vault config for the llm-wiki vault
- Coding agents (Claude Code settings, Codex CLI and its settings) sharing one
  `AGENTS.md` policy and one permission posture

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

herdr is the exception to the directory-shaped ones: only
`~/.config/herdr/config.toml` is linked, not `~/.config/herdr`. herdr keeps its
socket and session state in that same directory, and linking the directory would
pull live runtime state into the repo.

Run `./rebuild.sh` only when you change something that isn't a symlinked file:
a package list, a shell alias, a macOS default.

The agent directories follow the same rule as herdr, for the same reason. Only
named files are linked, never the directory: `settings.json` and
`statusline-command.sh` under `~/.claude`, `config.toml` and `AGENTS.md` under
`~/.codex`. Everything else in those directories - sessions, projects, history,
`settings.local.json`, Codex's sqlite state DBs and its `auth.json` - is
machine-local runtime state, and in `auth.json`'s case a live credential. See
[Agents](#agents) for what the managed files actually set.

## Homebrew is declarative

`configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`. Every switch
removes any formula or cask **not** listed in `brews` and `casks`.

Everything already on this machine is declared there, so the first switch is a
no-op. But if you `brew install` something later, add it to `configuration.nix`
too - otherwise the next `./rebuild.sh` takes it straight back out.

Magnet is Mac App Store only, so it isn't in `casks` at all - App Store apps are
declared in `home/mas/apps.tsv` and installed by `./mas-apps.sh`, for the reason
spelled out under [App Store apps](#app-store-apps).

Things deliberately left out of the brew lists:

- `claude-code` cask - `claude` is the native installer at `~/.local/bin/claude`
  and self-updates. The cask would be a second, competing install. Note this is
  *not* the case for Codex, which **is** declared as a cask and defers its own
  updates back to brew - see [Agents](#agents).
- `docker` formula and `docker-compose` - both ship inside Docker Desktop. The
  formula would also claim `/usr/local/bin/docker`, which the app owns.

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

**If selecting text copies anyway, check what's running in the terminal before
you touch either terminal's config.** A TUI that turns on mouse reporting
(`\e[?1000h`) takes the mouse away from the terminal and does its own thing with
it. Claude Code is the one that bites: it has its own `copyOnSelect` setting
which **defaults to on**, so it copies on select no matter what iTerm2 or WezTerm
are set to. Turn it off with `/config` → Input & controls → "Copy on select".

That setting lives in `~/.claude.json`, which also holds oauth tokens and
per-project history, so it is not symlinked into this repo and not declarative.
It's a one-time toggle per machine.

herdr is the third place that has to be told, and the same trap: it captures the
mouse for its own UI, and its `copy_on_select` also **defaults to on**, so inside
a herdr pane it wins over WezTerm's `Nop` bindings. Unlike Claude Code's, this
one is declarative - `[ui] copy_on_select = false` in
`home/.config/herdr/config.toml`, already set.

**Inside a herdr pane the copy key is `Ctrl` + `C`, not `Cmd` + `C`.** That's the
one place the table above doesn't hold. WezTerm takes `Cmd+C` for its own
selection, which is empty because herdr owns the mouse, so it never reaches
herdr. herdr's copy key is not configurable - there's no `copy` entry in
`[keys]`, it's baked into the `copy_on_select = false` path.

`Ctrl+C` is *not* swallowed. It copies any pending selection **and** still passes
through to whatever is running underneath, so Claude Code's own `Ctrl+C` ladder
(clear the input, then interrupt) works exactly as it does outside herdr. With a
selection pending it does both at once. Verified, not inferred - this was the
thing worth checking before trusting the setting, since a multiplexer that ate
`Ctrl+C` would mean not being able to interrupt a running agent.

A copy fires a clipboard toast (`[ui.toast.clipboard]`, on by default). That's the
tell for which of the two happened.

If you want the familiar semantics inside herdr, `Shift`+drag selects over its
head and `Cmd+C` copies, because `Shift` is WezTerm's
`bypass_mouse_reporting_modifiers`. See the herdr section for the rest.

### WezTerm

All of it lives in `home/.config/wezterm/wezterm.lua`, so it's fully declarative
and edits apply to new windows immediately. Full key reference, including the
defaults worth knowing: [`docs/wezterm-keys.md`](docs/wezterm-keys.md).

Option+arrow sends `ESC-b` / `ESC-f` and Cmd+arrow sends `Ctrl-A` / `Ctrl-E`,
which is what zsh's line editor expects.

Pane bindings, since the defaults (`Ctrl+Shift+Opt+'` and `Ctrl+Shift+Opt+5`) are
unmemorable and WezTerm ships **no** binding for closing a single pane:

| | |
| --- | --- |
| `Cmd` + `D` | Split - new pane to the right |
| `Cmd` + `Shift` + `D` | Split - new pane below |
| `Cmd` + `Shift` + `W` | Close pane (with confirm) |
| `Cmd` + `Opt` + arrows | Move focus between panes |

`Cmd+W` is left alone and still closes the whole tab. `Ctrl+Shift+arrows` still
moves pane focus too - that default isn't removed.

On copy-on-select, and the trap to avoid: **do not** reach for
`CompleteSelection("PrimarySelection")`. On macOS there is no separate primary
selection - it resolves to the same `NSPasteboard` as `Clipboard`, so it clobbers
Cmd+V exactly like the default `ClipboardAndPrimarySelection` does. There is no
"copy nowhere" destination either.

So every mouse-up that would complete a selection is bound to `act.Nop`. The
selection is made on Down/Drag, not Up, so text still highlights and Cmd+C still
copies it. All six Up variants must be listed - Shift+click and Alt+click keep
the copying default otherwise. Verify with:

```sh
wezterm show-keys | grep 'Up {'   # nothing may say Complete*
```

`Nop` costs click-to-open-link, since the default action did the opening and the
copying in one. `Cmd`+click takes that over.

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

## herdr

A terminal workspace manager for coding agents. It owns the terminals Claude Code
and friends run in, so an agent keeps working when the laptop closes or the
network drops, and you reattach later instead of starting over. Think tmux,
scoped to agents: it doesn't wrap or replace the CLIs, it just holds their PTYs.
The sidebar tracks which agents are working, blocked or idle.

Installed from `brews` in `configuration.nix` - it's in homebrew-core, no tap.
Not the `curl | sh` installer upstream advertises, which would be invisible to
this repo and absent on a fresh machine.

```sh
herdr                 # launch or attach
herdr status          # client and server state
herdr config check    # validate config.toml
```

Nothing needs starting. The formula's caveat suggests `brew services start
herdr`, but the client auto-spawns a server if one isn't running, so there's no
launchd agent here and nothing to declare.

Config is `home/.config/herdr/config.toml`, live-symlinked. Only the handful of
settings that differ from upstream defaults are in it - run
`herdr --default-config` for the full annotated schema. The running server does
not pick up edits on its own: `prefix+shift+r`, or `herdr server reload-config`.
The prefix is the default `ctrl+b`, which is free here because there's no tmux
and WezTerm's bindings are all Cmd-based. Confirmed it doesn't collide with
Claude Code either - `ctrl+b` enters prefix mode cleanly with an agent focused.

Detach with `prefix` then `q`. Quitting WezTerm entirely and running `herdr`
again brings the session back with the agent still alive and scrollback intact,
which is the whole point of the thing.

On the theme: herdr ships `rose-pine` and `rose-pine-dawn`, but **not**
`rose-pine-moon`, which is what Neovim and WezTerm use. Moon is close to
rose-pine with a lifted background, so the config takes the built-in theme for
its hues and overrides three background tokens (`panel_bg`, `surface0`,
`surface1`) to moon's values. The accent colors are left alone rather than
hand-mapped. The result is indistinguishable from a WezTerm pane side by side,
so the overrides are doing their job - if herdr ever starts looking darker than
the terminal around it, those three tokens stopped applying.

On the mouse: `[ui] mouse_capture` is a single all-or-nothing switch over herdr's
entire mouse UI, and it was tried both ways here before settling on the default.

| | `mouse_capture = true` | `false` |
| --- | --- | --- |
| Click panes and spaces | yes | **no** |
| Drag-select inside herdr | yes, copy with `Ctrl+C` | no |
| `Cmd`+click a URL | **no** | yes |

It's on. The deciding argument is the asymmetry, not preference: with capture on,
opening a link still has a route (select it, copy, paste), while with it off
there is no way to click a pane at all. Losing navigation costs more than losing
a shortcut to something still reachable another way.

The escape hatch worth remembering: **`Shift`+drag selects over herdr's head**,
and `Cmd+C` copies it. `Shift` is WezTerm's `bypass_mouse_reporting_modifiers`,
so it hands the mouse back to the terminal regardless of what the app asked for.
That's how to grab a URL or any other text without herdr in the middle, and it's
why `wezterm.lua` binds `SHIFT` mouse-up to `Nop` alongside the others - that
binding stops the Shift+drag selection auto-copying.

**Do not run `herdr update`.** It self-updates the binary, which Homebrew owns
here - `onActivation.cleanup = "zap"` reconciles against the `brews` list every
rebuild, so a self-update leaves the declared version and the real one
disagreeing. The background version check is off in the config for that reason.
Upgrade with `brew upgrade herdr`. The separate `manifest_check` is left on: it
refreshes agent-detection rules, not the binary.

## Agents

Two coding agents are set up here, Claude Code and Codex, and they are
deliberately configured to behave the same way.

**One policy file.** `home/AGENTS.md` is the canonical, harness-agnostic agent
doctrine. Each harness gets a symlink to it under the name it looks for -
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/AGENTS.md` for everything
else that reads that convention. `USER.md` and `OPINIONS.md` sit beside it in
`~` because `AGENTS.md` references them by path and loads them on demand. Edit
one file, every agent picks it up.

**One permission posture.** Both are set to never ask and never sandbox:

| | Claude Code | Codex |
| --- | --- | --- |
| File | `home/.claude/settings.json` | `home/.codex/config.toml` |
| Prompting | `permissions.defaultMode = "bypassPermissions"` | `approval_policy = "never"` |
| Containment | none available | `sandbox_mode = "danger-full-access"` |

This is deliberate, not an oversight. On the Claude side it's a setting rather
than a `--dangerously-skip-permissions` alias so it holds for every entry point -
shell, IDE extension, desktop app - and `skipDangerousModePermissionPrompt`
suppresses the one-time confirmation screen that mode would otherwise show on
startup.

On the Codex side the two keys are separate switches and both are load-bearing.
`approval_policy` decides whether Codex stops to ask; `sandbox_mode` decides what
it can reach when it doesn't. Setting only the first would leave the macOS
seatbelt sandbox on, and Codex would silently fail writes outside the workspace
rather than prompt for them - the worst of both. Check the resolved posture any
time with `codex doctor`, which prints the approval policy and both sandbox
states, and validate an edit to `config.toml` with
`codex --strict-config doctor`, which turns an unrecognized key into a hard
error instead of a silent no-op.

**Both defer to their installer, but not the same one.** Codex is a declared
cask and `codex doctor` reports its own update action as
`brew upgrade --cask codex`, so `codex update` routes back to Homebrew rather
than swapping the binary out from under it - the herdr problem doesn't arise, and
its startup version check is left on. Claude Code is the opposite: it isn't in
the brew lists at all, because `claude` is the native self-updating installer at
`~/.local/bin/claude` and the `claude-code` cask would be a second, competing
install. The `claude` cask that *is* declared is the desktop app, a different
thing.

**`codex login` is a manual step**, like signing into the App Store for
`mas-apps.sh`. Codex stores ChatGPT tokens in `~/.codex/auth.json`, which is a
credential and is neither symlinked nor committed. On a fresh machine run
`codex login` once; `codex doctor` confirms it under `auth`.

## Docker

Docker Desktop comes from the `docker-desktop` cask. The app bundles the whole
client and symlinks it into `/usr/local/bin` itself, so `docker`, `docker compose`
and the credential helpers all work with nothing else declared.

Two things the config can't do for you:

- **First launch needs an admin password.** Docker Desktop installs a privileged
  helper for its VM and networking, and that prompt only appears in a GUI
  session. Launch the app once by hand after a fresh setup.
- **The daemon has to be running.** `docker` on the CLI talks to the VM the app
  manages - if the app isn't open, every command fails with a socket error.
  Docker's own "Start Docker Desktop when you sign in" setting handles that;
  it's not declared as a launchd agent here because unlike Alfred or Magnet the
  VM is worth starting deliberately.

Images, volumes and containers live in `~/Library/Containers/com.docker.docker`,
which is untouched by rebuilds and by brew replacing the app.

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
