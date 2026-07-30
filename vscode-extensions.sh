#!/usr/bin/env bash
# VS Code extensions are not managed by Nix - the GUI has to stay able to
# install them. This script keeps home/vscode/extensions.txt in sync instead.
#
#   ./vscode-extensions.sh install   install everything listed in extensions.txt
#   ./vscode-extensions.sh save      rewrite extensions.txt from what's installed
#   ./vscode-extensions.sh diff      show what differs, change nothing
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LIST="$DIR/home/vscode/extensions.txt"

if ! command -v code >/dev/null 2>&1; then
  echo "error: the 'code' CLI is not on PATH." >&2
  echo "In VS Code: Cmd+Shift+P -> 'Shell Command: Install code command in PATH'" >&2
  exit 1
fi

case "${1:-}" in
  install)
    # --force skips the prompt when an extension is already present.
    while read -r ext; do
      [ -z "$ext" ] && continue
      case "$ext" in \#*) continue ;; esac
      echo "==> $ext"
      code --install-extension "$ext" --force
    done < "$LIST"
    echo "Done. Installed $(grep -cve '^\s*$' -e '^#' "$LIST") extensions."
    ;;
  save)
    code --list-extensions > "$LIST"
    echo "Wrote $(wc -l < "$LIST" | tr -d ' ') extensions to $LIST"
    echo "Review with: git -C \"$DIR\" diff home/vscode/extensions.txt"
    ;;
  diff)
    echo "--- only in extensions.txt (not installed) ---"
    comm -23 <(sort "$LIST") <(code --list-extensions | sort) || true
    echo "--- only installed (not in extensions.txt) ---"
    comm -13 <(sort "$LIST") <(code --list-extensions | sort) || true
    ;;
  *)
    sed -n '2,8p' "$0"
    exit 1
    ;;
esac
