#!/usr/bin/env bash
set -euo pipefail

base=/data/home/jiuding-asset-center
workspace="$base/workspace"
archive="$base/incoming/release.tar"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$workspace" "$base/backups"

if sudo systemctl cat jiuding-asset-center.service >/dev/null 2>&1; then
    sudo systemctl stop jiuding-asset-center.service
fi
if [ -d "$workspace/docs/art" ]; then
    tar -czf "$base/backups/data-$stamp.tar.gz" -C "$workspace" docs/art
fi

# The archive contains changed code/media and first-install data under .seed/.
tar -xf "$archive" -C "$workspace"
python3 - "$workspace" <<'PY'
from pathlib import Path
import shutil
import sys
root = Path(sys.argv[1])
for source in (root / ".seed").rglob("*"):
    if source.is_file():
        destination = root / source.relative_to(root / ".seed")
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            shutil.copy2(source, destination)
PY
python3 -m py_compile "$workspace/tools/asset_center/server.py" "$workspace/tools/asset_center/sync.py"
sudo install -m 600 "$base/incoming/service.env" "$base/service.env"
sudo tee /etc/systemd/system/jiuding-asset-center.service >/dev/null <<EOF
[Unit]
Description=Jiuding Asset Center
After=network.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$workspace
EnvironmentFile=$base/service.env
ExecStart=/usr/bin/python3 $workspace/tools/asset_center/server.py 8899
Restart=on-failure
RestartSec=3
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$workspace/docs/art
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable jiuding-asset-center.service >/dev/null
sudo systemctl restart jiuding-asset-center.service
python3 - "$base/incoming/service.env" <<'PY'
import base64
import json
import sys
import time
import urllib.request
from pathlib import Path
env = dict(line.split("=", 1) for line in Path(sys.argv[1]).read_text().splitlines())
token = base64.b64encode(
    f"{env['ASSET_CENTER_USERNAME']}:{env['ASSET_CENTER_PASSWORD']}".encode()
).decode()
for attempt in range(30):
    try:
        req = urllib.request.Request("http://127.0.0.1:8899/api/data",
                                     headers={"Authorization": "Basic " + token})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.load(response)
        if not data["assets"]:
            raise RuntimeError("Asset dataset is empty")
        print(json.dumps({"assets": len(data["assets"]), "stats": data["stats"]}, ensure_ascii=False))
        break
    except Exception:
        if attempt == 29:
            raise
        time.sleep(1)
PY
# Only a healthy release becomes the baseline for the next incremental upload.
cp "$workspace/.release-manifest.json" "$base/deployed-manifest.json"
unlink "$archive"
unlink "$base/incoming/service.env"
echo "Service is healthy; data backup: $base/backups/data-$stamp.tar.gz (on updates)"
