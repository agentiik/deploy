"""What the API asks of a proxy, answered by a stand-in on 127.0.0.1:8443, and checked through it.

    python3 backend.py serve          the stand-in, in plain HTTP on the loopback, as the API listens
    python3 backend.py check URL      the three checks, through the proxy at URL

The stand-in answers each route the way the API does where it matters to a proxy: a path echoed
exactly as it arrived, a log stream of server-sent events whose second event comes seconds after
the first, and an upload whose bytes are counted. Standard library only.
"""

import http.client
import http.server
import ssl
import sys
import time
import urllib.parse

ARTIFACT = "/api/v1/artifacts/agk%3A%2F%2Frun%2F01ABC%2Fgreet%2Fout%2Fgreeting.txt"
STREAM = "/api/v1/runs/01ABC/steps/greet/logs"
UPLOAD = "/objects/demo"
UPLOAD_BYTES = 64 << 20  # above nginx's default of 1 MiB, and Caddy's and Traefik's none


class Backend(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if self.path == STREAM:
            # As the API's log stream: headers first, then each event as it happens.
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("X-Accel-Buffering", "no")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b"event: line\ndata: first\n\n")
            self.wfile.flush()
            time.sleep(5)
            self.wfile.write(b"event: end\ndata: {}\n\n")
            self.wfile.flush()
            self.close_connection = True
            return
        self.answer(self.path.encode())  # the path as it arrived, never decoded

    def do_POST(self):
        size = 0
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            while True:
                n = int(self.rfile.readline().split(b";")[0], 16)
                if n == 0:
                    self.rfile.readline()
                    break
                while n:
                    got = len(self.rfile.read(min(n, 1 << 20)))
                    size, n = size + got, n - got
                self.rfile.readline()
        else:
            left = int(self.headers.get("Content-Length", 0))
            while left:
                got = len(self.rfile.read(min(left, 1 << 20)))
                size, left = size + got, left - got
        self.answer(str(size).encode())

    def answer(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def connect(url):
    u = urllib.parse.urlsplit(url)
    # The proxy's certificate is not what is checked here: the README job checks one end to end.
    return http.client.HTTPSConnection(u.hostname, u.port or 443, context=ssl._create_unverified_context(), timeout=60)


def check(url):
    c = connect(url)
    c.request("GET", ARTIFACT)
    got = c.getresponse().read().decode()
    assert got == ARTIFACT, f"the path reached the API as {got}, not {ARTIFACT}: %2F was decoded"
    print(f"{url}: %2F passed undecoded")

    c = connect(url)
    started = time.monotonic()
    c.request("GET", STREAM, headers={"Accept": "text/event-stream"})
    r = c.getresponse()
    assert r.status == 200, f"the log stream was answered {r.status}"
    while not r.readline().startswith(b"data: first"):
        pass
    first = time.monotonic() - started
    assert first < 3, f"the first event arrived after {first:.1f}s, with the second: the stream was buffered"
    r.read()
    print(f"{url}: the log stream's first event arrived after {first:.1f}s, before the stream ended")

    c = connect(url)
    c.request("POST", UPLOAD, body=b"\0" * UPLOAD_BYTES, headers={"Content-Type": "application/octet-stream"})
    r = c.getresponse()
    got = r.read().decode()
    assert r.status == 200 and got == str(UPLOAD_BYTES), f"an upload of {UPLOAD_BYTES} bytes was answered {r.status} {got}"
    print(f"{url}: an upload of {UPLOAD_BYTES >> 20} MiB went through whole")


if __name__ == "__main__":
    if sys.argv[1] == "serve":
        http.server.ThreadingHTTPServer(("127.0.0.1", 8443), Backend).serve_forever()
    else:
        check(sys.argv[2])
