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
    if python3 -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:$port/index.html', timeout=1).status == 200 else 1)" 2>/dev/null; then
        ok=1
        break
    fi
    sleep 0.1
done
if [ -z "$ok" ]; then
    echo "smoke: de lokale server kwam niet op binnen 5s" >&2
    exit 1
fi

body="$(python3 -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:$port/index.html').read().decode('utf-8'))")"

meta_marker="$(printf '%s' "$body" | grep -oE 'name="build-sha" content="[^"]*"' | head -n1)"
if [ -z "$meta_marker" ]; then
    echo "smoke: geen build-sha meta marker gevonden in de geserveerde index.html" >&2
    exit 1
fi
meta_value="$(printf '%s' "$meta_marker" | sed -E 's/^.*content="([^"]*)".*$/\1/')"

footer_marker="$(printf '%s' "$body" | grep -oE 'build [^<]*' | head -n1)"
if [ -z "$footer_marker" ]; then
    echo "smoke: geen build-sha footer marker gevonden in de geserveerde index.html" >&2
    exit 1
fi
footer_value="$(printf '%s' "$footer_marker" | sed -E 's/^build //')"

if [ "$meta_value" != "$sha" ]; then
    echo "smoke: build-sha meta marker is '$meta_value', verwacht '$sha'" >&2
    exit 1
fi

if [ "$footer_value" != "$sha" ]; then
    echo "smoke: build-sha footer marker is '$footer_value', verwacht '$sha'" >&2
    exit 1
fi

if [ "$meta_value" != "$footer_value" ]; then
    echo "smoke: meta marker '$meta_value' en footer marker '$footer_value' komen niet overeen" >&2
    exit 1
fi

echo "smoke: static-site geserveerd met meta content=\"$meta_value\" en footer \"build $footer_value\" (== $sha)"
