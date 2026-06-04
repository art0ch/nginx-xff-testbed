#!/usr/bin/env/ python3

import json
import signal
import sys
from encodings.utf_7 import encode
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, Any


class RequestHandler(BaseHTTPRequestHandler):

    def log_message(self, fmt: str, *args: Any) -> None:
        pass

    def do_GET(self) -> None:

        xff = self.headers.get("X-Forwarded-For")  # type: ignore[arg-type]
        host = self.headers.get("Host")            # type: ignore[arg-type]

        response: Dict[str, Any] = {
            "remote_addr": self.client_address[0],
            "x_forwarded_for": xff or "Not provided",
            "host": host or "Unknown",
            "path": self.path,
            "method": self.command,
        }

        response_body = json.dumps(response, indent=2).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response_body)))
        self.end_headers()
        self.wfile.write(response_body)


class GracefulServer(HTTPServer):

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)

        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        print(f"\n Received signal {signum}, shutting down...", flush=True)
        self.shutdown()


def run_server(port: int = 8000) -> None:
    server_address = ("", port)

    httpd = GracefulServer(server_address, RequestHandler)

    print(f"Server started on port {port}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
        print("Server stopped", flush=True)


if __name__ == "__main__":
    target_port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    run_server(target_port)