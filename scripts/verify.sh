#!/usr/bin/env bash
set -Eeuo pipefail

OCTOPRINT_VENV="${OCTOPRINT_VENV:-/opt/octopi/oprint}"
OCTOPRINT_SERVICE="${OCTOPRINT_SERVICE:-octoprint}"

INVOKING_USER="${SUDO_USER:-$USER}"
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"
OCTOPRINT_HOME="${OCTOPRINT_HOME:-$INVOKING_HOME/.octoprint}"
LOG="${OCTOPRINT_LOG:-$OCTOPRINT_HOME/logs/octoprint.log}"

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
    RECENT_LOG="$(mktemp)"
    trap 'rm -f "$RECENT_LOG"' EXIT

    tail -500 "$LOG" > "$RECENT_LOG"

    echo
    echo "=== PLUGIN HEALTH ==="

    if grep -Fq "successfully connected to canvas" "$RECENT_LOG"; then
        echo "OK: CANVAS MQTT connected"
    else
        echo "WARN: CANVAS MQTT connection confirmation not found"
    fi

    if grep -Fq "done initializing canvas" "$RECENT_LOG"; then
        echo "OK: CANVAS initialization completed"
    else
        echo "WARN: CANVAS initialization completion not found"
    fi

    if grep -Fq "Saturn CANVAS Theme loaded" "$RECENT_LOG"; then
        echo "OK: CANVAS theme compatibility plugin loaded"
    else
        echo "WARN: CANVAS theme load confirmation not found"
    fi

    if grep -Eq 'Palette 2 \(3\.0\.1\)|octoprint_palette2|palette-2 .*INFO' "$RECENT_LOG"; then
        echo "OK: Palette 2 plugin activity detected"
    else
        echo "WARN: Palette 2 activity not found"
    fi

    echo
    echo "=== PALETTE / CANVAS ERRORS ==="

    ERRORS="$(
        grep -Ei \
            'octoprint\.plugins\.(canvas|palette2).*(ERROR|CRITICAL)|Traceback|ModuleNotFoundError|ImportError' \
            "$RECENT_LOG" \
        | grep -Eiv \
            'octoprint\.plugins\.canvas - CRITICAL - (Linux|Python|OctoPrint):? ' \
        || true
    )"

    if [[ -n "$ERRORS" ]]; then
        printf '%s\n' "$ERRORS" | tail -40
    else
        echo "OK: no Palette/CANVAS runtime errors detected"
    fi

    echo
    echo "=== FUTURE COMPATIBILITY ==="

    if grep -Eq \
        'octoprint\.plugins\.(canvas|palette2).*autoescaping' \
        "$RECENT_LOG"; then
        echo "WARN: Palette/CANVAS template autoescaping needs review before OctoPrint 1.13"
    else
        echo "OK: no Palette/CANVAS autoescaping warning detected"
    fi

    if grep -Eq \
        'octoprint\.plugins\.(canvas|palette2).*is_api_protected' \
        "$RECENT_LOG"; then
        echo "WARN: Palette/CANVAS API protection declarations need review before a future OctoPrint release"
    else
        echo "OK: no Palette/CANVAS API-protection warning detected"
    fi

else
    echo
    echo "Log not found at $LOG; skipped log scan."
fi
