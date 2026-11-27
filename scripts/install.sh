#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/scripts/build-app.sh"

TARGET="/Applications/Flockerwhisper.app"

echo "==> Stopping existing Flockerwhisper (if running)..."
pkill -x Flockerwhisper 2>/dev/null || true
sleep 0.3

echo "==> Installing to ${TARGET}..."
rm -rf "$TARGET"
cp -R "$ROOT_DIR/dist/Flockerwhisper.app" "$TARGET"

echo "==> Launching ${TARGET}..."
open "$TARGET"
echo "Done. Press Option + Space anywhere to dictate."
