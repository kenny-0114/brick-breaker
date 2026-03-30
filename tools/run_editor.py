#!/usr/bin/env python3
"""레벨 에디터 로컬 서버. GET으로 파일 읽기, PUT으로 파일 쓰기, DELETE로 삭제를 처리한다."""
import http.server
import json
import os
import sys
import webbrowser
from pathlib import Path
from urllib.parse import unquote

PORT = 8190
PROJECT_ROOT = Path(__file__).resolve().parent.parent
LEVELS_DIR = PROJECT_ROOT / "data" / "levels"

class EditorHandler(http.server.SimpleHTTPRequestHandler):
    """정적 파일 서빙 + 레벨 파일 쓰기/삭제를 처리하는 핸들러."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PROJECT_ROOT), **kwargs)

    def do_PUT(self):
        """레벨 JSON 파일을 저장한다."""
        path = LEVELS_DIR / unquote(self.path.split("/")[-1])
        if not path.suffix == ".json":
            self.send_error(400, "JSON 파일만 저장 가능")
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            json.loads(body)  # JSON 유효성 검증
        except json.JSONDecodeError:
            self.send_error(400, "유효하지 않은 JSON")
            return
        path.write_bytes(body)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"ok": True}).encode())

    def do_DELETE(self):
        """레벨 파일을 삭제한다."""
        path = LEVELS_DIR / unquote(self.path.split("/")[-1])
        if path.exists() and path.suffix == ".json":
            path.unlink()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True}).encode())
        else:
            self.send_error(404, "파일 없음")

    def log_message(self, format, *args):
        pass  # 로그 끄기


if __name__ == "__main__":
    os.chdir(PROJECT_ROOT)
    server = http.server.HTTPServer(("localhost", PORT), EditorHandler)
    url = f"http://localhost:{PORT}/tools/level_editor.html"
    print(f"Level Editor: {url}")
    print("종료: Ctrl+C")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료.")
        server.server_close()
