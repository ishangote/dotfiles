{ config, pkgs, lib, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";

  # Only tools that are nothing but a binary on PATH belong here. Anything with
  # a `programs.<name>` module goes through the module instead - it installs the
  # same package AND wires up the shell integration, which is the part that was
  # missing. fzf, bat, eza and zoxide were all listed here as well; fzf and
  # zoxide were plain duplicates of their modules, and bat and eza had no module
  # at all, so nothing ever aliased `ls` or the pager to them and both went
  # unused.
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find, and what fzf shells out to - see programs.fzf below
    jq        # json on the command line
    lazygit
    tree
    htop
    neovim
    git-lfs   # was pulled in by programs.git.lfs.enable, see below
    # the font everything renders in
    nerd-fonts.fira-code
  ];
  fonts.fontconfig.enable = true;

  home.sessionVariables.EDITOR = "nvim";

  # `man` through bat, so man pages get the same syntax colouring as everything
  # else. `col -bx` strips the overstrike backspace sequences roff emits for
  # bold and underline, which bat would otherwise render literally.
  home.sessionVariables.MANPAGER = "sh -c 'col -bx | bat -l man -p'";

  # node comes from `nix profile install nixpkgs#nodejs_22`, so npm's default
  # global prefix is that read-only store path and `npm install -g` fails
  # outright. Point it at a writable directory instead. Declared here rather
  # than with `npm config set`, which would write an untracked ~/.npmrc.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";

  # The native claude installer lives here and self-updates; keep it reachable.
  # ~/.npm-global/bin is where the npm prefix above puts globally installed
  # binaries - currently just `pi`, see the Pi section below.
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.npm-global/bin" ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    # /opt/homebrew/bin is NOT in /etc/paths on Apple Silicon, so without this
    # every brew binary (tectonic, gh, cmake, ...) drops off PATH the moment the
    # old hand-written ~/.zprofile is replaced.
    #
    # Note that `brew shellenv` PREPENDS. /opt/homebrew/bin therefore sits ahead
    # of every Nix path - ~/.nix-profile/bin, /etc/profiles/per-user/<user>/bin,
    # /run/current-system/sw/bin - and Homebrew wins every name collision.
    # Read off this machine with `zsh -ilc 'print -l $path'`.
    #
    # The rule that follows: a tool goes in `home.packages` or in `brews`, never
    # both. Today nothing overlaps. The day something does, the Nix copy silently
    # stops being the one that runs and nothing warns you.
    #
    # nix-darwin's generated /etc/zshrc runs `brew shellenv` a second time for
    # interactive shells. That is a duplicate but not a redundancy: this one
    # covers login shells, which /etc/zshrc does not, so it stays.
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
    # Everything hand-written moved to home/.config/zsh/rc.zsh, which is a real
    # file in this repo symlinked to ~/.config/zsh/rc.zsh (declared below), so
    # shell code is editable without a rebuild like every other config here.
    # That file explains what belongs in it and what belongs up here.
    #
    # The guard is deliberate. A missing file would otherwise abort the rest of
    # ~/.zshrc on every single shell, and a shell that cannot start takes the
    # agents down with it. Loud, not silent: it says which invariant broke.
    initContent = ''
      if [[ -r "$HOME/.config/zsh/rc.zsh" ]]; then
        source "$HOME/.config/zsh/rc.zsh"
      else
        print -u2 "zsh: ~/.config/zsh/rc.zsh is missing - is this repo still symlinked at ~/.dotfiles?"
      fi
    '';
    history = {
      size = 100000;
      save = 100000;
      # Timestamps and durations per entry. home-manager forces
      # NO_EXTENDED_HISTORY otherwise, which leaves no record of *when* anything
      # ran - and since share_history (a home-manager default, already on)
      # merges every herdr pane into one file, the timestamps are the only thing
      # that makes the interleaved result readable afterwards.
      extended = true;
      # Keep only the most recent copy of a repeated command anywhere in the
      # file, not just consecutively. ignoreDups and ignoreSpace are already on
      # by default and are not restated here.
      ignoreAllDups = true;
      # Destructive one-offs, never worth resurrecting with a stray Up.
      ignorePatterns = [ "rm *" "kill *" ];
    };
    # Up/Down search history for entries matching what is already on the line,
    # instead of walking it blindly. Complements the autosuggestion on ^f rather
    # than replacing it: that completes one entry inline, this cycles matches.
    #
    # Both encodings of each arrow are bound. Terminals send ^[[A in normal
    # cursor mode and ^[OA in application mode, and which one arrives depends on
    # whether the line editor has switched the terminal over; home-manager's
    # default binds only the first.
    historySubstringSearch = {
      enable = true;
      searchUpKey = [ "^[[A" "^[OA" ];
      searchDownKey = [ "^[[B" "^[OB" ];
    };
    # Named directories. `~dot` expands anywhere a path is expected - cd,
    # completion, and the prompt, which shortens the displayed path to match.
    # An alias would only work as the first word of a command.
    dirHashes = {
      dot = dotfiles;
      dev = "${config.home.homeDirectory}/igote-dev";
      ws = "${config.home.homeDirectory}/igote-workspace";
    };
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      # Bypass mode is set in ~/.claude/settings.json (permissions.defaultMode),
      # so it applies to every entry point - shell, IDE extension, desktop app -
      # not just interactive shells. No need for the flag here.
      cc = "claude";
    };
  };

  # These replace the oh-my-zsh `fzf` and `z` plugins.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # Without these, fzf shells out to plain `find`, which descends into
    # node_modules and .git and ignores .gitignore entirely - so Ctrl+T in a
    # node repo spends most of its time somewhere useless. `fd` does all three
    # correctly and is already installed above; this is the reason it is there.
    # Confirmed unset before this was added, with
    #   zsh -ic 'echo "[$FZF_DEFAULT_COMMAND]"'
    # which printed an empty pair of brackets.
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    # Preview the file under the cursor in Ctrl+T. Capped at 200 lines because
    # the preview pane cannot show more and bat would colour the whole file.
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    ];
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # eza and bat were both in home.packages with nothing pointing at them, so
  # `ls` was still BSD ls and bat only ran when typed by name. These modules
  # install the same binaries and define the integration in one place.
  programs.eza = {
    enable = true;
    enableZshIntegration = true;  # defines ls, ll, la, lla and lt
    icons = "auto";               # only when stdout is a terminal
    git = true;                   # per-file git status column in listings
    extraOptions = [ "--group-directories-first" ];
  };
  programs.bat = {
    enable = true;
    # base16 is the closest thing bat ships to the rose-pine palette everything
    # else here uses. Read the full list with `bat --list-themes`.
    config.theme = "base16";
  };

  # Per-project toolchains, entered and left on cd. Without this, every repo
  # needs `nix develop` typed by hand, so whatever happens to be installed
  # globally wins by default and the flake in the repo is decoration.
  #
  # nix-direnv is the load-bearing half, not an optional extra: plain direnv
  # re-evaluates the flake on every cd into the directory, which is slow enough
  # to make the whole thing unusable, and it does not root the result against a
  # garbage collect. nix-direnv caches and roots it.
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # git's pager, with syntax highlighting and word-level intra-line diffs.
  # enableGitIntegration defaults to false and has to be asked for - it is what
  # sets delta as the pager for diff/log/show/blame and as the filter for
  # interactive staging. Chosen over difftastic, whose structural diffs are
  # better on code refactors and worse on prose, and most of this repo is prose.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;      # n and N jump file to file inside the pager
      line-numbers = true;
      syntax-theme = "base16";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      # An explicit format is a whitelist: every module not named here is off,
      # however relevant it would be. $nix_shell and $python are named because
      # without them a `nix develop` or an activated venv is completely
      # invisible, which on a machine built entirely on Nix is the one thing the
      # prompt most needs to say. Both render only when they apply.
      format = "$directory$git_branch$git_status$nix_shell$python$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Ishan Gote";
        # GitHub's noreply address rather than the real one, so commits pushed
        # from here don't publish a scrapeable inbox. GitHub still attributes
        # them - the numeric prefix is the account ID, from Settings -> Emails.
        email = "19831767+ishangote@users.noreply.github.com";
      };
      # VS Code stays the git editor for now. Switch to "nvim" once that's home.
      core.editor = "code --wait";
      # These are what `programs.git.lfs.enable` would generate, except it bakes
      # the absolute /nix/store path of the binary into each command. GitHub
      # Desktop compares them literally against "git-lfs clean -- %f" and warns
      # on every operation, so name the binary and let PATH resolve it - Desktop
      # then picks up its own bundled copy. lfs.enable stays off because it would
      # define these same keys a second time; git-lfs is in home.packages instead.
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
    };
    ignores = [ "**/.claude/settings.local.json" ];
  };

  # Edit-in-place: the real file stays in this repo, ~/.config just points at it.
  # No rebuild needed after editing anything below.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  # The hand-written half of the shell, sourced from the tail of the ~/.zshrc
  # home-manager generates. The file, not the directory: ~/.config/zsh is where
  # a future ZDOTDIR would put .zsh_history and the compdump, and neither of
  # those belongs in a public repo.
  home.file.".config/zsh/rc.zsh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/zsh/rc.zsh";

  # herdr gets the file, not the directory. Unlike nvim and wezterm above, its
  # config directory doubles as its runtime directory - herdr.sock and
  # sessions/ live in ~/.config/herdr - and symlinking the directory would drag
  # live sockets and session state into this repo.
  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr/config.toml";

  # Only settings.json, statusline-command.sh and CLAUDE.md (declared with the
  # agent policy at the bottom of this file) under ~/.claude are managed.
  # Everything else there (sessions, projects, history.jsonl,
  # settings.local.json) is machine-local runtime state and is left alone.
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  home.file.".claude/statusline-command.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/statusline-command.sh";

  # Pi. Installed from npm, NOT declared in configuration.nix: the version in
  # this repo's pinned nixpkgs is 0.75.4, nine releases behind, and Pi installs
  # its own declared packages at startup, so Homebrew/Nix would only ever fight
  # it. Install with:
  #   npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  #
  # Only these four repo-authored paths are managed. ~/.pi/agent ITSELF is
  # deliberately not linked - Pi keeps auth.json, sessions, trust decisions,
  # caches and the npm/git package trees it downloads in that same directory,
  # and none of that belongs in git. Same reasoning as herdr above.
  #
  # Run /reload inside Pi after editing a theme or a local extension.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";

  # VS Code. These are live symlinks, so editing settings through the GUI writes
  # straight back into this repo.
  # IMPORTANT: VS Code Settings Sync must stay OFF. If it is on, it periodically
  # overwrites settings.json from the cloud copy and silently reverts repo edits.
  # Extensions are not managed here - see ./vscode-extensions.sh.
  #
  # These two are the *default* profile only. Named profiles keep their own
  # settings.json and keybindings.json and cannot be declared here: a profile's
  # directory is not named after the profile and is not derivable from it either
  # (igote-dev-cpp lives in profiles/-3a41f61b, while VS Code's own
  # hash("igote-dev-cpp").toString(16) is 7cad4157), so the location is random per
  # creation. Hardcoding one would work here and silently point at nothing on a
  # fresh Mac. ./vscode-profiles.sh resolves it at run time instead.
  home.file."Library/Application Support/Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/vscode/settings.json";
  home.file."Library/Application Support/Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/vscode/keybindings.json";

  # Obsidian has no global settings layer - every setting lives in
  # <vault>/.obsidian. One shared copy in home/obsidian/config stands in for
  # that: point every vault at it and they all get the same theme, plugins and
  # hotkeys. Add a line here per vault you intend to keep, or run
  # ./obsidian-vault.sh <path> for a one-off.
  #
  # home.file."igote-dev/<vault>/.obsidian".source =
  #   config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/obsidian/config";
  home.file."igote-workspace/.obsidian".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/obsidian/config";

  # configuration.nix points screencapture.location here. macOS does not create
  # the folder itself - if it's missing, screenshots silently land on the Desktop.
  home.activation.createScreenshotsDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "$HOME/Screenshots"
    '';

  # The wallpaper is deliberately NOT managed here. Setting it needs AppleScript
  # to drive Finder, and activation has no GUI session to do that from - the same
  # limitation that rules out homebrew.masApps. It only ever warned, so it was
  # noise. Set it by hand: System Settings > Wallpaper > Solid Colors > Black.

  # Open at login. macOS "Login Items" set through an app's own preferences are
  # not reproducible on a new Mac, so these are declared as launchd agents
  # instead - one plist per app in ~/Library/LaunchAgents.
  #
  # -g launches without stealing focus, which matters at login: all three are
  # menu-bar apps and shouldn't pull a window to the front.
  #
  # Do NOT add KeepAlive here. `open` exits as soon as it has launched the app,
  # so launchd would treat that as a crash and respawn it forever.
  launchd.agents = {
    alfred = {
      enable = true;
      config = {
        Label = "dev.igote.login.alfred";
        ProgramArguments = [ "/usr/bin/open" "-g" "-a" "/Applications/Alfred 5.app" ];
        RunAtLoad = true;
      };
    };
    magnet = {
      enable = true;
      config = {
        Label = "dev.igote.login.magnet";
        ProgramArguments = [ "/usr/bin/open" "-g" "-a" "/Applications/Magnet.app" ];
        RunAtLoad = true;
      };
    };
    handy = {
      enable = true;
      config = {
        Label = "dev.igote.login.handy";
        ProgramArguments = [ "/usr/bin/open" "-g" "-a" "/Applications/Handy.app" ];
        RunAtLoad = true;
      };
    };
  };

  # One agent policy, shared by every agent that reads one. AGENTS.md is the
  # canonical, harness-agnostic file; each harness gets a link to it under the
  # name it looks for. USER.md and OPINIONS.md sit beside it in ~ because
  # AGENTS.md references them by path and loads them on demand.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  # Only AGENTS.md under ~/.codex is managed. config.toml deliberately is not:
  # Codex rewrites that file from scratch whenever a setting changes in the TUI,
  # which replaced the symlink with a regular file and aborted activation. Its
  # agent policy moved to /etc/codex/managed_config.toml, declared in
  # configuration.nix, where Codex cannot overwrite it. What is left in
  # ~/.codex/config.toml is model, reasoning effort and per-project trust, which
  # Codex should be free to change - the counterpart to settings.local.json.
  home.file."AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file."USER.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/USER.md";
  home.file."OPINIONS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/OPINIONS.md";
}
