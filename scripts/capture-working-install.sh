#!/usr/bin/env bash
set -Eeuo pipefail

OCTOPRINT_VENV="${OCTOPRINT_VENV:-/opt/octopi/oprint}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/captured"

rm -rf "$DEST"
mkdir -p "$DEST/plugins" "$DEST/systemd"

echo "Capturing reusable source from known-good installation."
echo "No OctoPrint config, .env, logs, uploads, timelapses, or API keys are copied."

python3 - "$OCTOPRINT_VENV" "$DEST" <<'PY'
from pathlib import Path
import shutil, sys

venv = Path(sys.argv[1])
dest = Path(sys.argv[2])

site_dirs = sorted(venv.glob("lib/python*/site-packages"))
if not site_dirs:
    raise SystemExit("Could not find site-packages")
site = site_dirs[-1]

targets = {
    "octoprint_canvasthumbnails": "plugins/canvas-thumbnails-installed",
}

for package, rel in targets.items():
    src = site / package
    if src.exists():
        out = dest / rel
        shutil.copytree(
            src, out,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo")
        )
        print(f"Captured {package}: {src} -> {out}")
    else:
        print(f"Not found: {src}")
PY

# Capture a development/source tree if it exists. The backup manifest on the
# known-good system referred to OctoPrint-CanvasThumbnails.
for src in \
  "$HOME/OctoPrint-CanvasThumbnails" \
  "/opt/OctoPrint-CanvasThumbnails"
do
  if [[ -d "$src" ]]; then
    rsync -a \
      --exclude '.git' \
      --exclude '__pycache__' \
      --exclude '*.pyc' \
      --exclude 'build' \
      --exclude 'dist' \
      --exclude '*.egg-info' \
      "$src/" "$DEST/plugins/canvas-thumbnails-source/"
    echo "Captured thumbnail source tree: $src"
    break
  fi
done

# Find custom theme code by its known display text, but only inside Python
# site-packages. Copy candidate package directories for manual review.
SITE="$(find "$OCTOPRINT_VENV/lib" -type d -name site-packages -print -quit)"
if [[ -n "$SITE" ]]; then
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    pkg="$hit"
    while [[ "$pkg" != "$SITE" && "$(dirname "$pkg")" != "$SITE" ]]; do
      pkg="$(dirname "$pkg")"
    done
    if [[ "$(dirname "$pkg")" == "$SITE" ]]; then
      base="$(basename "$pkg")"
      case "$base" in
        *.dist-info|*.egg-info) continue ;;
      esac
      if [[ ! -e "$DEST/plugins/theme-candidate-$base" ]]; then
        cp -a "$pkg" "$DEST/plugins/theme-candidate-$base"
        find "$DEST/plugins/theme-candidate-$base" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
        find "$DEST/plugins/theme-candidate-$base" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
        echo "Captured theme candidate: $pkg"
      fi
    fi
  done < <(grep -RIl --exclude='*.pyc' -E 'Saturn CANVAS Theme' "$SITE" 2>/dev/null || true)
fi

# Safe systemd unit capture. These units may contain paths but should not contain
# API keys; nevertheless, inspect them before committing.
for unit in octoprint-status.service; do
  if systemctl cat "$unit" >/dev/null 2>&1; then
    systemctl cat "$unit" > "$DEST/systemd/$unit"
    echo "Captured $unit"
  fi
done

# Hard fail if something secret-looking slipped in.
if grep -RIlE \
  'OCTOPRINT_API_KEY=.+|api[_-]?key[=:][[:space:]]*[A-Za-z0-9_-]{16,}|BEGIN .*PRIVATE KEY' \
  "$DEST" >/dev/null 2>&1; then
  echo "ERROR: secret-looking material detected in captured/. Review and delete it." >&2
  exit 1
fi

echo
echo "Capture complete: $DEST"
echo "Review every file before committing."
