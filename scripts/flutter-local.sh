#!/usr/bin/env sh
# Keep Flutter and Dart caches outside the project's persistent snapshot.
set -eu
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [ -z "$FLUTTER_BIN" ]; then
  echo 'Flutter introuvable. Ajoutez flutter au PATH ou définissez FLUTTER_BIN.' >&2
  exit 1
fi
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/epinal-reader"
mkdir -p "$CACHE_ROOT/home" "$CACHE_ROOT/pub"
export PUB_CACHE="$CACHE_ROOT/pub"
export HOME="$CACHE_ROOT/home"
exec "$FLUTTER_BIN" "$@"
