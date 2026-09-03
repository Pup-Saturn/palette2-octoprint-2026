#!/usr/bin/env bash
set -Eeuo pipefail

OCTOPRINT_VENV="${OCTOPRINT_VENV:-/opt/octopi/oprint}"
OCTOPRINT_HOME="${OCTOPRINT_HOME:-$HOME/.octoprint}"

echo "=== OCTOPRINT PYTHON ==="
"$OCTOPRINT_VENV/bin/python" --version || true

echo
echo "=== RELEVANT PACKAGES ==="
"$OCTOPRINT_VENV/bin/pip" list 2>/dev/null \
  | grep -Ei 'octoprint|palette|canvas|mqtt|ruamel|dotenv|AWSIoT|jwt|dictdiffer|six' || true

echo
echo "=== INSTALLED SOURCE LOCATIONS ==="
"$OCTOPRINT_VENV/bin/python" - <<'PY'
mods = [
    "octoprint_palette2",
    "octoprint_canvas",
    "octoprint_canvasthumbnails",
]
for mod in mods:
    try:
        m = __import__(mod)
        print(f"{mod}: {m.__file__}")
    except Exception as exc:
        print(f"{mod}: not importable ({exc})")
PY

echo
echo "=== CUSTOM THEME REFERENCES ==="
grep -RIl --exclude='*.pyc' --exclude='*.log' \
  -E 'Saturn CANVAS Theme|CANVAS Theme' \
  "$OCTOPRINT_VENV/lib" "$OCTOPRINT_HOME" 2>/dev/null | head -50 || true

echo
echo "=== SYSTEMD UNITS ==="
systemctl cat octoprint.service 2>/dev/null || true
systemctl cat octoprint-status.service 2>/dev/null || true
