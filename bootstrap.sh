#!/usr/bin/env bash
# Takes a Mac from nothing to a built nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: personalize the configured username"
# Do this before any sudo call: sudo resets $USER to root, so whoami has to
# run as the real interactive user first.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: move conflicting hand-written config out of the way"
# home-manager refuses to overwrite files it does not manage - it aborts the
# switch with "Existing file is in the way". Anything below that is a real file
# (not already a symlink into the nix store or this repo) gets moved to a
# timestamped backup dir. On a genuinely fresh Mac this is a no-op.
#
# ~/.gitconfig matters even though home-manager writes ~/.config/git/config:
# git prefers ~/.gitconfig when it exists, so leaving it behind would silently
# shadow everything declared in home.nix.
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
MOVED=0
for f in \
  "$HOME/.zshrc" \
  "$HOME/.zprofile" \
  "$HOME/.zshenv" \
  "$HOME/.gitconfig" \
  "$HOME/.config/git/ignore" \
  "$HOME/.claude/settings.json" \
  "$HOME/.claude/statusline-command.sh" \
  "$HOME/.claude/CLAUDE.md" \
  "$HOME/.codex/AGENTS.md" \
  "$HOME/.config/nvim" \
  "$HOME/.config/wezterm" \
  "$HOME/Library/Application Support/Code/User/settings.json" \
  "$HOME/Library/Application Support/Code/User/keybindings.json" \
; do
  # -e is false for a broken symlink, so test -L as well.
  if [ -e "$f" ] || [ -L "$f" ]; then
    if [ -L "$f" ]; then
      echo "    $f is already a symlink, leaving it"
      continue
    fi
    mkdir -p "$BACKUP/$(dirname "${f#"$HOME"/}")"
    mv "$f" "$BACKUP/${f#"$HOME"/}"
    echo "    moved $f"
    MOVED=1
  fi
done
if [ "$MOVED" -eq 1 ]; then
  echo "    Backup: $BACKUP"
  echo "    Nothing was deleted. ~/.oh-my-zsh is also left untouched on disk."
else
  echo "    nothing to move"
fi

echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
# darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
# from the flake this once. After this, rebuild.sh works normally.
# This fetches the darwin-rebuild tool from the nix-darwin-26.05 release branch,
# not the exact flake.lock revision. The system config it applies is still pinned
# by this repo's flake.lock.
# sudo resets PATH to a secure default that excludes /nix/.../bin, so a
# freshly installed `nix` would not be found under sudo even though it's
# on PATH here. Resolve the absolute path first and invoke that instead.
NIX_BIN="$(command -v nix)"
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
# If this fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.

echo "==> Done. Open a new terminal, then use ./rebuild.sh for future changes."
