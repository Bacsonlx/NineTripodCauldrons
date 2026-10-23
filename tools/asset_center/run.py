#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Nine Tripod Cauldrons - Asset Center Launcher
九鼎 · 十日 | 资产管理中心启动器
"""

import sys
import socket
import argparse
import webbrowser
import threading
import time
from pathlib import Path
current_dir = Path(__file__).resolve().parent
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))

from server import run_server

def is_port_available(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) != 0

def find_available_port(start_port=8899, max_attempts=20):
    for p in range(start_port, start_port + max_attempts):
        if is_port_available(p):
            return p
    return start_port

def main():
    parser = argparse.ArgumentParser(description="九鼎 · 十日 资产管理中心启动器")
    parser.add_argument("--port", type=int, default=8899, help="服务监听端口（默认: 8899）")
    parser.add_argument("--no-browser", action="store_true", help="不自动打开浏览器")
    args = parser.parse_args()

    port = find_available_port(args.port)
    url = f"http://localhost:{port}"

    if not args.no_browser:
        def open_browser():
            time.sleep(0.8)
            print(f"正在打开浏览器: {url}")
            webbrowser.open(url)
        threading.Thread(target=open_browser, daemon=True).start()

    run_server(port)

if __name__ == "__main__":
    main()
