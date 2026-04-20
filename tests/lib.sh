#!/bin/bash
# Shared test utilities. Sourced by run_all.sh and individual tests.

# Track background PIDs for cleanup
_TEST_PIDS=()

_cleanup_pids() {
  for pid in "${_TEST_PIDS[@]}"; do
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  _TEST_PIDS=()
}

# Start an HTTP listener that captures POST bodies to a file.
# Usage: start_listener PORT LOGFILE
# Sets LISTENER_PID to the background process PID.
start_listener() {
  local port="$1"
  local logfile="$2"

  rm -f "$logfile"
  python3 -c "
import http.server, socketserver

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode()
        with open('$logfile', 'w') as f:
            f.write(body)
        self.send_response(200)
        self.end_headers()
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
    def log_message(self, *args):
        pass

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', $port), Handler) as s:
    s.timeout = 5
    s.handle_request()
" &
  LISTENER_PID=$!
  _TEST_PIDS+=("$LISTENER_PID")
  sleep 0.3
}

# Kill a listener by PID and wait for it to exit.
stop_listener() {
  local pid="$1"
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  _TEST_PIDS=("${_TEST_PIDS[@]/$pid/}")
}
