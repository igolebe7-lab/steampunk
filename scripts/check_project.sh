#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/run_tests.gd
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --quit-after 2

echo "Проверка проекта завершена успешно."
