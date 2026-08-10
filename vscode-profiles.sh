#!/usr/bin/env bash
# VS Code profiles keep their own settings.json and keybindings.json, separate
# from the default profile's. This tracks them in home/vscode/profiles/<name>/.
#
#   ./vscode-profiles.sh save     copy live profile settings -> this repo
#   ./vscode-profiles.sh link     symlink the repo copies back over the live files
#   ./vscode-profiles.sh status   show what is linked, what drifted, change nothing
#
# Why this is not declared in home.nix like the default profile is: a profile's
# directory is not named after the profile. igote-dev-cpp lives in
# profiles/-3a41f61b, and that is not hash(name) either - VS Code's own
# hash("igote-dev-cpp").toString(16) is 7cad4157, so the location is random per
# creation and cannot be written into home.nix. A hardcoded mkOutOfStoreSymlink
# would work on this machine and silently point at nothing on a fresh one, so the
# location is resolved at run time out of VS Code's own storage.json instead.
# Same reasoning as obsidian-vault.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$DIR/home/vscode/profiles"
USERDIR="$HOME/Library/Application Support/Code/User"
STORAGE="$USERDIR/globalStorage/storage.json"

# The two files that hold real settings. extensions.json is deliberately left
# out: VS Code writes absolute paths, versions and install timestamps into it, so
# it is machine state rather than settings, and extensions.txt already records
# which extensions are wanted.
FILES=(settings.json keybindings.json)

# Read VS Code's profile registry. `registry names` prints every user-created
# profile; `registry locate <name>` prints one profile's directory and exits 1 if
# there is no such profile. Builtin profiles (the bundled Agents one) live under
# profiles/builtin and are not ours to manage.
registry() {
  python3 -c '
import json, sys
mode, path = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        storage = json.load(f)
except FileNotFoundError:
    sys.exit(1)
profiles = storage.get("userDataProfiles")
if isinstance(profiles, str):   # VS Code stores this value as embedded JSON
    profiles = json.loads(profiles)
profiles = [p for p in profiles or [] if not p["location"].startswith("builtin/")]
if mode == "names":
    for p in profiles:
        print(p["name"])
    sys.exit(0)
for p in profiles:
    if p["name"] == sys.argv[3]:
        print(p["location"])
        sys.exit(0)
sys.exit(1)
' "$1" "$STORAGE" "${2:-}"
}

# Every profile this repo tracks. Driven off the repo rather than off the machine,
# so a profile deleted in the GUI still shows up in `status` as missing.
tracked_profiles() {
  [ -d "$REPO" ] || return 0
  for path in "$REPO"/*/; do
    [ -d "$path" ] || continue
    basename "$path"
  done
}

case "${1:-}" in
  save)
    # Reads the machine, not the repo, so a newly created profile gets adopted.
    # Only useful before `link`, or after recreating a profile in the GUI: once a
    # live file is a symlink into the repo it already *is* the repo copy, and
    # copying it over itself would truncate it.
    names="$(registry names)" || { echo "error: cannot read $STORAGE" >&2; exit 1; }
    [ -n "$names" ] || { echo "No user-created VS Code profiles on this machine."; exit 0; }
    while read -r name; do
      location="$(registry locate "$name")"
      mkdir -p "$REPO/$name"
      for file in "${FILES[@]}"; do
        live="$USERDIR/profiles/$location/$file"
        [ -f "$live" ] || { echo "skip $name/$file (not present)"; continue; }
        if [ -L "$live" ]; then
          echo "skip $name/$file (already linked to the repo)"
          continue
        fi
        cp "$live" "$REPO/$name/$file"
        echo "==> saved $name/$file"
      done
    done <<< "$names"
    echo "Review with: git -C \"$DIR\" diff home/vscode/profiles"
    ;;
  link)
    while read -r name; do
      location="$(registry locate "$name")" ||
        { echo "skip $name (no such profile in VS Code - create it in the GUI first)"; continue; }
      target="$USERDIR/profiles/$location"
      mkdir -p "$target"
      for file in "${FILES[@]}"; do
        [ -f "$REPO/$name/$file" ] || { echo "skip $name/$file (not in repo)"; continue; }
        live="$target/$file"
        # A real file here may hold GUI edits that were never saved into the repo,
        # so keep a copy rather than clobbering it. An existing symlink is ours.
        if [ -f "$live" ] && [ ! -L "$live" ]; then
          backup="$live.backup-$(date +%Y%m%d-%H%M%S)"
          mv "$live" "$backup"
          echo "    kept the previous $file as $(basename "$backup")"
        fi
        # Point at ~/.dotfiles rather than this checkout's real path, so the
        # symlink survives the repo moving.
        ln -sfn "$HOME/.dotfiles/home/vscode/profiles/$name/$file" "$live"
        echo "==> $name/$file -> $(readlink "$live")"
      done
    done < <(tracked_profiles)
    echo
    # VS Code watches the default profile's settings.json and applies edits live.
    # Whether its watcher follows a profile file through a symlink was not tested
    # here, so say the safe thing rather than assert the convenient one.
    echo "If VS Code is running, switch profiles or restart it to be sure these apply."
    ;;
  status)
    while read -r name; do
      location="$(registry locate "$name")" ||
        { echo "$name: not created in VS Code"; continue; }
      echo "--- $name ($location) ---"
      for file in "${FILES[@]}"; do
        live="$USERDIR/profiles/$location/$file"
        repo="$REPO/$name/$file"
        if [ ! -e "$live" ]; then
          echo "  $file: missing on the machine"
        elif [ "$(readlink -f "$live")" = "$(readlink -f "$repo")" ]; then
          echo "  $file: linked"
        elif cmp -s "$live" "$repo"; then
          echo "  $file: identical but not linked (run 'link')"
        else
          echo "  $file: DRIFTED ('save' takes the live copy, 'link' takes the repo copy)"
        fi
      done
    done < <(tracked_profiles)
    ;;
  *)
    sed -n '2,7p' "$0"
    exit 1
    ;;
esac
