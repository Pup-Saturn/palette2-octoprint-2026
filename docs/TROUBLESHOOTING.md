# Troubleshooting

## Palette 2 plugin fails with `ModuleNotFoundError` involving `ruamel.yaml`

The original plugin metadata predates current `ruamel.yaml` packaging behavior.
Use the installer in this repo rather than installing the untouched 2021 ZIP.

Check the actual OctoPrint environment:

```bash
/opt/octopi/oprint/bin/python -c 'import ruamel.yaml; print(ruamel.yaml)'
```

## CANVAS is linked but remains offline

Check `octoprint.log` for MQTT exceptions.

A common failure on current Python environments is the paho-mqtt 2.x callback
API change. This repo patches CANVAS's `MQTT.py` to construct the client using
the legacy-compatible callback API explicitly.

## Plugin says installed but does not load

Run:

```bash
./scripts/verify.sh
```

and inspect:

```bash
grep -Ei 'canvas|palette2|Traceback|ImportError|ModuleNotFoundError' \
  ~/.octoprint/logs/octoprint.log | tail -200
```

## CANVAS UI colors are wrong

The original CANVAS theme targets an older OctoPrint UI. Modern OctoPrint can
leave stale blue, green/lime, or unstyled controls in settings/user dialogs.

Install the repository's `plugins/canvas-theme-compat/` package once the
known-good compatibility plugin has been captured and reviewed.

## Thumbnail missing

Confirm the custom plugin imports:

```bash
/opt/octopi/oprint/bin/python -c 'import octoprint_canvasthumbnails; print(octoprint_canvasthumbnails.__file__)'
```

Then inspect OctoPrint's plugin list/log for the thumbnail plugin.

## Palette and printer serial ports are confused

Do not guess device nodes. Use stable `/dev/serial/by-id/` paths where possible,
and verify which USB device is the printer and which is the Palette before
changing serial settings.
