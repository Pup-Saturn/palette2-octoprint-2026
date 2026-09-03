#!/usr/bin/env bash
set -Eeuo pipefail

PALETTE_URL="${PALETTE_URL:-https://gitlab.com/mosaic-mfg/palette-2-plugin/-/archive/3.0.1/palette-2-plugin-3.0.1.zip}"
CANVAS_URL="${CANVAS_URL:-https://gitlab.com/mosaic-mfg/canvas-plugin/-/archive/3.0.3/canvas-plugin-3.0.3.zip}"
OCTOPRINT_VENV="${OCTOPRINT_VENV:-/opt/octopi/oprint}"
INVOKING_USER="${SUDO_USER:-$USER}"
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"
OCTOPRINT_HOME="${OCTOPRINT_HOME:-$INVOKING_HOME/.octoprint}"
OCTOPRINT_SERVICE="${OCTOPRINT_SERVICE:-octoprint}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d)"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

say() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this installer with sudo."
[[ -x "$OCTOPRINT_VENV/bin/python" ]] || die "OctoPrint Python not found at $OCTOPRINT_VENV/bin/python"
[[ -x "$OCTOPRINT_VENV/bin/pip" ]] || die "OctoPrint pip not found at $OCTOPRINT_VENV/bin/pip"

say "Environment"
"$OCTOPRINT_VENV/bin/python" --version
"$OCTOPRINT_VENV/bin/pip" --version

if [[ -d "$OCTOPRINT_HOME" ]]; then
    BACKUP_PARENT="$(dirname "$OCTOPRINT_HOME")"
    BACKUP_FILE="$BACKUP_PARENT/octoprint-pre-palette2026-$STAMP.tar.gz"
    say "Backing up OctoPrint configuration to $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" \
        --exclude="$(basename "$OCTOPRINT_HOME")/logs" \
        --exclude="$(basename "$OCTOPRINT_HOME")/timelapse" \
        --exclude="$(basename "$OCTOPRINT_HOME")/data/backup" \
        -C "$BACKUP_PARENT" "$(basename "$OCTOPRINT_HOME")"
else
    say "OctoPrint home $OCTOPRINT_HOME not found; skipping config backup"
fi

command -v curl >/dev/null || die "curl is required"
command -v unzip >/dev/null || die "unzip is required"

say "Downloading Mosaic plugins"
curl -fL "$PALETTE_URL" -o "$WORKDIR/palette.zip"
curl -fL "$CANVAS_URL" -o "$WORKDIR/canvas.zip"
mkdir -p "$WORKDIR/palette" "$WORKDIR/canvas"
unzip -q "$WORKDIR/palette.zip" -d "$WORKDIR/palette"
unzip -q "$WORKDIR/canvas.zip" -d "$WORKDIR/canvas"

PALETTE_SRC="$(find "$WORKDIR/palette" -mindepth 1 -maxdepth 1 -type d | head -1)"
CANVAS_SRC="$(find "$WORKDIR/canvas" -mindepth 1 -maxdepth 1 -type d | head -1)"
[[ -f "$PALETTE_SRC/setup.py" ]] || die "Palette setup.py not found"
[[ -f "$CANVAS_SRC/setup.py" ]] || die "CANVAS setup.py not found"

say "Patching dependency metadata"
python3 - "$PALETTE_SRC/setup.py" "$CANVAS_SRC/setup.py" <<'PY'
from pathlib import Path
import re, sys

palette = Path(sys.argv[1])
canvas = Path(sys.argv[2])

def replace_requirements(path, requirements):
    text = path.read_text()
    replacement = "plugin_requires = " + repr(requirements)
    new, n = re.subn(
        r"plugin_requires\s*=\s*\[[\s\S]*?\]",
        replacement,
        text,
        count=1,
    )
    if not n:
        raise SystemExit(f"Could not locate plugin_requires in {path}")
    path.write_text(new)

replace_requirements(palette, [
    "ruamel.yaml==0.19.1",
    "python-dotenv==1.2.3",
    "six==1.17.0",
])

replace_requirements(canvas, [
    "ruamel.yaml==0.19.1",
    "python-dotenv==1.2.3",
    "AWSIoTPythonSDK==1.6.1",
    "PyJWT==2.13.0",
    "paho-mqtt==2.1.0",
    "dictdiffer==0.10.0",
])
PY

say "Using CANVAS legacy MQTT callback API"
echo "paho-mqtt 2.1.0 retains Callback API v1 compatibility; no CANVAS source patch required."

say "Installing patched Mosaic plugins into OctoPrint virtualenv"
"$OCTOPRINT_VENV/bin/pip" install --upgrade "$PALETTE_SRC"
"$OCTOPRINT_VENV/bin/pip" install --upgrade "$CANVAS_SRC"

install_local_plugin() {
    local dir="$1"
    local label="$2"
    if [[ -f "$dir/setup.py" || -f "$dir/pyproject.toml" ]]; then
        say "Installing $label"
        "$OCTOPRINT_VENV/bin/pip" install --upgrade "$dir"
    else
        say "$label source not bundled yet; skipping"
    fi
}

install_local_plugin "$SCRIPT_DIR/plugins/canvas-thumbnails" "CANVAS thumbnail compatibility plugin"

THEME_SRC="$SCRIPT_DIR/plugins/canvas-theme-compat"
THEME_DEST="$OCTOPRINT_HOME/plugins/saturn_canvas_theme"

if [[ -f "$THEME_SRC/__init__.py" ]]; then
    say "Installing CANVAS theme compatibility plugin"
    mkdir -p "$OCTOPRINT_HOME/plugins"
    rm -rf "$THEME_DEST"
    cp -a "$THEME_SRC" "$THEME_DEST"
    chown -R "$INVOKING_USER":"$(id -gn "$INVOKING_USER")" "$THEME_DEST"
else
    say "CANVAS theme compatibility source not bundled; skipping"
fi

say "Restarting OctoPrint"
systemctl restart "$OCTOPRINT_SERVICE"

say "Verification"
OCTOPRINT_VENV="$OCTOPRINT_VENV" \
OCTOPRINT_SERVICE="$OCTOPRINT_SERVICE" \
"$SCRIPT_DIR/scripts/verify.sh"

cat <<EOF

Installation pass complete.

Next:
  1. Open OctoPrint and confirm the CANVAS and Palette 2 tabs load.
  2. Re-link CANVAS if the device/account association was not retained.
  3. Connect the Palette and confirm it is detected.
  4. Upload a known CANVAS file and confirm thumbnail rendering.
  5. Review the OctoPrint settings dialog for theme holdouts.

Backup created before modification when $OCTOPRINT_HOME existed.
EOF
