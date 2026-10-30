import http.server, socketserver, os, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.abspath(ROOT), **kwargs)

    def end_headers(self):
        # local preview only: stop the browser caching HTML, CSS and JS while editing
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        rel = path.lstrip("/")
        full = os.path.join(os.path.abspath(ROOT), rel)
        if rel and not os.path.splitext(rel)[1] and os.path.exists(full + ".html"):
            full += ".html"
        return full


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
    print("serving on http://127.0.0.1:%d" % PORT, flush=True)
    httpd.serve_forever()
