#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_ID="${1:?Использование: scripts/run_playtest.sh PT-001}"
BUILD_REVISION="$(git -C "$PROJECT_DIR" rev-parse --short HEAD)"

exec "$GODOT_BIN" --path "$PROJECT_DIR" -- \
    "--playtest-session=$SESSION_ID" \
    "--playtest-build=$BUILD_REVISION"
