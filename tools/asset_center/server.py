#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Nine Tripod Cauldrons - Asset Center Local HTTP Server
九鼎 · 十日 | 资产管理中心本地服务
"""

import os
import sys
import json
import mimetypes
import base64
import hmac
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import urllib.parse

current_dir = Path(__file__).resolve().parent
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))

from sync import (
    WORKSPACE_ROOT,
    get_full_dataset,
    update_single_asset,
    create_new_asset
)

WEB_DIR = Path(__file__).resolve().parent / "web"

class AssetCenterHandler(SimpleHTTPRequestHandler):
    """Custom request handler supporting API endpoints and media streaming."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def log_message(self, format, *args):
        # Concise logging
        sys.stdout.write(f"[AssetCenter] {self.address_string()} - {format % args}\n")

    def end_headers(self):
        # Enable CORS and disable aggressive caching for local dev
        if not os.environ.get("ASSET_CENTER_PASSWORD"):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def authorize(self):
        password = os.environ.get("ASSET_CENTER_PASSWORD", "")
        if not password and os.environ.get("ASSET_CENTER_AUTH_REQUIRED") != "1":
            return True
        username = os.environ.get("ASSET_CENTER_USERNAME", "admin")
        expected = "Basic " + base64.b64encode(
            f"{username}:{password}".encode("utf-8")
        ).decode("ascii")
        supplied = self.headers.get("Authorization", "")
        if password and hmac.compare_digest(supplied.encode(), expected.encode()):
            return True
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Jiuding Asset Center", charset="UTF-8"')
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

    def do_HEAD(self):
        if self.authorize():
            super().do_HEAD()

    def do_OPTIONS(self):
        if not self.authorize():
            return
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if not self.authorize():
            return
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/data":
            self.handle_get_data()
        elif path.startswith("/media/"):
            self.handle_media(path[len("/media/"):])
        else:
            # Default static files in web/
            super().do_GET()

    def do_POST(self):
        if not self.authorize():
            return
        if os.environ.get("ASSET_CENTER_PASSWORD"):
            origin = self.headers.get("Origin")
            public_origin = os.environ.get("ASSET_CENTER_PUBLIC_ORIGIN", "").rstrip("/")
            same_host = origin and urllib.parse.urlsplit(origin).netloc == self.headers.get("Host")
            if self.headers.get("Sec-Fetch-Site") == "cross-site" or (
                origin and origin.rstrip("/") != public_origin and not same_host
            ):
                self.send_error_response(403, "Cross-origin writes are forbidden")
                return
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            payload = json.loads(body) if body else {}
        except Exception as e:
            self.send_error_response(400, f"JSON解析错误: {str(e)}")
            return

        if path == "/api/asset/update":
            self.handle_update_asset(payload)
        elif path == "/api/asset/create":
            self.handle_create_asset(payload)
        else:
            self.send_error_response(404, f"API endpoint not found: {path}")

    def handle_get_data(self):
        try:
            data = get_full_dataset()
            resp = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        except Exception as e:
            self.send_error_response(500, f"加载数据失败: {str(e)}")

    def handle_update_asset(self, payload):
        try:
            update_single_asset(payload)
            resp = json.dumps({
                "success": True,
                "message": f"资产 {payload.get('资产ID')} 已更新并同步保存到 CSV/JSON/Markdown！"
            }, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        except Exception as e:
            self.send_error_response(500, f"更新资产失败: {str(e)}")

    def handle_create_asset(self, payload):
        try:
            new_asset = create_new_asset(payload)
            resp = json.dumps({
                "success": True,
                "asset": new_asset,
                "message": f"新资产 {new_asset.get('资产ID')} 创建并同步完成！"
            }, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        except Exception as e:
            self.send_error_response(500, f"创建资产失败: {str(e)}")

    def handle_media(self, raw_rel_path):
        decoded = urllib.parse.unquote(raw_rel_path)
        safe_path = (WORKSPACE_ROOT / decoded).resolve()

        # Security check: must reside inside WORKSPACE_ROOT
        try:
            relative = safe_path.relative_to(WORKSPACE_ROOT)
        except ValueError:
            self.send_error_response(403, "Forbidden path access")
            return

        if os.environ.get("ASSET_CENTER_PASSWORD") and (
            not (relative.parts[:1] == ("assets",) or relative.parts[:2] == ("output", "art"))
            or safe_path.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg", ".svg"}
        ):
            self.send_error_response(403, "Forbidden media path")
            return

        if not safe_path.exists() or not safe_path.is_file():
            self.send_error_response(404, f"Media file not found: {decoded}")
            return

        # Determine MIME type
        mime_type, _ = mimetypes.guess_type(safe_path)
        if not mime_type:
            if safe_path.suffix.lower() == ".webp":
                mime_type = "image/webp"
            else:
                mime_type = "application/octet-stream"

        try:
            with open(safe_path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error_response(500, f"Error reading file: {str(e)}")

    def send_error_response(self, code, message):
        resp = json.dumps({"success": False, "error": message}, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

def run_server(port=8899):
    if os.environ.get("ASSET_CENTER_AUTH_REQUIRED") == "1" and not os.environ.get("ASSET_CENTER_PASSWORD"):
        raise RuntimeError("ASSET_CENTER_PASSWORD is required for public deployment")
    server_address = (os.environ.get("ASSET_CENTER_HOST", ""), port)
    httpd = ThreadingHTTPServer(server_address, AssetCenterHandler)
    print(f"\n=======================================================")
    print(f"  九鼎 · 十日 | 资产管理中心服务已启动")
    print(f"  本地访问地址: http://localhost:{port}")
    print(f"  数据接口: http://localhost:{port}/api/data")
    print(f"=======================================================\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n正在停止资产管理中心服务...")
        httpd.server_close()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    run_server(port)
