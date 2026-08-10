# The hand-written half of the shell.
#
# ~/.zshrc itself is NOT a file in this repo and cannot be: home-manager
# generates it into /nix/store from the `programs.zsh` block in home.nix, and
# owns it completely. This file is the escape hatch. home.nix sources it from
# the tail of the generated ~/.zshrc, and symlinks it here out of the repo, so
# it is edit-in-place like nvim and wezterm - save it, open a new shell, done.
# No rebuild.
#
# The split, so the next change lands in the right place:
#
#   home.nix   anything home-manager has an option for - aliases, history,
#              plugin enables, prompt, PATH, session variables. Declaring those
#              here instead would work, but it hides them from `nix eval` and
#              from anyone reading the config, and it needs a rebuild anyway.
#
#   this file  plain zsh that no option covers - key bindings, functions,
#              completion styles, anything you want to iterate on quickly.
#
# Sourced at home-manager's default init order, which puts it before the
# generated aliases and before zsh-syntax-highlighting. Do not define aliases
# here expecting them to win; home.nix would overwrite them a few lines later.

# Accept the whole autosuggestion. Ctrl+F rather than the default End/Right,
# because both of those are a stretch from the home row mid-command.
bindkey '^f' autosuggest-accept

# Option+Left / Option+Right word motion, iTerm2 ONLY.
#
# These two escape sequences are iTerm2's "Esc+" encoding of Option+arrow.
# WezTerm never sends them: home/.config/wezterm/wezterm.lua remaps the keys to
# Alt+b / Alt+f itself, which land on zsh's own emacs bindings (^[b / ^[f), so
# under WezTerm word motion already works with nothing bound here.
#
# Verified with `bindkey | grep -E '\^\[b|\^\[f|\^\[\^\[O'`, which lists all
# four. Retire these two lines when the iterm2 cask goes.
bindkey "\e\eOD" backward-word
bindkey "\e\eOC" forward-word
