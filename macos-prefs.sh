#!/usr/bin/env bash
# Version the settings of Mac apps that keep them in a preferences plist.
#
#   ./macos-prefs.sh export    read live prefs -> home/macos-prefs/*.plist
#   ./macos-prefs.sh import    write repo prefs -> live, then restart the app
#   ./macos-prefs.sh diff      show what differs, change nothing
#
# Plists are stored as XML so git diffs are readable, and are filtered down to
# real settings - telemetry IDs, updater state and window positions are dropped.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="$DIR/home/macos-prefs"

# domain:App Name  (App Name is quit before import so it can't overwrite it;
# leave it empty for domains that aren't owned by a running app)
DOMAINS=(
  "com.lwouis.alt-tab-macos:AltTab"
  # System keyboard shortcuts. Captured as a whole domain on purpose: 18 of the
  # 22 hotkeys here are disabled (Spotlight's Cmd+Space so Alfred can own it,
  # plus Mission Control and Spaces navigation), and writing a partial
  # AppleSymbolicHotKeys dict would replace the whole thing.
  # Takes effect on next login, not immediately.
  "com.apple.symbolichotkeys:"
)

# Keys matching these prefixes are machine-specific or telemetry, never settings.
NOISE_RE='^(MSAppCenter|SU[A-Z]|NSWindow Frame|NSNavLastRootDirectory|NSStatusItem)'

filter_plist() {
  # stdin: XML plist -> stdout: XML plist with noise keys removed
  python3 -c '
import plistlib, re, sys
noise = re.compile(sys.argv[1])
data = plistlib.loads(sys.stdin.buffer.read())
clean = {k: v for k, v in data.items() if not noise.match(k)}
sys.stdout.buffer.write(plistlib.dumps(clean, sort_keys=True))
' "$NOISE_RE"
}

read_live() {
  # `defaults export` emits a binary plist, so convert it to XML.
  defaults export "$1" - 2>/dev/null | plutil -convert xml1 -o - - | filter_plist
}

case "${1:-}" in
  export)
    mkdir -p "$OUT"
    for entry in "${DOMAINS[@]}"; do
      domain="${entry%%:*}"
      read_live "$domain" > "$OUT/$domain.plist"
      echo "==> $domain ($(grep -c '<key>' "$OUT/$domain.plist") settings)"
    done
    echo "Review with: git -C \"$DIR\" diff home/macos-prefs"
    ;;
  import)
    for entry in "${DOMAINS[@]}"; do
      domain="${entry%%:*}"
      app="${entry##*:}"
      file="$OUT/$domain.plist"
      [ -f "$file" ] || { echo "skip $domain (no file in repo)"; continue; }
      # macOS caches prefs in cfprefsd, so an app that owns the domain has to be
      # down first or it will write its in-memory copy back over the import.
      if [ -n "$app" ]; then
        osascript -e "quit app \"$app\"" 2>/dev/null || true
        sleep 1
      fi
      defaults import "$domain" "$file"
      killall cfprefsd 2>/dev/null || true
      if [ -n "$app" ]; then
        echo "==> imported $domain (restart $app to see it)"
      else
        echo "==> imported $domain (log out and back in to take effect)"
      fi
    done
    ;;
  diff)
    for entry in "${DOMAINS[@]}"; do
      domain="${entry%%:*}"
      file="$OUT/$domain.plist"
      [ -f "$file" ] || { echo "skip $domain (no file in repo)"; continue; }
      echo "--- $domain ---"
      diff <(cat "$file") <(read_live "$domain") && echo "(identical)"
    done
    ;;
  *)
    sed -n '2,8p' "$0"
    exit 1
    ;;
esac
