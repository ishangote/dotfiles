#!/usr/bin/env bash
# Install the Mac App Store apps listed in home/mas/apps.tsv.
#
#   ./mas-apps.sh install   install anything missing
#   ./mas-apps.sh status    show declared vs installed
#   ./mas-apps.sh save      rewrite apps.tsv from what's installed
#
# Why this isn't homebrew.masApps in configuration.nix:
# nix-darwin runs the Homebrew bundle as `sudo --user=<user> --set-home env brew
# bundle`. `sudo -u` lands in a different bootstrap namespace than the user's GUI
# session. `mas list` still works there (receipts are just files), but `mas
# install` and `mas upgrade` need the App Store daemon, which isn't reachable -
# so every entry fails and takes the whole activation down with it, including the
# home-manager user activation that runs afterwards.
#
# Run this from a normal terminal, signed into the App Store, and it works.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LIST="$DIR/home/mas/apps.tsv"

if ! command -v mas >/dev/null 2>&1; then
  echo "error: mas is not installed." >&2
  echo "It's declared in configuration.nix - run ./rebuild.sh first." >&2
  exit 1
fi

# "  441258766  Magnet  (3.0.7)" -> "441258766"
installed_ids() { mas list 2>/dev/null | awk '{print $1}'; }

case "${1:-}" in
  install)
    have="$(installed_ids)"
    missing=0
    while IFS=$'\t' read -r id name; do
      [ -z "${id:-}" ] && continue
      case "$id" in \#*) continue ;; esac
      if grep -qx "$id" <<<"$have"; then
        echo "==> $name already installed"
      else
        echo "==> installing $name ($id)"
        # Not fatal: a failure here is usually "not purchased by this Apple ID",
        # which is worth reporting at the end rather than aborting halfway.
        if ! mas install "$id"; then
          echo "!!  FAILED: $name ($id)"
          missing=$((missing + 1))
        fi
      fi
    done < "$LIST"
    if [ "$missing" -gt 0 ]; then
      echo
      echo "$missing app(s) failed. Usual causes:"
      echo "  - not signed into the App Store"
      echo "  - signed in with an Apple ID that never purchased them"
      exit 1
    fi
    echo "All App Store apps present."
    ;;
  status)
    have="$(installed_ids)"
    printf "%-12s %-26s %s\n" ID NAME STATUS
    while IFS=$'\t' read -r id name; do
      [ -z "${id:-}" ] && continue
      case "$id" in \#*) continue ;; esac
      if grep -qx "$id" <<<"$have"; then s="installed"; else s="MISSING"; fi
      printf "%-12s %-26s %s\n" "$id" "$name" "$s"
    done < "$LIST"
    echo
    echo "Installed but NOT declared (zap never touches these - remove by hand):"
    while read -r id; do
      [ -z "$id" ] && continue
      grep -q "^$id"$'\t' "$LIST" || printf "  %-12s %s\n" "$id" \
        "$(mas list 2>/dev/null | awk -v i="$id" '$1==i {$1=""; sub(/^ +/,""); print}')"
    done <<<"$have"
    ;;
  save)
    mkdir -p "$(dirname "$LIST")"
    {
      echo "# Mac App Store apps. id<TAB>name  -  installed by ./mas-apps.sh"
      mas list 2>/dev/null | sed -E 's/^ *([0-9]+) +(.*[^ ]) +\([^)]*\) *$/\1\t\2/'
    } > "$LIST"
    echo "==> wrote $LIST"
    echo "Review it - 'save' captures everything installed, including apps you"
    echo "may be about to delete."
    ;;
  *)
    sed -n '2,6p' "$0"
    exit 1
    ;;
esac
