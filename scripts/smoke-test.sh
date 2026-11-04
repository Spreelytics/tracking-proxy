#!/bin/sh
# Starts the image and checks the health page, the loader and a tracking request all answer 200.
# Usage: scripts/smoke-test.sh [image]   (default: spreelytics/tracking-proxy:test)
set -eu

IMAGE="${1:-spreelytics/tracking-proxy:test}"
PORT="${SMOKE_PORT:-18080}"
NAME="tracking-proxy-smoke-$$"

docker run -d --rm --name "$NAME" -p "$PORT:8080" "$IMAGE" >/dev/null
fail=0
cleanup() {
  [ "$fail" = 0 ] || docker logs "$NAME" 2>&1 | tail -n 20
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for nginx to start.
i=0
until curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; do
  i=$((i + 1))
  [ "$i" -ge 30 ] && { echo "proxy did not start"; fail=1; exit 1; }
  sleep 1
done

check() {
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT$1")
  if [ "$code" = "$2" ]; then echo "ok   $code $1"; else echo "FAIL $code $1 (want $2)"; fail=1; fi
}

check / 200
check /cdn/sdk/spreelytics-loader.js 200
check '/1.0/track/config?clientKey=x' 200
check /anything-else 404

# The proxy must never set cookies on your domain.
if curl -sI "http://localhost:$PORT/cdn/sdk/spreelytics-loader.js" | grep -qi '^set-cookie:'; then
  echo "FAIL Set-Cookie leaked through"; fail=1
else
  echo "ok   no Set-Cookie"
fi

exit "$fail"
