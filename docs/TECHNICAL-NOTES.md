# Technical notes

## Why this exists

Mosaic's Palette 2 and CANVAS OctoPrint plugins are legacy software. Their final
public releases were built for an older OctoPrint/Python dependency ecosystem.

A modern install can fail for several independent reasons:

- dependency declarations incompatible with modern Python packages;
- `ruamel.yaml` packaging/version changes;
- paho-mqtt 2.x callback API changes;
- OctoPrint UI/DOM changes that expose old CANVAS theme assumptions.

The goal here is to apply narrowly scoped compatibility patches while leaving
Mosaic's core Palette/CANVAS behavior intact.

## Known-good baseline

Initial community validation:

- OctoPrint 1.11.8
- Python 3.11 virtualenv
- OctoPi
- Palette 2S Pro
- CANVAS cloud integration
- custom CANVAS thumbnail rendering
- current-OctoPrint CANVAS theme compatibility

## Do not blindly copy an entire site-packages tree

The installer downloads the upstream plugins and applies reproducible changes.
Only genuinely custom code should live in `plugins/`.

That makes the repository auditable and avoids publishing unrelated packages,
machine-specific configuration, or secrets.

## Why keep paho-mqtt 2.x

Older community fixes often pinned `paho-mqtt<2` or modified the CANVAS MQTT
client constructor. Testing on the known-good 2026 setup confirmed that
`paho-mqtt==2.1.0` still accepts the original legacy constructor and
successfully connects using Callback API v1, while emitting a deprecation
warning.

The installer therefore pins `paho-mqtt==2.1.0` and deliberately leaves the
Mosaic MQTT source unchanged.

## CANVAS Python 3 runtime fixes

Two additional problems occur in CANVAS 3.0.3 on the tested modern environment.

First, CANVAS calls `platform.linux_distribution()`, an API that is no longer
available in modern Python. The installer replaces that call with
`platform.freedesktop_os_release()`.

Second, an OctoPrint `ClientOpened` event can arrive before CANVAS has assigned
`self.canvas`. The installer initializes `self.canvas = None` in
`CanvasPlugin.__init__()` so the existing event-handler logic remains valid
during early startup.

Both patches are applied to the freshly downloaded upstream CANVAS source
before pip installation.

## Verification

`./install.sh --check` performs a non-destructive preflight without requiring
root privileges.

After installation, `scripts/verify.sh` checks Palette/CANVAS imports and
runtime health, while keeping known future OctoPrint compatibility warnings
separate from current runtime failures.

## Licensing

Do not copy Mosaic's entire plugin source into this repository unless its
license clearly allows redistribution in the intended form and all required
notices are preserved. Prefer a patch-and-download installer.
