#!/usr/bin/env bash
# Point a vault at the shared Obsidian config in this repo.
#
#   ./obsidian-vault.sh ~/path/to/vault
#
# Obsidian has no global settings layer - every setting lives in
# <vault>/.obsidian. This symlinks that directory at the one shared copy in
# home/obsidian/config, so every vault gets the same theme, plugins and hotkeys.
#
# Vaults you intend to keep should also be declared in home.nix, so a fresh Mac
# wires them up automatically. This script is for doing it right now.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SHARED="$DIR/home/obsidian/config"

if [ $# -ne 1 ]; then
  sed -n '2,12p' "$0"
  exit 1
fi

VAULT="${1%/}"
if [ ! -d "$VAULT" ]; then
  echo "error: no such directory: $VAULT" >&2
  exit 1
fi

TARGET="$VAULT/.obsidian"

if [ -L "$TARGET" ]; then
  echo "==> $TARGET is already a symlink -> $(readlink "$TARGET")"
elif [ -d "$TARGET" ]; then
  BACKUP="$TARGET.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$TARGET" "$BACKUP"
  echo "==> moved existing config to $BACKUP"
fi

# Always point at ~/.dotfiles rather than this checkout's real path, so the
# symlink keeps working if the repo moves.
ln -sfn "$HOME/.dotfiles/home/obsidian/config" "$TARGET"
echo "==> $TARGET -> $(readlink "$TARGET")"

# workspace.json is per-session pane layout. Sharing it across vaults means each
# one opens with the last vault's layout, so keep it out of git (already
# gitignored) and let Obsidian regenerate it.
echo
echo "If the vault is a git repo, keep it from tracking the symlink:"
echo "    echo '.obsidian' >> $VAULT/.gitignore"
