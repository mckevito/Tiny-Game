#!/bin/bash
# Cloud sessions only: installs the official Godot 4.7.2 standard build so a session can import and run the headless
# tests before pushing. Runs in the background and is safe to rerun. Progress and the "ready" line: /tmp/session-start.log
set -euo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
echo '{"async": true, "asyncTimeout": 600000}'
V=4.7.2
NAME="Godot_v${V}-stable_linux.x86_64"
BIN="/opt/godot/${NAME}"
LOG=/tmp/session-start.log
SUDO=""; [ "$(id -u)" = "0" ] || SUDO="sudo -n"
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export GODOT=\"$BIN\"" >> "$CLAUDE_ENV_FILE"
{
  echo "start $(date -u +%H:%M:%S)"
  if [ ! -x "$BIN" ]; then
    tmp="$(mktemp -d)"
    curl -fsSL --retry 4 -o "$tmp/godot.zip" "https://github.com/godotengine/godot/releases/download/${V}-stable/${NAME}.zip"
    $SUDO mkdir -p /opt/godot
    $SUDO unzip -q -o "$tmp/godot.zip" -d /opt/godot
    rm -rf "$tmp"
  fi
  $SUDO ln -sf "$BIN" /usr/local/bin/godot
  echo "ready $(date -u +%H:%M:%S): $(godot --version 2>/dev/null | head -1)"
} >> "$LOG" 2>&1
