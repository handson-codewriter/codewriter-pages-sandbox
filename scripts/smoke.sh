#!/usr/bin/env bash
set -uo pipefail

SITE_SRC="index.html"
BUILD_DIR="_site"
PLACEHOLDER="__BUILD_SHA__"

if [ ! -f "$SITE_SRC" ]; then
    echo "smoke: $SITE_SRC bestaat niet" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
sha="$(git rev-parse HEAD 2>/dev/null || echo local-smoke-sha)"
sed "s/$PLACEHOLDER/$sha/g" "$SITE_SRC" > "$BUILD_DIR/index.html"

port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"

python3 -m http.server "$port" --directory "$BUILD_DIR" --bind 127.0.0.1 \
    >"$BUILD_DIR/.smoke-server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

ok=""
for _ in $(seq 1 50); do
    if curl -s -o /dev/null "http://127.0.0.1:$port/index.html"; then
        ok=1
        break
    fi
    sleep 0.1
done
if [ -z "$ok" ]; then
    echo "smoke: de lokale server kwam niet op binnen 5s" >&2
    exit 1
fi

body="$(curl -s "http://127.0.0.1:$port/index.html")"

marker="$(printf '%s' "$body" | grep -oE 'name="build-sha" content="[^"]*"' | head -n1)"
if [ -z "$marker" ]; then
    echo "smoke: geen build-sha marker gevonden in de geserveerde index.html" >&2
    exit 1
fi

marker_value="$(printf '%s' "$marker" | sed -E 's/^.*content="([^"]*)".*$/\1/')"
if [ "$marker_value" != "$sha" ]; then
    echo "smoke: build-sha marker is '$marker_value', verwacht '$sha' (A1.4b: de marker moet gelijk zijn aan de sha die smoke.sh zelf berekende, niet slechts 'aanwezig en niet de placeholder')" >&2
    exit 1
fi

echo "smoke: static-site geserveerd met marker content=\"$marker_value\" (== $sha)"
