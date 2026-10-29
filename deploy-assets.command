#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
status=0
python3 tools/asset_center/deploy.py || status=$?
if [ -t 0 ]; then
    read -r -p "Press Enter to close..."
fi
exit "$status"
