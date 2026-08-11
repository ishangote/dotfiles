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

# Xnip is sandboxed and keeps its settings in an app-group container, which
# `defaults` cannot reach by bundle id - `defaults read ME7L72N3S3.group...`
# reports the domain does not exist. Naming it by path does work. The app has
# migrated to the group (kXnipDidUserDefaultsMigrateToAppGroups), so this file
# is the authoritative one; the copy under Containers/com.zzd.Xnip is a
# pre-migration leftover.
XNIP_GROUP="$HOME/Library/Group Containers/ME7L72N3S3.group.com.zzd.Xnip/Library/Preferences/ME7L72N3S3.group.com.zzd.Xnip"

# domain:App Name[:file label]  (App Name is quit before import so it can't
# overwrite it; leave it empty for domains that aren't owned by a running app.
# The label names the file in macos-prefs/ and defaults to the domain - it only
# has to be given for path domains, which would otherwise nest the output.)
DOMAINS=(
  "com.lwouis.alt-tab-macos:AltTab"
  # System keyboard shortcuts. Captured as a whole domain on purpose: 19 of the
  # 23 hotkeys here are disabled (Spotlight's Cmd+Space so Alfred can own it,
  # plus Mission Control and Spaces navigation), and writing a partial
  # AppleSymbolicHotKeys dict would replace the whole thing.
  # Takes effect on next login, not immediately.
  "com.apple.symbolichotkeys:"
  # Xnip's capture shortcut. Cmd+Shift+4 is disabled as hotkey 30 in the
  # symbolichotkeys domain above so that Xnip can own the chord; without this
  # entry the disable ships on its own and Cmd+Shift+4 is simply dead on a
  # fresh Mac until someone binds it by hand in Xnip's preferences.
  # Only three of the ten keys here are settings - the rest is capture counts
  # and window state, dropped by NOISE_RE.
  "$XNIP_GROUP:Xnip:com.zzd.Xnip"
)

# Keys matching these prefixes are machine-specific or telemetry, never settings.
NOISE_RE='^(MSAppCenter|SU[A-Z]|NSWindow Frame|NSNavLastRootDirectory|NSStatusItem|kXnip(CaptureCount|DidUserDefaults|IsFirstRun|LastCapture|Version))'

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

parse_entry() {
  # entry -> $domain, $app, $label
  IFS=':' read -r domain app label <<< "$1"
  label="${label:-$domain}"
}

write_path_domain() {
  # $1 plist path without the extension, $2 repo file.
  #
  # `defaults` reads a path domain but will not write one: `defaults write`
  # exits 1 with "Could not write domain" and `defaults import` silently
  # no-ops, returning 0 having done nothing. So the file is written directly.
  #
  # Keys are merged, not replaced, which is the opposite of how the
  # symbolichotkeys domain is handled and deliberate. Xnip keeps runtime state
  # in this same file, and blowing away kXnipDidUserDefaultsMigrateToAppGroups
  # would invite the app to re-run its app-group migration and overwrite the
  # shortcut with the stale copy in Containers/com.zzd.Xnip. Absences carry no
  # meaning here; only the three exported keys do.
  python3 -c '
import os, plistlib, sys
target, src = sys.argv[1], sys.argv[2]
merged = {}
if os.path.exists(target):
    with open(target, "rb") as f:
        merged = plistlib.load(f)
with open(src, "rb") as f:
    merged.update(plistlib.load(f))
with open(target, "wb") as f:
    plistlib.dump(merged, f, fmt=plistlib.FMT_BINARY)
' "$1.plist" "$2"
}

case "${1:-}" in
  export)
    mkdir -p "$OUT"
    for entry in "${DOMAINS[@]}"; do
      parse_entry "$entry"
      read_live "$domain" > "$OUT/$label.plist"
      echo "==> $label ($(grep -c '<key>' "$OUT/$label.plist") settings)"
    done
    echo "Review with: git -C \"$DIR\" diff home/macos-prefs"
    ;;
  import)
    for entry in "${DOMAINS[@]}"; do
      parse_entry "$entry"
      file="$OUT/$label.plist"
      [ -f "$file" ] || { echo "skip $label (no file in repo)"; continue; }
      # A sandboxed app's container is created by the system on first launch,
      # and `defaults import` will not create it. On a fresh Mac this is the
      # normal state, so say what to do rather than failing under `set -e`.
      case "$domain" in
        /*) [ -d "$(dirname "$domain")" ] ||
              { echo "skip $label (container missing - launch $app once, then re-run)"; continue; } ;;
      esac
      # macOS caches prefs in cfprefsd, so an app that owns the domain has to be
      # down first or it will write its in-memory copy back over the import.
      if [ -n "$app" ]; then
        osascript -e "quit app \"$app\"" 2>/dev/null || true
        sleep 1
      fi
      case "$domain" in
        /*) write_path_domain "$domain" "$file" ;;
        *)  defaults import "$domain" "$file" ;;
      esac
      killall cfprefsd 2>/dev/null || true
      if [ -n "$app" ]; then
        echo "==> imported $label (restart $app to see it)"
      else
        echo "==> imported $label (log out and back in to take effect)"
      fi
    done
    ;;
  diff)
    for entry in "${DOMAINS[@]}"; do
      parse_entry "$entry"
      file="$OUT/$label.plist"
      [ -f "$file" ] || { echo "skip $label (no file in repo)"; continue; }
      echo "--- $label ---"
      diff <(cat "$file") <(read_live "$domain") && echo "(identical)"
    done
    ;;
  *)
    sed -n '2,8p' "$0"
    exit 1
    ;;
esac
