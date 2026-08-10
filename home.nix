{ config, pkgs, lib, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    bat       # cat with syntax highlighting
    eza       # modern ls
    zoxide    # smarter cd, replaces the oh-my-zsh `z` plugin
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
  # The native claude installer lives here and self-updates; keep it reachable.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    # /opt/homebrew/bin is NOT in /etc/paths on Apple Silicon, so without this
    # every brew binary (tectonic, gh, cmake, ...) drops off PATH the moment the
    # old hand-written ~/.zprofile is replaced.
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
    initContent = ''
      bindkey '^f' autosuggest-accept

      # carried over from the old .zshrc: alt-arrow word motion
      bindkey "\e\eOD" backward-word
      bindkey "\e\eOC" forward-word

      setopt share_history
    '';
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
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
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

  # VS Code. These are live symlinks, so editing settings through the GUI writes
  # straight back into this repo.
  # IMPORTANT: VS Code Settings Sync must stay OFF. If it is on, it periodically
  # overwrites settings.json from the cloud copy and silently reverts repo edits.
  # Extensions are not managed here - see ./vscode-extensions.sh.
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
  # Codex's settings, the counterpart to .claude/settings.json above. Same rule
  # applies: only this file and AGENTS.md under ~/.codex are managed. The rest -
  # auth.json with the ChatGPT tokens, the sqlite state DBs, session rollouts -
  # is machine-local and stays out of the repo.
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.codex/config.toml";
  home.file."AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file."USER.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/USER.md";
  home.file."OPINIONS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/OPINIONS.md";
}
