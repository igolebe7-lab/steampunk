#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="$("$GODOT_BIN" --version)"

if [[ "$GODOT_VERSION" != 4.6.2.* ]]; then
    echo "Требуется Godot 4.6.2, найден: $GODOT_VERSION" >&2
    exit 1
fi

run_godot_checked() {
    local output
    local status

    set +e
    output="$("$GODOT_BIN" "$@" 2>&1)"
    status=$?
    set -e
    printf '%s\n' "$output"

    if ((status != 0)); then
        return "$status"
    fi
    if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed loading resource:' <<<"$output"; then
        echo "Godot сообщил об ошибке при коде завершения 0." >&2
        return 1
    fi
}

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
run_godot_checked --headless --path "$PROJECT_DIR" --script res://tests/run_tests.gd
run_godot_checked --headless --path "$PROJECT_DIR" --quit-after 2

echo "Проверка проекта завершена успешно."
