#!/usr/bin/env bash
set -Eeuo pipefail

OCTOPRINT_VENV="${OCTOPRINT_VENV:-/opt/octopi/oprint}"
OCTOPRINT_SERVICE="${OCTOPRINT_SERVICE:-octoprint}"
LOG="${OCTOPRINT_LOG:-$HOME/.octoprint/logs/octoprint.log}"

echo "=== SERVICE ==="
systemctl is-active "$OCTOPRINT_SERVICE"

echo
echo "=== PYTHON IMPORTS ==="
"$OCTOPRINT_VENV/bin/python" - <<'PY'
mods = [
    "octoprint_palette2",
    "octoprint_canvas",
]
for mod in mods:
    try:
        imported = __import__(mod)
        print(f"OK: {mod} -> {getattr(imported, '__file__', 'unknown')}")
    except Exception as exc:
        print(f"FAILED: {mod}: {exc}")
        raise
PY

echo
echo "=== DEPENDENCIES ==="
"$OCTOPRINT_VENV/bin/python" - <<'PY'
import paho.mqtt
import ruamel.yaml
print("OK: paho-mqtt import")
print("OK: ruamel.yaml import")
PY

if [[ -f "$LOG" ]]; then
    echo
    echo "=== RECENT LOAD ERRORS ==="
    if tail -500 "$LOG" | grep -Ei 'palette2|canvas|ModuleNotFoundError|ImportError|Traceback' | tail -80; then
        :
    fi
else
    echo
    echo "Log not found at $LOG; skipped log scan."
fi
