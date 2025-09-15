#!/bin/bash
set -euo pipefail

PORT="${PORT:-8000}"

wait_mount () {
  local p="$1"
  local limit=60
  local i=0
  while [ $i -lt $limit ]; do
    if [ -d "$p" ] && ls "$p" >/dev/null 2>&1; then
      echo "[ok] mount ready: $p"
      return 0
    fi
    echo "[wait] mount not ready: $p"
    sleep 1; i=$((i+1))
  done
  echo "[warn] mount check timed out for $p (continuing anyway)"
}
wait_mount "/models" || true
wait_mount "/output" || true

python - <<'PY' &
from http.server import BaseHTTPRequestHandler,HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path=="/healthz":
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
        else:
            self.send_response(404); self.end_headers()
HTTPServer(("0.0.0.0", 8081), H).serve_forever()
PY

_term() { echo "SIGTERM received, exiting..."; kill -TERM "$child" 2>/dev/null || true; }
trap _term TERM INT

cd /app/ComfyUI
python3 main.py \
  --listen 0.0.0.0 \
  --port "${PORT}" \
  --enable-cors-header \
  --output-directory "/output" \
  --dont-print-server &
child=$!
wait "$child"


