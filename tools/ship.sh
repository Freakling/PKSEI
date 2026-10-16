#!/usr/bin/env bash
# Export the web build and push it to itch.io with butler.
#   bash tools/ship.sh                 export + push to the html5 channel
#   bash tools/ship.sh --export-only   export only (no butler needed)
#   bash tools/ship.sh <channel>       push to another channel, e.g. html5-test
#
# Needs: Godot export templates for the version in tools/godot_bin.local
# (Editor > Manage Export Templates), butler on PATH or $BUTLER, and `butler login` done once.
set -euo pipefail
cd "$(dirname "$0")/.."

ITCH_TARGET="${ITCH_TARGET:-freakling/pksei}"
CHANNEL="html5"
EXPORT_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --export-only) EXPORT_ONLY=1 ;;
    *) CHANNEL="$arg" ;;
  esac
done

[ -f tools/godot_bin.local ] || { echo "ship: run bash tools/setup-clone.sh first"; exit 3; }
GODOT_BIN="$(LC_ALL=C tr -d '\r' < tools/godot_bin.local | head -1)"

rm -rf build/web
mkdir -p build/web
echo "ship: exporting Web preset with $GODOT_BIN"
"$GODOT_BIN" --headless --export-release "Web" "build/web/index.html"
[ -f build/web/index.html ] || { echo "ship: export failed: build/web/index.html missing (are the export templates installed?)"; exit 1; }
echo "ship: export done: $(du -sh build/web | cut -f1) in build/web"

[ "$EXPORT_ONLY" = 1 ] && exit 0

BUTLER="${BUTLER:-}"
if [ -z "$BUTLER" ]; then
  for candidate in butler ./butler.exe /c/tools/butler/butler.exe; do
    if command -v "$candidate" >/dev/null 2>&1; then BUTLER="$candidate"; break; fi
  done
fi
[ -n "$BUTLER" ] || { echo "ship: butler not found; install it (or set BUTLER=<path>) and run: butler login"; exit 3; }
VERSION="$(git describe --always --dirty 2>/dev/null || echo dev)"
"$BUTLER" push build/web "$ITCH_TARGET:$CHANNEL" --userversion "$VERSION"
echo "ship: pushed $ITCH_TARGET:$CHANNEL ($VERSION)"
