#!/usr/bin/env bash
# iTerm2's preferences file is version controlled, and iTerm2 rewrites it in
# full every time it quits. Two of the keys it writes are machine fingerprints
# that have no business in a public repo, so they come back on their own and a
# one-time scrub does not hold.
#
#   ./scrub-iterm2-plist.sh          strip them, in place
#   ./scrub-iterm2-plist.sh --check  exit 1 if either key is present
#
# Run it before committing any change to the plist. --check is the form to wire
# into a pre-commit hook.
#
# Why this edits the XML by hand instead of using PlistBuddy: PlistBuddy parses
# and re-serializes the whole file, and its float writer disagrees with iTerm2's
# (it writes 0.086274512112140656 where iTerm2 writes 0.08627451211214066 - the
# same double, rendered differently). That is a 640-line diff on every run, and
# it would flip back and forth forever as iTerm2 and PlistBuddy took turns
# writing the file. The plist is stored as XML precisely so its diffs stay
# readable, so a surgical delete is the only version that keeps the promise.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLIST="$DIR/home/iterm2/com.googlecode.iterm2.plist"

if [ ! -f "$PLIST" ]; then
  echo "error: no plist at $PLIST" >&2
  exit 1
fi

MODE="${1:-scrub}"
case "$MODE" in
  scrub | --check) ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac

PLIST="$PLIST" MODE="$MODE" python3 - <<'PY'
import os
import re
import sys

path = os.environ["PLIST"]
check = os.environ["MODE"] == "--check"

# NSOSPLastRootDirectory is a macOS bookmark blob: it embeds the boot volume's
# UUID, so it is a stable hardware identifier, not a preference.
# NoSyncInstallationId is a per-install UUID that ties the checkout to a Mac.
# Neither affects how iTerm2 behaves, so dropping them costs nothing.
#
# Left alone deliberately: "Working Directory" (the username is in every nix
# path in this repo already) and the "NSWindow Frame *" keys (window geometry -
# noise, but iTerm2 rewrites them constantly and they identify nothing).
KEYS = {"NSOSPLastRootDirectory", "NoSyncInstallationId"}

# Both keys sit at the top level of the root <dict>, which the file indents with
# exactly one tab. Anchoring on that keeps the match from reaching a same-named
# key nested inside a profile.
KEY_RE = re.compile(r"^\t<key>([^<]+)</key>$")
OPEN_RE = re.compile(r"^\t<(\w+)")

with open(path, encoding="utf-8") as fh:
    lines = fh.read().split("\n")

out, found, i = [], [], 0
while i < len(lines):
    match = KEY_RE.match(lines[i])
    if not match or match.group(1) not in KEYS:
        out.append(lines[i])
        i += 1
        continue

    found.append(match.group(1))
    i += 1  # drop the <key> line
    if i >= len(lines):
        sys.exit(f"error: {path}: <key>{found[-1]}</key> has no value")

    value = lines[i]
    tag_match = OPEN_RE.match(value)
    if not tag_match:
        sys.exit(f"error: {path}: unparsable value after <key>{found[-1]}</key>")
    tag = tag_match.group(1)
    i += 1

    # A value is either self-contained on one line (<string>x</string>, <true/>)
    # or spans lines and closes on its own (a <data> blob).
    if not (value.endswith(f"</{tag}>") or value.endswith("/>")):
        close = f"\t</{tag}>"
        while i < len(lines) and lines[i] != close:
            i += 1
        if i >= len(lines):
            sys.exit(f"error: {path}: unterminated <{tag}> for {found[-1]}")
        i += 1  # drop the closing tag

if check:
    if not found:
        print("clean: no machine fingerprints in the plist")
        sys.exit(0)
    print(f"error: plist still contains: {' '.join(found)}", file=sys.stderr)
    print("Run ./scrub-iterm2-plist.sh before committing.", file=sys.stderr)
    sys.exit(1)

if not found:
    print("==> already clean, nothing to do")
    sys.exit(0)

with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))

for key in found:
    print(f"==> removed {key}")
PY

# Cheap insurance that the surgical edit left valid XML behind.
plutil -lint "$PLIST"
