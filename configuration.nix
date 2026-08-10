{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  # Codex's agent policy. It has to sit in /etc rather than under ~/.codex,
  # because Codex owns ~/.codex/config.toml and rewrites it from scratch on
  # every settings change, dropping whatever it does not recognise. See the
  # comments in the file itself for the full story.
  #
  # readFile rather than `.source`, because handing nix-darwin's /etc derivation
  # a flake source path makes it warn that the reference has no string context
  # and is unreliable. Embedding the text sidesteps that.
  environment.etc."codex/managed_config.toml".text =
    builtins.readFile ./etc/codex/managed_config.toml;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
      # No two-finger swipe for back/forward - it fires by accident constantly.
      AppleEnableSwipeNavigateWithScrolls = false;
    };

    dock = {
      autohide = true;
      tilesize = 46;
      show-recents = false;   # no recent apps cluttering the dock
      # Bottom-right hot corner triggers Quick Note, but only while holding Cmd
      # so it can't fire from a stray cursor. The modifier itself has no typed
      # option - see CustomUserPreferences below.
      wvous-br-corner = 14;

      # The dock, in order, left to right. This REPLACES the dock on every
      # switch - anything dragged in by hand disappears on the next rebuild, so
      # add it here instead.
      #
      # Safari must use the Cryptexes path, ugly as it is. /Applications/Safari.app
      # is only a symlink into that volume, and the Dock does not follow it to read
      # the bundle's display name - it falls back to the filename and the tile ends
      # up labelled "Safari.app". This is the path macOS itself stores.
      persistent-apps = [
        "/System/Applications/Launchpad.app"
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Reminders.app"
        "/Applications/Obsidian.app"
        "/System/Applications/Notes.app"
        "/Applications/Numi.app"
        "/Applications/WezTerm.app"          # replaced iTerm here
        "/Applications/Visual Studio Code.app"
        "/Applications/GitHub Desktop.app"
        "/System/Applications/System Settings.app"
        "/System/Applications/App Store.app"
      ];

      # No folders or files in the dock. Declared so a stray drag gets reverted
      # rather than silently kept.
      persistent-others = [ ];
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";  # list view by default
      CreateDesktop = false;          # clean desktop

      # Folders never mix in with files, in windows and on the desktop.
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;

      # Search the current folder, not the whole Mac.
      FXDefaultSearchScope = "SCcf";

      ShowPathbar = true;    # folder chain at the bottom, and a drop target
      ShowStatusBar = true;  # item count and free space
    };

    trackpad = {
      Clicking = true;                    # tap to click
      TrackpadThreeFingerTapGesture = 0;  # no three-finger tap to look up
    };

    # Screenshots go to a folder, not all over the desktop. home.nix creates the
    # directory - screencapture silently falls back to the Desktop if it's missing.
    screencapture.location = "/Users/${user}/Screenshots";

    menuExtraClock.ShowDate = 0;  # date only when there's room for it

    WindowManager = {
      # Clicking the wallpaper should not shove every window out of the way.
      EnableStandardClickToShowDesktop = false;
      AppWindowGroupingBehavior = true;  # show an app's windows all at once
    };

    # Escape hatch for keys nix-darwin has no typed option for.
    CustomUserPreferences = {
      # 1048576 = 0x100000 = the Cmd key. Pairs with dock.wvous-br-corner above.
      "com.apple.dock"."wvous-br-modifier" = 1048576;

      # View > Show Preview. No typed option in nix-darwin. Finder also tracks
      # the preview pane per view style, so a window opened before this was set
      # may keep its old state until toggled once by hand.
      "com.apple.finder"."ShowPreviewPane" = true;

      # iTerm2 loads its entire preferences from this repo. Everything else -
      # profile, theme, font, key mappings, CopySelection - lives in
      # home/iterm2/com.googlecode.iterm2.plist.
      #
      # Only these two bootstrap keys belong in the local domain: they're what
      # tells iTerm2 where to look, so they can't live in the file being loaded.
      "com.googlecode.iterm2" = {
        LoadPrefsFromCustomFolder = true;
        PrefsCustomFolder = "/Users/${user}/.dotfiles/home/iterm2";
      };
    };
  };

  nix-homebrew = {
    enable = true;
    inherit user;
    # This Mac already had Homebrew installed at /opt/homebrew before nix-homebrew
    # existed. Without autoMigrate, nix-homebrew refuses to manage a prefix it
    # did not create and the first switch fails outright.
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    # Every switch removes any formula or cask NOT listed below. Everything that
    # was already installed on this machine is declared here so the first switch
    # is a no-op. If you `brew install` something later, add it here too or the
    # next rebuild takes it back out.
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];

    brews = [
      "clang-format"
      "cmake"
      "gh"
      "googletest"
      # Agent multiplexer: owns the terminals Claude Code and friends run in, so
      # they survive a closed laptop. The server auto-spawns on first client
      # launch, so the formula's `brew services start herdr` caveat is noise.
      "herdr"
      "mas"         # App Store CLI, required by masApps below
      "poetry"
      "poppler"
      "python@3.11"
      "tectonic"    # load-bearing: builds the resume PDF, locally and in CI
    ];

    casks = [
      "alfred"      # installs "Alfred 5.app"
      "alt-tab"
      "claude"      # Anthropic's desktop app (NOT claude-code, see below)
      # OpenAI's terminal coding agent. This IS the right way to install it,
      # unlike claude-code below: `codex doctor` reports its own update action
      # as `brew upgrade --cask codex`, so the CLI defers to Homebrew instead of
      # replacing its own binary. Config lives in home/.codex/config.toml.
      # It's a cask, not a formula - the artifact is a prebuilt bin/codex.
      "codex"
      # Docker Desktop. The cask is "docker-desktop" - the plain "docker" cask
      # was renamed in 2025, and the "docker" *formula* is the CLI alone, which
      # would fight the app for /usr/local/bin/docker. The app ships the whole
      # client (docker, compose, credential helpers) and symlinks it there
      # itself, so nothing else needs declaring.
      "docker-desktop"
      "font-fira-code"
      "font-fira-code-nerd-font"
      "github"      # GitHub Desktop (the cask is "github", not "github-desktop")
      "handy"       # push-to-talk speech to text
      "iterm2"      # kept alongside wezterm; drop once wezterm sticks
      # NOT declared: mysides. It's unmaintained and broken on macOS 15 - `add`
      # reports success but `list` returns nothing and `remove` fails, because
      # both depend on enumerating via the long-deprecated LSSharedFileList API.
      # Finder favorites are a manual step, see README.
      "numi"
      "obsidian"
      "visual-studio-code"
      "wezterm"
    ];

    # NOTE: homebrew.masApps is deliberately NOT used.
    #
    # nix-darwin runs the Homebrew bundle as
    #   sudo --user=<user> --set-home env brew bundle ...
    # and `sudo -u` lands in a different bootstrap namespace than the user's GUI
    # session. `mas list` still works there (it reads receipts off disk), but
    # `mas install` and `mas upgrade` need the App Store daemon, which that
    # namespace can't reach - so every masApps entry fails and takes the whole
    # activation down with it, including the home-manager user activation that
    # runs afterwards.
    #
    # App Store apps are declared in home/mas/apps.tsv and installed by
    # ./mas-apps.sh, which runs from a normal shell where the daemon is
    # reachable. See README.

    # Claude, Docker, Numi, Obsidian and VS Code were all installed by hand into
    # /Applications before brew knew about them. onActivation.extraFlags has
    # --force, so the first switch lets brew adopt and overwrite those bundles.
    # App data lives in ~/Library and survives that - for Docker that means
    # images, volumes and containers (~/Library/Containers/com.docker.docker)
    # are kept when brew replaces the app.

    # Deliberately NOT declared:
    #   fzf                    -> installed via Nix in home.nix instead
    #   zsh-syntax-highlighting -> home-manager's programs.zsh provides it
    #   claude-code            -> the claude CLI is the native installer at
    #                             ~/.local/bin/claude and self-updates; the cask
    #                             would be a second, competing install. The
    #                             "claude" cask above is the desktop app, which
    #                             is a different thing.
    #   docker (formula)       -> the CLI only, and it installs its own
    #                             /usr/local/bin/docker. Docker Desktop already
    #                             puts one there; two owners of that path is a
    #                             fight nobody wins.
    #   docker-compose         -> shipped with Docker Desktop as a CLI plugin.
  };
}
